// TEMPORARY diagnostic build - not the real module.
// Right click shows ONE giant solid-red box with huge text, nothing else.
// Purpose: isolate whether the popover surface itself can render at a
// large size at all, independent of our sliders/labels/CSS classes.
//
// Build the same way as main.c, just point module_path at this instead:
//   gcc -shared -fPIC -o wb_cffi_diag.so main_diagnostic.c \
//       $(pkg-config --cflags --libs gtk+-3.0)
//
// "cffi/audio_sinks_diag": {
//     "module_path": ".config/waybar/cffi/wb_cffi_diag.so"
// }

#include "waybar_cffi_module.h"
#include <gtk/gtk.h>

const size_t wbcffi_version = 2;

typedef struct {
    GtkWidget *event_box;
    GtkWidget *popover;
} ModuleData;

static gboolean on_button_press(GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    (void)widget;
    ModuleData *m = (ModuleData *)user_data;
    if (event->button == GDK_BUTTON_SECONDARY || event->button == GDK_BUTTON_PRIMARY) {
        gtk_popover_popup(GTK_POPOVER(m->popover));
        return TRUE;
    }
    return FALSE;
}

void *wbcffi_init(const wbcffi_init_info *init_info,
                   const wbcffi_config_entry *config_entries, size_t config_entries_len) {
    (void)config_entries;
    (void)config_entries_len;

    ModuleData *m = g_new0(ModuleData, 1);

    GtkContainer *root = init_info->get_root_widget(init_info->obj);

    m->event_box = gtk_event_box_new();
    GtkWidget *bar_label = gtk_label_new("DIAG");
    gtk_container_add(GTK_CONTAINER(m->event_box), bar_label);
    gtk_container_add(root, m->event_box);

    m->popover = gtk_popover_new(m->event_box);
    gtk_popover_set_position(GTK_POPOVER(m->popover), GTK_POS_TOP);

    GtkWidget *test_label = gtk_label_new("TEST 123\nIF YOU SEE THIS BIG\nSIZING WORKS");
    gtk_widget_set_size_request(test_label, 300, 300);

    // Force a screaming-red background directly via CSS, at max priority,
    // so no external stylesheet can hide it.
    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider,
        "label { background-color: #ff0000; color: #ffffff; font-size: 24px; }"
        "popover { background-color: #ff0000; }"
        "popover contents { background-color: #ff0000; min-width: 300px; min-height: 300px; }",
        -1, NULL);
    gtk_style_context_add_provider(gtk_widget_get_style_context(test_label),
                                    GTK_STYLE_PROVIDER(provider),
                                    GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 100);
    gtk_style_context_add_provider(gtk_widget_get_style_context(m->popover),
                                    GTK_STYLE_PROVIDER(provider),
                                    GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 100);

    gtk_container_add(GTK_CONTAINER(m->popover), test_label);
    gtk_widget_show_all(test_label);

    gtk_widget_add_events(m->event_box, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(m->event_box, "button-press-event", G_CALLBACK(on_button_press), m);
    gtk_widget_show_all(m->event_box);

    return m;
}

void wbcffi_deinit(void *instance) { g_free(instance); }
void wbcffi_update(void *instance) { (void)instance; }
void wbcffi_refresh(void *instance, int signal) { (void)instance; (void)signal; }
void wbcffi_doaction(void *instance, const char *action_name) { (void)instance; (void)action_name; }
