# ChoirHelper Justfile - Development Task Runner

# Default recipe (shows help)
default:
    @just --list

# Auto-format Swift code and markdown docs
format:
    @echo "📝 Formatting Swift code..."
    swift-format --in-place --recursive Sources Tests
    @echo "📝 Formatting markdown docs..."
    markdownlint-cli2 --fix "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Formatting complete"

# Run all linters
lint:
    @echo "🔍 Running SwiftLint..."
    swiftlint lint --strict
    @echo "🔍 Running markdownlint..."
    markdownlint-cli2 "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Linting complete"

# Format check (for CI)
format-check:
    @echo "🔍 Checking Swift formatting..."
    swift-format lint --recursive Sources Tests
    @echo "🔍 Checking markdown formatting..."
    markdownlint-cli2 "**/*.md" "#.build" "#node_modules" "#.beads"
    @echo "✅ Format check complete"

# Run all tests with code coverage
test:
    @echo "🧪 Running tests with coverage..."
    xcrun swift test --enable-code-coverage
    @echo "✅ Tests complete"

# Build the project
build:
    @echo "🔨 Building project..."
    xcrun swift build
    @echo "✅ Build complete"

# Build for release
build-release:
    @echo "🔨 Building release..."
    xcrun swift build -c release
    @echo "✅ Release build complete"

# Run all quality checks (format + lint + test)
validate: format lint test
    @echo "✅ All validation checks passed!"

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    rm -rf .build
    @echo "✅ Clean complete"

# Clean all (including Nix results)
clean-all: clean
    @echo "🧹 Cleaning Nix results..."
    rm -rf result result-*
    @echo "✅ Deep clean complete"

# Update dependencies
update-deps:
    @echo "📦 Updating Swift dependencies..."
    xcrun swift package update
    @echo "✅ Dependencies updated"

# Resolve dependencies
resolve-deps:
    @echo "📦 Resolving Swift dependencies..."
    xcrun swift package resolve
    @echo "✅ Dependencies resolved"

# Check Nix flake
flake-check:
    @echo "❄️  Checking Nix flake..."
    nix flake check
    @echo "✅ Flake check complete"

# Update Nix flake inputs
flake-update:
    @echo "❄️  Updating Nix flake inputs..."
    nix flake update
    @echo "✅ Flake update complete"
