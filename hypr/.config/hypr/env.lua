--- Variables de entorno
hl.env("GDK_SCALE", "1")
hl.env("XCURSOR_THEME", "Breeze-Dark")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Hace que OBS-VKCAPTURE capture tambien mangohud
--hl.env("VK_INSTANCE_LAYERS", "VK_LAYER_MANGOHUD_overlay_x86_64:VK_LAYER_MANGOHUD_overlay_x86:VK_LAYER_OBS_vkcapture_64:VK_LAYER_OBS_vkcapture_32")

run_if_pc("GAMER", function()
    --hl.env("","")

    hl.env("RADV_PERFTEST","aco")

    --hl.env("MANGOHUD","1")
    hl.env("MANGOHUD_CONFIG","read_cfg"..[[
    ]])
    hl.env("MANGOHUD_CONFIG", table.concat({
        "read_cfg",
        "network=eno2",
        "cpu_text=i7-8700k",
        "gpu_text=RTX-3090",
        "pci_dev=0000\\:01\\:00.0",
    }, ","))

    hl.env("WINEUSEPORTALS","1")
    hl.env("WINE_NTSYNC","1")

    hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia")
    hl.env("__NV_PRIME_RENDER_OFFLOAD","1")
    hl.env("__GL_SHADER_DISK_CACHE","1")

    hl.env("OBS_VKCAPTURE","1")

    hl.env("DXVK_FILTER_DEVICE_NAME","NVIDIA GeForce RTX 3090")
    hl.env("DXVK_HUD","compiler,opacity=0.2,scale=1")
    hl.env("DXVK_ASYNC","1")
    
    hl.env("STAGING_SHARED_MEMORY","1")

    -- VK3D
    hl.env("VKD3D_CONFIG","no_upload_hlist,no_gs_copy")
    hl.env("VKD3D_FEATURE_LEVEL","1")
    hl.env("VKD3D_SHADER_CACHE","1")

    -- Proton
    hl.env("PROTON_ENABLE_WAYLAND","1")
    hl.env("PROTON_VERB","run")
    hl.env("PROTON_ENABLE_HIDRAW","1")
    
    --hl.env("PROTON_PREFER_SDL","0")
    --hl.env("SDL_GAMECONTROLLER_IGNORE_DEVICES","054c:05c4,054c:09cc") --DS4 v1 and v2
    

    -- Proton cachyOS
    hl.env("PROTON_USE_WAYLAND","1")
    hl.env("PROTON_DXVK_LOWLATENCY","1")
    hl.env("PROTON_VKD3D_LOWLATENCY","1")
    hl.env("DXVK_NVAPI_VKREFLEX","1")
    hl.env("PROTON_DISCORD_BRIDGE","1")
end)

run_if_pc("laptop-stefano", function()
    --hl.env("MANGOHUD_CONFIGFILE","/home/stefano/.config/MangoHud/laptop-stefano.conf")
    hl.env("MANGOHUD_CONFIG", table.concat({
        "read_cfg",
        "cpu_text=i7-1265U",
        "gpu_text=Iris-Xe",
        "pci_dev=0000:00:02.0",
        "gpu_temp=0",
        "gpu_fan=0",
        "vram=0",
    }, ","))

    hl.env("DXVK_FILTER_DEVICE_NAME","Intel(R) Iris(R) Xe Graphics (ADL GT2)");

    hl.env("MOZ_ENABLE_WAYLAND","1")
    hl.env("QT_SCALE_FACTOR","1")
    -- Forzar que Brave use Wayland nativo para evitar lags de scroll
    hl.env("ELECTRON_OZONE_PLATFORM_HINT","auto");
end)
