defmodule Arboretum.LLMClient do
  @moduledoc """
  A client for interacting with Large Language Models (LLMs).
  
  This module provides:
  - A struct for holding LLM configuration
  - Functions for creating clients
  - Functions for making queries to LLMs
  
  Currently supported providers:
  - OpenAI (ChatGPT, GPT-4o, etc.)
  """
  
  require Logger
  alias ExOpenAI.Chat
  
  defstruct [
    :provider,     # :openai, :anthropic, etc.
    :api_key,
    :model,
    :endpoint_url,
    :base_prompt,
    :http_client,
    :client_config # Provider-specific configuration
  ]
  
  @type provider :: :openai | :anthropic | :simulated
  
  @type t :: %__MODULE__{
    provider: provider(),
    api_key: String.t(),
    model: String.t(),
    endpoint_url: String.t(),
    base_prompt: String.t() | nil,
    http_client: module(),
    client_config: map()
  }
  
  # Default options for different providers
  @default_openai_options %{
    temperature: 0.7,
    max_tokens: 1024,
    top_p: 1.0,
    frequency_penalty: 0.0,
    presence_penalty: 0.0
  }
  
  # Define middleware for the Tesla HTTP client
  def middleware do
    [
      {Tesla.Middleware.Retry, [
        delay: 500,
        max_retries: 3,
        max_delay: 4_000,
        should_retry: fn
          {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] -> true
          {:error, _} -> true
          _ -> false
        end
      ]},
      {Tesla.Middleware.Timeout, timeout: 30_000},
      Tesla.Middleware.JSON,
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.Logger
    ]
  end
  
  @doc """
  Creates a new LLM client instance.
  
  ## Parameters
  
  - `llm_config` - A map containing configuration for the LLM client:
    - `api_key_env_var` - The name of the environment variable containing the API key.
    - `model` - The name of the model to use (e.g., "gpt-4o").
    - `endpoint_url` - The URL of the API endpoint.
    - `base_prompt` - (Optional) A base prompt to be included in all queries.
    - `provider` - (Optional) The provider to use (:openai, :anthropic, or :simulated).
    
  ## Returns
  
  A new LLMClient struct.
  
  ## Examples
  
  ```elixir
  config = %{
    api_key_env_var: "OPENAI_API_KEY",
    model: "gpt-4o",
    endpoint_url: "https://api.openai.com/v1/chat/completions",
    base_prompt: "You are a helpful assistant."
  }
  client = Arboretum.LLMClient.new(config)
  ```
  """
  @spec new(map()) :: t()
  def new(llm_config) do
    # Determine provider from config or model name
    provider = get_provider(llm_config)
    
    # Get API key from environment variable
    api_key = 
      if llm_config[:api_key_env_var] do
        System.get_env(llm_config[:api_key_env_var] || "")
      else
        nil
      end
      
    if (provider != :simulated) and (api_key == nil or api_key == "") do
      Logger.warning("API key not found in environment variable #{llm_config[:api_key_env_var]}")
    end
    
    # Setup HTTP client based on provider
    {http_client, client_config} = setup_client(provider, api_key, llm_config)
    
    %__MODULE__{
      provider: provider,
      api_key: api_key,
      model: llm_config[:model] || default_model(provider),
      endpoint_url: llm_config[:endpoint_url] || default_endpoint(provider),
      base_prompt: llm_config[:base_prompt],
      http_client: http_client,
      client_config: client_config
    }
  end
  
  @doc """
  Queries the LLM with a prompt.
  
  ## Parameters
  
  - `client` - An LLMClient struct.
  - `prompt` - The prompt to send to the LLM.
  - `query_opts` - (Optional) Additional options for the query:
    - `temperature` - The sampling temperature (0.0 to 2.0).
    - `max_tokens` - The maximum number of tokens to generate.
    - `top_p` - The nucleus sampling parameter (0.0 to 1.0).
    - `stream` - Whether to stream the response (not implemented yet).
    
  ## Returns
  
  - `{:ok, response}` - The query was successful.
  - `{:error, reason}` - The query failed.
  
  ## Examples
  
  ```elixir
  {:ok, response} = Arboretum.LLMClient.query(client, "What is the capital of France?")
  ```
  """
  @spec query(t(), String.t(), map()) :: {:ok, map()} | {:error, any()}
  def query(client, prompt, query_opts \\ %{}) do
    # Log query info
    Logger.info("Querying #{client.provider} model #{client.model} with prompt of length #{String.length(prompt)}")
    
    # Delegate to provider-specific query function
    case client.provider do
      :openai -> query_openai(client, prompt, query_opts)
      :anthropic -> query_anthropic(client, prompt, query_opts)
      :simulated -> query_simulated(client, prompt, query_opts)
    end
  end
  
  @doc """
  Extracts the text response from an LLM query result.
  
  ## Parameters
  
  - `result` - The result from `query/3` (as a tuple).
  
  ## Returns
  
  - `{:ok, text}` - The text response was successfully extracted.
  - `{:error, reason}` - The text response could not be extracted.
  
  ## Examples
  
  ```elixir
  {:ok, result} = Arboretum.LLMClient.query(client, "What is the capital of France?")
  {:ok, text} = Arboretum.LLMClient.extract_text(result)
  ```
  """
  @spec extract_text({:ok, map()} | {:error, any()}) :: {:ok, String.t()} | {:error, any()}
  def extract_text({:ok, response}) do
    try do
      text = extract_text_by_provider(response)
      {:ok, text}
    rescue
      e ->
        {:error, "Failed to extract text from response: #{inspect(e)}"}
    end
  end
  
  def extract_text({:error, reason}), do: {:error, reason}
  
  # Private functions
  
  # Determine provider from config or model name
  defp get_provider(%{provider: provider}) when provider in [:openai, :anthropic, :simulated], do: provider
  defp get_provider(%{model: model}) when is_binary(model) do
    cond do
      String.starts_with?(model, "gpt-") -> :openai
      String.starts_with?(model, "claude-") -> :anthropic
      true -> :openai  # Default to OpenAI
    end
  end
  defp get_provider(_), do: :openai  # Default to OpenAI
  
  # Setup HTTP client based on provider
  defp setup_client(:openai, api_key, _config) do
    # Initialize the ExOpenAI client
    if api_key && api_key != "" do
      Application.put_env(:ex_openai, :api_key, api_key)
    end
    
    # For direct HTTP usage, configure Tesla
    client = Tesla.client(middleware())
    
    {client, %{}}
  end
  
  defp setup_client(:anthropic, api_key, _config) do
    # For Anthropic, configure Tesla client with auth headers
    client = Tesla.client(middleware() ++ [
      {Tesla.Middleware.Headers, [{"x-api-key", api_key}]}
    ])
    
    {client, %{}}
  end
  
  defp setup_client(:simulated, _api_key, _config) do
    # No real HTTP client needed for simulation
    {nil, %{}}
  end
  
  # Default model names based on provider
  defp default_model(:openai), do: "gpt-4o"
  defp default_model(:anthropic), do: "claude-3-opus-20240229"
  defp default_model(:simulated), do: "simulated-model"
  
  # Default API endpoints
  defp default_endpoint(:openai), do: "https://api.openai.com/v1/chat/completions"
  defp default_endpoint(:anthropic), do: "https://api.anthropic.com/v1/messages"
  defp default_endpoint(:simulated), do: nil
  
  # OpenAI specific query implementation
  defp query_openai(client, prompt, query_opts) do
    # Verify API key is present
    if client.api_key == nil or client.api_key == "" do
      {:error, "OpenAI API key not found"}
    else
      # Extract options
      options = Map.merge(@default_openai_options, query_opts)
      
      # Prepare messages for chat API
      messages = [
        %{role: "system", content: client.base_prompt || "You are a helpful assistant."},
        %{role: "user", content: prompt}
      ]
      
      # Execute the API call
      try do
        case Chat.create_chat_completion(
          messages,
          model: client.model,
          temperature: options.temperature,
          max_tokens: options.max_tokens,
          top_p: options.top_p,
          frequency_penalty: options.frequency_penalty,
          presence_penalty: options.presence_penalty
        ) do
          {:ok, response} ->
            # Transform the ExOpenAI response to our standard format
            transformed_response = %{
              provider: :openai,
              model: client.model,
              choices: transform_openai_choices(response.choices),
              usage: response.usage,
              id: response.id,
              created: response.created,
              raw_response: response
            }
            
            {:ok, transformed_response}
            
          {:error, reason} ->
            # Log the error
            Logger.error("OpenAI API error: #{inspect(reason)}")
            {:error, reason}
        end
      rescue
        e ->
          Logger.error("Exception in OpenAI query: #{inspect(e)}")
          {:error, "Exception in OpenAI query: #{inspect(e)}"}
      end
    end
  end
  
  # Transform OpenAI choices to our standard format
  defp transform_openai_choices(choices) do
    Enum.map(choices, fn choice ->
      %{
        message: choice.message,
        index: choice.index,
        finish_reason: choice.finish_reason
      }
    end)
  end
  
  # Anthropic specific query implementation
  defp query_anthropic(_client, _prompt, _query_opts) do
    # Not implemented yet
    {:error, "Anthropic integration not implemented yet"}
  end
  
  # Simulated LLM provider for testing
  defp query_simulated(client, prompt, _query_opts) do
    # Simulate a successful response
    response = %{
      provider: :simulated,
      model: client.model,
      choices: [
        %{
          message: %{
            role: "assistant",
            content: "This is a simulated response to: #{prompt}\n\nIn a real implementation, this would be the actual response from an LLM provider."
          },
          index: 0,
          finish_reason: "stop"
        }
      ],
      usage: %{
        prompt_tokens: div(String.length(prompt), 4),
        completion_tokens: 50,
        total_tokens: div(String.length(prompt), 4) + 50
      },
      id: "sim_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}",
      created: System.system_time(:second)
    }
    
    # Simulate network delay (100-300ms)
    delay = Enum.random(100..300)
    :timer.sleep(delay)
    
    {:ok, response}
  end
  
  # Extract text based on provider format
  defp extract_text_by_provider(%{provider: :openai} = response) do
    response.choices
    |> List.first()
    |> Map.get(:message)
    |> Map.get(:content)
  end
  
  defp extract_text_by_provider(%{provider: :anthropic} = response) do
    response.content
    |> List.first()
    |> Map.get(:text)
  end
  
  defp extract_text_by_provider(%{provider: :simulated} = response) do
    response.choices
    |> List.first()
    |> Map.get(:message)
    |> Map.get(:content)
  end
  
  # Legacy format support (for batch query ability)
  defp extract_text_by_provider(response) when is_map(response) do
    if Map.has_key?(response, :choices) do
      response.choices
      |> List.first()
      |> get_in([:message, :content])
    else
      raise "Unknown response format: #{inspect(response)}"
    end
  end
end