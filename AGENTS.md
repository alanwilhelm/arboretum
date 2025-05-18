# AGENTS Instructions for arboretum

These guidelines explain how the AI Code Assistant should interact with this repository.

## Code Guidelines
- Write clean, well-formatted Elixir code following the project's style conventions
- Include appropriate tests for any new functionality
- Ensure code is properly documented with Elixir docstrings where appropriate

## Development Workflow

1. **Format code** before committing:
   ```bash
   mix format
   ```
2. **Run tests** to ensure everything passes:
   ```bash
   mix test
   ```
3. Keep commit messages concise and descriptive. Use one commit per logical change.
4. Documentation lives in the `docs/` directory. Add or update docs when you introduce new features.

## Commit Guidance
- Work directly on the main branch (no new branches).
- Provide clear commit messages describing the changes.
- Keep the worktree clean before finishing.

## Setup

See [docs/SETUP.md](docs/SETUP.md) for detailed setup instructions.

## Pull Requests

- Each PR should focus on a single feature or fix.
- Ensure the test suite passes and code is formatted before opening a PR.