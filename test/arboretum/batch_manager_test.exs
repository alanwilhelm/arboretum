defmodule Arboretum.BatchManagerTest do
  use Arboretum.DataCase

  alias Arboretum.BatchManager

  describe "check_rate_limit/3" do
    test "allows requests within the rate limit" do
      # Using a custom bucket name that won't interfere with other tests
      bucket = "test_bucket_#{System.unique_integer([:positive])}"
      
      # Test with default cost (1)
      assert :ok = BatchManager.check_rate_limit(bucket, "test_key")
      
      # Test multiple requests within the limit
      for _ <- 1..5, do: assert(:ok = BatchManager.check_rate_limit(bucket, "test_key"))
    end

    test "returns rate limit error when limit is exceeded" do
      # Create a custom test bucket with very low limits
      _bucket = :"test_bucket_#{System.unique_integer([:positive])}"
      
      # Override rate limit buckets for testing (this is just for demonstration,
      # in reality we'd need to make the buckets configurable)
      # For now, let's use default bucket and expect rate limiting after 100 requests
      
      # First, exhaust the default rate limit (100 requests per minute)
      for _ <- 1..100, do: BatchManager.check_rate_limit(:default, "test_key")
      
      # The next request should be rate limited
      result = BatchManager.check_rate_limit(:default, "test_key")
      assert {:error, :rate_limited, wait_time} = result
      assert is_integer(wait_time)
      assert wait_time > 0
    end

    test "supports cost parameter" do
      bucket = "test_cost_bucket_#{System.unique_integer([:positive])}"
      
      # Test with cost > 1
      assert :ok = BatchManager.check_rate_limit(bucket, "test_key", 5)
      
      # This should consume 5 slots at once
      # Additional requests with high cost should eventually hit the limit
      for _ <- 1..20, do: BatchManager.check_rate_limit(bucket, "test_key", 5)
      
      # Should hit rate limit faster with higher cost
      result = BatchManager.check_rate_limit(bucket, "test_key", 5)
      assert {:error, :rate_limited, wait_time} = result
      assert is_integer(wait_time)
    end
  end

  describe "get_rate_limit_bucket_for_agent/1" do
    test "returns default bucket for nil agent" do
      assert :default = BatchManager.get_rate_limit_bucket_for_agent(nil)
    end

    test "returns model-specific bucket when available" do
      agent = %Arboretum.Agents.Agent{
        llm_config: %{"model" => "gpt-4"}
      }
      assert "gpt-4" = BatchManager.get_rate_limit_bucket_for_agent(agent)
    end

    test "returns provider-specific bucket based on model prefix" do
      agent = %Arboretum.Agents.Agent{
        llm_config: %{"model" => "gpt-3.5-turbo"}
      }
      assert :openai = BatchManager.get_rate_limit_bucket_for_agent(agent)
      
      agent = %Arboretum.Agents.Agent{
        llm_config: %{"model" => "claude-3-opus"}
      }
      assert :anthropic = BatchManager.get_rate_limit_bucket_for_agent(agent)
    end

    test "returns provider-specific bucket when explicitly set" do
      agent = %Arboretum.Agents.Agent{
        llm_config: %{"provider" => "openai", "model" => "custom-model"}
      }
      assert :openai = BatchManager.get_rate_limit_bucket_for_agent(agent)
    end

    test "returns default bucket for unknown providers" do
      agent = %Arboretum.Agents.Agent{
        llm_config: %{"model" => "unknown-model"}
      }
      assert :default = BatchManager.get_rate_limit_bucket_for_agent(agent)
    end
  end
end