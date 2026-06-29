#!/usr/bin/env bash
# install-macos.sh -- Download and install the Headroom proxy Copilot extension on macOS
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/damnthonyy/vscode/main/scripts/install-macos.sh)
#   or:  bash scripts/install-macos.sh [--port PORT] [--version TAG]
# Default port: 8787

set -euo pipefail

HEADROOM_PORT="${HEADROOM_PORT:-8787}"
GITHUB_REPO="damnthonyy/vscode"
VERSION=""

# Parse optional arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
		--port)
			HEADROOM_PORT="$2"
			shift 2
			;;
		--version)
			VERSION="$2"
			shift 2
			;;
		*)
			echo "Unknown argument: $1" >&2
			echo "Usage: $0 [--port PORT] [--version TAG]" >&2
			exit 1
			;;
	esac
done

# 1. Prerequisite checks

check_command() {
	if ! command -v "$1" &>/dev/null; then
		echo "ERROR: '$1' is not installed or not in PATH." >&2
		echo "       $2" >&2
		exit 1
	fi
}

check_command curl "curl is required to download the extension."
check_command code "Install the 'code' CLI: open VS Code → Cmd+Shift+P → 'Shell Command: Install code in PATH'."

# 2. Kill all VS Code processes
#
# On macOS, Copilot Chat is bundled as a built-in extension inside the app.
# After a first install attempt, VS Code writes a "pending restart" state.
# If any Code Helper process is still running, the reinstall fails with:
#   "Please restart VS Code before reinstalling GitHub Copilot Chat."
# Cmd+Q alone is not enough — helper processes linger in the background.

echo ""
echo "==> Stopping all VS Code processes..."
pkill -f "Visual Studio Code" 2>/dev/null || true
pkill -f "Code Helper"        2>/dev/null || true
sleep 2
echo "    Done."

# 3. Download the VSIX from the latest (or specified) GitHub release

if [[ -z "$VERSION" ]]; then
	echo ""
	echo "==> Fetching latest release tag..."
	VERSION=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
		| grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
	if [[ -z "$VERSION" ]]; then
		echo "ERROR: Could not determine the latest release." >&2
		exit 1
	fi
fi
echo "    Version: $VERSION"

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/copilot-proxy.vsix"
TMPDIR_DL="$(mktemp -d)"
VSIX_FILE="${TMPDIR_DL}/copilot-proxy.vsix"

echo ""
echo "==> Downloading copilot-proxy.vsix..."
if ! curl -fSL -o "$VSIX_FILE" "$DOWNLOAD_URL"; then
	echo "ERROR: Failed to download $DOWNLOAD_URL" >&2
	rm -rf "$TMPDIR_DL"
	exit 1
fi
echo "    Downloaded: $VSIX_FILE ($(du -h "$VSIX_FILE" | cut -f1))"

# 4. Install the extension

echo ""
echo "==> Installing extension into VS Code..."
code --install-extension "$VSIX_FILE" --force
rm -rf "$TMPDIR_DL"
echo "    Done."

PROXY_URL="http://localhost:${HEADROOM_PORT}/v1"

# 5. Settings + auto-update warning

echo ""
echo "======================================================================"
echo " IMPORTANT: Configure the proxy URL in VS Code settings"
echo "======================================================================"
echo ""
echo " Open VS Code → Cmd+Shift+P → 'Open User Settings (JSON)' → add:"
echo ""
echo "   \"github.copilot.chat.proxy.url\": \"${PROXY_URL}\","
echo "   \"extensions.autoUpdate\": false,"
echo "   \"extensions.autoCheckUpdates\": false"
echo ""
echo " Both autoUpdate AND autoCheckUpdates must be false — one alone is"
echo " not enough to prevent VS Code from replacing the patched extension."
echo "======================================================================"
echo ""
echo "==> Installation complete."
echo "    If the extension is ever replaced, re-run:"
echo "    bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install-macos.sh)"
