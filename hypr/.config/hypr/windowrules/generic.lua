-- =========================================================
-- ⚙️ REGLAS GENÉRICAS Y DE SISTEMA
-- =========================================================

-- Suprimir eventos de maximizado (ayuda con apps de QT/GTK)  
hl.window_rule({
    name = "suppress-maximize",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

-- --- UTILIDADES FLOTANTES ---  
-- Grupo de Apps que siempre deben flotar y centrarse  
hl.window_rule({
    name = "floating-utils",
    match = {
        class = "^(org.gnome.Nautilus|thunar|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$",
    },
    float = true,
    center = true,
})

-- Tamaños específicos para Gestor de Archivos  
hl.window_rule({
    name = "FileManager",
    match = {
        class = "^(org.gnome.Nautilus|thunar)$",
    },
    size = "1000 800",
    center = true,
})

-- Tamaños específicos para Control de Volumen  
hl.window_rule({
    name = "pavucontrol-size",
    match = {
        class = "org.pulseaudio.pavucontrol",
    },
    size = "800 500",
})

-- Reglas para esconder ventanas
hl.window_rule({
    name = "xwaylandvideobridge",
    match = {
        class = "xwaylandvideobridge",
    },
    opacity = "0.0 override 0.0 override",
    workspace = "special:hidden silent",
    float = false,
    no_anim = true,
    no_initial_focus = true,
    max_size = "1 1",
    no_blur = true,
})

hl.window_rule({
    name = "xembedsniproxy",
    match = {
        class = "xembedsniproxy",
        float = true,
    },
    opacity = "0.0 override 0.0 override",
    workspace = "special:hidden silent",
    float = false,
    no_anim = true,
    no_initial_focus = true,
    max_size = "1 1",
    no_blur = true,
})

-- Reglas para portal de XDG
hl.window_rule({
    name = "guardado-de-archivos-portal",
    match = {
        class = "org.freedesktop.impl.portal.desktop.kde",
    },
    float = true,
    center = true,
    size = "monitor_w*0.84 monitor_h*0.84",
})

hl.window_rule({
    name = "Print",
    match = {
        initial_title = "Print",
    },
    float = true,
})

hl.window_rule({
    name = "Qalculate",
    match = {
        class = "qalculate-gtk",
    },
    float = true,
    size = "782 539",
})

hl.window_rule({
    name = "Terminal",
    match = {
        class = "Alacritty",
    },
    float = false,
    --opacity = "1 override 1 override 1 override",
    tag = "+hyprglass_enabled",
    --xray = true, -- rompe hyprglass
    size = "1167, 793",
})

hl.window_rule({
    name = "workspace1",
    match = {
        workspace = 1,
    },
    -- debe estar por encima de reglas que muevan las ventanas a otros workspaces
    -- por debajo de todas las demas
    float = true,
    size = "80% 80%",
})

hl.window_rule({
    name = "workspace10",
    match = {
        workspace = 10,
    },
    opacity = "1 override 1 override",
    focus_on_activate = false,
})

-- OpenSnitch
hl.window_rule({
    name = "opensnitch-main",
    match = {
        class = "opensnitch_ui",
        title = "^(OpenSnitch Network Statistics.*)$",
    },
    size = "782 539",
    float = true,
})

hl.window_rule({
    name = "opensnitch-popup",
    match = {
        class = "opensnitch_ui",
        title = "^(OpenSnitch v.*)$",
    },
    float = true,
    pin = true,
})

-- Ark: archiving tool
hl.window_rule({
    name = "Ark-archiving",
    match = {
        class = "org.kde.ark",
    },
    float = true,
})

-- Reglas para el Video Peek (wl-mirror)
-- TODO: manual review — top-level key 'windowrulev = float, title:^(hypr_video_peek)$' has no enclosing section
-- TODO: manual review — top-level key 'windowrulev = center, title:^(hypr_video_peek)$' has no enclosing section
-- TODO: manual review — top-level key 'windowrulev = size 960 540, title:^(hypr_video_peek)$' has no enclosing section
-- TODO: manual review — top-level key 'windowrulev = sticky, title:^(hypr_video_peek)$' has no enclosing section
-- TODO: manual review — top-level key 'windowrulev = pin, title:^(hypr_video_peek)$' has no enclosing section
-- TODO: manual review — top-level key 'windowrulev = bordercolor rgb(ff0000), title:^(hypr_video_peek)$' has no enclosing section
