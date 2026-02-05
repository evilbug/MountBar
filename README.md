# MountBar

[![CI](https://github.com/evilbug/MountBar/actions/workflows/ci.yml/badge.svg)](https://github.com/evilbug/MountBar/actions/workflows/ci.yml)
[![Release](https://github.com/evilbug/MountBar/actions/workflows/release.yml/badge.svg)](https://github.com/evilbug/MountBar/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/evilbug/MountBar)](https://github.com/evilbug/MountBar/releases)
[![License](https://img.shields.io/github/license/evilbug/MountBar)](LICENSE)

A secure macOS menu bar application for managing and automatically mounting SMB network shares.

## Features

- **Menu Bar Integration**: Lives in your macOS menu bar for quick access
- **Add/Edit Volumes**: Easy-to-use forms for managing SMB mount configurations
- **Automatic Mounting**: Continuously monitors and auto-mounts enabled shares when network becomes available
- **Mount/Unmount**: Manual control to mount and unmount shares on demand
- **Open Folder**: Quick access to mounted shares directly from the menu
- **Secure Password Storage**: Passwords encrypted with AES-GCM and stored in macOS Keychain
- **Persistent Storage**: All SMB mount configurations saved securely
- **Real-time Status**: Visual indicators showing mount status (mounted/unmounted/mounting/failed)
- **Modern UI**: Built with SwiftUI for a native macOS experience
- **Input Validation**: Prevents command injection and path traversal attacks

## Security Features

MountBar prioritizes security in every aspect:

- **🔐 App Sandbox**: Runs with macOS App Sandbox enabled (network client entitlement)
- **🔑 Secure Keychain Storage**: 
  - Master encryption key stored in macOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  - Encrypted passwords stored in Keychain (not UserDefaults)
  - No keychain prompts during normal operation
- **🛡️ Password Protection**:
  - AES-GCM encryption for all stored passwords
  - Passwords passed via stdin (not command-line arguments)
  - No password exposure in process listings or logs
- **🔒 Memory Security**:
  - Root encryption key cleared from memory when no longer needed
  - Uses `SecRandomCopyBytes` for cryptographically secure random key generation
- **✅ Input Validation**:
  - Server address validation (prevents command injection)
  - Share name sanitization
  - Mount point path traversal protection
  - Symlink resolution checks
- **📝 Safe Logging**: No sensitive data (passwords, credentials) written to logs

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)

## Installation

### From Release (Recommended)

1. Download the latest `MountBar.dmg` from [Releases](https://github.com/evilbug/MountBar/releases)
2. Open the DMG and drag `MountBar.app` to your Applications folder
3. Launch MountBar from Applications

### Build from Source

```bash
git clone https://github.com/evilbug/MountBar.git
cd MountBar/src
xcodebuild -project MountBar.xcodeproj -scheme MountBar -configuration Release
```

The built app will be in `build/Release/MountBar.app`

## Usage

### Adding a New Mount

1. Launch the app - it will appear in your menu bar with a server rack icon (📁 fallback)
2. Click the menu bar icon to open the popover
3. Click "Add Volume" to add a new SMB mount
4. Fill in the form with your SMB server details:
   - **Volume Name**: A friendly name for this mount
   - **Server Address**: The IP address or hostname (e.g., `192.168.10.1`, `nas.local`)
   - **Share Name**: The shared folder name (e.g., `user`, `shared`)
   - **Username**: Your SMB username
   - **Password**: Your SMB password (stored encrypted)
   - **Mount Point**: Local path (default: `~/SMBMounts/[sharename]`)
   - **Auto-mount**: Enable for automatic mounting
5. Click "Add" to save

### Managing Mounts

- **Mount**: Click "Mount" to manually mount a share
- **Unmount**: Click "Unmount" to safely unmount
- **Open Folder**: Click "Open Folder" to reveal in Finder (mounted shares only)
- **Edit**: Click the pencil icon to modify or delete a mount
- **Status Indicators**: 
  - 🟢 Green = Mounted
  - 🔴 Red = Unmounted/Failed
  - 🔄 Spinner = Mounting in progress

### Auto-Mount Feature

Mounts with "Auto-mount" enabled are continuously monitored every 5 seconds:
- Automatically mounts when the app starts
- Automatically remounts when network becomes available (e.g., returning home with laptop)
- Silently retries failed mounts without user warnings
- Perfect for seamless access to network shares

## SMB Mount Entity

Each SMB mount contains the following information:
- Unique ID (UUID)
- Volume name
- Server address
- Share name
- Username
- Password (encrypted with AES-GCM, stored in macOS Keychain)
- Mount point path
- Auto-mount preference
- Creation timestamp
- Mount status (unmounted/mounting/mounted/failed)

## Architecture

### Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| App Entry | `MountBarApp.swift` | Menu bar setup, lifecycle |
| Mount Data | `Models/SMBMount.swift` | Data model + Input validation |
| UI | `Views/*.swift` | SwiftUI interfaces |
| Mount Manager | `SMBMountManager.swift` | Persistence, CRUD operations |
| Mount Daemon | `MountDaemon.swift` | Background mounting/unmounting |
| Password Manager | `PasswordManager.swift` | Encryption, Keychain operations |
| Keychain Manager | `KeychainManager.swift` | Legacy password migration |

### Security Architecture

```
┌─────────────────────────────────────────┐
│           User Interface                │
│    (AddVolumeView/EditVolumeView)       │
│         ↓ Input Validation              │
├─────────────────────────────────────────┤
│         SMBMountManager                 │
│      (Persistence Layer)                │
│         ↓                               │
├─────────────────────────────────────────┤
│         PasswordManager                 │
│    (AES-GCM Encryption)                 │
│         ↓                               │
├─────────────────────────────────────────┤
│         MountDaemon                     │
│   (Password via stdin to mount_smbfs)   │
│         ↓                               │
├─────────────────────────────────────────┤
│          macOS Keychain                 │
│    (Master Key Storage)                 │
└─────────────────────────────────────────┘
```

## CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment:

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI** | Push/PR to main | Build, test, lint, security scan |
| **Release** | Tag push (v*.*.*) | Build, sign, create DMG, GitHub release |
| **Manual Bump** | Workflow dispatch | Semantic version bump via UI |

### Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):
- `v1.2.3` - MAJOR.MINOR.PATCH
- `v1.2.3-beta.1` - Pre-release versions

### Creating a Release

**Option 1: Local Script**
```bash
./scripts/bump-version.sh patch  # or: minor, major, pre, release
```

**Option 2: GitHub Actions**
1. Go to Actions → "Manual Version Bump"
2. Select bump type
3. Run workflow

**Option 3: Manual Tag**
```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

The release workflow automatically:
- Builds the app
- Creates a signed DMG
- Generates changelog from commits
- Creates GitHub release with artifacts

## Development

### Setup

```bash
git clone https://github.com/evilbug/MountBar.git
cd MountBar
```

### Build

```bash
cd src
xcodebuild -project MountBar.xcodeproj -scheme MountBar -configuration Release
```

### Test

```bash
cd src
xcodebuild test -project MountBar.xcodeproj -scheme MountBar
```

### Security Scan

```bash
# Install SwiftLint if needed
brew install swiftlint
swiftlint
```

## Security Considerations

### What We Protect Against

| Threat | Mitigation |
|--------|-----------|
| Credential theft in logs | Passwords passed via stdin, not logged |
| Process argument exposure | No passwords in command-line args |
| Keychain prompt fatigue | `AfterFirstUnlockThisDeviceOnly` access |
| Path traversal | Symlink resolution + path validation |
| Command injection | Input validation on server/share names |
| Memory dumps | Secure memory clearing for root key |
| Weak random keys | `SecRandomCopyBytes` for key generation |

### Permissions

MountBar requires these entitlements:
- `com.apple.security.app-sandbox` - Enabled
- `com.apple.security.network.client` - SMB connections
- `com.apple.security.files.user-selected.read-write` - File access
- `com.apple.security.temporary-exception.files.home-relative-path.read-write` - Mount point creation

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Mount fails | Check server address, credentials, network connectivity |
| Permission errors | Ensure mount point is within `~/` directory |
| Keychain prompts | First launch only; won't prompt again until reboot |
| Stale mounts | App auto-cleans stale mount points |
| Network unavailable | Auto-mount continuously retries when network returns |

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Security Reports

Report security vulnerabilities privately via [GitHub Security Advisories](https://github.com/evilbug/MountBar/security/advisories/new).

## License

[MIT License](LICENSE) - See LICENSE file for details.

## About

Created by [Iago OP](https://github.com/evilbug)

If you find MountBar useful, consider supporting development:

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/iagoop)