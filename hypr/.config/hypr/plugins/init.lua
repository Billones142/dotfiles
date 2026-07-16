local _hyprcapture_enabled = hl.plugin.hyprcapture and hyprcapture_enabled;
local _hyprglass_enabled = hl.plugin.hyprglass and hyprglass_enabled;

local function notifyNotInstalledPlugin(pluginName, pluginExist, pluginIsConfigured)
    --hl.notification.create({ text=pluginName .. (pluginIsConfigured and " seConfiguro" or " noSeConfiguro") .. (pluginExist and " existe" or " noExiste"), duration=20000}); -- DEBUG
    if pluginIsConfigured and (not pluginExist) then
        hl.notification.create({ text=pluginName.." configurado pero no instalado/habilitado", duration=20000});
    end
end

notifyNotInstalledPlugin("Hyprcapture", hl.plugin.hyprcapture, _hyprcapture_enabled);
notifyNotInstalledPlugin("Hyprglass", hl.plugin.hyprglass, _hyprglass_enabled);

-- TODO: manual review — plugin section ''. The new Lua API exposes plugins via hl.plugin.<name>(...) — wire up per the plugin's docs.
--[[
  hyprbars { ... }
  --    hyprexpo {
  --        columns = 3
  --        gap_size = 5
  --        bg_col = rgb(111111)
  --        workspace_method = center current
  --
  --        gesture_distance = 300
  --    }
  hy3 { ... }
--]]

if _hyprcapture_enabled then
    require("plugins.hyprcapture")
end

if _hyprglass_enabled then
    require("plugins.hyprglass")
end
