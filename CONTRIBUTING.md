# Contributing to Arboretum

Thank you for considering contributing to Arboretum! This document outlines the process for contributing to the project.

## Development Workflow

1. **Fork the Repository**: Fork the repository on GitHub.

2. **Clone Your Fork**: 
   ```bash
   git clone https://github.com/your-username/arboretum.git
   cd arboretum
   ```

3. **Create a Feature Branch**: 
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make Your Changes**: Implement your changes with appropriate tests.

5. **Follow Code Standards**:
   - Run `mix format` before committing
   - Ensure all tests pass with `mix test`
   - Follow Elixir best practices and conventions

6. **Commit Your Changes**:
   ```bash
   git commit -m "Add feature X"
   ```

7. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

8. **Submit a Pull Request**: Create a pull request from your fork to the main repository.

## Pull Request Guidelines

- Provide a clear description of the problem your PR solves
- Include relevant issue numbers in the PR description
- Make sure all tests pass and add new tests for new functionality
- Update documentation as needed
- Keep PRs focused on a single concern/feature

## Development Setup

Follow the setup instructions in the README.md file to get your development environment running.

## Testing

All new features should include appropriate tests. Run the test suite with:

```bash
mix test
```

## Code Style

We follow the standard Elixir formatting conventions. Run the formatter before committing:

```bash
mix format
```

## License

By contributing to Arboretum, you agree that your contributions will be licensed under the project's MIT License.