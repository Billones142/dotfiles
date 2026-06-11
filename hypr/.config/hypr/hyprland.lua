-- Lista de pc's conocidas para aplicar configuraciones especificas
local pcs =
{
  ["GAMER"]={
	  systemdID="6503f1a4984e4725abb0e8938c245cbd",
  },
  ["laptop-stefano"]={
	  systemdID="2ce56e0901cd4d70b3e88ac4dd5920ee",
  },
}

-- Funcion para extraer salida de un comando
local function get_cmd_output(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    -- Eliminamos espacios en blanco y saltos de línea al inicio y final
    return result:match("^%s*(.-)%s*$")
end

local systemdID = get_cmd_output("cat /etc/machine-id");


local pcActual = (function ()
    for clave, datos in pairs(pcs) do
        if systemdID == datos.systemdID then
            hl.notification.create({ text="Pc actual: "..clave, duration=5000})
            return clave
        end
    end
    return nil
end)()

-- funcion que ejecuta una funcion lambda si la pc es la especificada
function run_if_pc(pc, funcion)
	if (pc == pcActual) then
		funcion();
	end
end
-- ejemplo de uso
--run_if_pc("GAMER", function()
--    hl.notification.create({ text="La pc es GAMER", duration=3000 });
--end)

--- MONITORES ---

-- Monitor principal para que sunshine pueda tener un stream constante
hl.monitor({
    output = "virtual-fallback-display",
    mode = "1920x1080@144",
    position = "0x0",
    --position = auto
    scale = "1",
    vrr = 1,
    --bitdepth = 8
    --bitdepth = 10
    --cm = hdr
})

-- gamer
hl.monitor({
    output = "desc:Acer Technologies Acer KG241 P 0x92638149",
    mirror = "virtual-fallback-display",
    mode = "1920x1080@144",
    scale = "1",
    bitdepth = 8,
    --cm = hdr,
    vrr = 1,
})

-- laptop-stefano
hl.monitor({
    output = "desc:AU Optronics 0x4A90",
    --mirror = "virtual-fallback-display",
    mirror = "virtual-fallback-display",
    mode = "1920x1080@60",
    scale = "1.2",
    bitdepth = 8,
    vrr = 1,
})

--monitorv2 { # HDMI laptop
--    output = HDMI-A-1
--    mirror = HEADLESS-2
--    position = auto
--    scale = 1
--    bitdepth = 8
--    vrr=1
--}

-- Pantalla tactil Raspberry
hl.monitor({
    output = "desc:Mediatrix Peripherals Inc MPI5001 0x00000001",
    mode = "1280x720@60",
    bitdepth = 8,
    scale = "1.6",
    position = "560x1080",
})

-- Configuracion por defecto
hl.monitor({
    output = "",
    disabled = true,
})

--monitor=,preferred,auto,1


-- Hace que algunas apps con datos posiblemente sensibles no se vean al compartir pantalla
streamer_mode = false

-- --- PROGRAMAS ---
terminal = "alacritty"
fileManager = "dolphin"

-- comandos
--$menu = wofi --show drun
--$menu = rofi -show drun
menu = "~/.config/hypr/scripts/rofi_launcher.sh"
screenshot = "grim -g \"$(slurp)\" - | swappy -f -"
poweroff = "hyprshutdown --post-cmd \"systemctl poweroff\""
reboot = "hyprshutdown --post-cmd \"systemctl reboot\""
logout = "hyprshutdown"
--$browser= uwsm app -- brave-browser.desktop
browser = "uwsm app -- com.brave.Origin.beta.desktop"


function uwsm_execute(command)
    hl.exec_cmd("uwsm app -- "..command)
end

-- --- AUTOSTART ---
hl.on("hyprland.start", function()
    --# para uwsm usar el comando para los programas: uwsm app -- [comando], no recomendable para scripts de ejecucion temporal
    hl.exec_cmd("~/.scripts/sunshine_desk_deactivate.sh")
    -- Borrar historial del portapapeles de la anterior sesion anterior
    hl.exec_cmd("rm \"$HOME/.cache/cliphist/db\"")
    --hl.exec_cmd("echo $HYPRLAND_INSTANSE_SIGNATURE > /home/stefano/.cache/hyprsignature.txt")

    --- APPS DE SISTEMA ---
    uwsm_execute("/usr/lib/pam_kwallet_init")
    uwsm_execute("xembedsniproxy")
    --uwsm_execute("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- inhibir el boton de inicio
    uwsm_execute("systemd-inhibit --what=handle-power-key:handle-reboot-key:handle-lid-switch --who=\"Hyprland Session\" --why=\"Custom shutdown/lid handling\" --mode=block Hyprland")
    
    --uwsm_execute("/home/stefano/proyectos/ProyectoAutoCambiadorPerfiles/clanker")

    -- Replay buffer de obs
    --uwsm_execute("obs --minimize-to-tray --startreplaybuffer --scene Replay")
    uwsm_execute("kdeconnect-indicator")
    uwsm_execute("swayosd-server")
    --- PORTAPAPELES (CLIPBOARD) ---
    -- Iniciar servicios de copiado
    uwsm_execute("wl-paste --type text --watch cliphist store")
    uwsm_execute("wl-paste --type image --watch cliphist store")

    -- Plugins
    uwsm_execute("hyprpm reload -n")


    hl.exec_cmd("touch $HOME/.config/hypr/monitors_sunshine.lua")
    hl.exec_cmd("touch $HOME/.config/hypr/monitors_presentation.lua")
end)



-- --- PERMISOS ---
hl.permission({ binary = "/usr/bin/hyprlock", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm", type = "plugin", mode = "allow" })


-- Layouts
--workspace = 1, layout:master

--- Variables de entorno
hl.env("GDK_SCALE", "1")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

run_if_pc("GAMER", function()
    hl.env("MANGOHUD_CONFIG","read_cfg,cpu_text=i7-8700k,gpu_text=3090,pci_dev=0000\\:01\\:00.0")
    hl.env("DXVK_FILTER_DEVICE_NAME","NVIDIA GeForce RTX 3090")
end)

run_if_pc("laptop-stefano", function()
    hl.env("MANGOHUD_CONFIG","read_cfg,pci_dev=0000\\:00\\:02.0")
    hl.env("DXVK_FILTER_DEVICE_NAME","Intel(R) Iris(R) Xe Graphics (ADL GT2)");

    hl.env("MOZ_ENABLE_WAYLAND","1")
    hl.env("QT_SCALE_FACTOR","1")
    -- Forzar que Brave use Wayland nativo para evitar lags de scroll
    hl.env("ELECTRON_OZONE_PLATFORM_HINT","auto");
end)

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 7,
    bezier = "myBezier",
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 7,
    bezier = "default",
    style = "popin 80%",
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 10,
    bezier = "default",
})
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 8,
    bezier = "default",
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 7,
    bezier = "default",
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6,
    bezier = "default",
})
hl.animation({
    leaf = "layers",
    enabled = false,
})

