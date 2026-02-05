# MountBar

[![CI](https://github.com/evilbug/MountBar/actions/workflows/ci.yml/badge.svg)](https://github.com/evilbug/MountBar/actions/workflows/ci.yml)
[![Release](https://github.com/evilbug/MountBar/actions/workflows/release.yml/badge.svg)](https://github.com/evilbug/MountBar/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/evilbug/MountBar)](https://github.com/evilbug/MountBar/releases)
[![License](https://img.shields.io/github/license/evilbug/MountBar)](LICENSE)

A macOS menu bar application for managing and automatically mounting SMB network shares.

## Features

- **Menu Bar Integration**: Lives in your macOS menu bar for quick access
- **Add/Edit Volumes**: Easy-to-use forms for managing SMB mount configurations
- **Automatic Mounting**: Continuously monitors and auto-mounts enabled shares when network becomes available
- **Mount/Unmount**: Manual control to mount and unmount shares on demand
- **Open Folder**: Quick access to mounted shares directly from the menu
- **Secure Password Storage**: Passwords encrypted with AES-GCM and stored in the mount configuration, master key securely stored in Keychain
- **Persistent Storage**: All SMB mount configurations saved using UserDefaults
- **Real-time Status**: Visual indicators showing mount status (mounted/unmounted/mounting/failed)
- **Modern UI**: Built with SwiftUI for a native macOS experience

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Building the Project

1. Open `MountBar/MountBar.xcodeproj` in Xcode
2. Select your development team in the project settings (Signing & Capabilities)
3. Build and run the project (⌘R)

**Note**: The app requires App Sandbox to be disabled to allow `mount_smbfs` system operations.

## Usage

### Adding a New Mount

1. Launch the app - it will appear in your menu bar with a snackbar icon
2. Click the menu bar icon to open the app
3. Click "Add Volume" to add a new SMB mount
4. Fill in the form with your SMB server details:
   - **Volume Name**: A friendly name for this mount
   - **Server Address**: The IP address or hostname of the SMB server (e.g., `192.168.10.1`)
   - **Share Name**: The name of the shared folder (e.g., `user`)
   - **Username**: Your username for authentication
   - **Password**: Your password
   - **Mount Point**: Local path where the volume should be mounted (default: `~/SMBMounts/[sharename]`)
   - **Auto-mount**: Toggle to enable automatic mounting when network is available
5. Click "Add" to save the configuration

### Managing Mounts

- **Mount**: Click the "Mount" button to manually mount an unmounted share
- **Unmount**: Click the "Unmount" button to unmount a mounted share
- **Open Folder**: Click "Open Folder" to open the mounted share in Finder (only visible when mounted)
- **Edit**: Click the pencil icon to edit mount configuration or delete the mount
- **Status Indicator**: Green dot = mounted, Red dot = unmounted/failed, Spinner = mounting

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
- Password (encrypted with AES-GCM, stored in mount configuration)
- Mount point path
- Auto-mount preference
- Creation timestamp
- Mount status (unmounted/mounting/mounted/failed)

## Architecture

### Core Files
- **MountBarApp.swift**: Main app entry point with menu bar setup
- **Models/SMBMount.swift**: Data model for SMB mount entities with status tracking

### Views
- **MenuBarView.swift**: Main menu bar popover view with mount list
- **AddVolumeView.swift**: Form for adding new SMB mounts
- **EditVolumeView.swift**: Form for editing existing mounts with delete functionality
- **MountItemView**: Individual mount item display with status and controls

### Managers
- **SMBMountManager.swift**: Handles data persistence, CRUD operations for mounts
- **MountDaemon.swift**: Background daemon for mounting, unmounting, and auto-mount monitoring
- **PasswordManager.swift**: Manages encryption/decryption of passwords, stores master key in Keychain

### Key Components

**MountDaemon**:
- Runs a timer every 5 seconds to check mount status
- Automatically mounts volumes with auto-mount enabled
- Detects when mounts become unavailable and updates status
- Handles mount/unmount operations using `mount_smbfs` and `umount`

**PasswordManager**:
- Encrypts passwords using AES-GCM with a master key
- Master key is stored securely in macOS Keychain
- Encrypted passwords are stored within the SMBMount model
- Application retrieves master key once at startup for decryption operations

## Technical Details

- **Mounting**: Uses macOS `mount_smbfs` command-line tool
- **Mount Detection**: Uses `/sbin/mount` to check if volumes are mounted
- **Mount Point**: Default location is `~/SMBMounts/[sharename]`
- **Security**: App Sandbox disabled to allow system mount operations
- **Password Encoding**: Passwords are URL-encoded for safe SMB URL construction

## Troubleshooting

- **Mount fails**: Ensure server address is reachable and credentials are correct
- **Permission errors**: The app requires App Sandbox to be disabled
- **Stale mounts**: The app automatically cleans up stale mount points before mounting
- **Network unavailable**: Auto-mount will continuously retry when network becomes available

## About

This app was created by [Iago OP](https://github.com/evilbug).

If you find it usefull, please consider buying me a coffee :)
[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/iagoop)