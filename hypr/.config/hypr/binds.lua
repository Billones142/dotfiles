-- --- ATAJOS DE TECLADO ---

local mainMod = "SUPER"

-- TODO: Hacer que cambie la distribucion de teclado, que de una notificacion de a que distro cambio
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_raw("hyprctl switchxkblayout all next"));

-- Convertir la ventana actual en un Grupo (o añadirla a uno existente)
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())

-- Navegar entre las ventanas del mismo grupo (Como en Sway)
-- Si presionas Super + Flecha Derecha, pasas a la siguiente "pestaña"
hl.bind(mainMod .. " + right", hl.dsp.group.next())
hl.bind(mainMod .. " + left", hl.dsp.group.prev())

-- Sacar una ventana del grupo (si quieres que vuelva a estar al lado)
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))
--##

-- Bind inicial para entrar al menú
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("rofi -show power"))
--bind = $mainMod SHIFT, E, exec, notify-send "Power Menu" "L: Logout | S: Shutdown | R: Reboot | Esc: Cancel"
--bind = $mainMod SHIFT, E, submap, power_menu

hl.define_submap("power_menu", function()

    -- L - Logout (Ejecuta directo o podrías pedir otra confirmación)
    hl.bind("L", hl.dsp.exec_cmd(logout))
    hl.bind("L", hl.dsp.submap("reset"))

    -- S - Shutdown (Usa el post-cmd que mencionaste)
    hl.bind("S", hl.dsp.exec_cmd(poweroff))
    hl.bind("S", hl.dsp.submap("reset"))

    -- R - Reboot
    hl.bind("R", hl.dsp.exec_cmd(reboot))
    hl.bind("R", hl.dsp.submap("reset"))

    -- Cancelar
    hl.bind("Escape", hl.dsp.submap("reset"))
    hl.bind("N", hl.dsp.submap("reset"))
end)

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
--
-- bloquear acceso
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("uwsm app -- loginctl lock-session"))

-- cerrar ventana
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
-- forzar cierre de proceso de ventana: sigterm 9
hl.bind(mainMod .. " + CONTROL + T", hl.dsp.window.signal({ signal = 9 }))
-- reanudar proceso de ventana: sigcont 18
hl.bind(mainMod .. " + CONTROL + C", hl.dsp.window.signal({ signal = 18 }))
-- pausar proceso de ventana: sigstop 19
hl.bind(mainMod .. " + CONTROL + S", hl.dsp.window.signal({ signal = 19 }))


hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- " .. fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
--bind = $mainMod, J, togglesplit,
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
--hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot))
hl.bind(mainMod .. " + SHIFT + S", function()
    hl.plugin.hyprcapture.open()
end)

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload && pkill -SIGUSR2 waybar"))
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))

-- Foco y Movimiento
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "d" }))

-- Fijar/Desanclar ventana activa (Pin)
hl.bind(mainMod .. " + CTRL + P", hl.dsp.window.pin())

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Scratchpads
hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + period", hl.dsp.workspace.toggle_special("magic2"))
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.window.move({ workspace = "special:magic2" }))

hl.bind(mainMod .. " + comma", hl.dsp.workspace.toggle_special("magic3"))
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.window.move({ workspace = "special:magic3" }))

hl.bind(mainMod .. " + CTRL + F9", hl.dsp.workspace.toggle_special("whatsapp"))
hl.bind(mainMod .. " + CTRL + F10", hl.dsp.workspace.toggle_special("ytmusic"))
hl.bind(mainMod .. " + CTRL + F11", hl.dsp.workspace.toggle_special("discord"))

-- Resize Submap
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
    hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("return", hl.dsp.submap("reset"))
end)

-- Mouse Binding
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Botón de Apagado (Power)
hl.bind("XF86PowerOff", hl.dsp.exec_cmd(poweroff), { locked = true })

-- Botón de Reinicio (si tu teclado/laptop tiene uno dedicado)
-- Nota: A veces se mapea como una combinación o tecla especial
hl.bind("XF86Sleep", hl.dsp.exec_cmd(reboot), { locked = true })

-- Multimedia
--bindel = ,XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
--bindel = ,XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
--bindel = ,XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true, repeating = true })
--bindel = ,XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { locked = true, repeating = true })
--bindel = ,XF86MonBrightnessUp, exec, brightnessctl set 5%+
--bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 5%-
-- Control de Brillo con OSD
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

-- Necesita playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Abrir historial de portapapeles con Wofi
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard_launcher.sh"))

-- Al cerrar la tapa (on)
hl.bind("switch:on:Lid Switch", hl.dsp.dpms({ action = "off" }), { locked = true })

-- Al abrir la tapa (off)
hl.bind("switch:off:Lid Switch", hl.dsp.dpms({ action = "on" }), { locked = true })

-- binds para programas
hl.bind("SUPER + F10", hl.dsp.pass({ window = "class:^(com\\.obsproject\\.Studio)$" }))

-- Hyprexpo (Workspace Preview)
--bind = $mainMod ALT, 1, hyprexpo:expo, all
--bind = $mainMod ALT, 2, hyprexpo:expo, all
--bind = $mainMod ALT, 3, hyprexpo:expo, all
--bind = $mainMod ALT, 4, hyprexpo:expo, all
--bind = $mainMod ALT, 5, hyprexpo:expo, all
--bind = $mainMod ALT, 6, hyprexpo:expo, all
--bind = $mainMod ALT, 7, hyprexpo:expo, all
--bind = $mainMod ALT, 8, hyprexpo:expo, all
--bind = $mainMod ALT, 9, hyprexpo:expo, all
--bind = $mainMod ALT, 0, hyprexpo:expo, all

