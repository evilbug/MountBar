#!/bin/bash

# Semantic Versioning Script for MountBar
# Usage: ./scripts/bump-version.sh [major|minor|patch|pre|release]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the latest tag
get_latest_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"
}

# Parse version components
parse_version() {
    local version=$1
    version=${version#v}  # Remove 'v' prefix
    echo "$version"
}

# Bump version
bump_version() {
    local current=$1
    local bump_type=$2
    
    current=$(parse_version "$current")
    
    # Split into components
    IFS='.' read -r major minor patch <<< "$current"
    IFS='-' read -r patch prerelease <<< "$patch"
    
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            prerelease=""
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            prerelease=""
            ;;
        patch)
            patch=$((patch + 1))
            prerelease=""
            ;;
        pre)
            if [ -z "$prerelease" ]; then
                patch=$((patch + 1))
                prerelease="beta.1"
            else
                # Extract prerelease number
                prenum=${prerelease##*.}
                prename=${prerelease%.*}
                prenum=$((prenum + 1))
                prerelease="${prename}.${prenum}"
            fi
            ;;
        release)
            prerelease=""
            ;;
        *)
            echo -e "${RED}Unknown bump type: $bump_type${NC}"
            exit 1
            ;;
    esac
    
    if [ -n "$prerelease" ]; then
        echo "v${major}.${minor}.${patch}-${prerelease}"
    else
        echo "v${major}.${minor}.${patch}"
    fi
}

# Update version in files
update_version_files() {
    local new_version=$1
    local version=${new_version#v}
    
    echo "Updating version to $version..."
    
    # Update Info.plist if it exists
    if [ -f "src/MountBar/Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" src/MountBar/Info.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" src/MountBar/Info.plist 2>/dev/null || true
        echo -e "${GREEN}✓ Updated Info.plist${NC}"
    fi
    
    # Update README.md badge
    if [ -f "README.md" ]; then
        sed -i '' "s/version-[0-9]*\.[0-9]*\.[0-9]*/version-$version/" README.md 2>/dev/null || true
        echo -e "${GREEN}✓ Updated README.md${NC}"
    fi
    
    # Create or update VERSION file
    echo "$version" > VERSION
    echo -e "${GREEN}✓ Updated VERSION file${NC}"
}

# Main
main() {
    local bump_type=${1:-patch}
    
    # Validate we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository${NC}"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Get current version
    current=$(get_latest_tag)
    echo -e "${YELLOW}Current version: $current${NC}"
    
    # Calculate new version
    new_version=$(bump_version "$current" "$bump_type")
    echo -e "${GREEN}New version: $new_version${NC}"
    
    # Confirm
    read -p "Create tag $new_version? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
    
    # Update version files
    update_version_files "$new_version"
    
    # Commit version changes
    git add -A
    git commit -m "chore: bump version to $new_version" || true
    
    # Create tag
    git tag -a "$new_version" -m "Release $new_version"
    
    echo -e "${GREEN}✓ Created tag $new_version${NC}"
    echo -e "${YELLOW}To push the tag and trigger release:${NC}"
    echo -e "  git push origin main --tags"
}

# Show help
show_help() {
    echo "Semantic Versioning Script for MountBar"
    echo ""
    echo "Usage: $0 [major|minor|patch|pre|release]"
    echo ""
    echo "Commands:"
    echo "  major    - Bump major version (X.0.0)"
    echo "  minor    - Bump minor version (x.X.0)"
    echo "  patch    - Bump patch version (x.x.X) - default"
    echo "  pre      - Create/Increment prerelease (x.x.X-beta.N)"
    echo "  release  - Remove prerelease suffix (x.x.X)"
    echo ""
    echo "Examples:"
    echo "  $0 patch     # 1.0.0 -> 1.0.1"
    echo "  $0 minor     # 1.0.0 -> 1.1.0"
    echo "  $0 major     # 1.0.0 -> 2.0.0"
    echo "  $0 pre       # 1.0.0 -> 1.0.1-beta.1"
    echo "  $0 release   # 1.0.1-beta.1 -> 1.0.1"
}

# Handle arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

main "$@"
