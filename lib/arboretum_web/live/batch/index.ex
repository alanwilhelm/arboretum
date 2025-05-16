defmodule ArboretumWeb.BatchLive.Index do
  use ArboretumWeb, :live_view

  alias Arboretum.BatchResults
  
  @impl true
  def mount(_params, _session, socket) do
    batches = BatchResults.get_batches_summary()
    
    {:ok, assign(socket, 
      batches: batches,
      page_title: "Batch Operations"
    )}
  end
  
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
  
  # Refresh the batches list 
  @impl true
  def handle_event("refresh", _params, socket) do
    batches = BatchResults.get_batches_summary()
    {:noreply, assign(socket, batches: batches)}
  end
  
  # Format the timestamp for display
  defp format_date(datetime) do
    Calendar.strftime(
      datetime, 
      "%Y-%m-%d %H:%M:%S", 
      :strftime
    )
  end
end