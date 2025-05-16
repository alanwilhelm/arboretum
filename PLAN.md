# Arboretum Dynamic Agent Architecture - Detailed Implementation Plan

## 1. Goal
Develop a system of dynamic GenServer-based "Agents" within the Arboretum application. Each Agent's lifecycle and configuration will be driven by records in an `agents` database table. Agents will be capable of interacting with Large Language Models (LLMs) and executing predefined "abilities" based on their configuration. The system will include a Phoenix LiveView interface for managing and monitoring these agents.

## 2. Core Components & Supervision Tree
These components will be added to `Arboretum.Application`'s `start/2` function.

*   **`Arboretum.AgentRegistry`**
    *   Type: `Registry`
    *   Purpose: Allows dynamic GenServers (Agents) to be registered with unique names derived from their configuration (e.g., `agent.id` or `agent.name`), enabling targeted message passing.
    *   `child_spec`: `{Registry, keys: :unique, name: Arboretum.AgentRegistry}`

*   **`Arboretum.AgentDynamicSupervisor`**
    *   Type: `DynamicSupervisor`
    *   Purpose: Supervises the dynamically started `Arboretum.Agents.AgentServer` instances.
    *   `child_spec`: `{DynamicSupervisor, name: Arboretum.AgentDynamicSupervisor, strategy: :one_for_one}`

*   **`Arboretum.Agents.AgentServerManager`**
    *   Type: `GenServer`
    *   Purpose: Orchestrates the creation, termination, and updating of `AgentServer` instances based on database configurations and PubSub events.
    *   `child_spec`: `{Arboretum.Agents.AgentServerManager, []}`

## 3. Database Schema (`agents` table)
Migration will create the `agents` table. Ecto schema `Arboretum.Agents.Agent`.

*   `id` (Primary Key): `:uuid`, `autogenerate: true`
*   `name` (Unique Identifier): `:string` (consider `citext` for case-insensitivity if DB supports)
    *   Validation: `unique_constraint(:name)`, `validate_required([:name])`
*   `status`: `:string`, e.g., "active", "inactive", "error", "disabled_flapping"
    *   Default: `"inactive"`
    *   Validation: `validate_inclusion(:status, ["active", "inactive", "error", "disabled_flapping"])`
*   `llm_config`: `:map` (JSONB in DB)
    *   Structure: `%{api_key_env_var: "AGENT_XYZ_OPENAI_KEY", model: "gpt-4o", endpoint_url: "https://api.openai.com/v1/chat/completions", base_prompt_override: "You are a helpful assistant for Arboretum."}`
    *   API keys should be stored as environment variable names, resolved at runtime.
*   `prompts`: `:map` (JSONB in DB)
    *   Structure: `%{task_type_1: "Prompt template for task 1...", task_type_2: "Another prompt..."}`
*   `abilities`: `{:array, :string}` (JSONB array of strings in DB)
    *   Format: `"ModuleName.function_name/arity"`, e.g., `"Arboretum.Abilities.Summarizer.summarize_text/2"`
*   `responsibilities`: `{:array, :string}` (JSONB array of strings/tags in DB)
    *   Purpose: Defines what triggers an agent or what scheduled tasks it performs.
    *   Examples: `["process_new_document:pdf", "daily_report:sales", "cron:0 0 * * *"]`
*   `retry_policy`: `:map` (JSONB in DB)
    *   Structure: `%{type: "exponential_backoff", max_retries: 5, base_delay_ms: 1000, max_delay_ms: 60000}`
    *   Default: `%{type: "fixed", max_retries: 3, delay_ms: 5000}`
*   `last_error`: `:string` (TEXT in DB), nullable
*   `inserted_at`, `updated_at`: Standard Ecto timestamps.

## 4. Context Module: `Arboretum.Agents`
File: `lib/arboretum/agents/agents.ex`

*   `alias Arboretum.Repo`
*   `alias Arboretum.Agents.Agent`
*   `import Ecto.Query`

