# Repository Guidelines

## Project Structure & Module Organization

- `bin/clir` is the CLI entrypoint (Rscript wrapper); it sources shared logic from `src/`.
- `src/` contains the core R implementation (e.g., install/update/validate helpers in `src/util.R`).
- `install_clir.sh` bootstraps dependencies and installs the CLI.
- `r/` holds runtime config/state (e.g., `r/clir.yml` created by `clir config --init`).
- `Dockerfile` and `compose.yml` define containerized usage.
- CI workflows live in `.github/workflows/`.

## Build, Test, and Development Commands

- `./install_clir.sh` installs the CLI and required R packages locally.
- `bin/clir --help` (or `clir --help` if on PATH) shows the CLI contract.
- `bin/clir config --init` initializes local configuration in `r/clir.yml`.
- `docker build -t clir .` builds the Docker image locally.
- Optional lint (mirrors CI intent): `R -q -e 'lintr::lint_dir("src")'`.

## Coding Style & Naming Conventions

- R code uses 2-space indentation and snake_case for functions/variables (see `src/`).
- Keep lines to 99 characters where practical (configured in `.lintr`).
- Prefer small, single-purpose helper functions (e.g., `install_pkgs`, `validate_loading`).

## Testing Guidelines

- There are no unit-test files; CI runs integration-style CLI checks.
- Follow the workflow in `.github/workflows/test.yml` as a template.
- Typical local checks:
  - `./install_clir.sh`
  - `bin/clir --version`
  - `bin/clir install foreach doParallel tidyverse`
  - `bin/clir validate foreach doParallel tidyverse`

## Commit & Pull Request Guidelines

- Commit messages are short, imperative, and sentence case (e.g., “Update CI”, “Remove explicit return”).
- PRs should describe intent, mention how changes were validated, and keep related updates together.
- Ensure CI passes (lint/test workflows) before requesting review.

## Configuration Tips

- The CLI respects `R_LIBS_USER`/`R_LIBS` and writes config to `r/clir.yml`.
- Add `${HOME}/.clir/bin` to PATH for a global `clir` command.

## Code Design Principles

Follow Robert C. Martin's SOLID and Clean Code principles:

### SOLID Principles

1. **SRP (Single Responsibility)**: One reason to change per class; separate concerns (e.g., storage vs formatting vs calculation)
2. **OCP (Open/Closed)**: Open for extension, closed for modification; use polymorphism over if/else chains
3. **LSP (Liskov Substitution)**: Subtypes must be substitutable for base types without breaking expectations
4. **ISP (Interface Segregation)**: Many specific interfaces over one general; no forced unused dependencies
5. **DIP (Dependency Inversion)**: Depend on abstractions, not concretions; inject dependencies

### Clean Code Practices

- **Naming**: Intention-revealing, pronounceable, searchable names (`daysSinceLastUpdate` not `d`)
- **Functions**: Small, single-task, verb names, 0-3 args, extract complex logic
- **Classes**: Follow SRP, high cohesion, descriptive names
- **Error Handling**: Exceptions over error codes, no null returns, provide context, try-catch-finally first
- **Testing**: TDD, one assertion/test, FIRST principles (Fast, Independent, Repeatable, Self-validating, Timely), Arrange-Act-Assert pattern
- **Code Organization**: Variables near usage, instance vars at top, public then private functions, conceptual affinity
- **Comments**: Self-documenting code preferred, explain "why" not "what", delete commented code
- **Formatting**: Consistent, vertical separation, 88-char limit, team rules override preferences
- **General**: DRY, KISS, YAGNI, Boy Scout Rule, fail fast

## Development Methodology

Follow Martin Fowler's Refactoring, Kent Beck's Tidy Code, and t_wada's TDD principles:

### Core Philosophy

- **Small, safe changes**: Tiny, reversible, testable modifications
- **Separate concerns**: Never mix features with refactoring
- **Test-driven**: Tests provide safety and drive design
- **Economic**: Only refactor when it aids immediate work

### TDD Cycle

1. **Red** → Write failing test
2. **Green** → Minimum code to pass
3. **Refactor** → Clean without changing behavior
4. **Commit** → Separate commits for features vs refactoring

### Practices

- **Before**: Create TODOs, ensure coverage, identify code smells
- **During**: Test-first, small steps, frequent tests, two hats rule
- **Refactoring**: Extract function/variable, rename, guard clauses, remove dead code, normalize symmetries
- **TDD Strategies**: Fake it, obvious implementation, triangulation

### When to Apply

- Rule of Three (3rd duplication)
- Preparatory (before features)
- Comprehension (as understanding grows)
- Opportunistic (daily improvements)

### Key Rules

- One assertion per test
- Separate refactoring commits
- Delete redundant tests
- Human-readable code first

> "Make the change easy, then make the easy change." - Kent Beck
