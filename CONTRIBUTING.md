# Contributing to MountBar

Thank you for your interest in contributing to MountBar! This document provides guidelines and information for contributors.

## Security First

MountBar handles sensitive operations (SMB mounts with passwords). All contributions must prioritize security:

- Never commit hardcoded credentials
- Follow secure coding practices
- Run security scans before submitting PRs
- Report security vulnerabilities privately via GitHub Security Advisories

## Development Setup

### Prerequisites
- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

### Building
```bash
cd src
xcodebuild -project MountBar.xcodeproj -scheme MountBar
```

### Running Tests
```bash
cd src
xcodebuild test -project MountBar.xcodeproj -scheme MountBar
```

## Pull Request Process

1. **Fork and Branch**: Create a feature branch from `main`
2. **Code**: Make your changes following our style guide
3. **Test**: Ensure all tests pass and add new tests for new features
4. **Security**: Verify no security regressions
5. **Document**: Update README.md if needed
6. **PR**: Submit using our PR template

## Semantic Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes

### Creating a Release

**Option 1: Manual Script (Recommended)**
```bash
./scripts/bump-version.sh patch  # or minor, major, pre
```

**Option 2: GitHub Actions**
Go to Actions → "Manual Version Bump" → Run workflow

## CI/CD Pipeline

Our GitHub Actions workflows:
- **CI**: Builds, tests, and lints on every push/PR
- **Security Scan**: CodeQL analysis for vulnerabilities
- **Release**: Automatic release on tag push with DMG generation

## Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable names
- Add comments for complex security logic
- Keep functions focused and small

## Reporting Issues

- Use GitHub Issues
- Include macOS version and MountBar version
- Provide steps to reproduce
- For security issues, use private vulnerability reporting

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