require("devices")

require("binds")

require("layerrules")

require("windowrules")

require("plugins")

require("monitors_presentation")

require("monitors_sunshine")


hl.config({
    group = {
        insert_after_current = true,
        col = {
            border_active = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            border_inactive = "rgba(595959aa)",
        },
        groupbar = {
            font_size = 10,
            gradients = true,
            render_titles = true,
            col = {
                active = "rgba(33ccffee)",
                inactive = "rgba(595959aa)",
            },
        },
    },
    misc = {
        --vfr = true
        vrr = true,
        render_unfocused_fps = 30,
	disable_autoreload = false
    },
    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = true,
    },
    ecosystem = {
        --enforce_permissions = true
        enforce_permissions = false,
    },
    --- INPUT ---
    input = {
        kb_layout = "latam",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        numlock_by_default = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = false,
            clickfinger_behavior = true,
            drag_lock = true,
            scroll_factor = 0.15,
        },
        sensitivity = 0,
        -- El retraso antes de empezar a repetir (en milisegundos)
        repeat_delay = 200,
        -- La velocidad de repetición (caracteres por segundo)
        repeat_rate = 45,
    },
    -- --- APARIENCIA ---
    general = {
        gaps_in = 2,
        gaps_out = 5,
        border_size = 0,
        col = {
            active_border = "rgb(d05d0e)",
            inactive_border = "rgb(181825)",
        },
        layout = "dwindle",
        allow_tearing = true,
    },
    render = {
        direct_scanout = false, -- A veces true causa artefactos en desktop
    },
    debug = {
        damage_tracking = 1, -- 2 es el valor por defecto y más estable
        disable_logs = true,
    },
    -- Opciones experimentales para Nvidia
    cursor = {
        no_hardware_cursors = true,
    },
    decoration = {
        rounding = 3,
        active_opacity = 1.0,
        inactive_opacity = 0.8,
        -- SINTAXIS NUEVA (Shadow)
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },
    },
    -- --- ANIMACIONES ---
    animations = {
        enabled = false,
    },
    -- --- LAYOUTS ---
    dwindle = {
        preserve_split = true,
    },
})
