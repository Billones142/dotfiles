-- Utilidades para averiguar de que ejecutable viene una ventana.
-- HL.Window no expone la ruta del binario, solo el pid, asi que hay que
-- resolverla leyendo /proc/<pid>/exe.

local M = {}

-- Ejecuta un comando y devuelve su salida sin espacios sobrantes.
-- Devuelve nil si el popen falla o la salida esta vacia.
local function get_cmd_output(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    if not result then return nil end
    result = result:match("^%s*(.-)%s*$")
    if result == "" then return nil end
    return result
end

-- Valida que el argumento sea una ventana usable y devuelve su pid.
local function pid_de(win)
    if not win then return nil, "ventana nula" end
    local ok, pid = pcall(function() return win.pid end)
    if not ok then return nil, "el objeto no es una HL.Window" end
    if type(pid) ~= "number" or pid <= 0 then return nil, "pid invalido" end
    return pid
end

-- Ruta absoluta del binario de una ventana.
-- Devuelve nil + motivo si el proceso es de otro usuario o ya murio.
function M.exe(win)
    local pid, err = pid_de(win)
    if not pid then return nil, err end
    local ruta = get_cmd_output("readlink -f /proc/" .. pid .. "/exe 2>/dev/null")
    if not ruta then
        return nil, "no se pudo leer /proc/" .. pid .. "/exe (proceso muerto o de otro usuario)"
    end
    return ruta
end

-- Lista de argumentos de un proceso leyendo /proc/<pid>/cmdline, que los
-- separa con NUL. Se descartan los vacios: wine rellena el final con NULs
-- tras reescribir argv.
local function leer_args(pid)
    local f = io.open("/proc/" .. pid .. "/cmdline", "rb")
    if not f then return nil end
    local datos = f:read("*a")
    f:close()
    if not datos then return nil end
    local args = {}
    for arg in datos:gmatch("[^%z]+") do
        args[#args + 1] = arg
    end
    if #args == 0 then return nil end
    return args
end

-- Linea de comandos completa. Util cuando exe() apunta a un lanzador
-- (Electron, Proton/Wine, flatpak) en vez de a la aplicacion real.
function M.cmdline(win)
    local pid, err = pid_de(win)
    if not pid then return nil, err end
    local args = leer_args(pid)
    if not args then
        return nil, "no se pudo leer /proc/" .. pid .. "/cmdline"
    end
    return table.concat(args, " ")
end

-- Argumentos del proceso como lista (argv[0] incluido). En procesos de wine
-- son los de Windows: { "C:\\windows\\system32\\explorer.exe", "/desktop" }.
function M.args(win)
    local pid, err = pid_de(win)
    if not pid then return nil, err end
    local args = leer_args(pid)
    if not args then
        return nil, "no se pudo leer /proc/" .. pid .. "/cmdline"
    end
    return args
end

-- Un binario es de wine si su nombre empieza por "wine": cubre wine, wine64,
-- wine-preloader y wine64-preloader (tambien los de Proton).
local function es_wine(ruta)
    local nombre = ruta:match("[^/]+$") or ruta
    return nombre:match("^wine") ~= nil
end

-- Escapa una cadena para usarla como argumento de shell.
local function sh_quote(s)
    return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

local function existe(ruta)
    local f = io.open(ruta, "rb")
    if not f then return false end
    f:close()
    return true
end

-- Valor de una variable de entorno de otro proceso (/proc/<pid>/environ).
local function leer_env(pid, nombre)
    local f = io.open("/proc/" .. pid .. "/environ", "rb")
    if not f then return nil end
    local datos = f:read("*a")
    f:close()
    if not datos then return nil end
    for par in datos:gmatch("[^%z]+") do
        local clave, valor = par:match("^([^=]+)=(.*)$")
        if clave == nombre then return valor end
    end
    return nil
end

-- Busca cada componente sin distinguir mayusculas, como hace Windows.
-- Solo se usa si la ruta exacta no existe, porque lanza un `ls` por nivel.
local function resolver_sin_mayusculas(base, componentes)
    local actual = base
    for _, comp in ipairs(componentes) do
        local candidato = actual .. "/" .. comp
        if not existe(candidato) then
            local listado = get_cmd_output("ls -A " .. sh_quote(actual) .. " 2>/dev/null")
            if not listado then return nil end
            local buscado = comp:lower()
            candidato = nil
            for entrada in listado:gmatch("[^\n]+") do
                if entrada:lower() == buscado then
                    candidato = actual .. "/" .. entrada
                    break
                end
            end
            if not candidato then return nil end
        end
        actual = candidato
    end
    return actual
end

-- Traduce una ruta de Windows a la ruta real del sistema para el proceso
-- de wine indicado. Las unidades se resuelven con los enlaces de
-- $WINEPREFIX/dosdevices (p.ej. "s:" -> /mnt/juegos/steamapps) y las rutas
-- relativas contra el cwd del proceso.
local function ruta_windows_a_unix(pid, ruta_win)
    local unidad, resto = ruta_win:match("^(%a):[\\/]?(.*)$")
    local base
    if unidad then
        local prefijo = leer_env(pid, "WINEPREFIX")
        if not prefijo then
            local home = leer_env(pid, "HOME") or os.getenv("HOME")
            if not home then return nil, "no se pudo determinar el WINEPREFIX" end
            prefijo = home .. "/.wine"
        end
        local enlace = prefijo:gsub("/+$", "") .. "/dosdevices/" .. unidad:lower() .. ":"
        base = get_cmd_output("readlink -f " .. sh_quote(enlace) .. " 2>/dev/null")
        if not base then
            return nil, "la unidad " .. unidad:upper() .. ": no existe en " .. prefijo
        end
    elseif ruta_win:match("^[\\/]") then
        return nil, "ruta de Windows no soportada: " .. ruta_win
    else
        resto = ruta_win
        base = get_cmd_output("readlink -f /proc/" .. pid .. "/cwd 2>/dev/null")
        if not base then return nil, "no se pudo leer el cwd del proceso" end
    end

    local componentes = {}
    for comp in resto:gmatch("[^\\/]+") do
        componentes[#componentes + 1] = comp
    end
    base = base:gsub("/+$", "")

    local exacta = base .. "/" .. table.concat(componentes, "/")
    if existe(exacta) then return exacta end
    local resuelta = resolver_sin_mayusculas(base, componentes)
    if resuelta then return resuelta end
    return nil, "no existe en el sistema: " .. ruta_win .. " (" .. exacta .. ")"
end

-- Ejecutable real de una ventana, resolviendo wine.
-- Devuelve exe, wine:
--   * proceso nativo: exe = ruta del binario, wine = nil
--   * proceso de wine: exe = ruta del .exe en el sistema, wine = ruta del
--     binario de wine
-- Wine reescribe argv con la linea de comandos de Windows, asi que argv[0]
-- es el ejecutable que esta corriendo; se traduce a ruta del sistema.
-- En caso de error exe es nil y el tercer valor es el motivo.
function M.ejecutable(win)
    local ruta, err = M.exe(win)
    if not ruta then return nil, nil, err end
    if not es_wine(ruta) then return ruta, nil end

    local args = leer_args(win.pid)
    if not args then
        return nil, ruta, "proceso de wine sin cmdline legible"
    end
    local exe, exe_err = ruta_windows_a_unix(win.pid, args[1])
    return exe, ruta, exe_err
end

-- Binario de la ventana enfocada.
function M.exe_activa()
    local win = hl.get_active_window()
    if not win then return nil, "no hay ventana activa" end
    return M.exe(win)
end

-- Tabla { class, title, pid, exe, wine, error } por cada ventana abierta.
-- exe y wine siguen la semantica de M.ejecutable().
function M.listar()
    local salida = {}
    for _, win in ipairs(hl.get_windows()) do
        local ruta, wine, err = M.ejecutable(win)
        salida[#salida + 1] = {
            class = win.class,
            title = win.title,
            pid   = win.pid,
            exe   = ruta,
            wine  = wine,
            error = err,
        }
    end
    return salida
end

-- Version en texto de listar(), pensada para `hyprctl repl` o notificaciones.
function M.listar_texto()
    local lineas = {}
    for _, w in ipairs(M.listar()) do
        local exe = w.exe or ("<" .. (w.error or "desconocido") .. ">")
        if w.wine then exe = exe .. " [wine: " .. w.wine .. "]" end
        lineas[#lineas + 1] = string.format("%-32s pid=%-7d %s", w.class, w.pid, exe)
    end
    return table.concat(lineas, "\n")
end

--- Busqueda por identificador -------------------------------------------

-- hl.get_window() acepta el mismo formato de regex que las window rules:
--   address:0x55d8690469e0 | stableid:180000a3 | class:foo | title:foo | pid:123
-- Ojo: stableid se pasa en hexadecimal sin "0x", mientras que la propiedad
-- win.stable_id de Lua es un numero decimal.

-- Convierte un identificador suelto en un selector de hl.get_window().
local function a_selector(id)
    local t = type(id)
    if t == "number" then
        -- stable_id numerico, tal cual lo devuelve win.stable_id
        return string.format("stableid:%x", id)
    end
    if t ~= "string" then
        return nil, "identificador de tipo " .. t .. " no soportado"
    end
    if id:match("^%a+:") then
        return id                                   -- ya es un selector
    end
    if id:match("^0[xX]%x+$") then
        return "address:" .. id                     -- direccion
    end
    if id:match("^%x+$") then
        return "stableid:" .. id:lower()            -- stable id en hex
    end
    return nil, "no reconozco el identificador '" .. id .. "'"
end

-- Devuelve la HL.Window correspondiente a un identificador.
-- Acepta: la propia ventana, address ("0x..."), stable id (numero o hex),
-- o un selector completo ("class:Alacritty").
-- Si el id es hex ambiguo prueba primero stableid y luego address.
function M.buscar(id)
    if type(id) == "userdata" then return id end

    local selector, err = a_selector(id)
    if not selector then return nil, err end

    local win = hl.get_window(selector)
    if win then return win end

    -- Un hex sin prefijo puede ser tambien una direccion; reintentamos.
    if type(id) == "string" and id:match("^%x+$") and not id:match("^%a+:") then
        win = hl.get_window("address:0x" .. id)
        if win then return win end
    end

    return nil, "ninguna ventana coincide con '" .. selector .. "'"
end

-- Objeto con todos los datos utiles de una ventana.
-- Campos: address, stable_id, stable_id_hex, class, initial_class, title,
-- initial_title, pid, exe, wine, cmdline, xwayland, floating, fullscreen,
-- workspace, monitor, exe_error, cmdline_error.
function M.info(id)
    local win, err = M.buscar(id)
    if not win then return nil, err end

    local exe, wine, exe_err = M.ejecutable(win)
    local cmd, cmd_err = M.cmdline(win)

    local ws = win.workspace
    local mon = win.monitor

    return {
        address       = win.address,
        stable_id     = win.stable_id,
        stable_id_hex = string.format("%x", win.stable_id),
        class         = win.class,
        initial_class = win.initial_class,
        title         = win.title,
        initial_title = win.initial_title,
        pid           = win.pid,
        exe           = exe,
        wine          = wine,
        cmdline       = cmd,
        xwayland      = win.xwayland,
        floating      = win.floating,
        fullscreen    = win.fullscreen,
        workspace     = ws and ws.name or nil,
        monitor       = mon and mon.name or nil,
        exe_error     = exe_err,
        cmdline_error = cmd_err,
        window        = win,
    }
end

-- Version en texto de info(), para `hyprctl repl` o notificaciones.
function M.info_texto(id)
    local datos, err = M.info(id)
    if not datos then return "error: " .. err end
    local orden = {
        "address", "stable_id", "stable_id_hex", "class", "initial_class",
        "title", "initial_title", "pid", "exe", "wine", "cmdline", "xwayland",
        "floating", "fullscreen", "workspace", "monitor",
        "exe_error", "cmdline_error",
    }
    local lineas = {}
    for _, clave in ipairs(orden) do
        local valor = datos[clave]
        if valor ~= nil then
            lineas[#lineas + 1] = string.format("%-14s %s", clave, tostring(valor))
        end
    end
    return table.concat(lineas, "\n")
end

-- Atajo: solo ejecutable y linea de comandos de un identificador.
function M.exe_de(id)
    local win, err = M.buscar(id)
    if not win then return nil, err end
    return M.exe(win)
end

function M.cmdline_de(id)
    local win, err = M.buscar(id)
    if not win then return nil, err end
    return M.cmdline(win)
end

-- w.tags puede venir como tabla o como cadena separada por comas.
function M.tiene_tag(w, tag)
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

return M
