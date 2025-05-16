defmodule ArboretumWeb.AgentLive.Show do
  use ArboretumWeb, :live_view

  alias Arboretum.Agents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Agents.subscribe_agents_changed()
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Agent Details")
     |> assign(:agent, Agents.get_agent(id))
     |> assign(:live_action, socket.assigns.live_action || :show)}
  end

  @impl true
  def handle_info({:agent_updated, agent}, socket) do
    if socket.assigns.agent && socket.assigns.agent.id == agent.id do
      {:noreply, assign(socket, :agent, agent)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:agent_deleted, agent}, socket) do
    if socket.assigns.agent && socket.assigns.agent.id == agent.id do
      {:noreply, redirect(socket, to: ~p"/agents")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("change_status", %{"status" => status}, socket) do
    agent = socket.assigns.agent
    {:ok, _} = Agents.change_agent_status(agent.id, status)
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _, socket) do
    agent = socket.assigns.agent
    {:ok, _} = Agents.delete_agent(agent)

    {:noreply,
     socket
     |> put_flash(:info, "Agent deleted successfully")
     |> redirect(to: ~p"/agents")}
  end
  
  # Helper functions for display
  defp format_json(data) when is_map(data) do
    Jason.encode!(data, pretty: true)
  end
  
  defp format_list(items) when is_list(items) do
    Enum.join(items, "\n")
  end
  
  defp status_badge_class(status) do
    base_class = "px-3 py-1 inline-flex text-sm leading-5 font-semibold rounded-full"
    
    status_specific_class = case status do
      "active" -> "bg-green-100 text-green-800"
      "inactive" -> "bg-gray-100 text-gray-800"
      "error" -> "bg-red-100 text-red-800"
      "disabled_flapping" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
    
    "#{base_class} #{status_specific_class}"
  end
end