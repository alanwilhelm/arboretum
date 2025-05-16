# Arboretum Scripts

This directory contains utility scripts for managing the Arboretum application.

## Available Scripts

### `reset_and_seed_db.sh`

Resets the database and populates it with seed data. This script will:

1. Drop the existing database
2. Create a new database 
3. Run all migrations
4. Seed the database with initial data

**Usage:**

```bash
./scripts/reset_and_seed_db.sh
```

**Warning:** This will delete all existing data in the database!

### `migrate.sh`

Runs database migrations only. Use this to update your database schema without losing data.

**Usage:**

```bash
./scripts/migrate.sh
```

## Adding New Scripts

When adding new scripts to this directory:

1. Make sure to make them executable: `chmod +x scripts/your_script.sh`
2. Add documentation about the script in this README
3. Use proper error handling and user feedback in your scripts