defmodule ArboretumWeb.AgentLive.Index do
  use ArboretumWeb, :live_view

  alias Arboretum.Agents
  
  # Helper functions for the template
  defp status_badge_class(status) do
    base_class = "px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
    
    status_specific_class = case status do
      "active" -> "bg-green-100 text-green-800"
      "inactive" -> "bg-gray-100 text-gray-800"
      "error" -> "bg-red-100 text-red-800"
      "disabled_flapping" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
    
    "#{base_class} #{status_specific_class}"
  end
  
  defp error_summary(nil), do: "None"
  defp error_summary(error) when is_binary(error) do
    if String.length(error) > 30 do
      "#{String.slice(error, 0, 30)}..."
    else
      error
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Agents.subscribe_agents_changed()
    
    {:ok, assign(socket, :agents, list_agents())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Agents")
    |> assign(:agent, nil)
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Agent")
    |> assign(:agent, %Arboretum.Agents.Agent{
      status: "inactive",
      llm_config: %{},
      prompts: %{},
      abilities: [],
      responsibilities: [],
      retry_policy: %{}
    })
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Agent")
    |> assign(:agent, Agents.get_agent(id))
  end

  @impl true
  def handle_info({:agent_created, _agent}, socket) do
    {:noreply, assign(socket, :agents, list_agents())}
  end

  @impl true
  def handle_info({:agent_updated, _agent}, socket) do
    {:noreply, assign(socket, :agents, list_agents())}
  end

  @impl true
  def handle_info({:agent_deleted, _agent}, socket) do
    {:noreply, assign(socket, :agents, list_agents())}
  end

  defp list_agents do
    Agents.list_all_agents()
  end
end