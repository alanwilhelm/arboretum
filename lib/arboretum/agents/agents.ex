defmodule Arboretum.Agents do
  @moduledoc """
  The Agents context.
  Provides functions for managing and interacting with agent configurations.
  """

  import Ecto.Query
  alias Arboretum.Repo
  alias Arboretum.Agents.Agent

  @doc """
  Returns the list of all agents.

  ## Examples

      iex> list_all_agents()
      [%Agent{}, ...]

  """
  def list_all_agents do
    Repo.all(Agent)
  end

  @doc """
  Returns the list of active agents.

  ## Examples

      iex> list_active_agents()
      [%Agent{}, ...]

  """
  def list_active_agents do
    Agent
    |> where([a], a.status == "active")
    |> Repo.all()
  end

  @doc """
  Gets a single agent by ID.

  Returns nil if the Agent does not exist.

  ## Examples

      iex> get_agent(123)
      %Agent{}

      iex> get_agent(456)
      nil

  """
  def get_agent(id) do
    Repo.get(Agent, id)
  end

  @doc """
  Gets a single agent by name.

  Returns nil if the Agent does not exist.

  ## Examples

      iex> get_agent_by_name("some_name")
      %Agent{}

      iex> get_agent_by_name("nonexistent")
      nil

  """
  def get_agent_by_name(name) do
    Repo.get_by(Agent, name: name)
  end

  @doc """
  Creates a new agent.

  ## Examples

      iex> create_agent(%{field: value})
      {:ok, %Agent{}}

      iex> create_agent(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_agent(attrs \\ %{}) do
    result =
      %Agent{}
      |> Agent.changeset(attrs)
      |> Repo.insert()
    
    case result do
      {:ok, agent} ->
        broadcast_change({:agent_created, agent})
        result
      _ ->
        result
    end
  end

  @doc """
  Updates an agent.

  ## Examples

      iex> update_agent(agent, %{field: new_value})
      {:ok, %Agent{}}

      iex> update_agent(agent, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_agent(%Agent{} = agent, attrs) do
    result =
      agent
      |> Agent.changeset(attrs)
      |> Repo.update()
    
    case result do
      {:ok, updated_agent} ->
        broadcast_change({:agent_updated, updated_agent})
        result
      _ ->
        result
    end
  end

  @doc """
  Deletes an agent.

  ## Examples

      iex> delete_agent(agent)
      {:ok, %Agent{}}

      iex> delete_agent(agent)
      {:error, %Ecto.Changeset{}}

  """
  def delete_agent(%Agent{} = agent) do
    result = Repo.delete(agent)
    
    case result do
      {:ok, deleted_agent} ->
        broadcast_change({:agent_deleted, deleted_agent})
        result
      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking agent changes.

  ## Examples

      iex> change_agent(agent)
      %Ecto.Changeset{data: %Agent{}}

  """
  def change_agent(%Agent{} = agent, attrs \\ %{}) do
    Agent.changeset(agent, attrs)
  end

  @doc """
  Changes an agent's status.

  ## Examples

      iex> change_agent_status(agent_id, "active")
      {:ok, %Agent{}}

      iex> change_agent_status(agent_id, "invalid_status")
      {:error, %Ecto.Changeset{}}

  """
  def change_agent_status(agent_id, new_status) do
    with %Agent{} = agent <- get_agent(agent_id),
         {:ok, updated_agent} <- update_agent(agent, %{status: new_status}) do
      # Note: update_agent already broadcasts the change
      {:ok, updated_agent}
    else
      nil -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  @doc """
  Subscribes to the 'agents:changed' topic via PubSub.
  
  This is useful for LiveViews that need to react to agent changes.
  
  ## Examples
  
      iex> subscribe_agents_changed()
      :ok
  
  """
  def subscribe_agents_changed do
    Phoenix.PubSub.subscribe(Arboretum.PubSub, "agents:changed")
  end
  
  # Private functions
  
  defp broadcast_change(message) do
    Phoenix.PubSub.broadcast(Arboretum.PubSub, "agents:changed", message)
  end
end