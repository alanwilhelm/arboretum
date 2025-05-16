# Arboretum: Dynamic Agent Architecture for LLMs

![Arboretum Banner](priv/static/images/logo.svg)

## Overview

Arboretum is a powerful dynamic agent architecture built with Elixir and Phoenix for creating, managing, and scaling autonomous agents that interact with Large Language Models (LLMs). It excels at both individual agent operations and large-scale batch processing with up to hundreds of concurrent agents.

## ✨ Key Features

- **Dynamic Agent System**: Create, configure, and deploy LLM agents on demand
- **Batch Processing**: Run hundreds of concurrent agent operations with built-in rate limiting
- **Phoenix LiveView UI**: Real-time interface for agent management and monitoring
- **Provider Abstraction**: Support for multiple LLM providers with a unified API
- **Rate Limiting**: Smart rate limiting to respect API provider constraints
- **Resilient Architecture**: Built with OTP principles for maximum reliability

## 🚀 Quick Start

### Prerequisites

- Elixir 1.15+
- Erlang 26+
- PostgreSQL 13+
- Node.js 18+ (for asset compilation)

### Setup

```bash
# Clone the repository
git clone https://github.com/alanwilhelm/arboretum.git
cd arboretum

# Install dependencies
mix setup

# Reset and seed the database
./scripts/reset_and_seed_db.sh

# Start the Phoenix server
mix phx.server
```

Then visit [`localhost:4000`](http://localhost:4000) to explore the application.

## 📦 Project Structure

```
arboretum/
├── lib/
│   ├── arboretum/               # Core business logic
│   │   ├── abilities/           # Agent abilities
│   │   ├── agents/              # Agent management
│   │   ├── batch_results/       # Batch operation results
│   │   └── ...
│   ├── arboretum_web/           # Web interface
│   │   ├── live/                # LiveView components
│   │   ├── controllers/         # Web controllers
│   │   └── ...
│   └── examples/                # Example use cases
├── priv/
│   ├── repo/                    # Database migrations and seeds
│   └── static/                  # Static assets
├── test/                        # Test suite
├── scripts/                     # Utility scripts
└── docs/                        # Documentation and planning
```

## 🧩 Core Components

### Agent System

Arboretum's agent system is built on Elixir's GenServer and OTP principles:

- **AgentServer**: Individual agent processes that can perform LLM operations
- **AgentServerManager**: Supervises and coordinates agent lifecycles
- **Registry & DynamicSupervisor**: Core OTP components for managing dynamic processes

### Batch Processing

The batch processing system enables large-scale concurrent operations:

- **BatchManager**: Coordinates batch operations across multiple agents
- **BatchResults**: Stores and retrieves operation results
- **Rate Limiting**: Prevents API rate limit violations

### LLM Integration

The LLM client system provides a unified interface to language models:

- **LLMClient**: Core client with provider abstraction
- **Middleware**: Extensible middleware system for request processing
- **Error Handling**: Robust error handling with retries

## 🌐 Web Interface

The web interface is built with Phoenix LiveView for real-time interactions:

- **Agent Management**: Create, configure, and monitor agents
- **Batch Operations**: Launch and track batch operations
- **Results Viewer**: Analyze operation results

## 📚 Documentation

For more detailed documentation:

- See the [docs/](docs/) directory for planning and architecture documents
- Review the [GitHub Wiki](https://github.com/alanwilhelm/arboretum/wiki) for guides and tutorials
- Check out [examples/](lib/examples/) for sample implementations

## 🚧 Current Status & Roadmap

Arboretum is under active development. Current focus areas:

- Building a monitoring dashboard
- Adding streaming support
- Implementing API key management
- Developing a comprehensive test suite

For a detailed roadmap, see our [GitHub Project](https://github.com/alanwilhelm/arboretum/projects) or [Issues](https://github.com/alanwilhelm/arboretum/issues).

## 🧪 Testing

```bash
# Run the test suite
mix test

# Run with detailed output
mix test --trace
```

## 🧰 Development Tools

```bash
# Format code
mix format

# Check formatting
mix format --check-formatted

# Run migrations
./scripts/migrate.sh

# Reset and seed the database
./scripts/reset_and_seed_db.sh
```

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.