-- =========================================================
-- 💬 DISCORD
-- =========================================================

hl.window_rule({
    name = "Discord-Main",
    match = {
        class = "discord",
    },
    opacity = "1.0 override 1.0 override",
})

hl.window_rule({
    name = "Discord-PopUp",
    match = {
        class = "discor)",
        initial_title = "Discord Popout",
    },
    opacity = "1.0 override 1.0 override",
    float = true,
})

hl.window_rule({
    name = "discord",
    match = {
        class = "discord",
    },
    workspace = "special:discord silent",
    float = false,
})
