-- =========================================================
-- 🎮 JUEGOS Y LANZADORES
-- =========================================================

-- >> LANZADORES (Lutris, Heroic)  
-- Al Workspace 5 junto con Steam  
hl.window_rule({
    name = "game-launchers",
    match = {
        class = "^(heroic|net.lutris.Lutris)$",
    },
    workspace = "5 silent",
})

hl.window_rule({
    name = "lutris-others",
    match = {
        class = "net.lutris.Lutris",
    },
    float = true,
})

hl.window_rule({
    name = "lutris-main",
    match = {
        class = "net.lutris.Lutris",
        initial_title = "Lutris",
    },
    float = false,
})

-- >> JUEGOS EN EJECUCIÓN  
-- Juegos de Steam, Proton, CS2 o Wine  
hl.window_rule({
    name = "running-games-1",
    match = {
        class = "^(steam_app_.*|steam_proton|cs2|gamescope)$",
    },
    render_unfocused = true,
    workspace = "6 silent",
})

hl.window_rule({
    name = "running-games-2",
    match = {
        xdg_tag = "proton-game",
    },
    render_unfocused = true,
    workspace = "6 silent",
})

hl.window_rule({
    name = "running-games-3",
    match = {
        content = 3,
    },
    render_unfocused = true,
    workspace = "6 silent",
})

hl.window_rule({
    name = "SystrayWine",
    match = {
        class = "^(steam_app_.*|steam_proton|cs2|gamescope)$",
        initial_title = "",
    },
    workspace = "",
})

-- Launcher Epic Games
hl.window_rule({
    name = "EpicGamesLauncher",
    match = {
        class = "^(steam_app_.*|steam_proton|cs2|gamescope|epicgameslauncher.exe|steam_app_epicgameslauncher)$",
        initial_title = "Epic Games Launcher",
    },
    float = true,
    workspace = "5 silent",
})

hl.window_rule({
    name = "EpicGamesLauncher-2",
    match = {
        class = "^(steam_app_epicgameslauncher)$",
    },
    float = true,
    workspace = "5 silent",
})

-- Descargas Epic Games
hl.window_rule({
    name = "EpicGamesLauncher-downloads",
    match = {
        class = "^(steam_app_.*|steam_proton|cs2|gamescope|epicgameslauncher.exe|steam_app_epicgameslauncher)$",
        initial_title = "Download Manager",
    },
    float = true,
    workspace = "5 silent",
})

 -- Moonlight
hl.window_rule({
    name = "Moonlight-stream",
    match = {
        class = "com.moonlight_stream.Moonlight",
        initial_title = "^(.*- Moonlight)$",
    },
    fullscreen = true,
    no_initial_focus = false,
})

hl.window_rule({
    name = "vkcube",
    match = {
        initial_title = "vkcube",
    },
    no_initial_focus = true,
    opacity = "1 override 1 override 1 override",
    render_unfocused = true,
})