*   **Public Functions:**
    *   `list_active_agents() :: [%Agent{}]`
        *   `Agent |> where([a], a.status == "active") |> Repo.all()`
    *   `list_all_agents() :: [%Agent{}]`
    *   `get_agent(id :: Ecto.UUID.t()) :: %Agent{} | nil`
    *   `get_agent_by_name(name :: String.t()) :: %Agent{} | nil`
    *   `create_agent(attrs :: map()) :: {:ok, %Agent{}} | {:error, Ecto.Changeset.t()}`
        *   `%Agent{} |> Agent.changeset(attrs) |> Repo.insert()`
        *   On success, broadcast: `Phoenix.PubSub.broadcast(Arboretum.PubSub, "agents:changed", {:agent_created, agent})`
    *   `update_agent(%Agent{} = agent, attrs :: map()) :: {:ok, %Agent{}} | {:error, Ecto.Changeset.t()}`
        *   `Agent.changeset(agent, attrs) |> Repo.update()`
        *   On success, broadcast: `Phoenix.PubSub.broadcast(Arboretum.PubSub, "agents:changed", {:agent_updated, updated_agent})`
    *   `delete_agent(%Agent{} = agent) :: {:ok, %Agent{}} | {:error, Ecto.Changeset.t()}`
        *   `Repo.delete(agent)`
        *   On success, broadcast: `Phoenix.PubSub.broadcast(Arboretum.PubSub, "agents:changed", {:agent_deleted, agent})`
    *   `change_agent_status(agent_id :: Ecto.UUID.t(), new_status :: String.t()) :: {:ok, %Agent{}} | {:error, any()}`
        *   Fetches agent, updates status, broadcasts.
    *   `subscribe_agents_changed() :: :ok`
        *   `Phoenix.PubSub.subscribe(Arboretum.PubSub, "agents:changed")` (Helper for LiveViews)

*   **Ecto Schema `Arboretum.Agents.Agent`** (`lib/arboretum/agents/agent.ex`):
    *   Define `schema "agents"` with fields from section 3.
    *   `changeset(agent, attrs)` function with validations.

## 5. Orchestrator: `Arboretum.Agents.AgentServerManager`
File: `lib/arboretum/agents/agent_server_manager.ex`
`use GenServer`

*   **State:** `%{running_agents: %{agent_id :: Ecto.UUID.t() => pid()}}`

*   **`init(_opts)`:**
    1.  Fetch all active agents: `Arboretum.Agents.list_active_agents()`.
    2.  For each agent config:
        *   Call `start_agent_process(agent_config)`.
        *   Store `%{agent_config.id => pid}` in `state.running_agents`.
    3.  Subscribe to PubSub: `Phoenix.PubSub.subscribe(Arboretum.PubSub, "agents:changed")`.
    4.  Return `{:ok, state}`.

*   **`handle_info({:agent_created, %Agent{status: "active"} = agent_config}, state)`:**
    1.  If agent not already in `state.running_agents`:
        *   `start_agent_process(agent_config)` and update `state.running_agents`.
    2.  Return `{:noreply, new_state}`.

*   **`handle_info({:agent_updated, %Agent{} = agent_config}, state)`:**
    1.  `current_pid = state.running_agents[agent_config.id]`
    2.  If `agent_config.status == "active"`:
        *   If `current_pid` exists: Terminate existing (`stop_agent_process(current_pid, agent_config.id)`), then `start_agent_process(agent_config)`. (Restart strategy for simplicity).
        *   Else (was not running): `start_agent_process(agent_config)`.
    3.  Else (status is not "active"):
        *   If `current_pid` exists: `stop_agent_process(current_pid, agent_config.id)`.
    4.  Update `state.running_agents`.
    5.  Return `{:noreply, new_state}`.

*   **`handle_info({:agent_deleted, %Agent{} = agent_config}, state)`:**
    1.  If agent in `state.running_agents`:
        *   `stop_agent_process(state.running_agents[agent_config.id], agent_config.id)`.
        *   Remove from `state.running_agents`.
    2.  Return `{:noreply, new_state}`.

*   **`handle_info({:DOWN, ref, :process, pid, _reason}, state)`:**
    *   Find agent_id associated with pid that went down.
    *   Log the crash. Remove from `state.running_agents`.
    *   Consider logic for flap detection: if an agent crashes too often, `Arboretum.Agents.change_agent_status(agent_id, "disabled_flapping")`.
    *   Return `{:noreply, new_state}`.

*   **Helper `start_agent_process(agent_config)`:**
    1.  `child_spec = {Arboretum.Agents.AgentServer, {agent_config, Arboretum.AgentRegistry}}`
    2.  `DynamicSupervisor.start_child(Arboretum.AgentDynamicSupervisor, child_spec)`
    3.  If `{:ok, pid, _}` or `{:ok, pid}`:
        *   `Process.monitor(pid)`
        *   Return `pid`.
    4.  Else log error.

*   **Helper `stop_agent_process(pid, agent_id)`:**
    1.  `DynamicSupervisor.terminate_child(Arboretum.AgentDynamicSupervisor, pid)`.
    2.  Log termination.

## 6. Dynamic Agent: `Arboretum.Agents.AgentServer`
File: `lib/arboretum/agents/agent_server.ex`
`use GenServer`

*   **State:** `%{agent_config: %Agent{}, llm_client: %Arboretum.LLMClient{}, name_for_registry: any()}`

