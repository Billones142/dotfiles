hl.workspace_rule({
	workspace = "1",
	--layout = "scrolling",
	layout = "monocle",
	--animation = "fade",
	--layout_opts = { direction = "right" }

})

hl.workspace_rule({
	workspace = "6",
	--layout = "scrolling",
	layout = "monocle",
	default_name = "juegos",
	animation = "fade",
	monitor = "virtual-fallback-display",
	--tiledLayout = "",
})


hl.workspace_rule({
	workspace = "4",
	--layout = "scrolling",
	layout = "monocle",
	animation = "fade",
})

hl.workspace_rule({
	workspace = "special:whatsapp",
	--layout = "scrolling",
	animation = "fade",

})

hl.workspace_rule({
	workspace = "special:ytmusic",
	--layout = "scrolling",
	animation = "fade",
	on_created_empty = "uwsm app -- WebApp-YoutubeMusicChromium5294.desktop",

})

hl.workspace_rule({
	workspace = "special:whatsapp",
	--layout = "scrolling",
	animation = "fade",
	on_created_empty = "uwsm app -- WebApp-WhatsappWeb1304.desktop",

})

hl.workspace_rule({
	workspace = "special:magic",
	layout = "scrolling",
	animation = "fade",

})
hl.workspace_rule({
	workspace = "special:magic2",
	layout = "scrolling",
	animation = "fade",

})
hl.workspace_rule({
	workspace = "special:magic3",
	layout = "scrolling",
	animation = "fade",

})

hl.workspace_rule({
	workspace = "name:presentacion",
	no_rounding = true,
	decorate = false
})
