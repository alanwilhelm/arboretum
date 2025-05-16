defmodule ArboretumWeb.AgentLive.FormComponent do
  use ArboretumWeb, :live_component

  alias Arboretum.Agents
  alias Arboretum.Agents.Agent
  
  # Helper functions for template
  defp format_json_field(changeset, field) do
    case Ecto.Changeset.get_field(changeset, field) do
      nil -> ""
      value when is_map(value) -> Jason.encode!(value, pretty: true)
      value -> Jason.encode!(value, pretty: true)
    end
  end
  
  defp format_list_field(changeset, field) do
    case Ecto.Changeset.get_field(changeset, field) do
      nil -> ""
      value when is_list(value) -> Enum.join(value, "\n")
      _ -> ""
    end
  end
  
  defp error_tag(changeset, field) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> case do
      %{^field => errors} when errors != [] ->
        Phoenix.HTML.raw("<div class=\"mt-1 text-sm text-red-600\">#{Enum.join(errors, ", ")}</div>")
      _ -> ""
    end
  end

  @default_llm_config %{
    api_key_env_var: "OPENAI_API_KEY",
    model: "gpt-4o",
    endpoint_url: "https://api.openai.com/v1/chat/completions",
    base_prompt: "You are a helpful assistant."
  }

  @default_retry_policy %{
    type: "fixed",
    max_retries: 3,
    delay_ms: 5000
  }

  @default_prompts %{
    default: "You are a helpful assistant. Please respond to the following query:"
  }

  @impl true
  def update(%{agent: agent} = assigns, socket) do
    changeset = Agents.change_agent(agent)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"agent" => agent_params}, socket) do
    # Convert JSON strings to maps/lists
    agent_params = parse_json_fields(agent_params)

    changeset =
      socket.assigns.agent
      |> Agents.change_agent(agent_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"agent" => agent_params}, socket) do
    # Convert JSON strings to maps/lists
    agent_params = parse_json_fields(agent_params)
    
    save_agent(socket, socket.assigns.action, agent_params)
  end

  defp save_agent(socket, :edit, agent_params) do
    case Agents.update_agent(socket.assigns.agent, agent_params) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_agent(socket, :new, agent_params) do
    case Agents.create_agent(agent_params) do
      {:ok, _agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # Helper to convert JSON strings to Elixir data structures
  defp parse_json_fields(params) do
    params
    |> parse_json_field("llm_config", @default_llm_config)
    |> parse_json_field("prompts", @default_prompts)
    |> parse_json_field("retry_policy", @default_retry_policy)
    |> parse_list_field("abilities")
    |> parse_list_field("responsibilities")
  end

  defp parse_json_field(params, field, default_value) do
    case params[field] do
      value when is_binary(value) and value != "" ->
        case Jason.decode(value) do
          {:ok, decoded} -> Map.put(params, field, decoded)
          {:error, _} -> Map.put(params, field, default_value)
        end
      nil -> Map.put(params, field, default_value)
      _ -> params
    end
  end

  defp parse_list_field(params, field) do
    case params[field] do
      value when is_binary(value) and value != "" ->
        items = 
          value
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
        
        Map.put(params, field, items)
        
      nil -> Map.put(params, field, [])
      _ -> params
    end
  end
end