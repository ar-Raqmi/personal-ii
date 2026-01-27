#!/usr/bin/env bash
# One-time setup script for hyprpm plugins
# This runs automatically on first Hyprland start

SETUP_MARKER="$HOME/.config/illogical-impulse/hyprpm_setup_done"

# Check if already set up
if [ -f "$SETUP_MARKER" ]; then
    exit 0
fi

# Check if hyprpm is available
if ! command -v hyprpm > /dev/null 2>&1; then
    exit 0
fi

# Notify user
notify-send "Hyprland Setup" "Setting up hyprbars plugin..." -t 3000 2>/dev/null || true

# Add repository
hyprpm add https://github.com/hyprwm/hyprland-plugins 2>/dev/null || true

# Update headers
hyprpm update 2>/dev/null || true

# Enable hyprbars
if hyprpm enable hyprbars 2>/dev/null; then
    # Reload to load the plugin immediately
    hyprpm reload -n 2>/dev/null || true
    notify-send "Hyprland Setup" "✓ Hyprbars plugin enabled!" -t 3000 2>/dev/null || true
fi

# Mark as complete
mkdir -p "$(dirname "$SETUP_MARKER")"
touch "$SETUP_MARKER"