*   **`start_link({agent_config, registry_module})`:**
    *   `name_for_registry = {:via, registry_module, {Arboretum.AgentRegistry, agent_config.id}}` (or `agent_config.name`)
    *   `GenServer.start_link(__MODULE__, {agent_config, name_for_registry}, name: name_for_registry)`

*   **`init({agent_config, name_for_registry})`:**
    1.  `llm_client_instance = Arboretum.LLMClient.new(agent_config.llm_config)` (resolves API keys from env).
    2.  Schedule initial tasks based on `agent_config.responsibilities` (e.g., cron-like entries).
    3.  Return `{:ok, %{agent_config: agent_config, llm_client: llm_client_instance, name_for_registry: name_for_registry}}`.

*   **`handle_call({:trigger_responsibility, responsibility_key, payload}, _from, state)`:**
    1.  Find matching responsibility in `state.agent_config.responsibilities`.
    2.  Identify associated abilities.
    3.  For each ability: `execute_ability(ability_string, payload, state)`.
    4.  Return `{:reply, :ok, state}`. (Or result of abilities).

*   **`handle_info({:scheduled_task, responsibility_key}, state)`:**
    1.  Similar to `handle_call` for triggering responsibilities.
    2.  Reschedule next occurrence if it's a recurring task.
    3.  Return `{:noreply, state}`.

*   **Helper `execute_ability(ability_string, payload, state)`:**
    1.  Parse `ability_string` (e.g., `"MyModule.my_fun/2"`) into `{MyModule, :my_fun, 2}`.
        *   Use `String.split`, `String.to_atom`, `String.to_integer`.
        *   Security: Validate module against an allow-list of `Arboretum.Abilities.*` modules.
    2.  Construct arguments: `[payload, state.agent_config, state.llm_client]`. Ensure arity matches.
    3.  Call `safe_apply(module, fun, args, state.agent_config.retry_policy)`.
    4.  Handle result: log, update `last_error` in DB via context.

*   **Helper `safe_apply(module, fun, args, retry_policy)`:**
    *   Implement retry logic based on `retry_policy`.
    *   `try do apply(module, fun, args) rescue e -> {:error, e} catch kind, reason -> {:exit, {kind, reason}} end`
    *   Log extensively.
    *   Return `{:ok, result}` or `{:error, reason}`.

## 7. Shared Components

*   **`Arboretum.LLMClient`** (`lib/arboretum/llm_client.ex`)
    *   `defstruct api_key: nil, model: nil, endpoint_url: nil, base_prompt: nil, http_client: Tesla`
    *   `new(llm_service_config :: map()) :: %__MODULE__{}`:
        *   Resolves `api_key_env_var` to actual key using `System.get_env/1`.
        *   Initializes HTTP client (e.g., Tesla with middleware for JSON, retries, rate limiting if possible).
    *   `query(client :: %__MODULE__{}, prompt :: String.t(), query_opts :: map()) :: {:ok, response_map} | {:error, reason}`:
        *   Constructs request payload for the specific LLM API.
        *   Makes HTTP call. Handles responses, errors.

*   **Ability Behaviour** (`lib/arboretum/abilities/ability.ex`)
    *   `defmodule Arboretum.Abilities.Ability do`
    *   `  @callback handle(payload :: any(), agent_config :: %Arboretum.Agents.Agent{}, llm_client :: %Arboretum.LLMClient{}) :: {:ok, any()} | {:error, any()}`
    *   `end`
    *   Ability modules (e.g., `lib/arboretum/abilities/summarizer.ex`) will `use Arboretum.Abilities.Ability` and implement `handle/3`.

## 8. LiveView Components (`lib/arboretum_web/live/agent/`)
*   **`AgentLive.Index`** (`index.ex`, `index.html.heex`)
    *   Displays a list of all agents.
    *   `mount/3`: Fetches all agents using `Arboretum.Agents.list_all_agents()`, subscribes via `Arboretum.Agents.subscribe_agents_changed()`. Assigns agents to socket.
    *   `handle_info({:agent_created | :agent_updated | :agent_deleted, _}, socket)`: Re-fetches agents and updates socket assigns to reflect changes.
    *   Table columns: Name, Status, # Abilities, # Responsibilities, Last Error (summary).
    *   Links to `AgentLive.Show` for each agent.
    *   Link/button to `AgentLive.FormComponent` (for new agent).

*   **`AgentLive.Show`** (`show.ex`, `show.html.heex`)
    *   Displays details of a single agent.
    *   `mount/3`: Fetches agent by ID using `Arboretum.Agents.get_agent(id)`, subscribes.
    *   `handle_info`: Updates agent details if changed.
    *   Displays all fields from the `Agent` schema.
    *   Buttons: "Edit" (to `AgentLive.FormComponent`), "Delete" (with confirmation modal).
    *   Potentially a section to trigger responsibilities manually or view recent activity logs (future enhancement).

