import os
import re
import sys
import json
import time
import asyncio
import subprocess
from typing import Any, Dict, List, Optional
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("hypr-desktop-control")

def get_home_dir() -> str:
    return os.environ.get("HOME", "/home/stefano")

def send_notification(app_name: str, title: str, message: str, icon: Optional[str] = None, urgency: str = "normal"):
    try:
        # Check if notify-send is available
        if subprocess.run(["which", "notify-send"], capture_output=True).returncode == 0:
            cmd = ["notify-send", "-a", app_name, "-u", urgency]
            if icon:
                cmd.extend(["-i", icon])
            cmd.extend([title, message])
            subprocess.run(cmd, check=True)
    except Exception as e:
        sys.stderr.write(f"Failed to send desktop notification: {e}\n")

def get_active_special_workspace() -> Optional[str]:
    try:
        res = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True)
        monitors = json.loads(res.stdout)
        for monitor in monitors:
            if monitor.get("focused"):
                special = monitor.get("specialWorkspace", {})
                if special.get("id", 0) != 0 and special.get("name"):
                    return special.get("name")
    except Exception as e:
        sys.stderr.write(f"Error checking active special workspace: {e}\n")
    return None

def dismiss_active_special_workspaces() -> List[str]:
    dismissed = []
    try:
        res = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True)
        monitors = json.loads(res.stdout)
        for monitor in monitors:
            special = monitor.get("specialWorkspace", {})
            if special.get("id", 0) != 0 and special.get("name"):
                name = special.get("name")
                if name.startswith("special:"):
                    name = name[len("special:"):]
                # Toggle special workspace to hide it
                dispatcher = f'hl.dsp.workspace.toggle_special("{name}")'
                subprocess.run(["hyprctl", "dispatch", dispatcher], capture_output=True, text=True, check=True)
                dismissed.append(name)
    except Exception as e:
        sys.stderr.write(f"Error dismissing special workspaces: {e}\n")
    return dismissed

def run_dispatcher_internal(dispatcher: str, send_notify: bool = True) -> str:
    res = subprocess.run(["hyprctl", "dispatch", dispatcher], capture_output=True, text=True)
    stdout = res.stdout.strip()
    stderr = res.stderr.strip()
    
    if res.returncode != 0 or "error" in stdout.lower() or "error" in stderr.lower():
        error_msg = stdout if stdout else stderr
        if send_notify:
            send_notification("hyprcontrol", "Error de Control", f"Fallo al ejecutar: {dispatcher}\nError: {error_msg}", urgency="critical")
        raise Exception(f"Dispatcher failed: {error_msg}")
        
    if send_notify:
        title = "Control de Hyprland"
        msg = f"Se ejecutó con éxito: {dispatcher}"
        icon = "preferences-desktop-display"
        
        # Regexes matching bash script
        pat_window = r'hl\.dsp\.focus.*window\s*=\s*"([^"]+)"'
        pat_dir = r'hl\.dsp\.focus.*direction\s*=\s*"([^"]+)"'
        pat_special = r'hl\.dsp\.workspace\.toggle_special\("([^"]+)"\)'
        pat_workspace = r'hl\.dsp\.focus.*workspace\s*=\s*"([^"]+)"'
        pat_float = r'hl\.dsp\.window\.float'
        
        if re.search(pat_window, dispatcher):
            m = re.search(pat_window, dispatcher)
            title = "Foco Cambiado"
            msg = f"Ventana enfocada: {m.group(1)}"
        elif re.search(pat_dir, dispatcher):
            m = re.search(pat_dir, dispatcher)
            title = "Foco Cambiado"
            direction = m.group(1)
            dir_names = {"l": "izquierda", "r": "derecha", "u": "arriba", "d": "abajo"}
            msg = f"Foco movido hacia la {dir_names.get(direction, direction)}"
        elif re.search(pat_special, dispatcher):
            m = re.search(pat_special, dispatcher)
            title = "Workspace Especial"
            msg = f"Workspace especial alternado: {m.group(1)}"
        elif re.search(pat_workspace, dispatcher):
            m = re.search(pat_workspace, dispatcher)
            title = "Workspace Cambiado"
            msg = f"Workspace enfocado: {m.group(1)}"
        elif re.search(pat_float, dispatcher):
            title = "Estado de Ventana"
            msg = "Estado flotante de la ventana alternado"
            
        send_notification("hyprcontrol", title, msg, icon=icon)
        
    return stdout

