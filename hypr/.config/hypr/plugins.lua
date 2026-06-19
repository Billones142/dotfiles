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
]]

if hl.plugin.hyprcapture then
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
                include_cursor = false,
                thumbnail_timeout_ms = 5000,
                watermark = "",
                watermark_position = "central",
                watermark_width = "20%",
                watermark_offset = "0 0",
            },
        },
    })
end

