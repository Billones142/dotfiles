---
name: hypr-desktop-control
description: Enables the agent to control active windows, workspaces, screenshot capture, media playback, and KDE Connect device messaging within the Hyprland desktop environment using Model Context Protocol (MCP). Activate this skill whenever you need to interact with windows, query screen state, control playback, or send push notifications.
---

# Hyprland Graphical Desktop Control Manager

This plugin exposes MCP tools to inspect and manipulate the Hyprland desktop environment, query workspaces, capture screenshots, control media playback, and send messages/notifications to paired devices.

> [!IMPORTANT]
> **DO NOT** run direct CLI binaries (`hyprctl`, `grim`, `playerctl`, `kdeconnect-cli`) or wrapper scripts. Always use the MCP tools exposed by the `hypr-desktop-control` server. This ensures proper parameters, automatic desktop notifications, and correct window/workspace focus/screenshot behavior.

## Available Tools

### 1. State Inspection (`get_desktop_state`)
Get the current state of workspaces, clients, active window, and monitors.

### 2. Workspace & Window Control (`focus_workspace`, `execute_dispatcher`)
* **Focus a workspace:** Use `focus_workspace(workspace="N")`. This tool automatically dismisses any open special workspace (scratchpad) on the active monitor first, preventing it from overlaying or blocking regular workspace content.
* **Execute raw Lua dispatcher:** Use `execute_dispatcher(dispatcher="hl.dsp...")`.

### 3. Screen & Window Capture (`take_screenshot`)
* **Take a screenshot:** Use `take_screenshot(mode="output"|"window", target=None, save_directory=None, delay_seconds=0.5)`.
* This tool automatically waits for `delay_seconds` to allow Hyprland's transitions and animations to complete before taking the screenshot.
* Default screenshot output path: `${HYPRCAPTURE_DIR}` or `~/.gemini/antigravity-cli/scratch/hypr_capture.png`.

### 4. Media Control (`media_control`)
* **Control media players:** Use `media_control(action="list"|"pause_video"|"pause_all"|"pause_player", player=None)`.
* Avoid pausing music players unless the user explicitly requests it.

### 5. KDE Connect (`kde_connect_control`)
* **Interact with paired devices:** Use `kde_connect_control(action="list"|"notify"|"share", device_id=None, content=None)`.

### 6. Action Concatenation (`execute_sequence`)
To chain multiple actions together in a single execution step (e.g., focus a workspace, wait for animations, and take a screenshot), use `execute_sequence(actions=[...])`.
Example sequence payload:
```json
[
  {"type": "focus_workspace", "workspace": "3"},
  {"type": "screenshot", "mode": "output"}
]
```
