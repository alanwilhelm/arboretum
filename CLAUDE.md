# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Arboretum is a Phoenix web application built with Elixir. It uses Phoenix 1.7, LiveView, Ecto with PostgreSQL, and TailwindCSS for styling.

## Commands

### Setup and Installation

```bash
# Install dependencies and setup the project
mix setup
```

### Development

```bash
# Start the Phoenix server
mix phx.server

# Start the Phoenix server with an interactive Elixir shell (IEx)
iex -S mix phx.server

# Generate Phoenix resources (controllers, views, etc.)
mix phx.gen.[resource|context|schema|etc] ...

# Compile the project
mix compile
```

### Database

```bash
# Create and migrate the database
mix ecto.setup

# Reset the database (drop, create, migrate)
mix ecto.reset

# Create the database
mix ecto.create

# Run migrations
mix ecto.migrate

# Generate a new migration
mix ecto.gen.migration migration_name
```

### Assets

```bash
# Setup assets (install Tailwind and esbuild if missing)
mix assets.setup

# Build assets
mix assets.build

# Build and minify assets for production
mix assets.deploy
```

### Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/path/to/test_file.exs

# Run a specific test (line number)
mix test test/path/to/test_file.exs:42

# Run tests with detailed output
mix test --trace
```

### Code Quality

```bash
# Format code
mix format

# Check formatting without making changes
mix format --check-formatted
```

## Architecture

Arboretum follows the standard Phoenix 1.7 architecture:

- **lib/arboretum/** - Contains the business logic contexts
- **lib/arboretum_web/** - Contains the web interface (controllers, views, templates)
- **lib/arboretum/repo.ex** - Database repository using Ecto with PostgreSQL
- **lib/arboretum/application.ex** - OTP Application that starts the supervision tree

The application uses:
- Phoenix LiveView for interactive UIs
- Ecto for database interactions
- Swoosh for email handling
- Tailwind for CSS styling
- esbuild for JavaScript bundling

The main components are:
1. **Router** (lib/arboretum_web/router.ex) - Defines routes
2. **Controllers** (lib/arboretum_web/controllers/) - Handle HTTP requests
3. **Templates** (lib/arboretum_web/controllers/page_html/) - Define HTML views
4. **Layouts** (lib/arboretum_web/components/layouts/) - Define page layouts

Database schema migrations are stored in priv/repo/migrations/.