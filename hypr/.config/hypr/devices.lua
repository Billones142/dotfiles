local redragon_azure = {
    layout = "latam",
    model = "",
    variant = "",
    options = "",
    rules = "",
};

-- Redragon azure usb
hl.device({
    name = "by-tech-gaming-keyboard",
    kb_layout = redragon_azure.layout,
    kb_model = redragon_azure.model,
    kb_variant = redragon_azure.variant,
    kb_options = redragon_azure.options,
    kb_rules = redragon_azure.rules,
})
-- Redragon azure dongle
hl.device({
    name = "compx-2.4g-wireless-receiver",
    kb_layout = redragon_azure.layout,
    kb_model = redragon_azure.model,
    kb_variant = redragon_azure.variant,
    kb_options = redragon_azure.options,
    kb_rules = redragon_azure.rules,
})
-- Redragon azure BT 3.0
hl.device({
    name = "bt-3.0kb-keyboard",
    kb_layout = redragon_azure.layout,
    kb_model = redragon_azure.model,
    kb_variant = redragon_azure.variant,
    kb_options = redragon_azure.options,
    kb_rules = redragon_azure.rules,
})
-- Redragon azure BT 5.0
hl.device({
    name = "bt-5.0kb-keyboard",
    kb_layout = redragon_azure.layout,
    kb_model = redragon_azure.model,
    kb_variant = redragon_azure.variant,
    kb_options = redragon_azure.options,
    kb_rules = redragon_azure.rules,
})

hl.device({
    name = "logitech-usb-keyboard",
    kb_layout = "es",
})

-- laptop Dell Latitude 7430 
hl.device({
    name = "at-translated-set-2-keyboard",
    kb_layout = "us",
})

-- Sunshine keyboard
hl.device({
    name = "keyboard-passthrough",
    kb_layout = "es",
})

hl.device({
    name = "wireless-controller-touchpad",
    enabled = false,
})

hl.device({
    name = "qdtech-mpi5001",
    --enabled = false
    output = "desc:Mediatrix Peripherals Inc MPI5001 0x00000001",
})

-- Laptop touchpad
hl.device({
    name = "ven_0488:00-0488:1040-touchpad",
    -- especifico touchpad
    disable_while_typing = true,
    tap_to_click = true,
    clickfinger_behavior = true,
    -- especifico mouse
    natural_scroll = true,
    drag_lock = true,
    sensitivity = 0.3,
    scroll_factor = 0.5,
})
