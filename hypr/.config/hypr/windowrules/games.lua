-- =========================================================
-- 🎮 JUEGOS Y LANZADORES =========================================================

local game_titles = "^(.*  |No Man's Sky|Just Cause 3|STAR WARS Jedi: Fallen Order™|DeadByDaylight.*|Rocket League.*|Marvel's Spider-Man 2.*|SN2.*)$";
local launchers_titles = "^()$";

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

-- Proton Experimental
hl.window_rule({
    -- es el explorador "explorer.exe"
    name = "running-games-proton",
    match = {
        initial_class = "^(steam_app_[0-9]{1,10})$",
	--initial_title = game_titles,
    },
    tag = "+running_game",
    --move = "1428 5",
    --no_initial_focus = true,
    --no_focus = true,
    --pin = true
})

-- New Club Penguin
hl.window_rule({
    name = "new_club_penguin",
    match = {
        initial_class = "^(.*newcp.net__play_.*)$",
	initial_title = "newcp.net_/play/",
    },
    tag = "+running_game",
    no_initial_focus = true,
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
    name = "running-games-minecraft",
    match = {
        class = "^(Minecraft .*)$",
    },
    tag = "+running_game",
})

hl.window_rule({
    name = "beyond-all-reason",
    match = {
        initial_title = "^(Recoil .*)$",
	initial_class = "spring",
    },
    tag = "+running_game",
})


-- Launcher Epic Games
hl.window_rule({
    name = "EpicGamesLauncher",
    match = {
        class = "^(epicgameslauncher.exe|steam_app_epicgameslauncher|steam_app_.*)$",
        initial_title = "Epic Games Launcher",
    },
    tag = "+game_laucher",
    float = true,
})

