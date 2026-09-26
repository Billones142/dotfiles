-- =========================================================
-- 🗂️ REGLAS PARA TODAS LAS VENTANAS DE UN WORKSPACE
-- =========================================================
-- Una window_rule con match "workspace = N" se evalua al mapear la ventana,
-- cuando todavia esta en el workspace activo. Las reglas "workspace = X silent"
-- y los handlers de window.open (ej: windowrules/games.lua) la mueven despues,
-- asi que la regla terminaba afectando a ventanas que no quedaban en N.
--
-- Aqui el workspace se comprueba despues de esos moves: se le pone a la
-- ventana un tag por workspace y los efectos dinamicos se aplican con una
-- regla que hace match por ese tag. Los estaticos (float) se aplican con
-- dispatcher, solo al abrir la ventana.

-- workspacerules se carga antes que windowrules, donde se define el global wx
local wx = require("winexe")

-- Tiempo que se espera tras abrir/mover una ventana antes de comprobar su
-- workspace, para que las reglas y los otros handlers terminen de moverla.
local espera_ms = 100

local reglas = {}

local function tag_de(workspace)
    return "ws_" .. tostring(workspace):gsub("[^%w]", "_")
end

-- Numero: se compara con el id. Texto: con el nombre (ej: "special:magic").
local function coincide(ws, objetivo)
    if not ws then return false end
    if type(objetivo) == "number" then return ws.id == objetivo end
    return ws.name == objetivo
end

local function despachar(dispatcher, w, accion)
    local r = hl.dispatch(dispatcher)
    if type(r) == "table" and r.ok == false then
        hl.notification.create({
            text = "workspaces.lua: fallo " .. accion .. " en " .. tostring(w.class) .. ": " .. tostring(r.error),
            timeout = 5000,
            icon = "error",
        })
    end
end

-- Tamano logico del monitor, el mismo que usa monitor_w/monitor_h en las reglas.
local function tamano_monitor(m)
    local ancho, alto = m.width / m.scale, m.height / m.scale
    if m.transform % 2 == 1 then ancho, alto = alto, ancho end
    return ancho, alto
end

-- max_size de una regla solo limita la ventana cuando se redimensiona, asi
-- que una ventana que flota con un tamano mayor se achica a mano. Se
-- conserva su centro para que no quede corrida.
local function limitar_tamano(w, fraccion)
    if not w.floating or not w.monitor then return end
    local ancho_mon, alto_mon = tamano_monitor(w.monitor)
    local max_x, max_y = math.floor(ancho_mon * fraccion), math.floor(alto_mon * fraccion)
    local x, y = w.size.x, w.size.y
    if x <= max_x and y <= max_y then return end
    local nuevo_x, nuevo_y = math.min(x, max_x), math.min(y, max_y)
    despachar(hl.dsp.window.resize({ x = nuevo_x, y = nuevo_y, window = w }), w, "resize")
    despachar(hl.dsp.window.move({
        x = math.floor(w.at.x + (x - nuevo_x) / 2),
        y = math.floor(w.at.y + (y - nuevo_y) / 2),
        window = w,
    }), w, "move")
end

local function aplicar(address, al_abrir)
    local w = hl.get_window("address:" .. address)
    if not w then return end
    for _, r in ipairs(reglas) do
        local dentro = coincide(w.workspace, r.workspace)
        local tiene = wx.tiene_tag(w, r.tag)
        if dentro and not tiene then
            despachar(hl.dsp.window.tag({ tag = "+" .. r.tag, window = w }), w, "+" .. r.tag)
        elseif not dentro and tiene then
            despachar(hl.dsp.window.tag({ tag = "-" .. r.tag, window = w }), w, "-" .. r.tag)
        end
        if al_abrir and dentro and r.float and not w.floating then
            despachar(hl.dsp.window.float({ action = "enable", window = w }), w, "float")
        end
        if dentro and r.max_monitor then
            limitar_tamano(w, r.max_monitor)
        end
    end
end

local function aplicar_diferido(w, al_abrir)
    if not w then return end
    local address = w.address
    hl.timer(function() aplicar(address, al_abrir) end, { timeout = espera_ms, type = "oneshot" })
end

--- Registra reglas para las ventanas que terminan en un workspace.
--- spec.workspace: id (numero) o nombre (texto) del workspace.
--- spec.float: se aplica solo al abrir la ventana.
--- spec.max_monitor: fraccion del monitor (ej: 0.8) como tamano maximo de
--- las ventanas flotantes; se aplica al entrar al workspace y como max_size.
--- El resto de campos se pasan a una window_rule y deben ser efectos
--- dinamicos (opacity, max_size, ...), porque el tag se pone despues de abrir.
local function regla_workspace(spec)
    assert(spec and spec.workspace ~= nil, "regla_workspace: falta spec.workspace")
    local tag = tag_de(spec.workspace)

    local efectos = {}
    for k, v in pairs(spec) do
        if k ~= "workspace" and k ~= "float" and k ~= "max_monitor" then efectos[k] = v end
    end
    if spec.max_monitor then
        efectos.max_size = string.format("monitor_w*%s monitor_h*%s", spec.max_monitor, spec.max_monitor)
    end
    if next(efectos) then
        efectos.name = "workspace-" .. tag
        efectos.match = { tag = tag }
        hl.window_rule(efectos)
    end

    reglas[#reglas + 1] = {
        workspace = spec.workspace,
        tag = tag,
        float = spec.float,
        max_monitor = spec.max_monitor,
    }
end

hl.on("window.open", function(w) aplicar_diferido(w, true) end)

-- El evento se emite en medio del move, por eso tambien se difiere
hl.on("window.move_to_workspace", function(w) aplicar_diferido(w, false) end)

--- Reglas -------------------------------------------------------------

regla_workspace({
    workspace = 1,
    float = true,
    max_monitor = 0.8,
})

regla_workspace({
    workspace = 10,
    opacity = "1 override 1 override",
    focus_on_activate = false,
})
