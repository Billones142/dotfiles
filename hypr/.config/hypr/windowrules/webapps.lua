-- =========================================================
-- 📱 WEB APPS
-- =========================================================

-- >> YOUTUBE MUSIC (Web App)  
hl.window_rule({
    name = "webapp-ytmusic",
    match = {
        class = "^(.*-music.youtube.com__-Default)$",
    },
    workspace = "special:ytmusic silent",
    float = false,
})

-- >> WHATSAPP (Web App)
hl.window_rule({
    name = "webapp-whatsapp",
    match = {
        class = "^(.*-web.whatsapp.com__-Default)$",
    },
    workspace = "special:whatsapp silent",
    float = false,
})
