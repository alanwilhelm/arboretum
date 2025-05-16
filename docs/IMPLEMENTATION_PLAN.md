# Arboretum Dynamic Agent Implementation Steps

## Phase 1: Core Infrastructure (DB, Supervisor, Basic Agent)
1.  **Generate Migration:**
    *   Command: `mix ecto.gen.migration create_agents_table`
    *   Edit migration file to define the `agents` table schema as specified in `PLAN.md` (Section 3: id, name, status, llm_config, prompts, abilities, responsibilities, retry_policy, last_error, timestamps).
    *   Run: `mix ecto.migrate`
2.  **Define Ecto Schema:**
    *   Create `lib/arboretum/agents/agent.ex`.
    *   Define `Arboretum.Agents.Agent` Ecto schema matching the `agents` table.
    *   Implement `changeset(agent, attrs)` function with validations for all fields.
3.  **Implement Context Module (Initial):**
    *   Create `lib/arboretum/agents/agents.ex`.
    *   Implement `Arboretum.Agents` context.
    *   Functions: `list_all_agents/0`, `get_agent/1`, `create_agent/1` (no PubSub yet), `update_agent/2` (no PubSub yet), `delete_agent/1` (no PubSub yet).
4.  **Update Application Supervision Tree:**
    *   Edit `lib/arboretum/application.ex`.
    *   Add `Arboretum.AgentRegistry` (as `{Registry, keys: :unique, name: Arboretum.AgentRegistry}`) to children.
    *   Add `Arboretum.AgentDynamicSupervisor` (as `{DynamicSupervisor, name: Arboretum.AgentDynamicSupervisor, strategy: :one_for_one}`) to children.
5.  **Implement AgentServerManager (Initial):**
    *   Create `lib/arboretum/agents/agent_server_manager.ex`.
    *   Implement `Arboretum.Agents.AgentServerManager` GenServer.
    *   `init/1`: Fetch active agents using `Arboretum.Agents.list_active_agents/0` (to be added to context). For each, call internal `start_agent_process/1`. No PubSub yet.
    *   Internal `start_agent_process/1`: `DynamicSupervisor.start_child(Arboretum.AgentDynamicSupervisor, child_spec)`. Child spec is `{Arboretum.Agents.AgentServer, {agent_config, Arboretum.AgentRegistry}}`. Monitor started process.
    *   Internal `stop_agent_process/2`: `DynamicSupervisor.terminate_child/2`.
    *   Add `Arboretum.Agents.AgentServerManager` to `Arboretum.Application` children.
6.  **Implement AgentServer (Basic):**
    *   Create `lib/arboretum/agents/agent_server.ex`.
    *   Implement `Arboretum.Agents.AgentServer` GenServer.
    *   `start_link/1`: Takes `{agent_config, registry_module}`, registers with `registry_module` via `agent_config.id`.
    *   `init/1`: Receives `{agent_config, name_for_registry}`. Store `agent_config`. Log `agent_config`.
7.  **Initial Test (Manual):**
    *   In IEx: `Arboretum.Agents.create_agent(%{name: "TestAgent1", status: "active", ...other_minimal_fields})`.
    *   Verify `AgentServerManager` starts a process for "TestAgent1".
    *   Verify `AgentServer` for "TestAgent1" logs its config.

## Phase 2: Dynamic Updates & PubSub
1.  **Enhance Context Module for PubSub:**
    *   In `lib/arboretum/agents/agents.ex`:
        *   Modify `create_agent/1`, `update_agent/2`, `delete_agent/1` to broadcast `{:agent_created, agent}`, `{:agent_updated, agent}`, `{:agent_deleted, agent}` respectively on `"agents:changed"` topic via `Phoenix.PubSub.broadcast(Arboretum.PubSub, "agents:changed", message)`.
        *   Add `subscribe_agents_changed/0` function: `Phoenix.PubSub.subscribe(Arboretum.PubSub, "agents:changed")`.
        *   Add `list_active_agents/0` and `change_agent_status/2` (which also broadcasts).
2.  **Implement PubSub Handling in AgentServerManager:**
    *   In `lib/arboretum/agents/agent_server_manager.ex`:
        *   `init/1`: Subscribe to `"agents:changed"` topic.
        *   `handle_info({:agent_created, %Agent{status: "active"} = agent_config}, state)`: If not running, `start_agent_process(agent_config)`, update internal state.
        *   `handle_info({:agent_updated, agent_config}, state)`: If status active & running -> restart; if active & not running -> start; if not active & running -> stop. Update internal state.
        *   `handle_info({:agent_deleted, agent_config}, state)`: If running, `stop_agent_process(pid, agent_config.id)`, update internal state.
        *   `handle_info({:DOWN, ...}, state)`: Log crash, remove from state, consider flap detection (call `Arboretum.Agents.change_agent_status/2`).
3.  **PubSub Test (IEx):**
    *   In IEx: `Arboretum.Agents.subscribe_agents_changed()`.
    *   Call `Arboretum.Agents.create_agent(...)`, `update_agent(...)`, `delete_agent(...)`.
    *   Verify `AgentServerManager` receives messages and starts/stops/restarts `AgentServer` processes correctly. Check running processes.

## Phase 3: Basic LiveView UI
1.  **Implement AgentLive.Index:**
    *   Create `lib/arboretum_web/live/agent/index.ex` and `index.html.heex`.
    *   `mount/3`: Fetch all agents (`Arboretum.Agents.list_all_agents/0`), subscribe (`Arboretum.Agents.subscribe_agents_changed/0`), assign to socket.
    *   `handle_info({:agent_created | :agent_updated | :agent_deleted, _}, socket)`: Re-fetch agents, update socket.
    *   Template: Display agents in a table (Name, Status). Link to Show and New.
