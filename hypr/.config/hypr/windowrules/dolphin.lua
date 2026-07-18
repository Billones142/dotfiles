-- =========================================================
-- 📂 KDE DOLPHIN
-- =========================================================

hl.window_rule({
    name = "dolphin-main",
    match = {
        class = "org.kde.dolphin",
        initial_title = "^(.* — Dolphin)$",
    },
    --float = true,
})

hl.window_rule({
    name = "dolphin-main-floating",
    match = {
        class = "org.kde.dolphin",
        initial_title = "^(.* — Dolphin)$",
        float = true,
    },
    center = true,
    --size = 1200 800
    max_size = {"monitor_w * 0.84", "monitor_h * 0.84"},
})

hl.window_rule({
    name = "dolphin-process-dialog",
    match = {
        class = "org.kde.dolphin",
        initial_title = "^(Progress Dialog.*)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "dolphin-properties",
    match = {
        class = "org.kde.dolphin",
        initial_title = "^(Properties for.*)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "dolphin-folder-already-exist",
    match = {
        class = "org.kde.dolphin",
        initial_title = "Folder Already Exists — Dolphin",
    },
    float = true,
    center = true,
    -- TODO: hacer que este por encima de los otros
})
