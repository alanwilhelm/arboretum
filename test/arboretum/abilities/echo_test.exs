defmodule Arboretum.Abilities.EchoTest do
  use ExUnit.Case, async: true
  
  alias Arboretum.Abilities.Echo
  alias Arboretum.Agents.Agent
  
  describe "handle/3" do
    test "echoes the input payload" do
      # Create a mock agent config
      agent_config = %Agent{
        id: "test-id",
        name: "test-agent",
        status: "active"
      }
      
      # Test payload
      payload = %{message: "Hello, world!"}
      
      # Call the Echo ability
      {:ok, result} = Echo.handle(payload, agent_config, nil)
      
      # Verify the result
      assert result.echo == payload
      assert result.agent_name == "test-agent"
      assert result.agent_id == "test-id"
      assert %DateTime{} = result.timestamp
    end
    
    test "works with any payload type" do
      agent_config = %Agent{id: "test", name: "test"}
      
      # String payload
      {:ok, result1} = Echo.handle("string payload", agent_config, nil)
      assert result1.echo == "string payload"
      
      # List payload
      {:ok, result2} = Echo.handle([1, 2, 3], agent_config, nil)
      assert result2.echo == [1, 2, 3]
      
      # Integer payload
      {:ok, result3} = Echo.handle(42, agent_config, nil)
      assert result3.echo == 42
    end
  end
end