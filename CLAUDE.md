# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Arboretum is a Phoenix web application built with Elixir. It uses Phoenix 1.7, LiveView, Ecto with PostgreSQL, and TailwindCSS for styling.

**GitHub Organization**: This project is hosted under the `floranetwork` organization on GitHub.

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

## GitHub CLI (gh) for Project Management

These are commands and practices for using GitHub CLI for project management in this repository:

### Repository Management

```bash
# Create a new repository (private by default)
gh repo create arboretum --description "Description here"

# Make repository public
gh repo edit alanwilhelm/arboretum --visibility public

# Clone repository
gh repo clone alanwilhelm/arboretum
```

### Project Board Management

```bash
# Create a project board
gh project create --owner alanwilhelm --title "Arboretum Development"

# List projects
gh project list --owner alanwilhelm

# Link project to repository
gh project link 1 --owner alanwilhelm --repo alanwilhelm/arboretum

# List fields in project
gh project field-list 1 --owner alanwilhelm

# List items in project
gh project item-list 1 --owner alanwilhelm

# Add item to project (like issues)
gh project item-add 1 --owner alanwilhelm --url "https://github.com/alanwilhelm/arboretum/issues/1"
```

### Issue Management

```bash
# Create a new issue
gh issue create --repo alanwilhelm/arboretum --title "Issue Title" --body "Description" --label "enhancement"

# Edit an existing issue
gh issue edit 1 --body "Updated description"

# List issues
gh issue list --repo alanwilhelm/arboretum
```

### GraphQL API for Advanced Operations

```bash
# Update item status in project board
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "PVT_kwHOAAKs-c4A5IAE",
      itemId: "PVTI_lAHOAAKs-c4A5IAEzgac1p0",
      fieldId: "PVTSSF_lAHOAAKs-c4A5IAEzgt-gnQ",
      value: { singleSelectOptionId: "47fc9ee4" }
    }) {
      clientMutationId
    }
  }
'
```

### Limitations and Notes

1. Some operations like adding custom columns, changing view layout, or reordering columns must be done through the web interface
2. Use `gh project view 1 --owner alanwilhelm --web` to open the project in a browser
3. The GraphQL API is powerful but requires knowledge of field IDs and option IDs
4. Card formatting in descriptions works best with simple formatting (avoid markdown headers in card descriptions)