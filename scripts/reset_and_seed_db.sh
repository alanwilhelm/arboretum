#!/bin/bash
# Script to reset, migrate, and seed the database

# Set script to exit on any error
set -e

echo "=== Arboretum Database Reset and Setup ==="
echo "This script will:"
echo "  1. Drop the existing database"
echo "  2. Create a new database"
echo "  3. Run all migrations"
echo "  4. Seed the database with initial data"
echo ""
echo "Warning: This will DELETE all existing data!"
echo ""

# Ask for confirmation
read -p "Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Operation canceled."
    exit 0
fi

# Project root directory (get the directory the script is in and go up one level)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo ""
echo "=== Step 1: Dropping existing database ==="
mix ecto.drop
echo "✅ Database dropped"

echo ""
echo "=== Step 2: Creating new database ==="
mix ecto.create
echo "✅ Database created"

echo ""
echo "=== Step 3: Running migrations ==="
mix ecto.migrate
echo "✅ Migrations completed"

echo ""
echo "=== Step 4: Seeding database ==="
mix run priv/repo/seeds.exs
echo "✅ Database seeded"

echo ""
echo "=== Database reset and setup completed successfully! ==="