2.  **Implement AgentLive.Show:**
    *   Create `lib/arboretum_web/live/agent/show.ex` and `show.html.heex`.
    *   `mount/3`: Fetch agent by ID (`Arboretum.Agents.get_agent/1`), subscribe, assign.
    *   `handle_info`: Update agent details if changed.
    *   Template: Display all agent fields. Links to Edit and Delete.
3.  **Implement AgentLive.FormComponent:**
    *   Create `lib/arboretum_web/live/agent/form_component.ex` and `form_component.html.heex`.
    *   `mount/3`: If editing, fetch agent. If new, init empty changeset (`Arboretum.Agents.Agent.changeset(%Arboretum.Agents.Agent{}, %{})`).
    *   Template: Use `<.form>` for agent attributes.
    *   `handle_event("validate", ...)`: Update changeset.
    *   `handle_event("save", ...)`: Call `Arboretum.Agents.create_agent/1` or `update_agent/2`. Redirect on success.
4.  **Add Routes:**
    *   Edit `lib/arboretum_web/router.ex`.
    *   Add `live "/agents", AgentLive.Index, :index`, etc. as per `PLAN.md` (Section 8).
5.  **LiveView Test:**
    *   Navigate browser to `/agents`.
    *   Perform CRUD operations on agents via the UI. Verify changes are reflected and processes start/stop.

## Phase 4: Abilities & LLM Interaction
1.  **Define Ability Behaviour:**
    *   Create `lib/arboretum/abilities/ability.ex`.
    *   Define `@callback handle(payload, agent_config, llm_client) :: {:ok, any} | {:error, any}`.
2.  **Implement LLMClient (Basic):**
    *   Create `lib/arboretum/llm_client.ex`.
    *   `defstruct [:api_key, :model, :endpoint_url, :base_prompt, :http_client]`.
    *   `new(llm_config)`: Resolves `api_key_env_var` from `System.get_env/1`. Initializes Tesla.
    *   `query(client, prompt, query_opts)`: Makes HTTP call to LLM.
3.  **Implement AgentServer Ability Execution:**
    *   In `lib/arboretum/agents/agent_server.ex`:
        *   `init/1`: Initialize `llm_client` using `Arboretum.LLMClient.new(agent_config.llm_config)`.
        *   Helper `execute_ability(ability_string, payload, state)`: Parse string, validate module, construct args, call `safe_apply`.
        *   Helper `safe_apply(module, fun, args, retry_policy)`: `try/rescue/catch apply/3`. Initial: no retry, just log.
4.  **Create Echo Ability:**
    *   Create `lib/arboretum/abilities/echo.ex`.
    *   `use Arboretum.Abilities.Ability`.
    *   Implement `handle(payload, _agent_config, _llm_client)`: `{:ok, payload}`.
5.  **Implement AgentServer Responsibility Trigger:**
    *   In `lib/arboretum/agents/agent_server.ex`:
        *   `handle_call({:trigger_responsibility, key, payload}, _from, state)`: Find abilities for key, call `execute_ability` for each.
6.  **Ability Test:**
    *   In IEx: `GenServer.call({:via, Arboretum.AgentRegistry, {Arboretum.AgentRegistry, agent_id}}, {:trigger_responsibility, :echo_test, %{data: "hello"}})`.
    *   Ensure agent has `"Arboretum.Abilities.Echo.handle/3"` in its `abilities` and a corresponding responsibility. Verify result.

## Phase 5: Advanced Features & Polish
1.  **Implement Full Retry Logic:**
    *   In `Arboretum.Agents.AgentServer.safe_apply/4`: Implement retry based on `retry_policy` from agent config.
2.  **Implement Scheduled Tasks:**
    *   In `Arboretum.Agents.AgentServer.init/1`: Parse `responsibilities` for "cron:" entries, schedule using `Process.send_after`.
    *   `handle_info({:scheduled_task, responsibility_key}, state)`: Trigger abilities, reschedule.
3.  **Develop Summarization Ability:**
    *   Create `lib/arboretum/abilities/summarizer.ex`.
    *   Implement `handle/3` to take text payload, use `state.llm_client` to call an LLM for summarization.
4.  **Enhance LiveView UI:**
    *   Improve display of JSON fields (e.g., pretty print or dedicated components).
    *   Add action buttons (e.g., trigger responsibility, change status directly from index/show).
    *   Clearer status indicators.
5.  **Observability:**
    *   Add `Telemetry.execute/3` calls in critical paths (`AgentServerManager` start/stop, `AgentServer` ability execution, `LLMClient` calls).
    *   Integrate with LiveDashboard: Define metrics and add to dashboard.
6.  **Resilience:**
    *   `AgentServer.execute_ability`: Implement allow-list for callable ability modules.
    *   Secure API key handling: Ensure keys are only read from env vars, not stored directly in DB or logs. Consider `runtime.exs` for env var loading.
    *   `AgentServerManager.handle_info({:DOWN,...})`: Implement robust flap detection (e.g., if agent restarts N times in M seconds, change status to "disabled_flapping" via context).

## Phase 6: Testing & Documentation
1.  **Comprehensive Tests:**
    *   Write unit tests for all new modules and functions.
    *   Write integration tests for agent lifecycle, PubSub interactions, and ability execution.
    *   Write LiveView tests for UI interactions and CRUD operations.
2.  **Documentation:**
    *   Update `README.md` with an overview of the agent system.
    *   Add inline documentation (`@doc`, `@moduledoc`) to all new modules and public functions.
    *   Refine `PLAN.md` if necessary to reflect final implementation details.