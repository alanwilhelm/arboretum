# Arboretum

A dynamic agent architecture for large-scale LLM operations, built with Phoenix and Elixir.

## Overview

Arboretum is a system for creating, managing, and scaling autonomous agents that interact with Large Language Models (LLMs). The system supports both individual agents and large-scale batch operations with up to hundreds of concurrent agents.

Each agent has:
- A configuration stored in the database
- A set of abilities (functions they can execute)
- Responsibilities (triggers that activate the agent)
- Custom prompts and LLM settings

The system is built with Phoenix 1.7, LiveView, Ecto with PostgreSQL, and TailwindCSS.

## Features

- **Individual Agent Management**: Create, update, and delete agent configurations via a web interface
- **Batch Operations**: Run large-scale operations with 100+ concurrent agents
- **Rate Limiting**: Provider-specific rate limiting to prevent API throttling
- **Result Storage**: Store and analyze batch operation results
- **Automatic Process Lifecycle**: Agents are automatically started, stopped, and restarted based on configuration changes
- **Ability System**: Agents can execute abilities (functions) based on their configuration
- **Responsibility Triggers**: Agents can be triggered by events or scheduled tasks
- **LLM Integration**: Supports multiple LLM providers (OpenAI, simulated, etc.)

## Getting Started

### Prerequisites

- Elixir 1.14+
- Erlang 26+
- PostgreSQL 14+
- Node.js 16+ (for assets)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/arboretum.git
   cd arboretum
   ```

2. Install dependencies and setup the database:
   ```bash
   mix setup
   ```

3. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

4. Visit [`localhost:4000/agents`](http://localhost:4000/agents) in your browser.

### Creating Your First Agent

1. Navigate to the agents page and click "New Agent"
2. Fill in the required fields:
   - **Name**: A unique identifier for your agent
   - **Status**: Set to "inactive" initially
   - **LLM Configuration**: JSON object with `api_key_env_var`, `model`, and `endpoint_url`
   - **Abilities**: List of abilities, e.g., `Arboretum.Abilities.Echo.handle/3`
   - **Responsibilities**: List of responsibilities, e.g., `echo:test` or `cron:60`
3. Save the agent
4. Change the status to "active" to start the agent

## Architecture

The system is built around these core components:

- **Agents Context**: Manages agent configurations in the database
- **AgentServerManager**: Monitors agent configurations and manages agent processes
- **AgentServer**: Represents a running agent, executing abilities based on responsibilities
- **Abilities**: Modular functions that agents can execute
- **LLMClient**: Interface for interacting with language models

## Development

### Commands

```bash
# Run tests
mix test

# Format code
mix format

# Check for compilation warnings
mix compile --warnings-as-errors

# Check formatting
mix format --check-formatted

# Run the server with auto-reload
mix phx.server
```

### Adding New Abilities

1. Create a new module in `lib/arboretum/abilities/`:
   ```elixir
   defmodule Arboretum.Abilities.YourAbility do
     use Arboretum.Abilities.Ability
     
     @impl true
     def handle(payload, agent_config, llm_client) do
       # Your ability logic here
       {:ok, result}
     end
   end
   ```

2. Add the ability to an agent's configuration: `Arboretum.Abilities.YourAbility.handle/3`

## License

[MIT License](LICENSE)

## Contributing

Please see [NEXT_STEPS.md](NEXT_STEPS.md) for planned enhancements and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.