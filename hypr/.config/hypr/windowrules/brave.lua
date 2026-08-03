-- =========================================================
-- 🌐 BRAVE BROWSER
-- =========================================================

local braveClass = "^([Bb]rave-browser|[Bb]rave-origin|[Bb]rave-origin-beta)$"

hl.window_rule({
    name = "brave-browser",
    match = {
        initial_class = braveClass,
    },
    no_blur = true,
    opacity = "1 override 1 override",
    --border_color = "rgb(d05d0e)",
})

hl.window_rule({
    name = "brave-browser-pinned",
    match = {
        initial_class = braveClass,
	pin = true,
    },
    no_blur = true,
    opacity = "1 override 1 override 1 override",
})

-- >> BRAVE (Principal): debajo de la regla de ventanas flotantes para el workspace 1
hl.window_rule({
    name = "brave-browser-principal",
    match = {
        initial_class = braveClass,
        initial_title = "Principal",
    },
    --maximize = true
    no_blur = true,
    workspace = "1",
    float = false,
    border_size = 0,
    sync_fullscreen = false,
})
-- TODO: hacer que las ventanas con el mismo PID que brave se  puedan identificar
