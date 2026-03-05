#!/bin/bash
# Script to publish GitHub release notes with migration highlights

set -e

VERSION="5.0.0"
TAG="5.0.0"
REPO="tradingview/LightweightChartsIOS"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== LightweightCharts iOS v${VERSION} Release Publisher ===${NC}"
echo ""

# Check if tag exists
if ! git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo -e "${RED}Error: Tag ${TAG} does not exist locally.${NC}"
    echo "Please create the tag first: git tag ${TAG}"
    exit 1
fi

# Check if tag is pushed to remote
if ! git ls-remote --tags origin | grep -q "${TAG}$"; then
    echo -e "${YELLOW}Warning: Tag ${TAG} is not pushed to remote yet.${NC}"
    read -p "Push tag now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "${TAG}"
    else
        echo "Please push the tag manually: git push origin ${TAG}"
        exit 1
    fi
fi

# Release notes
RELEASE_NOTES="# Lightweight Charts iOS v${VERSION}

This release upgrades the embedded JavaScript library to TradingView Lightweight Charts v5.1.0 and introduces a new plugin system for extended chart functionality.

## 🎉 What's New

### Plugin System

Version 5.0 introduces a powerful new plugin architecture:

- **SeriesMarkersPlugin** - Explicit control over series markers with lifecycle management
- **UpDownMarkersPlugin** - Directional price movement indicators for LineSeries and AreaSeries
- **TextWatermarkPlugin** - Multi-line text watermarks with per-line styling
- **ImageWatermarkPlugin** - Display images as watermarks on any pane

\`\`\`swift
// Create a text watermark plugin
let watermark = chart.createTextWatermarkPlugin(
    paneIndex: 0,
    options: TextWatermarkOptions(
        text: \"Loading data...\",
        color: \"rgba(171, 71, 188, 0.5)\",
        fontSize: 24
    )
)

// Update or detach when done
watermark.applyOptions(options: TextWatermarkOptions(visible: false))
watermark.detach()
\`\`\`

## 📚 Documentation

- [Plugin Guide](https://github.com/tradingview/LightweightChartsIOS/blob/${TAG}/PLUGIN_GUIDE.md) - Complete plugin system documentation
- [Migration Guide](https://github.com/tradingview/LightweightChartsIOS/blob/${TAG}/MIGRATION_V4_TO_V5.md) - Step-by-step migration from v4

## 🔄 Migration from v4

Most existing code works without changes. Key changes:

- **Minimum iOS version** is now **13.0** (was 12.0 for CocoaPods, 10.0 for SPM)
- \`ChartOptions.watermark\` is **deprecated** - use \`createTextWatermarkPlugin()\` instead
- New explicit plugin APIs for markers and watermarks

\`\`\`ruby
# Update your Podfile
pod 'LightweightCharts', '~> 5.0.0'
\`\`\`

See the [Migration Guide](https://github.com/tradingview/LightweightChartsIOS/blob/${TAG}/MIGRATION_V4_TO_V5.md) for detailed guidance.

## 📝 Full Changelog

See [CHANGELOG.md](https://github.com/tradingview/LightweightChartsIOS/blob/${TAG}/CHANGELOG.md)

## ⬇️ Installation

\`\`\`ruby
pod 'LightweightCharts', '~> 5.0.0'
\`\`\`

---

**License**: Apache License 2.0 | [TradingView](https://www.tradingview.com/)"

# Handle --api flag for GitHub API
if [[ "$1" == "--api" ]]; then
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: GITHUB_TOKEN environment variable not set.${NC}"
        echo "Create a token at: https://github.com/settings/tokens"
        echo "Required scopes: repo (or public_repo for public repos)"
        exit 1
    fi

    echo -e "${GREEN}Using GitHub API to create release...${NC}"

    # Escape newlines for JSON
    JSON_NOTES=$(echo "$RELEASE_NOTES" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    RESPONSE=$(curl -s -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/repos/${REPO}/releases" \
        -d "{
            \"tag_name\": \"${TAG}\",
            \"target_commitish\": \"master\",
            \"name\": \"v${VERSION}\",
            \"body\": \"${JSON_NOTES}\",
            \"draft\": false,
            \"prerelease\": false
        }")

    if echo "$RESPONSE" | grep -q "html_url"; then
        URL=$(echo "$RESPONSE" | grep -o '"html_url": "[^"]*' | cut -d'"' -f4)
        echo -e "${GREEN}✓ Release published successfully!${NC}"
        echo "View at: ${URL}"
    else
        echo -e "${RED}Error creating release:${NC}"
        echo "$RESPONSE"
        exit 1
    fi
    exit 0
fi

# Check for gh CLI
if command -v gh &> /dev/null; then
    echo -e "${GREEN}Using GitHub CLI to create release...${NC}"
    echo "$RELEASE_NOTES" | gh release create "${TAG}" --title "v${VERSION}" --notes-file -
    echo -e "${GREEN}✓ Release published successfully!${NC}"
    echo "View at: https://github.com/${REPO}/releases/tag/${TAG}"
else
    echo -e "${YELLOW}GitHub CLI (gh) not found. Here are your options:${NC}"
    echo ""
    echo "Option 1: Install GitHub CLI"
    echo "  brew install gh"
    echo "  gh auth login"
    echo ""
    echo "Option 2: Create release manually"
    echo "  1. Go to: https://github.com/${REPO}/releases/new"
    echo "  2. Select tag: ${TAG}"
    echo "  3. Title: v${VERSION}"
    echo "  4. Use the release notes below:"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "$RELEASE_NOTES"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Option 3: Use GitHub API with curl (requires GitHub token)"
    echo "  GITHUB_TOKEN=\"your_token\" bash $0 --api"
fi
