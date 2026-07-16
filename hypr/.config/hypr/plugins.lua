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
    hl.config({
        plugin = {
            hyprcapture = {
                default_mode = "region",
                fullscreen_scope = "all",
                window_background = "follow-system",
                window_border = "keep",
                window_shadow = "keep",
                save = true,
                clipboard = true,
                show_thumbnail = true,
                allow_quick = false,
                confirm_before_capture = false,
                fusion_mode = false,
                save_dir = "$XDG_PICTURES_DIR/Screenshots",
                filename_template = "Screenshot-%Y-%m-%d-%H%M%S.png",
                record_save_dir = "$XDG_VIDEOS_DIR/Screenrecords",
                record_filename_template = "Recording-%Y-%m-%d-%H%M%S.mp4",
                record_format = "mp4",
                record_transparent_format = "webm",
                record_fps = 30,
                record_fps_options = "15 24 30 60",
                record_window_fps_limit = 12,
                record_window_real_bg_fps_limit = 8,
                record_codec = "libx264",
                record_transparent_codec = "auto",
                record_solid_alpha = false,
                record_preset = "veryfast",
                record_gsr_flags = "",
                record_window_backend = "compositor",
                record_max_seconds = 0,
                record_countdown_seconds = 0,
                include_cursor = true,
                thumbnail_timeout_ms = 5000,
                watermark = "Stefano Merino",
                watermark_position = "central",
                watermark_width = "20%",
                watermark_offset = "0 0",
		helper = "~/.local/bin/hyprcapture-ui",
            },
        },
    })
end

if _hyprglass_enabled then
    local hg = hl.plugin.hyprglass

    hg.config({
        default_theme = "dark",
        default_preset = "clear",
	--ignore_window_alpha = true, -- Por si se aceptan mis cambios :)
        --tint_color = 0x8899aa22,
        tint_color = 0x00000022,

        brightness = 0.9,
        dark = { brightness = 0.82 },
        light = { adaptive_boost = 0.5 },

        layers = { enabled = true },
    })

    -- Layer surfaces: each call whitelists the namespace and configures it
    hg.layer("waybar", { preset = "waybar_glass", mask_threshold = 0.079 })
    hg.layer("swaync", { preset = "clear", mask_threshold = 0.079 })
    --hg.layer("debug-panel", { exclude = true })
    hg.layer("rofi", { preset = "rofi_glass", mask_threshold = 0.031 })
    hg.layer("swaync-notification-window", { preset = "clear", mask_threshold = 0.031 })
    hg.layer("swaync-control-center", { preset = "clear", mask_threshold = 0.031 })


    -- Presets
    hg.preset("clear", {
        glass_opacity = 1,
        blur_strength = 0,
        fresnel_strength = 0.1,      -- Brillo satinado en los bordes
        dark = { brightness = 0.5, tint_color = "0x00000000" },
        light = { brightness = 1.2, tint_color = "0x00000000" },
	lens_distortion = 2,
    })

    hg.preset("waybar_glass", {
        glass_opacity = 1,
        blur_strength = 0,
        fresnel_strength = 0.45,
        dark = { brightness = 0.5, tint_color = "0xed8e0000"  },
    })

    hg.preset("rofi_glass", {
        glass_opacity = 1,
        blur_strength = 0.2,
	lens_distortion = 10,
        refraction_strength = 0, -- causa distorsion circular extraña en el centro
        chromatic_aberration = 0,
        fresnel_strength = 0.1,
        edge_thickness = 1.0,
        dark = { brightness = 0.8, tint_color = "0x00000000" },
        light = { brightness = 1.3, tint_color = "0xed8e000d" },
    })

    hg.preset("contrasted", {
        inherits = "high_contrast",
        contrast = 1.2,
        adaptive_dim = 1.5,
        dark = { tint_color = 0x02142aa9 },
    })
end
