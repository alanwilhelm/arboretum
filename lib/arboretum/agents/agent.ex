defmodule Arboretum.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @valid_statuses ["active", "inactive", "error", "disabled_flapping"]

  schema "agents" do
    field :name, :string
    field :status, :string, default: "inactive"
    field :llm_config, :map
    field :prompts, :map
    field :abilities, {:array, :string}
    field :responsibilities, {:array, :string}
    field :retry_policy, :map, default: %{type: "fixed", max_retries: 3, delay_ms: 5000}
    field :last_error, :string

    timestamps()
  end

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name, :status, :llm_config, :prompts, :abilities, :responsibilities, :retry_policy, :last_error])
    |> validate_required([:name, :status, :llm_config, :prompts, :abilities, :responsibilities])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint(:name)
    |> validate_retry_policy()
    |> validate_llm_config()
  end

  defp validate_retry_policy(changeset) do
    case get_change(changeset, :retry_policy) do
      nil ->
        changeset

      retry_policy ->
        case retry_policy do
          %{type: "fixed", max_retries: max_retries, delay_ms: delay_ms} 
          when is_integer(max_retries) and is_integer(delay_ms) and max_retries >= 0 and delay_ms >= 0 ->
            changeset

          %{type: "exponential_backoff", max_retries: max_retries, base_delay_ms: base_delay_ms, max_delay_ms: max_delay_ms}
          when is_integer(max_retries) and is_integer(base_delay_ms) and is_integer(max_delay_ms) 
            and max_retries >= 0 and base_delay_ms >= 0 and max_delay_ms >= base_delay_ms ->
            changeset

          _ ->
            add_error(changeset, :retry_policy, "invalid retry policy structure")
        end
    end
  end

  defp validate_llm_config(changeset) do
    case get_change(changeset, :llm_config) do
      nil ->
        changeset

      llm_config ->
        if is_map(llm_config) and Map.has_key?(llm_config, :api_key_env_var) and Map.has_key?(llm_config, :model) do
          changeset
        else
          add_error(changeset, :llm_config, "must contain at least api_key_env_var and model keys")
        end
    end
  end
end