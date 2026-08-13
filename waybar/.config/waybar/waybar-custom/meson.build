project('wb_cffi_audio_sinks', 'c')

gtk_dep = dependency('gtk+-3.0')
json_glib_dep = dependency('json-glib-1.0')
layer_shell_dep = dependency('gtk-layer-shell-0')

shared_library(
    'wb_cffi_audio_sinks',
    'main.c',
    dependencies: [gtk_dep, json_glib_dep, layer_shell_dep],
    name_prefix: '',
    install: false,
)