def focus_workspace_internal(workspace: str, dismiss_special: bool = True, send_notify: bool = True) -> Dict[str, Any]:
    dismissed = []
    if dismiss_special:
        dismissed = dismiss_active_special_workspaces()
        if dismissed:
            # Sleep a bit to let the dismiss animation complete
            time.sleep(0.5)
            
    dispatcher = f'hl.dsp.focus({{ workspace = "{workspace}" }})'
    result = run_dispatcher_internal(dispatcher, send_notify=send_notify)
    return {"status": "success", "focused_workspace": workspace, "dismissed_special_workspaces": dismissed}

def take_screenshot_internal(mode: str = "output", target: Optional[str] = None, save_directory: Optional[str] = None, delay_seconds: float = 0.5) -> Dict[str, Any]:
    # Sleep to allow animations to complete
    if delay_seconds > 0:
        time.sleep(delay_seconds)
        
    # Determine output path
    if not save_directory:
        save_directory = os.environ.get("HYPRCAPTURE_DIR")
    if not save_directory:
        save_directory = f"{get_home_dir()}/.gemini/antigravity-cli/scratch"
        
    os.makedirs(save_directory, exist_ok=True)
    filename = "hypr_capture.png"
    output_path = os.path.join(save_directory, filename)
    
    # Remove existing screenshot file if it exists
    if os.path.exists(output_path):
        try:
            os.remove(output_path)
        except Exception:
            pass
            
    # Check if grim is available
    if subprocess.run(["which", "grim"], capture_output=True).returncode != 0:
        raise Exception("grim is not installed.")
        
    if target:
        # Determine geometry of target window
        prefix = ""
        value = target
        if ":" in target:
            prefix, value = target.split(":", 1)
        if prefix not in ["address", "class", "title"]:
            prefix = "class"
            value = target
            
        # Run hyprctl clients -j
        res = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, check=True)
        clients = json.loads(res.stdout)
        geometry = None
        for client in clients:
            if str(client.get(prefix)) == value:
                at = client.get("at", [0, 0])
                size = client.get("size", [0, 0])
                geometry = f"{at[0]},{at[1]} {size[0]}x{size[1]}"
                break
                
        if not geometry:
            error_msg = f"No se encontró la ventana '{target}'."
            send_notification("hyprcapture", "Captura Fallida", error_msg, urgency="critical")
            raise Exception(f"Target window '{target}' not found.")
            
        subprocess.run(["grim", "-g", geometry, output_path], check=True)
    else:
        # Default behavior: active window or output
        if mode == "window":
            if subprocess.run(["which", "hyprshot"], capture_output=True).returncode == 0:
                subprocess.run(["hyprshot", "-m", "window", "-m", "active", "-o", save_directory, "-f", filename, "--silent"], check=True)
            else:
                # Fallback to grim of active monitor if hyprshot not available, or get active window geom
                # Let's get active window geom and use grim
                res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, check=True)
                if res.stdout.strip() and res.stdout.strip() != "{}":
                    win = json.loads(res.stdout)
                    at = win.get("at", [0, 0])
                    size = win.get("size", [0, 0])
                    geom = f"{at[0]},{at[1]} {size[0]}x{size[1]}"
                    subprocess.run(["grim", "-g", geom, output_path], check=True)
                else:
                    # Fallback to full screen
                    subprocess.run(["grim", output_path], check=True)
        else:
            # Output mode
            if subprocess.run(["which", "hyprshot"], capture_output=True).returncode == 0:
                subprocess.run(["hyprshot", "-m", "output", "-m", "active", "-o", save_directory, "-f", filename, "--silent"], check=True)
            else:
                subprocess.run(["grim", output_path], check=True)
                
    if os.path.exists(output_path):
        if target:
            send_notification("hyprcapture", "Captura de Pantalla", f"Se guardó captura de la ventana '{target}' sin cambiar el foco.", icon="camera-photo")
        else:
            send_notification("hyprcapture", "Captura de Pantalla", f"Se guardó captura de tipo '{mode}' en: {output_path}", icon="camera-photo")
        return {"status": "success", "image_path": output_path}
    else:
        send_notification("hyprcapture", "Captura Fallida", "Error al intentar guardar captura.", urgency="critical")
        raise Exception("Failed to take screenshot: output file not created.")

