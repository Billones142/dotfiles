-- =========================================================
-- 🎮 JUEGOS Y LANZADORES
-- =========================================================

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
    tag = "+game_laucher",
    float = false,
})

-- Juegos corriendo en proton 
hl.window_rule({
    name = "running-games-proton-ge-xwayland",
    match = {
        class = "^(steam_proton)$",
	xwayland = true,
    },
    tag = "+running_game",
})


hl.window_rule({
    name = "running-games-gamescope",
    match = {
        class = "gamescope",
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "running-games-xdg-proton",
    match = {
        xdg_tag = "proton-game",
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "running-games-content",
    match = {
        content = 3,
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "running-games-epicgames",
    match = {
        class = "^(steam_app_epicgameslauncher)$",
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "running-games-shadps4",
    match = {
        class = "shadps4",
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "SystrayWine",
    match = {
        class = "^(steam_app_.*|steam_proton)$",
        initial_title = "",
    },
})

-- Launcher Epic Games
hl.window_rule({
    name = "EpicGamesLauncher",
    match = {
        class = "^(epicgameslauncher.exe|steam_app_epicgameslauncher)$",
        initial_title = "Epic Games Launcher",
    },
    tag = "+game_laucher",
    float = true,
})

-- Descargas Epic Games
hl.window_rule({
    name = "EpicGamesLauncher-downloads",
    match = {
        class = "^(epicgameslauncher.exe|steam_app_epicgameslauncher)$",
        initial_title = "Download Manager",
    },
    tag = "+game_laucher",
    float = true,
})

hl.window_rule({
    name = "EA-Launcher",
    match = {
        class = "^(EA)$",
        initial_title = "EA",
    },
    tag = "+game_laucher",
})

hl.window_rule({
    name = "EpicGamesLauncher-JediFallenOrder", match = { class = "^(steam_app_epicgameslauncher)$",
        initial_title = "STAR WARS Jedi: Fallen Order™",
    },
    tag = "+running_game",
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


-- Launchers de juegos
hl.window_rule({
    name = "game-launchers",
    match = {
        tag = "game_laucher",
    },
    tag = "-running_game",
    workspace = "5 silent",
})

hl.window_rule({
    -- es el explorador "explorer.exe"
    name = "proton-system-tray",
    match = {
	float = true,
        initial_class = "^(steam_app_.*)$",
        initial_title = "",
    },
    tag = "-running_game",
    max_size = "60 350",
    --move = "1428 5",
    --no_initial_focus = true,
    --no_focus = true,
    --pin = true
})

hl.window_rule({
    name = "running-games",
    match = {
        tag = "running_game", --,^(?!game_laucher).*
    },
    render_unfocused = true,
    workspace = "6",
    --no_initial_focus = true,
    --stay_focused = true,
})
