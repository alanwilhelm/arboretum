defmodule Arboretum.Repo.Migrations.CreateBatchResultsTable do
  use Ecto.Migration

  def change do
    create table(:batch_results, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :batch_id, :string, null: false
      add :agent_id, :uuid, null: false
      add :agent_name, :string
      add :agent_index, :integer
      add :prompt, :text, null: false
      add :response, :text, null: false
      add :metadata, :map
      add :processed, :boolean, default: false

      timestamps()
    end

    # Add indexes to optimize batch querying
    create index(:batch_results, [:batch_id])
    create index(:batch_results, [:agent_id])
    create index(:batch_results, [:batch_id, :agent_index])
    create index(:batch_results, [:batch_id, :processed])
  end
end
