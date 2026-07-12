---
name: hypr-desktop-control
description: Enables the agent to control active windows, workspaces, screenshot capture, media playback, and KDE Connect device messaging within the Hyprland desktop environment. Activate this skill whenever you need to interact with windows, query screen state, control playback, or send push notifications.
---

# Hyprland Graphical Desktop Control Manager

This skill provides a unified suite of wrapper scripts to inspect and manipulate the Hyprland desktop environment, query workspaces, capture screenshots, filter media pausing, and send notifications to paired devices.

> [!IMPORTANT]
> **DO NOT** run direct CLI binaries (`hyprctl`, `grim`, `playerctl`, `kdeconnect-cli`) in your terminal commands. Always call the corresponding wrapper scripts listed below. This ensures proper parameters, automatic user desktop notification of changes, and prevents repeating permission prompts.

---

## 1. Inspecting Workspaces & Windows

To inspect the workspace state and layout:

* **List all active workspaces (including special workspaces):**
  ```bash
  hyprctl workspaces -j
  ```

* **Get active monitor workspace details:**
  ```bash
  hyprctl activeworkspace -j
  ```

* **Determine current window's workspace (Crucial for Special Workspaces):**
  Special workspaces (scratchpads) act as overlays. Always inspect the active window's workspace:
  ```bash
  hyprctl activewindow -j | jq '.workspace'
  ```

* **List all open client windows:**
  ```bash
  hyprctl clients -j
  ```

---

## 2. Window & Workspace Control (`hyprcontrol`)

To change focus, workspace, floating status, or layout position, use the `hyprcontrol` wrapper:
```bash
/home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol '<lua-dispatcher>'
```
This executes the dispatcher and triggers a desktop notification via `notify-send`.

### A. Focus & Workspaces
* **Focus a normal workspace (by ID or Name):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.focus({ workspace = "1" })'
  ```
* **Toggle a Special Workspace (scratchpad):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.workspace.toggle_special("magic3")'
  ```
* **Focus a window by its hexadecimal address (Highly Recommended):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.focus({ window = "address:0x<address>" })'
  ```
  > [!TIP]
  > It is always preferred to target windows using their hexadecimal address (`address:0x...`) rather than their class name, as addresses are 100% unique. Only use the class name if the target is a window that is continuously opened and closed (making its address dynamic).
* **Focus by window class:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.focus({ window = "class:<class>" })'
  ```
* **Directional Focus (move focus left, right, up, down):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.focus({ direction = "l" })'  # Left ("r", "u", "d")
  ```

### B. Layout & Geometry Modifications
* **Toggle Floating State:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.window.float({ action = "toggle" })'
  ```
* **Move/Swap Tiling Window position:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcontrol 'hl.dsp.window.move({ direction = "l" })'
  ```

---

## 3. Screen & Window Capture (`hyprcapture`)

To visualize what is on the screen without disturbing window focus, use the `hyprcapture` script. 

Always prefix the execution with `HYPRCAPTURE_DIR` pointing to your conversation's unique scratch directory to prevent collision and bypass authorization prompts:
```bash
HYPRCAPTURE_DIR=/home/stefano/.gemini/antigravity-cli/brain/<conversation-id>/scratch
```

* **Capture Active Monitor (Visualizes entire screen):**
  ```bash
  HYPRCAPTURE_DIR=/home/stefano/.gemini/antigravity-cli/brain/<conversation-id>/scratch /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcapture output
  ```

* **Capture Specific Window (WITHOUT changing focus - Recommended):**
  ```bash
  HYPRCAPTURE_DIR=/home/stefano/.gemini/antigravity-cli/brain/<conversation-id>/scratch /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcapture window <target>
  ```
  Where `<target>` can be `address:0x...`, `class:...`, or `title:...`.

* **Capture Active Window Only (Falls back to hyprshot):**
  ```bash
  HYPRCAPTURE_DIR=/home/stefano/.gemini/antigravity-cli/brain/<conversation-id>/scratch /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprcapture window
  ```

* **Inspect the captured screen:**
  View the image file from your conversation's scratch directory:
  ```json
  {
    "AbsolutePath": "/home/stefano/.gemini/antigravity-cli/brain/<conversation-id>/scratch/hypr_capture.png"
  }
  ```

---

## 4. Media Control & Filtering (`hyprplayer`)

To list media status or pause players selectively, use the `hyprplayer` wrapper:
```bash
/home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprplayer <action> [player]
```

### A. Actions
* **List active players and current track metadata:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprplayer list
  ```
* **Pause only video/browser players (preserves music):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprplayer pause-video
  ```
* **Pause all active players:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprplayer pause-all
  ```
* **Pause a specific player (e.g., spotify or kdeconnect):**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprplayer pause-player <player-name>
  ```

> [!IMPORTANT]
> **DO NOT** pause active music players (such as Spotify, KDE Connect phone tracks, or browser tabs playing tracks with artist metadata) unless the user explicitly asks to pause music, pause everything, or pause that specific player. For temporary screen captures, use `pause-video` or let music continue playing.

---

## 5. KDE Connect Notifications & Sharing (`hyprconnect`)

To list, ping, or send clipboard text to paired devices via KDE Connect, use the `hyprconnect` wrapper:
```bash
/home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprconnect <action> [device_id] [content]
```

### A. Actions
* **List paired and reachable devices:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprconnect list
  ```
* **Send a push notification (ping message) to a device:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprconnect notify <device_id> "<message>"
  ```
* **Share text or clipboard content with a device:**
  ```bash
  /home/stefano/.gemini/config/skills/hypr_desktop_control/scripts/hyprconnect share <device_id> "<text>"
  ```