*   **`AgentLive.FormComponent`** (`form_component.ex`, `form_component.html.heex`)
    *   A modal or separate page for creating/editing agents.
    *   `mount/3`: If editing, fetches agent. If new, initializes an empty changeset.
    *   Uses a `Phoenix.HTML.Form` (`<.form let={f} for={@changeset} ...>`).
    *   Fields for all editable `Agent` attributes (name, status, llm_config as text/JSON, prompts as text/JSON, abilities as list of strings, responsibilities as list of strings, retry_policy as text/JSON).
    *   `handle_event("validate", %{"agent" => agent_params}, socket)`: Calls `Arboretum.Agents.Agent.changeset/2`.
    *   `handle_event("save", %{"agent" => agent_params}, socket)`: Calls `Arboretum.Agents.create_agent/1` or `update_agent/2`. Redirects or sends success message on completion. Handles errors by re-rendering form with changeset errors.

*   **Router (`lib/arboretum_web/router.ex`)**
    *   Add routes for agent LiveViews:
        ```elixir
        scope "/agents", ArboretumWeb do
          pipe_through :browser
          live "/", AgentLive.Index, :index
          live "/new", AgentLive.FormComponent, :new
          live "/:id", AgentLive.Show, :show
          live "/:id/edit", AgentLive.FormComponent, :edit
        end
        ```

## 9. Roadmap (Refined with LiveView)
1.  **Phase 1: Core Infrastructure (DB, Supervisor, Basic Agent)**
    *   1.1. Create migration for `agents` table.
    *   1.2. Define `Arboretum.Agents.Agent` Ecto schema and changesets.
    *   1.3. Implement `Arboretum.Agents` context module (basic CUD, no PubSub yet).
    *   1.4. Add `AgentRegistry`, `AgentDynamicSupervisor` to `Arboretum.Application`.
    *   1.5. Implement `Arboretum.Agents.AgentServerManager` (init loads from DB, no PubSub yet).
    *   1.6. Implement basic `Arboretum.Agents.AgentServer` (init, logs config).
    *   1.7. Test: Manually insert an agent, see if `AgentServerManager` starts it, and `AgentServer` logs its config.
2.  **Phase 2: Dynamic Updates & PubSub**
    *   2.1. Add PubSub broadcasting to `Arboretum.Agents` CUD functions and `subscribe_agents_changed/0` helper.
    *   2.2. Implement PubSub handling in `AgentServerManager` (`handle_info` for created/updated/deleted).
    *   2.3. Test: Create/update/delete agents via IEx, verify `AgentServerManager` starts/stops/restarts corresponding `AgentServer` processes.
3.  **Phase 3: Basic LiveView UI**
    *   3.1. Implement `AgentLive.Index` to list agents and react to PubSub.
    *   3.2. Implement `AgentLive.Show` to display agent details.
    *   3.3. Implement `AgentLive.FormComponent` for creating and editing agents.
    *   3.4. Add routes to `router.ex`.
    *   3.5. Test: CRUD agents through the LiveView interface.
4.  **Phase 4: Abilities & LLM Interaction**
    *   4.1. Define `Arboretum.Abilities.Ability` behaviour.
    *   4.2. Implement `Arboretum.LLMClient` (basic version, e.g., for OpenAI).
    *   4.3. Implement `AgentServer`'s `execute_ability` and `safe_apply` logic (initially without full retry).
    *   4.4. Create a simple "echo" ability: `Arboretum.Abilities.Echo.handle/3` that returns its payload.
    *   4.5. Add `handle_call({:trigger_responsibility, ...})` to `AgentServer`.
    *   4.6. Test: Trigger echo ability on a running agent via `GenServer.call` (or a temporary button in `AgentLive.Show`).
5.  **Phase 5: Advanced Features & Polish**
    *   5.1. Implement full retry logic in `safe_apply`.
    *   5.2. Implement scheduled tasks in `AgentServer` based on `responsibilities`.
    *   5.3. Develop a more complex ability (e.g., text summarization using `LLMClient`).
    *   5.4. Enhance LiveView UI: better display for JSON fields, action buttons, status indicators.
    *   5.5. Observability: Add Telemetry events, integrate with LiveDashboard.
    *   5.6. Resilience: Implement ability allow-list, secure API key handling (e.g. libvault if needed), flap detection in `AgentServerManager`.
6.  **Phase 6: Testing & Documentation**
    *   6.1. Write comprehensive unit and integration tests, including LiveView tests.
    *   6.2. Document the agent system architecture and usage.

This detailed plan provides a clearer path for implementation, now including the LiveView frontend.