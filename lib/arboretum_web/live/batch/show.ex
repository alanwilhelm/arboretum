defmodule ArboretumWeb.BatchLive.Show do
  use ArboretumWeb, :live_view

  alias Arboretum.BatchResults
  
  @impl true
  def mount(%{"id" => batch_id}, _session, socket) do
    results = BatchResults.get_batch_results(batch_id)
    
    {:ok, assign(socket, 
      results: results,
      batch_id: batch_id,
      page_title: "Batch Results",
      show_prompt: nil,
      show_response: nil
    )}
  end
  
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
  
  # Refresh the results list
  @impl true
  def handle_event("refresh", _params, socket) do
    results = BatchResults.get_batch_results(socket.assigns.batch_id)
    {:noreply, assign(socket, results: results)}
  end
  
  # Toggle all as processed/unprocessed
  @impl true
  def handle_event("mark_all_processed", _params, socket) do
    batch_id = socket.assigns.batch_id
    # TODO: implement mark_batch_processed functionality
    
    results = BatchResults.get_batch_results(batch_id)
    {:noreply, assign(socket, results: results)}
  end
  
  # Delete all results for this batch
  @impl true
  def handle_event("delete_batch", _params, socket) do
    batch_id = socket.assigns.batch_id
    BatchResults.clear_batch(batch_id)
    
    {:noreply, 
      socket
      |> put_flash(:info, "Batch deleted successfully")
      |> redirect(to: ~p"/batches")}
  end
  
  # Show prompt details
  @impl true
  def handle_event("show_prompt", %{"id" => _id}, socket) do
    # TODO: implement get_result functionality
    result = nil
    {:noreply, assign(socket, show_prompt: result)}
  end
  
  # Show response details
  @impl true
  def handle_event("show_response", %{"id" => _id}, socket) do
    # TODO: implement get_result functionality
    result = nil
    {:noreply, assign(socket, show_response: result)}
  end
  
  # Close modal
  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_prompt: nil, show_response: nil)}
  end
  
  # Toggle processed status for a single result
  @impl true
  def handle_event("toggle_processed", %{"id" => _id}, socket) do
    # TODO: implement get_result and mark_processed functionality
    results = BatchResults.get_batch_results(socket.assigns.batch_id)
    {:noreply, assign(socket, results: results)}
  end
  
  # Format the timestamp for display
  defp format_date(datetime) do
    Calendar.strftime(
      datetime, 
      "%Y-%m-%d %H:%M:%S", 
      :strftime
    )
  end
  
  # Status badge class
  defp processed_badge_class(processed) do
    base_class = "px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
    
    if processed do
      "#{base_class} bg-green-100 text-green-800"
    else
      "#{base_class} bg-gray-100 text-gray-800"
    end
  end
  
  # Format content preview
  defp content_preview(content, max_length \\ 50) do
    if is_binary(content) do
      if String.length(content) > max_length do
        String.slice(content, 0, max_length) <> "..."
      else
        content
      end
    else
      "N/A"
    end
  end
end