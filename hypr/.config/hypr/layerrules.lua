-- -- LAYERRULES ---

hl.layer_rule({
    name = "rofi",
    match = {
        namespace = "rofi",
    },
    blur = true,
    no_screen_share = streamer_mode
})

hl.layer_rule({
    name = "swaync-control-center",
    match = {
        namespace = "swaync-control-center",
    },
    no_screen_share = streamer_mode
})

hl.layer_rule({
    name = "swaync-notification",
    match = {
        namespace = "swaync-notification-window",
    },
    no_screen_share = streamer_mode
})
