# Arboretum Setup Guide

This document outlines how to configure and run Arboretum for local development.

## Prerequisites

- **Elixir** 1.15 or later
- **Erlang/OTP** 26 or later
- **PostgreSQL** 13 or later
- **Node.js** 18 or later (for assets)

## 1. Clone the Repository

```bash
git clone https://github.com/alanwilhelm/arboretum.git
cd arboretum
```

## 2. Install Dependencies

Use the built-in `mix setup` task to install Elixir and JavaScript packages:

```bash
mix setup
```

## 3. Configure Environment Variables

Arboretum relies on several runtime environment variables.
Create a `.env` file or export them in your shell before running the app.
The most important variables are:

- `PHX_HOST` - the hostname used in URLs (default `localhost`)
- `PORT` - port for the web server (default `4000`)
- `DATABASE_URL` - Ecto connection string, e.g. `ecto://USER:PASS@localhost/arboretum_dev`
- `SECRET_KEY_BASE` - secret key for signing cookies (`mix phx.gen.secret` to create)

Example shell setup:

```bash
export PHX_HOST=localhost
export PORT=4000
export DATABASE_URL=ecto://postgres:postgres@localhost/arboretum_dev
export SECRET_KEY_BASE=$(mix phx.gen.secret)
```

## 4. Prepare the Database

Run the provided script to create, migrate, and seed the database:

```bash
./scripts/reset_and_seed_db.sh
```

## 5. Start the Server

Launch the Phoenix server:

```bash
mix phx.server
```

Visit <http://localhost:4000> in your browser to access the UI.

## 6. Running Tests and Formatting

Before committing code, run:

```bash
mix format
mix test
```

These commands ensure consistent formatting and a passing test suite.

---

For additional documentation, see the project [README](../README.md) and files in the `docs/` directory.