-- Descargas Epic Games
hl.window_rule({
    name = "EpicGamesLauncher-downloads",
    match = {
        class = "^(epicgameslauncher.exe|steam_app_epicgameslauncher|steam_app_.*)$",
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
    name = "beyond-all-reason-launcher",
    match = {
        class = "Beyond-All-Reason",
        initial_title = "Beyond All Reason",
    },
    tag = "+game_laucher",
})

hl.window_rule({
    name = "EpicGamesLauncher-Game", match = { class = "^(steam_app_epicgameslauncher)$",
        initial_title = game_titles,
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
    name = "running-games",
    match = {
        tag = "running_game",
    },
    render_unfocused = true,
    workspace = "6 silent",
    no_initial_focus = true,
    confine_pointer = true,
    -- Algunos juegos (p.ej. Proton con winewayland) piden fullscreen en un
    -- monitor concreto y Hyprland los mueve al workspace activo de ese monitor.
    suppress_event = "fullscreenoutput",
    --idle_inhibit = "focus",
    --stay_focused = true,
})

--- Deteccion de juegos por ejecutable ------------------------------------
-- Para agregar otra biblioteca de juegos o de prefixes basta con sumar su
-- ruta a la lista correspondiente ("~" se expande al home).

-- Directorios donde se instalan juegos (nativos o de Windows).
local directorios_juegos = {
    "~/.local/share/Steam/steamapps/common",
    "/mnt/masJuegos/exe/steamapps/common",
}

-- Directorios que contienen prefixes de wine.
local directorios_prefixes = {
    "~/.local/share/Steam/steamapps/compatdata",
    "/mnt/masJuegos/exe/steamapps/compatdata",
}

-- Dentro de un prefix, ejecutables que no son juegos (explorer.exe,
-- services.exe, el steam.exe de Proton, etc.). Busqueda literal.
local excluidos_en_prefixes = {
    "/drive_c/windows/",
}

local workspace_juegos = 6
local workspace_launchers = 5

-- Muestra una notificacion por cada decision de la deteccion.
local debug_deteccion = false

local function debug(icono, mensaje, w, detalle)
    if not debug_deteccion then return end
    hl.notification.create({
        text = string.format("[juegos] %s\n%s | %s\n%s",
            mensaje, w.class or "?", w.title or "", detalle or ""),
        duration = 10000,
        icon = icono,
    })
end

-- Normaliza una lista de directorios: expande "~" y fuerza "/" final para
-- que "/juegos" no coincida con "/juegos2".
local function normalizar_directorios(lista)
    local home = os.getenv("HOME") or ""
    local salida = {}
    for _, dir in ipairs(lista) do
        dir = dir:gsub("^~", home):gsub("/+$", "")
        salida[#salida + 1] = dir .. "/"
    end
    return salida
end

directorios_juegos = normalizar_directorios(directorios_juegos)
directorios_prefixes = normalizar_directorios(directorios_prefixes)

local function empieza_con_alguno(ruta, prefijos)
    for _, prefijo in ipairs(prefijos) do
        if ruta:sub(1, #prefijo) == prefijo then return true end
    end
    return false
end

local function contiene_alguno(ruta, fragmentos)
    for _, fragmento in ipairs(fragmentos) do
        if ruta:find(fragmento, 1, true) then return true end
    end
    return false
end

-- w.tags puede venir como tabla o como cadena separada por comas.
local function tiene_tag(w, tag)
    local tags = w.tags
    if type(tags) == "table" then
        for _, t in ipairs(tags) do
            if t == tag then return true end
        end
        return false
    end
    if type(tags) == "string" then
        for t in tags:gmatch("[^,%s]+") do
            if t == tag then return true end
        end
    end
    return false
end

-- Aplica a mano lo que haria la regla "running-games". Hace falta aunque la
-- ventana ya tenga el tag: el workspace de esa regla se evalua una sola vez
-- al abrir y no ve los tags que pone otra regla en la misma pasada.
-- Durante este tiempo tras detectar un juego, si algo lo saca del
-- workspace de juegos se lo devuelve. Cubre a las ventanas detectadas por
-- ejecutable, a las que ya no se les puede aplicar suppress_event (es una
-- regla estatica que solo se evalua al abrir).
local proteccion_ms = 10000
local protegidos = {}

local function workspace_id(w)
    local ws = w.workspace
    return ws and ws.id or nil
end

-- Mueve la ventana al workspace de juegos y avisa si el dispatcher falla.
local function mover_a_juegos(w)
    if workspace_id(w) == workspace_juegos then return end
    local r = hl.dispatch(hl.dsp.window.move({ workspace = workspace_juegos, follow = false, window = w }))
    if type(r) == "table" and r.ok == false then
        debug("error", "fallo el move al workspace " .. workspace_juegos, w, r.error)
    end
end

local function verificar_workspace(address)
    local w = hl.get_window("address:" .. address)
    if not w then return end
    local actual = workspace_id(w)
    if actual == workspace_juegos then return end
    debug("warning", "la ventana termino en el workspace " .. tostring(actual) .. ", devolviendola", w, address)
    mover_a_juegos(w)
end

local function proteger(address)
    protegidos[address] = true
    hl.timer(function() protegidos[address] = nil end, { timeout = proteccion_ms, type = "oneshot" })
end

local function marcar_como_juego(w)
    if not tiene_tag(w, "running_game") then
        hl.dispatch(hl.dsp.window.tag({ tag = "+running_game", window = w }))
    end
    mover_a_juegos(w)
    proteger(w.address)
end

hl.on("window.move_to_workspace", function(w, ws)
    if not tiene_tag(w, "running_game") then return end
    local id = ws and ws.id
    debug("info", "juego movido al workspace " .. tostring(id), w, w.address)
    if protegidos[w.address] and id ~= workspace_juegos then
        -- El evento se emite en medio del move; se difiere la correccion
        -- para no mover la ventana de forma reentrante.
        local address = w.address
        hl.timer(function() verificar_workspace(address) end, { timeout = 50, type = "oneshot" })
    end
end)

-- Devuelve el ejecutable de la ventana salvo que sea un launcher,
-- o nil + motivo si no se pudo resolver.
local function exe_sin_clasificar(w)
    if tiene_tag(w, "game_laucher") then return nil end
    local exe, _, err = wx.ejecutable(w)
    return exe, err
end

-- ver si alguna ventana es un juego viendo si su ejecutable esta en un directorio de instalacion de juegos, ej: directorio common de steam
hl.on("window.open", function(w)
    local exe, err = exe_sin_clasificar(w)
    if err then
        -- Solo se avisa aqui para no duplicar la notificacion en el otro handler
        debug("warning", "no se pudo resolver el ejecutable", w, err)
        return
    end
    if exe and empieza_con_alguno(exe, directorios_juegos) then
        marcar_como_juego(w)
        debug("ok", "juego detectado (directorio de juegos)", w, exe)
    end
end)

-- ver si alguna ventana es un juego viendo si su ejecutable esta en un directorio de prefixes de wine, ej: directorio compatdata de steam
hl.on("window.open", function(w)
    local exe = exe_sin_clasificar(w)
    if not exe or not empieza_con_alguno(exe, directorios_prefixes) then return end
    if contiene_alguno(exe, excluidos_en_prefixes) then
        debug("info", "ignorado: ejecutable del sistema de wine", w, exe)
        return
    end
    marcar_como_juego(w)
    debug("ok", "juego detectado (prefix de wine)", w, exe)
end)

--- Bandeja del sistema de wine ------------------------------------------
-- La bandeja la crea el proceso "explorer.exe /desktop" de cada prefix y su
-- ventana no tiene titulo. Como Proton le pone la clase steam_app_<id>, la
-- regla "running-games-proton" la etiqueta como juego; aqui se deshace.
-- No se confunde con:
--   * el explorador de archivos: corre como "explorer.exe" sin "/desktop"
--   * un escritorio virtual: usa "/desktop=Nombre,AnchoxAlto"

-- Titulos que puede tener la ventana de la bandeja.
local titulos_bandeja_wine = {
    "",
}

local function es_explorer_de_wine(exe)
    return exe:lower():match("/drive_c/windows/.-explorer%.exe$") ~= nil
end

local function tiene_argumento(args, buscado)
    for i = 2, #args do
        if args[i]:lower() == buscado then return true end
    end
    return false
end

local function titulo_de_bandeja(w)
    local titulo = w.initial_title or ""
    for _, t in ipairs(titulos_bandeja_wine) do
        if titulo == t then return true end
    end
    return false
end

-- Devuelve true + exe si es la bandeja. Si es un explorer.exe de wine que
-- no cumple el resto, devuelve false + motivo (para el debug); para
-- cualquier otra ventana devuelve solo false.
local function es_bandeja_wine(w)
    local exe, wine = wx.ejecutable(w)
    if not exe or not wine or not es_explorer_de_wine(exe) then return false end
    if not titulo_de_bandeja(w) then
        return false, "titulo inicial no es de bandeja: '" .. (w.initial_title or "") .. "'"
    end
    local args, err = wx.args(w)
    if not args then return false, err end
    if not tiene_argumento(args, "/desktop") then
        return false, "sin argumento /desktop: " .. table.concat(args, " ", 2)
    end
    return true, exe
end

hl.on("window.open", function(w)
    local es_bandeja, detalle = es_bandeja_wine(w)
    if not es_bandeja then
        if detalle then
            debug("info", "explorer.exe de wine descartado como bandeja", w, detalle)
        end
        return
    end
    hl.dispatch(hl.dsp.window.tag({ tag = "-running_game", window = w }))
    hl.dispatch(hl.dsp.window.tag({ tag = "+wine_systray", window = w }))
    hl.dispatch(hl.dsp.window.move({ workspace = workspace_launchers, follow = false, window = w }))
    debug("ok", "bandeja de wine detectada, movida al workspace " .. workspace_launchers, w, detalle)
end)

-- TODO: identificar cuando se enfoca una ventana de juego y deshabilitar la opcion que apaga el trackpad al usar el teclado y viceversa
