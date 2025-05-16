defmodule Arboretum.BatchResults.BatchResult do
  @moduledoc """
  Schema for batch results.
  
  Represents a result from a batch LLM query operation. Each record contains:
  - The batch ID it belongs to
  - The agent that made the query
  - The prompt and response
  - Additional metadata
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "batch_results" do
    field :batch_id, :string
    field :agent_id, :binary_id
    field :agent_name, :string
    field :agent_index, :integer
    field :prompt, :string
    field :response, :string
    field :metadata, :map, default: %{}
    field :processed, :boolean, default: false
    
    timestamps()
  end
  
  @doc """
  Creates a changeset for a batch result.
  """
  def changeset(batch_result, attrs) do
    batch_result
    |> cast(attrs, [:batch_id, :agent_id, :agent_name, :agent_index, :prompt, :response, :metadata, :processed])
    |> validate_required([:batch_id, :agent_id, :prompt, :response])
  end
end