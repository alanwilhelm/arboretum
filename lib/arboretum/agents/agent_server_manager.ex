defmodule Arboretum.Agents.AgentServerManager do
  @moduledoc """
  Manages the lifecycle of AgentServer processes based on database configurations.
  
  This GenServer:
  1. Starts AgentServer processes for active agent configurations in the database
  2. Tracks running AgentServer processes
  3. Monitors processes to handle crashes
  """

  use GenServer
  require Logger
  alias Arboretum.Agents
  alias Arboretum.Agents.Agent

  # Client API

  @doc """
  Starts the AgentServerManager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting AgentServerManager")
    
    # Initial state with empty running_agents map
    state = %{running_agents: %{}}
    
    # Load and start active agents from database
    active_agents = Agents.list_active_agents()
    
    # Start each active agent and track it
    state =
      Enum.reduce(active_agents, state, fn agent, acc ->
        case start_agent_process(agent) do
          {:ok, pid} ->
            Logger.info("Started agent #{agent.name} (#{agent.id}) with pid #{inspect(pid)}")
            ref = Process.monitor(pid)
            put_in(acc, [:running_agents, agent.id], %{pid: pid, ref: ref, agent: agent})

          {:error, reason} ->
            Logger.error("Failed to start agent #{agent.name} (#{agent.id}): #{inspect(reason)}")
            acc
        end
      end)
    
    # Subscribe to agent changes
    Agents.subscribe_agents_changed()
    Logger.info("Subscribed to agents:changed PubSub topic")

    {:ok, state}
  end
  
  @impl true
  def handle_info({:agent_created, %Agent{status: "active"} = agent_config}, state) do
    Logger.info("Received agent_created event for #{agent_config.name} (#{agent_config.id})")
    
    # Only start the agent if it's not already running
    state =
      if Map.has_key?(state.running_agents, agent_config.id) do
        Logger.warning("Agent #{agent_config.name} (#{agent_config.id}) already running, ignoring create event")
        state
      else
        case start_agent_process(agent_config) do
          {:ok, pid} ->
            Logger.info("Started agent #{agent_config.name} (#{agent_config.id}) with pid #{inspect(pid)}")
            ref = Process.monitor(pid)
            put_in(state, [:running_agents, agent_config.id], %{pid: pid, ref: ref, agent: agent_config})

          {:error, reason} ->
            Logger.error("Failed to start agent #{agent_config.name} (#{agent_config.id}): #{inspect(reason)}")
            state
        end
      end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:agent_created, agent_config}, state) do
    # Agent was created with a non-active status, nothing to do
    Logger.debug("Received agent_created event for inactive agent #{agent_config.name} (#{agent_config.id})")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:agent_updated, %Agent{} = agent_config}, state) do
    Logger.info("Received agent_updated event for #{agent_config.name} (#{agent_config.id})")
    
    # Check if the agent is currently running
    current_agent_data = Map.get(state.running_agents, agent_config.id)
    
    state =
      cond do
        # Case 1: Agent is now active and was already running
        agent_config.status == "active" and current_agent_data != nil ->
          # Restart the agent to apply new configuration
          Logger.info("Restarting active agent #{agent_config.name} (#{agent_config.id}) to apply new configuration")
          _ = stop_agent_process(current_agent_data.pid, agent_config.id)
          
          case start_agent_process(agent_config) do
            {:ok, pid} ->
              ref = Process.monitor(pid)
              put_in(state, [:running_agents, agent_config.id], %{pid: pid, ref: ref, agent: agent_config})
            
            {:error, reason} ->
              Logger.error("Failed to restart agent #{agent_config.name} (#{agent_config.id}): #{inspect(reason)}")
              # Remove the agent from running_agents since we couldn't restart it
              {_, new_state} = pop_in(state, [:running_agents, agent_config.id])
              new_state
          end
          
        # Case 2: Agent is now active but wasn't running
        agent_config.status == "active" and current_agent_data == nil ->
          Logger.info("Starting newly activated agent #{agent_config.name} (#{agent_config.id})")
          
          case start_agent_process(agent_config) do
            {:ok, pid} ->
              ref = Process.monitor(pid)
              put_in(state, [:running_agents, agent_config.id], %{pid: pid, ref: ref, agent: agent_config})
            
            {:error, reason} ->
              Logger.error("Failed to start newly activated agent #{agent_config.name} (#{agent_config.id}): #{inspect(reason)}")
              state
          end
          
        # Case 3: Agent is not active now but was running
        agent_config.status != "active" and current_agent_data != nil ->
          Logger.info("Stopping deactivated agent #{agent_config.name} (#{agent_config.id})")
          _ = stop_agent_process(current_agent_data.pid, agent_config.id)
          
          # Remove the agent from running_agents
          {_, new_state} = pop_in(state, [:running_agents, agent_config.id])
          new_state
          
        # Case 4: Agent is not active and wasn't running
        true ->
          Logger.debug("No action needed for updated inactive agent #{agent_config.name} (#{agent_config.id})")
          state
      end
      
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:agent_deleted, %Agent{} = agent_config}, state) do
    Logger.info("Received agent_deleted event for #{agent_config.name} (#{agent_config.id})")
    
    # Check if the agent is currently running
    current_agent_data = Map.get(state.running_agents, agent_config.id)
    
    state =
      if current_agent_data != nil do
        # Stop the agent process
        Logger.info("Stopping deleted agent #{agent_config.name} (#{agent_config.id})")
        _ = stop_agent_process(current_agent_data.pid, agent_config.id)
        
        # Remove the agent from running_agents
        {_, new_state} = pop_in(state, [:running_agents, agent_config.id])
        new_state
      else
        Logger.debug("Deleted agent #{agent_config.name} (#{agent_config.id}) was not running")
        state
      end
      
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # Find the agent ID for this pid/ref
    {agent_id, _agent_data} = 
      Enum.find(state.running_agents, {nil, nil}, fn {_id, data} -> 
        data.pid == pid && data.ref == ref
      end)
      
    if agent_id do
      Logger.warning("Agent process #{agent_id} crashed: #{inspect(reason)}")
      
      # Check if we should restart or disable due to flapping
      flapping? = check_flapping(agent_id, reason)
      
      if flapping? do
        # Disable the agent due to flapping
        Logger.error("Agent #{agent_id} is flapping, disabling it")
        Task.start(fn -> 
          Agents.change_agent_status(agent_id, "disabled_flapping") 
        end)
        
        # Remove from running_agents
        {_, new_state} = pop_in(state, [:running_agents, agent_id])
        {:noreply, new_state}
      else
        # Not flapping, try to restart if it's supposed to be active
        case Agents.get_agent(agent_id) do
          %Agent{status: "active"} = agent_config ->
            Logger.info("Restarting crashed agent #{agent_config.name} (#{agent_id})")
            
            case start_agent_process(agent_config) do
              {:ok, new_pid} ->
                new_ref = Process.monitor(new_pid)
                new_state = put_in(state, [:running_agents, agent_id], %{
                  pid: new_pid, 
                  ref: new_ref, 
                  agent: agent_config
                })
                {:noreply, new_state}
                
              {:error, restart_error} ->
                Logger.error("Failed to restart agent #{agent_id}: #{inspect(restart_error)}")
                {_, new_state} = pop_in(state, [:running_agents, agent_id])
                {:noreply, new_state}
            end
            
          _ ->
            # Agent no longer active or doesn't exist
            Logger.info("Not restarting crashed agent #{agent_id} as it's no longer active")
            {_, new_state} = pop_in(state, [:running_agents, agent_id])
            {:noreply, new_state}
        end
      end
    else
      # Unknown process, ignore
      Logger.warning("Received DOWN message for unknown process: #{inspect(pid)}")
      {:noreply, state}
    end
  end
  
  # Simple flap detection - in a real system, this might track crashes over time
  # and be more sophisticated, possibly stored in ETS or another persistence layer
  defp check_flapping(_agent_id, _reason) do
    # For now, we'll return false as a placeholder
    # In a real implementation, this would track crash times and frequencies
    false
  end

  # Helper functions
  
  defp start_agent_process(agent_config) do
    child_spec = {Arboretum.Agents.AgentServer, {agent_config, Registry}}
    
    case DynamicSupervisor.start_child(Arboretum.AgentDynamicSupervisor, child_spec) do
      {:ok, pid} ->
        {:ok, pid}
        
      {:error, {:already_started, pid}} ->
        Logger.warning("Agent #{agent_config.name} already running with pid #{inspect(pid)}")
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("Error starting agent #{agent_config.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp stop_agent_process(pid, agent_id) do
    Logger.info("Stopping agent #{agent_id}")
    
    case DynamicSupervisor.terminate_child(Arboretum.AgentDynamicSupervisor, pid) do
      :ok ->
        Logger.info("Successfully stopped agent #{agent_id}")
        :ok
        
      {:error, :not_found} ->
        Logger.warning("Agent #{agent_id} not found or already stopped")
        :ok
        
      {:error, reason} ->
        Logger.error("Error stopping agent #{agent_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end