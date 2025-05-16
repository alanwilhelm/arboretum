defmodule Arboretum.AgentsTest do
  use Arboretum.DataCase, async: true

  alias Arboretum.Agents
  alias Arboretum.Agents.Agent

  describe "agents" do
    @valid_attrs %{
      name: "test-agent",
      status: "inactive",
      llm_config: %{
        api_key_env_var: "TEST_API_KEY",
        model: "test-model",
        endpoint_url: "https://test-endpoint.com"
      },
      prompts: %{default: "You are a test assistant."},
      abilities: ["Arboretum.Abilities.Echo.handle/3"],
      responsibilities: ["test:echo"],
      retry_policy: %{type: "fixed", max_retries: 3, delay_ms: 1000}
    }
    @update_attrs %{
      name: "updated-agent",
      status: "active"
    }
    @invalid_attrs %{name: nil, status: "invalid_status"}

    test "list_all_agents/0 returns all agents" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert Agents.list_all_agents() == [agent]
    end

    test "list_active_agents/0 returns active agents" do
      {:ok, inactive_agent} = Agents.create_agent(@valid_attrs)
      {:ok, active_agent} = Agents.create_agent(Map.put(@valid_attrs, :status, "active") |> Map.put(:name, "active-agent"))
      
      active_agents = Agents.list_active_agents()
      assert length(active_agents) == 1
      assert hd(active_agents).id == active_agent.id
    end

    test "get_agent/1 returns the agent with given id" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert Agents.get_agent(agent.id) == agent
    end

    test "get_agent_by_name/1 returns the agent with given name" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert Agents.get_agent_by_name(agent.name) == agent
    end

    test "create_agent/1 with valid data creates a agent" do
      assert {:ok, %Agent{} = agent} = Agents.create_agent(@valid_attrs)
      assert agent.name == "test-agent"
      assert agent.status == "inactive"
    end

    test "create_agent/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Agents.create_agent(@invalid_attrs)
    end

    test "update_agent/2 with valid data updates the agent" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert {:ok, %Agent{} = updated} = Agents.update_agent(agent, @update_attrs)
      assert updated.name == "updated-agent"
      assert updated.status == "active"
    end

    test "update_agent/2 with invalid data returns error changeset" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Agents.update_agent(agent, @invalid_attrs)
      assert agent == Agents.get_agent(agent.id)
    end

    test "delete_agent/1 deletes the agent" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert {:ok, %Agent{}} = Agents.delete_agent(agent)
      assert nil == Agents.get_agent(agent.id)
    end

    test "change_agent/1 returns a agent changeset" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert %Ecto.Changeset{} = Agents.change_agent(agent)
    end

    test "change_agent_status/2 changes agent status" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert {:ok, %Agent{status: "active"}} = Agents.change_agent_status(agent.id, "active")
      assert Agents.get_agent(agent.id).status == "active"
    end

    test "change_agent_status/2 with invalid status returns error" do
      {:ok, agent} = Agents.create_agent(@valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Agents.change_agent_status(agent.id, "invalid")
      assert Agents.get_agent(agent.id).status == "inactive"
    end
  end
end