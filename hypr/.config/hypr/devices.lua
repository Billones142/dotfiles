local redragon_azure_kb_file = "~/.config/xkb/symbols/Redragon-Azure.xkb";

-- Redragon azure usb
hl.device({
    name = "by-tech-gaming-keyboard",
    kb_file = redragon_azure_kb_file,
})
-- Redragon azure dongle
hl.device({
    name = "compx-2.4g-wireless-receiver",
    kb_file = redragon_azure_kb_file,
})
-- Redragon azure BT 3.0
hl.device({
    name = "bt-3.0kb-keyboard",
    kb_file = redragon_azure_kb_file,
})
-- Redragon azure BT 5.0
hl.device({
    name = "bt-5.0kb-keyboard",
    kb_file = redragon_azure_kb_file,
})

hl.device({
    name = "logitech-usb-keyboard",
    kb_layout = "es",
})

-- laptop Dell Latitude 7430 
hl.device({
    name = "at-translated-set-2-keyboard",
    kb_layout = "us",
    kb_variant = "altgr-intl",
    kb_file = "~/.config/xkb/symbols/Dell_Latitude_7430.xkb"
})

-- Sunshine keyboard
hl.device({
    name = "keyboard-passthrough",
    kb_layout = "es",
})

hl.device({
    name = "ds4linux-virtual-ds4-touchpad",
    enabled = false,
})

hl.device({
    name = "wireless-controller-touchpad",
    enabled = false,
})

hl.device({
    name = "sony-computer-entertainment-wireless-controller-touchpad",
    enabled = false,
})

hl.device({
    name = "sony-interactive-entertainment-dualsense-wireless-controller-touchpad",
    enabled = false,
})

hl.device({
    name = "inputplumber-mouse",
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
