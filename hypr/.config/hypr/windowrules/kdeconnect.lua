-- =========================================================
-- 📱 KDE CONNECT
-- =========================================================

hl.window_rule({
    name = "kdeconnect-presentation-fix",
    match = {
        class = "org.kde.kdeconnect.daemon",
    },
    float = true,
    suppress_event = "fullscreen",
    
    size = {"monitor_w", "monitor_h"}, -- que ocupe todo el monitor
    move = {"0", "0"}, -- arreglo para cuando queda mas abajo
    pin = true, -- que siga al usuario

    tag = "+hyprglass_disabled",
    no_initial_focus = true,
    no_anim = true,
    no_blur = true,
})
