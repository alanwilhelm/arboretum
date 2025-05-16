defmodule Arboretum.Repo.Migrations.CreateAgentsTable do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :status, :string, default: "inactive", null: false
      add :llm_config, :map, null: false
      add :prompts, :map, null: false
      add :abilities, {:array, :string}, null: false
      add :responsibilities, {:array, :string}, null: false
      add :retry_policy, :map, default: %{type: "fixed", max_retries: 3, delay_ms: 5000}, null: false
      add :last_error, :text

      timestamps()
    end

    create unique_index(:agents, [:name])
  end
end
