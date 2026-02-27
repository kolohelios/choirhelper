# AI Agent Collaboration Standards

This document defines standards for AI agents working on the ChoirHelper project.

## CRITICAL: Version Control

**This project uses Jujutsu (jj), NOT git.**

- ALWAYS use `jj` commands for version control operations
- NEVER use `git` commands directly
- Jujutsu manages git as a backend, but you interact only through `jj`

## Commit Standards

### Conventional Commits

All commits MUST follow [Conventional Commits](https://www.conventionalcommits.org/):

**Format:** `<type>(<scope>): <subject>`

**Maximum length:** 70 characters for the title

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build/tooling
- `build`: Nix/build system changes
- `ci`: CI/CD changes

### Atomic Commits

Each commit MUST be:

- **Self-contained**: Passes `just validate` (format + lint + test)
- **Single-purpose**: One logical change per commit
- **Reviewable**: Easy to understand in isolation
- **Revertible**: Can be safely reverted without breaking the build

## Code Quality Requirements

### Before Every Commit

Run the validation suite:

```bash
just validate
```

### Swift Code Standards

- SwiftLint rules in `.swiftlint.yml`
- swift-format rules in `.swift-format`
- Line length: 100 characters (format), 120 characters (lint warning)
- Indentation: 4 spaces
- Swift 6 strict concurrency

### Testing Requirements

- Protocol-based design with mock implementations
- Code coverage target: **80% minimum**
- All tests must pass before commit

### Documentation Standards

- Markdown linting with markdownlint (`.markdownlint.json`)
- Update documentation when changing behavior

## Development Workflow

```bash
cd choir_helper
nix develop          # Or: direnv allow
just validate        # Run all quality checks
just build           # Build the project
just test            # Run tests with coverage
```

## Version Control with Jujutsu

```bash
jj describe -m "type(scope): description"
jj new -m "feat(models): add score types"
jj git push --all
```

## Critical Rules

- NEVER mention Claude, AI, or automation in commits or PRs
- Write commits as if a human developer wrote them
- Focus on "why" in the title, "what/how" in the body
- Quality over speed - every commit should be production-ready
