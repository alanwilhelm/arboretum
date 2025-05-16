defmodule Arboretum.Agents.AgentServer do
  @moduledoc """
  GenServer implementation for each individual agent.
  
  Each AgentServer instance:
  1. Holds its own agent configuration
  2. Registers with the Registry using its agent ID
  3. Executes abilities based on responsibilities
  """

  use GenServer
  require Logger
  alias Arboretum.Agents.Agent

  # Client API

  @doc """
  Starts an AgentServer process with the given configuration.
  
  ## Parameters
  
  - `{agent_config, registry_module}` - A tuple containing:
    - `agent_config` - The Agent struct with configuration
    - `registry_module` - The registry module (typically Registry)
  """
  def start_link({agent_config, registry_module}) do
    name_for_registry = {:via, registry_module, {Arboretum.AgentRegistry, agent_config.id}}
    GenServer.start_link(__MODULE__, {agent_config, name_for_registry}, name: name_for_registry)
  end

  # Server Callbacks

  @impl true
  def init({agent_config, name_for_registry}) do
    Logger.info("Starting AgentServer for #{agent_config.name} (#{agent_config.id})")
    
    # Log the agent configuration for debugging
    Logger.debug(fn -> "Agent configuration: #{inspect(agent_config)}" end)
    
    # Initialize the LLM client
    llm_client = Arboretum.LLMClient.new(agent_config.llm_config)
    
    state = %{
      agent_config: agent_config,
      name_for_registry: name_for_registry,
      llm_client: llm_client,
      scheduled_tasks: %{}
    }
    
    # Schedule cron-based responsibilities
    state = schedule_cron_responsibilities(state)
    
    {:ok, state}
  end

  @impl true
  def handle_info({:scheduled_task, responsibility_key}, state) do
    Logger.info("Executing scheduled task for responsibility #{responsibility_key}")
    
    # Extract payload from responsibility_key if it exists (format: "key:value")
    payload = 
      case String.split(responsibility_key, ":", parts: 2) do
        [_, value] -> %{data: value}
        _ -> %{}
      end
    
    # Execute abilities for this responsibility
    results = execute_all_abilities(payload, state)
    
    # Reschedule the task
    state = reschedule_task(responsibility_key, state)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(message, state) do
    Logger.debug("AgentServer for #{state.agent_config.name} received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, %{id: state.agent_config.id, name: state.agent_config.name, status: state.agent_config.status}, state}
  end

  @impl true
  def handle_call({:trigger_responsibility, responsibility_key, payload}, _from, state) do
    Logger.info("Triggering responsibility #{responsibility_key} for agent #{state.agent_config.name}")
    
    # Find responsibilities matching the key
    matching_responsibilities = 
      state.agent_config.responsibilities
      |> Enum.filter(fn responsibility ->
        String.starts_with?(responsibility, "#{responsibility_key}:")
      end)
    
    if Enum.empty?(matching_responsibilities) do
      Logger.warn("No matching responsibilities found for key #{responsibility_key}")
      {:reply, {:error, :no_matching_responsibility}, state}
    else
      # Execute all matching responsibilities
      results =
        Enum.map(matching_responsibilities, fn _responsibility ->
          # For now, we'll execute all abilities for the agent
          # In a more sophisticated implementation, we might map specific 
          # responsibilities to specific abilities
          execute_all_abilities(payload, state)
        end)
      
      {:reply, {:ok, results}, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("AgentServer for #{state.agent_config.name} (#{state.agent_config.id}) terminating: #{inspect(reason)}")
    :ok
  end
  
  # Execute all abilities for an agent
  defp execute_all_abilities(payload, state) do
    state.agent_config.abilities
    |> Enum.map(fn ability_string ->
      result = execute_ability(ability_string, payload, state)
      {ability_string, result}
    end)
  end
  
  # Execute a single ability
  defp execute_ability(ability_string, payload, state) do
    Logger.info("Executing ability #{ability_string} for agent #{state.agent_config.name}")
    
    # Parse the ability string into module, function, and arity
    with {:ok, {module, function, arity}} <- parse_ability_string(ability_string),
         true <- validate_ability_module(module),
         {:ok, args} <- build_ability_args(payload, state, arity) do
      
      # Apply the function with retry logic based on the agent's retry policy
      safe_apply(module, function, args, state.agent_config.retry_policy)
    else
      {:error, reason} ->
        Logger.error("Failed to execute ability #{ability_string}: #{inspect(reason)}")
        update_last_error(state.agent_config.id, "Failed to execute ability #{ability_string}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Parse an ability string in the format "Module.function/arity"
  defp parse_ability_string(ability_string) do
    case Regex.run(~r/^(.+)\.([^\/]+)\/(\d+)$/, ability_string) do
      [_, module_string, function_string, arity_string] ->
        module = 
          module_string
          |> String.split(".")
          |> Enum.map(&String.to_atom/1)
          |> Module.concat()
          
        function = String.to_atom(function_string)
        {arity, _} = Integer.parse(arity_string)
        
        {:ok, {module, function, arity}}
        
      _ ->
        {:error, "Invalid ability string format: #{ability_string}"}
    end
  end
  
  # Validate that the module is allowed to be called
  defp validate_ability_module(module) do
    module_string = to_string(module)
    
    if String.starts_with?(module_string, "Elixir.Arboretum.Abilities.") do
      true
    else
      {:error, "Module #{module_string} is not in the Arboretum.Abilities namespace"}
    end
  end
  
  # Build arguments for the ability function based on its arity
  defp build_ability_args(payload, state, arity) do
    case arity do
      3 -> {:ok, [payload, state.agent_config, state.llm_client]}
      _ -> {:error, "Unsupported arity: #{arity}"}
    end
  end
  
  # Execute a function with retry logic
  defp safe_apply(module, function, args, retry_policy) do
    max_retries = retry_policy["max_retries"] || 3
    safe_apply(module, function, args, retry_policy, 0, max_retries)
  end
  
  defp safe_apply(_module, _function, _args, _retry_policy, current_retry, max_retries) 
       when current_retry >= max_retries do
    {:error, "Max retries reached"}
  end
  
  defp safe_apply(module, function, args, retry_policy, current_retry, max_retries) do
    try do
      result = apply(module, function, args)
      result
    rescue
      e ->
        Logger.error("Error executing #{module}.#{function}/#{length(args)}: #{inspect(e)}")
        
        # Calculate delay based on retry policy
        delay_ms = calculate_delay(retry_policy, current_retry)
        
        if current_retry < max_retries do
          Logger.info("Retrying (#{current_retry + 1}/#{max_retries}) after #{delay_ms}ms...")
          :timer.sleep(delay_ms)
          safe_apply(module, function, args, retry_policy, current_retry + 1, max_retries)
        else
          {:error, "Max retries reached: #{inspect(e)}"}
        end
    catch
      kind, reason ->
        Logger.error("Caught #{kind} while executing #{module}.#{function}/#{length(args)}: #{inspect(reason)}")
        {:error, "#{kind}: #{inspect(reason)}"}
    end
  end
  
  # Calculate delay based on retry policy
  defp calculate_delay(retry_policy, current_retry) do
    policy_type = retry_policy["type"] || "fixed"
    
    case policy_type do
      "fixed" ->
        retry_policy["delay_ms"] || 5000
        
      "exponential_backoff" ->
        base_delay = retry_policy["base_delay_ms"] || 1000
        max_delay = retry_policy["max_delay_ms"] || 60000
        
        # Calculate exponential backoff: base_delay * 2^retry
        delay = base_delay * :math.pow(2, current_retry)
        
        # Cap at max_delay
        min(round(delay), max_delay)
        
      _ ->
        5000  # Default delay
    end
  end
  
  # Update the agent's last_error field in the database
  defp update_last_error(agent_id, error_message) do
    Task.start(fn ->
      agent = Arboretum.Agents.get_agent(agent_id)
      
      if agent do
        Arboretum.Agents.update_agent(agent, %{last_error: error_message})
      end
    end)
  end
  
  # Schedule cron-based responsibilities
  defp schedule_cron_responsibilities(state) do
    # Find responsibilities that start with "cron:"
    cron_responsibilities =
      state.agent_config.responsibilities
      |> Enum.filter(fn responsibility ->
        String.starts_with?(responsibility, "cron:")
      end)
      
    # Schedule each cron responsibility
    Enum.reduce(cron_responsibilities, state, fn responsibility, acc_state ->
      schedule_cron_task(responsibility, acc_state)
    end)
  end
  
  # Schedule a single cron task
  defp schedule_cron_task(responsibility, state) do
    case String.split(responsibility, "cron:", parts: 2) do
      [_, cron_expression] ->
        # Parse the cron expression
        case parse_cron_expression(cron_expression) do
          {:ok, interval_ms} ->
            # Schedule the task
            timer_ref = Process.send_after(self(), {:scheduled_task, responsibility}, interval_ms)
            
            # Store the timer reference
            put_in(state, [:scheduled_tasks, responsibility], %{
              timer_ref: timer_ref,
              interval_ms: interval_ms
            })
            
          {:error, reason} ->
            Logger.error("Failed to parse cron expression '#{cron_expression}': #{reason}")
            state
        end
        
      _ ->
        Logger.error("Invalid cron responsibility: #{responsibility}")
        state
    end
  end
  
  # Reschedule a task after it has been executed
  defp reschedule_task(responsibility, state) do
    case get_in(state, [:scheduled_tasks, responsibility]) do
      %{interval_ms: interval_ms} ->
        # Cancel the old timer if it exists
        old_timer_ref = get_in(state, [:scheduled_tasks, responsibility, :timer_ref])
        if old_timer_ref, do: Process.cancel_timer(old_timer_ref)
        
        # Schedule a new timer
        timer_ref = Process.send_after(self(), {:scheduled_task, responsibility}, interval_ms)
        
        # Update the timer reference
        put_in(state, [:scheduled_tasks, responsibility, :timer_ref], timer_ref)
        
      nil ->
        # This task was not scheduled, possibly triggered manually
        state
    end
  end
  
  # Parse a cron expression into milliseconds
  # This is a simplified version that just supports intervals in seconds
  # In a real implementation, this would parse actual cron expressions like "0 0 * * *"
  defp parse_cron_expression(expression) do
    # For simplicity, we'll treat the expression as seconds
    # In a real implementation, you would use a proper cron parser
    case Integer.parse(String.trim(expression)) do
      {seconds, _} when seconds > 0 ->
        {:ok, seconds * 1000}
        
      _ ->
        {:error, "Invalid cron expression"}
    end
  end
end