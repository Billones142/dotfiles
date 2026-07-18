-- =========================================================
-- 🖥️ CISCO PACKET TRACER
-- =========================================================

hl.window_rule({
    name = "PacketTracerOther",
    match = {
        class = "PacketTracer",
    },
    opacity = "1.0 override 1.0 override",
    stay_focused = false,
    float = true,
})

hl.window_rule({
    name = "PacketTracerOther-2",
    match = {
        class = "PacketTracer",
        title = "Error",
    },
    opacity = "1.0 override 1.0 override",
    stay_focused = false,
    float = true,
})

-- Global for PacketTracer
hl.window_rule({
    name = "PacketTracer",
    match = {
        class = "PacketTrace",
    },
    -- Fix drag and drop on XWayland
    no_initial_focus = true,
    float = true,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    opaque = true,
    immediate = true,
    border_size = 0,
    rounding = 0,
    decorate = false,
    nearest_neighbor = true,
    xray = true,
    min_size = {1,1},
    keep_aspect_ratio = true,
})

hl.window_rule({
    name = "PacketTracer2",
    match = {
        class = "PacketTracer",
        title = "Cisco Packet Tracer",
    },
    keep_aspect_ratio = true,
    focus_on_activate = true,
})

hl.window_rule({
    name = "PacketTracer3",
    match = {
        class = "PacketTracer",
        title = "Preference",
    },
    min_size = "486 628",
    --stayfocused = on
})

hl.window_rule({
    name = "PacketTracer4",
    match = {
        class = "PacketTracer",
        title = "^(.*outer.*)",
    },
    min_size = "486 628",
})

hl.window_rule({
    name = "PacketTracer5",
    match = {
        class = "PacketTracer",
        title = "^(.*witch.*)",
    },
    min_size = "486 628",
})

hl.window_rule({
    name = "PacketTracer5",
    match = {
        class = "PacketTracer",
        title = "^(.*PC.*)",
    },
    min_size = "772 700",
})

hl.window_rule({
    name = "PacketTracer6",
    match = {
        class = "PacketTracer",
        title = "^(.*Save File.*)",
    },
    min_size = "807 655",
})
