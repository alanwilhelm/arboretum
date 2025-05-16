defmodule Arboretum.Abilities.Echo do
  @moduledoc """
  A simple ability that echoes back its input.
  
  This ability is useful for testing the agent's ability execution mechanism without introducing
  external dependencies or complex logic.
  """
  
  use Arboretum.Abilities.Ability
  require Logger
  
  @impl true
  def handle(payload, agent_config, _llm_client) do
    Logger.info("Echo ability called for agent #{agent_config.name} with payload: #{inspect(payload)}")
    
    response = %{
      echo: payload,
      timestamp: DateTime.utc_now(),
      agent_name: agent_config.name,
      agent_id: agent_config.id
    }
    
    {:ok, response}
  end
end