def media_control_internal(action: str, player: Optional[str] = None) -> Dict[str, Any]:
    if subprocess.run(["which", "playerctl"], capture_output=True).returncode != 0:
        raise Exception("playerctl is not installed.")
        
    if action == "list":
        players_res = subprocess.run(["playerctl", "-l"], capture_output=True, text=True)
        players = players_res.stdout.strip().split("\n")
        
        meta_res = subprocess.run(["playerctl", "--all-players", "metadata"], capture_output=True, text=True)
        return {
            "players": [p for p in players if p],
            "metadata": meta_res.stdout.strip()
        }
    elif action == "pause_video":
        players_res = subprocess.run(["playerctl", "-l"], capture_output=True, text=True)
        players = [p for p in players_res.stdout.strip().split("\n") if p]
        paused = []
        for p in players:
            if any(video_term in p.lower() for video_term in ["brave", "chromium", "plasma-browser-integration", "firefox"]):
                subprocess.run(["playerctl", "-p", p, "pause"], check=True)
                paused.append(p)
        return {"paused_players": paused}
    elif action == "pause_all":
        subprocess.run(["playerctl", "pause"], check=True)
        return {"status": "all players paused"}
    elif action == "pause_player":
        if not player:
            raise Exception("player parameter is required for pause_player action")
        subprocess.run(["playerctl", "-p", player, "pause"], check=True)
        return {"paused_player": player}
    else:
        raise Exception(f"Unknown media action: {action}")

def kde_connect_internal(action: str, device_id: Optional[str] = None, content: Optional[str] = None) -> Dict[str, Any]:
    if subprocess.run(["which", "kdeconnect-cli"], capture_output=True).returncode != 0:
        raise Exception("kdeconnect-cli is not installed.")
        
    if action == "list":
        res = subprocess.run(["kdeconnect-cli", "-l"], capture_output=True, text=True)
        return {"devices": res.stdout.strip()}
    elif action == "notify":
        if not device_id or not content:
            raise Exception("device_id and content are required for notify action")
        subprocess.run(["kdeconnect-cli", "-d", device_id, "--ping-msg", content], check=True)
        return {"status": "notification sent", "device_id": device_id}
    elif action == "share":
        if not device_id or not content:
            raise Exception("device_id and content are required for share action")
        subprocess.run(["kdeconnect-cli", "-d", device_id, "--share-text", content], check=True)
        return {"status": "text shared", "device_id": device_id}
    else:
        raise Exception(f"Unknown kde_connect action: {action}")


@mcp.tool()
async def get_desktop_state() -> str:
    """Get the current state of the Hyprland desktop environment.
    
    Returns:
        JSON string containing information about workspaces, active workspace, clients, active window, and monitors.
    """
    state = {}
    try:
        for cmd, key in [
            (["hyprctl", "workspaces", "-j"], "workspaces"),
            (["hyprctl", "activeworkspace", "-j"], "active_workspace"),
            (["hyprctl", "clients", "-j"], "clients"),
            (["hyprctl", "activewindow", "-j"], "active_window"),
            (["hyprctl", "monitors", "-j"], "monitors")
        ]:
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                try:
                    state[key] = json.loads(res.stdout)
                except Exception:
                    state[key] = res.stdout.strip()
            else:
                state[key] = f"Error: {res.stderr.strip()}"
    except Exception as e:
        state["error"] = str(e)
    return json.dumps(state, indent=2)

@mcp.tool()
async def execute_dispatcher(dispatcher: str, send_notification: bool = True) -> str:
    """Execute a raw Lua dispatcher in Hyprland (analogous to hyprcontrol).
    
    Args:
        dispatcher: The Lua dispatcher command string (e.g. 'hl.dsp.focus({ workspace = "1" })')
        send_notification: If True, send a desktop notification about the action.
    """
    try:
        result = run_dispatcher_internal(dispatcher, send_notify=send_notification)
        return json.dumps({"status": "success", "result": result})
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})

@mcp.tool()
async def focus_workspace(workspace: str, dismiss_special: bool = True, send_notification: bool = True) -> str:
    """Focus a normal workspace, automatically dismissing any active special workspaces.
    
    Args:
        workspace: The workspace ID or name to focus.
        dismiss_special: If True, will check for and hide/dismiss any visible special workspace first.
        send_notification: If True, send a desktop notification.
    """
    try:
        result = focus_workspace_internal(workspace, dismiss_special=dismiss_special, send_notify=send_notification)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})

@mcp.tool()
async def take_screenshot(mode: str = "output", target: Optional[str] = None, save_directory: Optional[str] = None, delay_seconds: float = 0.5) -> str:
    """Capture a screenshot of the active monitor or a specific window.
    
    Args:
        mode: 'output' to capture the active monitor, or 'window' to capture the active window.
        target: Optional specific window selector, e.g. 'class:firefox', 'address:0x556db493fdd0', or 'title:Document'. If provided, captures that window's region.
        save_directory: Optional directory path where the screenshot will be saved.
        delay_seconds: Seconds to wait before taking the screenshot (important to let animations finish). Defaults to 0.5s.
    """
    try:
        result = take_screenshot_internal(mode=mode, target=target, save_directory=save_directory, delay_seconds=delay_seconds)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})

