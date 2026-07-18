-- =========================================================
-- 🎮 STEAM
-- =========================================================

-- >> STEAM (Ventanas de propiedades de juegos)
hl.window_rule({
    name = "steam-games-properties",
    match = {
        class = "steam",
    },
    float = true,
    center = true,
})

-- >> STEAM (Ventanas Secundarias/Popups)
hl.window_rule({
    name = "steam-popups",
    match = {
        class = "steam",
        title = "^(Sign in to Steam|Friends List|Steam Settings|Create or select.*|Sign in to Steam|Special Offers)$",
    },
    float = true,
    center = true,
})

-- >> STEAM (Arreglo de Menús y Tooltips)  
-- Fix crítico para menús que parpadean o aparecen vacíos  
hl.window_rule({
    name = "steam-menus-fix",
    match = {
        class = "steam",
        title = "^$",
    },
    stay_focused = true,
    min_size = {1, 1},
})

-- steam (para ventanas de propiedades de juegos)
hl.window_rule({
    name = "steam-game-config",
    match = {
        class = "steam",
    },
    workspace = "5 silent",
    float = true,
})

hl.window_rule({
    name = "steam-game-config",
    match = {
        class = "steam",
        initial_title = "Steam Big Picture Mode",
    },
    workspace = "5",
    float = true,
})

-- >> STEAM (Cliente Principal)  
-- Enviar la ventana principal al Workspace 5 y evitar que flote  
hl.window_rule({
    name = "steam-main",
    match = {
        class = "steam",
        title = "Steam",
    },
    workspace = "5 silent",
    float = false,
})

hl.window_rule({
    name = "steam-big-picture",
    match = {
        class = "steam",
        title = "Steam Big Picture Mode",
    },
    workspace = "5",
    fullscreen = true,
})
