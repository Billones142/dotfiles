-- The animations are a tree. If an animation is unset, it will inherit its parent’s values.
--
--global
--↳ windows - styles: slide, popin, gnomed
--  ↳ windowsIn - window open - styles: same as windows
--  ↳ windowsOut - window close - styles: same as windows
--  ↳ windowsMove - everything in between, moving, dragging, resizing.
--↳ layers - styles: slide, popin, fade
--  ↳ layersIn - layer open
--  ↳ layersOut - layer close
--↳ fade
--  ↳ fadeIn - fade in for window open
--  ↳ fadeOut - fade out for window close
--  ↳ fadeSwitch - fade on changing activewindow and its opacity
--  ↳ fadeShadow - fade on changing activewindow for shadows
--  ↳ fadeGlow - fade on changing activewindow for glow
--  ↳ fadeDim - the easing of the dimming of inactive windows
--  ↳ fadeLayers - for controlling fade on layers
--    ↳ fadeLayersIn - fade in for layer open
--    ↳ fadeLayersOut - fade out for layer close
--  ↳ fadePopups - for controlling fade on wayland popups
--    ↳ fadePopupsIn - fade in for wayland popup open
--    ↳ fadePopupsOut - fade out for wayland popup close
--  ↳ fadeDpms - for controlling fade when dpms is toggled
--↳ border - for animating the border's color switch speed
--↳ borderangle - for animating the border's gradient angle - styles: once (default), loop
--↳ shadowangle - for animating the shadow's gradient angle - styles: once (default), loop
--↳ glowangle - for animating the glow's gradient angle - styles: once (default), loop
--↳ workspaces - styles: slide, slidevert, fade, slidefade, slidefadevert
--  ↳ workspacesIn - styles: same as workspaces
--  ↳ workspacesOut - styles: same as workspaces
--  ↳ specialWorkspace - styles: same as workspaces
--    ↳ specialWorkspaceIn - styles: same as workspaces
--    ↳ specialWorkspaceOut - styles: same as workspaces
--↳ zoomFactor - animates the screen zoom
--↳ monitorAdded - monitor added zoom animation

hl.config({
    animations = {
        enabled = true,
    }
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({
    leaf = "global",
    enabled = false,
})

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
hl.animation({ -- afecta a rofi
    leaf = "fade",
    enabled = true,
    speed = 7,
    bezier = "default",
})
hl.animation({ -- afecta a rofi
    leaf = "fadeLayersIn",
    enabled = false,
    speed = 7,
    bezier = "default",
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 10,
    bezier = "default",
})
hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 6,
    bezier = "default",
})
hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 1,
    bezier = "default",
})
-- TODO: encontrar como quitar animacion de "spotlight" a rofi

