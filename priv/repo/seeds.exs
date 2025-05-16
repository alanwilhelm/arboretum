# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Arboretum.Repo.insert!(%Arboretum.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Arboretum.Repo
alias Arboretum.Agents.Agent
alias Arboretum.BatchResults.BatchResult

IO.puts("=== Seeding database with example data ===")

# Create sample agents
IO.puts("Creating sample agents...")

# Simple echo agent
echo_agent =
  Repo.insert!(%Agent{
    name: "Echo Agent",
    status: "active",
    llm_config: %{
      "provider" => "simulated",
      "model" => "simulated-model"
    },
    prompts: %{
      "default" => "You are an echo agent. You repeat back the user's input."
    },
    abilities: ["Arboretum.Abilities.Echo"],
    responsibilities: ["echo:standard"],
    retry_policy: %{
      "type" => "fixed",
      "max_retries" => 3,
      "delay_ms" => 1000
    }
  })

# LLM query agent
llm_agent =
  Repo.insert!(%Agent{
    name: "Query Agent",
    status: "active",
    llm_config: %{
      "provider" => "simulated",
      "model" => "simulated-model",
      "api_key_env_var" => "OPENAI_API_KEY"
    },
    prompts: %{
      "default" => "You are a helpful assistant that answers questions accurately and concisely."
    },
    abilities: ["Arboretum.Abilities.QueryLLM"],
    responsibilities: ["query_llm:standard"],
    retry_policy: %{
      "type" => "exponential",
      "max_retries" => 3,
      "initial_delay_ms" => 1000,
      "max_delay_ms" => 10000
    }
  })

# Batch operation agent
batch_agent =
  Repo.insert!(%Agent{
    name: "Batch Agent",
    status: "active",
    llm_config: %{
      "provider" => "simulated",
      "model" => "simulated-model"
    },
    prompts: %{
      "default" => "You are a batch processing agent that handles multiple requests efficiently."
    },
    abilities: ["Arboretum.Abilities.BatchQuery"],
    responsibilities: ["batch_query:standard"],
    retry_policy: %{
      "type" => "fixed",
      "max_retries" => 3,
      "delay_ms" => 2000
    }
  })

# Create sample batch results
IO.puts("Creating sample batch results...")

batch_id = "sample-batch-#{:os.system_time(:millisecond)}"

# Create 5 sample batch results
for i <- 1..5 do
  Repo.insert!(%BatchResult{
    batch_id: batch_id,
    agent_id: batch_agent.id,
    agent_name: batch_agent.name,
    agent_index: i - 1,
    prompt: "What is the capital of #{Enum.at(["France", "Germany", "Italy", "Spain", "UK"], i - 1)}?",
    response: "The capital of #{Enum.at(["France", "Germany", "Italy", "Spain", "UK"], i - 1)} is #{Enum.at(["Paris", "Berlin", "Rome", "Madrid", "London"], i - 1)}.",
    processed: i <= 3,  # Mark the first 3 as processed
    metadata: %{
      "execution_time_ms" => 100 + :rand.uniform(200),
      "tokens" => 20 + :rand.uniform(30)
    }
  })
end

IO.puts("Database seeding completed successfully!")
