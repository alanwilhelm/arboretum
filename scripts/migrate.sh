#!/bin/bash
# Script to run database migrations

# Set script to exit on any error
set -e

echo "=== Arboretum Database Migration ==="
echo ""

# Project root directory (get the directory the script is in and go up one level)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Running migrations..."
mix ecto.migrate
echo "✅ Migrations completed"

echo ""
echo "=== Database migration completed successfully! ==="