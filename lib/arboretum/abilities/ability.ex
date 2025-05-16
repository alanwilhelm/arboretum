defmodule Arboretum.Abilities.Ability do
  @moduledoc """
  A behaviour that defines the contract for agent abilities.
  
  Abilities are functions that can be invoked by agents to perform specific tasks.
  Each ability module should implement the `handle/3` callback, which receives:
  
  - A payload (any term)
  - The agent configuration
  - An LLM client for interacting with language models
  
  ## Example
  
  ```elixir
  defmodule Arboretum.Abilities.Echo do
    @moduledoc "A simple ability that returns its input"
    @behaviour Arboretum.Abilities.Ability
    
    @impl true
    def handle(payload, _agent_config, _llm_client) do
      {:ok, payload}
    end
  end
  ```
  """
  
  @doc """
  Handles a request to execute an ability with the given payload.
  
  ## Parameters
  
  - `payload` - Any term representing the input data for the ability.
  - `agent_config` - The %Arboretum.Agents.Agent{} configuration of the agent.
  - `llm_client` - An %Arboretum.LLMClient{} instance for interacting with language models.
  
  ## Returns
  
  - `{:ok, result}` - The ability executed successfully.
  - `{:error, reason}` - The ability failed to execute.
  """
  @callback handle(payload :: any(), agent_config :: Arboretum.Agents.Agent.t(), llm_client :: any()) ::
              {:ok, any()} | {:error, any()}
              
  @doc """
  A helper for modules that implement this behaviour.
  
  When used, it:
  - Declares that the module is an Ability
  - Ensures the module implements the Ability behaviour
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Arboretum.Abilities.Ability
      
      def __ability_name__ do
        __MODULE__
        |> to_string()
        |> String.split(".")
        |> List.last()
        |> String.downcase()
      end
    end
  end
end