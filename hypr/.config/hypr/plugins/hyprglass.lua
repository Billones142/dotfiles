local hg = hl.plugin.hyprglass

hg.config({
    default_theme = "dark",
    default_preset = "clear",
    ignore_window_alpha = true, -- Por si se aceptan mis cambios :)
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