@mcp.tool()
async def media_control(action: str, player: Optional[str] = None) -> str:
    """Control media playback in the current session (using playerctl).
    
    Args:
        action: 'list' (list players and metadata), 'pause_video' (pause browser/video players), 'pause_all' (pause all players), or 'pause_player' (pause a specific player).
        player: Required only when action is 'pause_player'. Specify player name (e.g. 'spotify').
    """
    try:
        result = media_control_internal(action=action, player=player)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})

@mcp.tool()
async def kde_connect_control(action: str, device_id: Optional[str] = None, content: Optional[str] = None) -> str:
    """Interact with paired devices via KDE Connect.
    
    Args:
        action: 'list' (list paired/reachable devices), 'notify' (send a ping message), or 'share' (share clipboard/text).
        device_id: The target device ID (required for 'notify' and 'share').
        content: The message or text to send/share (required for 'notify' and 'share').
    """
    try:
        result = kde_connect_internal(action=action, device_id=device_id, content=content)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"status": "error", "message": str(e)})

@mcp.tool()
async def execute_sequence(actions: List[Dict[str, Any]]) -> str:
    """Execute a list of Hyprland/desktop actions in sequence (concatenation).
    
    Args:
        actions: A list of dicts. Each dict must have a 'type' key. Supported actions:
            - {"type": "focus_workspace", "workspace": "1", "dismiss_special": true, "send_notification": true}
            - {"type": "toggle_special_workspace", "name": "magic"}
            - {"type": "focus_window", "window": "address:0x..." or "class:..."}
            - {"type": "screenshot", "mode": "output|window", "target": "...", "save_directory": "...", "delay_seconds": 0.5}
            - {"type": "media", "action": "list|pause_video|pause_all|pause_player", "player": "..."}
            - {"type": "kde_connect", "action": "list|notify|share", "device_id": "...", "content": "..."}
            - {"type": "delay", "seconds": 0.5}
    """
    results = []
    for i, action in enumerate(actions):
        a_type = action.get("type")
        results.append({"step": i, "type": a_type})
        try:
            if a_type == "focus_workspace":
                workspace = action.get("workspace")
                dismiss_special = action.get("dismiss_special", True)
                send_notification = action.get("send_notification", True)
                if not workspace:
                    raise Exception("Missing 'workspace' parameter for focus_workspace action")
                res = focus_workspace_internal(str(workspace), dismiss_special=dismiss_special, send_notify=send_notification)
                results[-1]["result"] = res
            elif a_type == "toggle_special_workspace":
                name = action.get("name")
                if not name:
                    raise Exception("Missing 'name' parameter for toggle_special_workspace action")
                dispatcher = f'hl.dsp.workspace.toggle_special("{name}")'
                res = run_dispatcher_internal(dispatcher, send_notify=True)
                results[-1]["result"] = {"status": "success", "toggled": name, "dispatcher_result": res}
            elif a_type == "focus_window":
                window = action.get("window")
                if not window:
                    raise Exception("Missing 'window' parameter for focus_window action")
                dispatcher = f'hl.dsp.focus({{ window = "{window}" }})'
                res = run_dispatcher_internal(dispatcher, send_notify=True)
                results[-1]["result"] = {"status": "success", "focused_window": window, "dispatcher_result": res}
            elif a_type == "screenshot":
                mode = action.get("mode", "output")
                target = action.get("target")
                save_dir = action.get("save_directory")
                delay = float(action.get("delay_seconds", 0.5))
                res = take_screenshot_internal(mode=mode, target=target, save_directory=save_dir, delay_seconds=delay)
                results[-1]["result"] = res
            elif a_type == "media":
                m_action = action.get("action")
                player = action.get("player")
                if not m_action:
                    raise Exception("Missing 'action' parameter for media action")
                res = media_control_internal(action=m_action, player=player)
                results[-1]["result"] = res
            elif a_type == "kde_connect":
                k_action = action.get("action")
                device_id = action.get("device_id")
                content = action.get("content")
                if not k_action:
                    raise Exception("Missing 'action' parameter for kde_connect action")
                res = kde_connect_internal(action=k_action, device_id=device_id, content=content)
                results[-1]["result"] = res
            elif a_type == "delay":
                seconds = float(action.get("seconds", 0.5))
                time.sleep(seconds)
                results[-1]["result"] = {"status": "success", "waited_seconds": seconds}
            else:
                raise Exception(f"Unsupported action type: {a_type}")
        except Exception as e:
            results[-1]["status"] = "error"
            results[-1]["error"] = str(e)
            break
    return json.dumps(results, indent=2)

def main():
    mcp.run(transport='stdio')

if __name__ == "__main__":
    main()
