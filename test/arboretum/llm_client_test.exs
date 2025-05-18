defmodule Arboretum.LLMClientTest do
  use ExUnit.Case, async: true
  
  alias Arboretum.LLMClient
  
  describe "new/1" do
    test "creates a new LLM client with valid config" do
      # Set test API key in environment
      System.put_env("TEST_API_KEY", "test-key-value")
      
      config = %{
        api_key_env_var: "TEST_API_KEY",
        model: "test-model",
        endpoint_url: "https://test-endpoint.com",
        base_prompt: "You are a test assistant",
        provider: :simulated
      }
      
      client = LLMClient.new(config)
      
      assert client.api_key == "test-key-value"
      assert client.model == "test-model"
      assert client.endpoint_url == "https://test-endpoint.com"
      assert client.base_prompt == "You are a test assistant"
      assert client.provider == :simulated
    end
    
    test "uses default values for missing config" do
      client = LLMClient.new(%{api_key_env_var: "NON_EXISTENT_KEY"})
      
      assert client.api_key == nil
      assert client.model == "gpt-4o" # Default model
      assert client.endpoint_url == "https://api.openai.com/v1/chat/completions" # Default URL
    end
  end
  
  describe "query/3" do
    test "returns a simulated response when API key is present" do
      client = %LLMClient{
        api_key: "test-key",
        model: "test-model",
        endpoint_url: "https://test-endpoint.com",
        provider: :simulated
      }
      
      {:ok, response} = LLMClient.query(client, "Test prompt")
      
      assert is_map(response)
      assert is_list(response.choices)
      assert is_map(hd(response.choices).message)
    end
    
    test "returns error when API key is missing" do
      client = %LLMClient{
        api_key: nil,
        model: "test-model",
        endpoint_url: "https://test-endpoint.com",
        provider: :openai
      }
      
      assert {:error, "OpenAI API key not found"} = LLMClient.query(client, "Test prompt")
    end
  end
  
  describe "extract_text/1" do
    test "extracts text from a valid response" do
      response = %{
        choices: [
          %{
            message: %{
              role: "assistant",
              content: "Test response content"
            }
          }
        ]
      }
      
      assert {:ok, "Test response content"} = LLMClient.extract_text({:ok, response})
    end
    
    test "propagates errors" do
      assert {:error, "some error"} = LLMClient.extract_text({:error, "some error"})
    end
    
    test "handles malformed responses" do
      response = %{invalid: "format"}
      
      assert {:error, _} = LLMClient.extract_text({:ok, response})
    end
  end
end