project('wb_cffi_audio_sinks', 'c')

gtk_dep = dependency('gtk+-3.0')
json_glib_dep = dependency('json-glib-1.0')
layer_shell_dep = dependency('gtk-layer-shell-0')

lib = shared_library(
    'wb_cffi_audio_sinks',
    'main.c',
    dependencies: [gtk_dep, json_glib_dep, layer_shell_dep],
    name_prefix: '',
    install: false,
)

# `meson compile -C build install-cffi` (or `ninja -C build install-cffi`):
# copies the freshly built .so to ~/.config/waybar/cffi/ and restarts the
# user's waybar systemd service so the change takes effect immediately.
run_target(
    'install-cffi',
    command: [
        'sh', '-c',
        'mkdir -p "$HOME/.config/waybar/cffi" && ' +
        'cp "$1" "$HOME/.config/waybar/cffi/wb_cffi_audio_sinks.so" && ' +
        'systemctl --user restart waybar.service',
        'sh', lib.full_path(),
    ],
    depends: lib,
)
