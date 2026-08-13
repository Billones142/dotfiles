// wb_cffi_audio_sinks: a Waybar CFFI module.
//
// Left click on the bar widget: toggle mute on sinks[0].
// Scroll on the bar widget: adjust sinks[0]'s volume (0-100%).
// Right click: opens a real layer-shell popup window with one live slider
// per configured sink (up to "max_sinks", default 8), each wired directly to
// `pactl set-sink-volume`/`set-sink-mute`. Sliders go up to 150% and can be
// scrolled directly; scrolling the popup background (not a slider) scrolls
// the list if there are more sinks than fit on screen.
//
// Sinks are configured entirely from the waybar JSON config, e.g.:
//
//   "cffi/audio_sinks": {
//       "module_path": ".config/waybar/cffi/wb_cffi_audio_sinks.so",
//       "max_sinks": 8,
//       "sinks": [
//           {"label": "Speakers", "name": "alsa_output.pci-0000_00_1f.3.analog-stereo"},
//           {"label": "Headphones", "name": "alsa_output.usb-Generic_USB_Audio-00.analog-stereo"},
//           {"label": "HDMI", "name": "alsa_output.pci-0000_01_00.1.hdmi-stereo"}
//       ]
//   }
//
// Find your real sink names with: pactl list sinks short
//
// Build and install:
//   meson setup build
//   meson compile -C build install-cffi

#include "waybar_cffi_module.h"
#include <gtk/gtk.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <json-glib/json-glib.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const size_t wbcffi_version = 2;

#define DEFAULT_MAX_VISIBLE_SINKS 8  // "max_sinks" config default, if unset
#define MAX_SINKS_HARD_CAP 32         // absolute ceiling on configured sinks, sanity bound
#define POPUP_ABS_MAX_HEIGHT 600      // outer safety clamp on popup height regardless of config
#define POPUP_WIDTH 360               // must stay >= box border*2 + label + spacing + scale + entry + mute button
#define POPUP_BORDER 10                // border-width on the popup's outer (non-scrolling) frame
#define ROW_SPACING 8                   // vertical spacing between sink rows
#define POPUP_HIDE_DELAY_MS 400       // grace period before auto-closing on mouse-away
#define SCROLL_VOLUME_STEP 5
#define SLIDER_MAX_VOLUME 150  // sliders (only) allow boosting past 100%, "up to 11"

typedef struct {
    wbcffi_module *obj;
    GtkWidget *event_box;
    GtkWidget *label;
    GtkWidget *popup_window;  // manual layer-shell surface, replaces GtkPopover
    int num_sinks;              // all configured sinks (up to MAX_SINKS_HARD_CAP) — all get loaded
    int max_visible_sinks;      // config: "max_sinks" — rows visible before the popup scrolls
    GtkWidget **rows;           // [num_sinks] — popup row box, hidden when the sink is absent
    int primary_idx;            // sink the bar widget represents: first present one, -1 if none
    GtkWidget **scales;         // [num_sinks]
    GtkWidget **mute_buttons;   // [num_sinks]
    GtkWidget **volume_entries; // [num_sinks] — editable volume text next to each slider
    gulong *handler_ids;        // [num_sinks]
    char **sink_names;          // [num_sinks]
    char **sink_labels;         // [num_sinks]
    GtkLayerShellEdge bar_edge;  // which screen edge the bar (and popup) anchor to
    int popup_margin;            // extra gap below the bar; -1 = auto (flush, no gap)
    guint hide_timeout_id;       // pending auto-close timer, 0 if none scheduled
    guint update_timeout_id;     // periodic bar-label refresh, 0 if none scheduled
    gint64 popup_shown_at;        // g_get_monotonic_time() at last show, for focus-out grace period
} ModuleData;

#define POPUP_FOCUS_OUT_GRACE_US (500 * 1000)  // ignore focus-out this soon after showing

// Scale/button signal handlers only get one user_data pointer, so bundle the
// module + which of the sinks this particular row controls.
typedef struct {
    ModuleData *m;
    int idx;
} SinkRowUserData;

// ---- Config parsing (json-glib) -------------------------------------------
// Waybar hands array/object config values to CFFI modules as raw JSON text
// (see waybar_cffi_module.h). json-glib does the actual parsing so we don't
// have to hand-roll one.

// Config values above ABI v1 come JSON-encoded even for plain strings/ints
// (see waybar_cffi_module.h), so a bare "top"/"bottom" arrives as `"top"`
// (with quotes) and a bare 30 arrives as `30`. Strip surrounding quotes for
// the string case; atoi() already tolerates the int case as-is.
static char *unquote_json_string(const char *raw) {
    size_t len = strlen(raw);
    if (len >= 2 && raw[0] == '"' && raw[len - 1] == '"') {
        return g_strndup(raw + 1, len - 2);
    }
    return g_strdup(raw);
}

static void parse_config(ModuleData *m, const wbcffi_config_entry *config_entries,
                          size_t config_entries_len) {
    m->bar_edge = GTK_LAYER_SHELL_EDGE_TOP;
    m->popup_margin = -1;  // sentinel: auto (flush against the bar)
    m->primary_idx = 0;    // provisional until refresh_sink_presence() runs
    m->max_visible_sinks = DEFAULT_MAX_VISIBLE_SINKS;
    const char *sinks_raw = NULL;

    for (size_t i = 0; i < config_entries_len; i++) {
        if (strcmp(config_entries[i].key, "sinks") == 0) {
            sinks_raw = config_entries[i].value;
        } else if (strcmp(config_entries[i].key, "max_sinks") == 0) {
            m->max_visible_sinks = CLAMP(atoi(config_entries[i].value), 1, MAX_SINKS_HARD_CAP);
        } else if (strcmp(config_entries[i].key, "bar_position") == 0) {
            char *pos = unquote_json_string(config_entries[i].value);
            if (strcmp(pos, "bottom") == 0) {
                m->bar_edge = GTK_LAYER_SHELL_EDGE_BOTTOM;
            } else if (strcmp(pos, "top") != 0) {
                g_warning("wb_cffi_audio_sinks: unknown bar_position \"%s\", "
                          "defaulting to \"top\"", pos);
            }
            g_free(pos);
        } else if (strcmp(config_entries[i].key, "popup_margin") == 0) {
            m->popup_margin = atoi(config_entries[i].value);
        }
    }

    guint array_len = 0;
    JsonParser *parser = NULL;
    JsonArray *arr = NULL;
    if (sinks_raw && sinks_raw[0]) {
        parser = json_parser_new();
        GError *err = NULL;
        if (json_parser_load_from_data(parser, sinks_raw, -1, &err)) {
            JsonNode *root = json_parser_get_root(parser);
            if (root && json_node_get_node_type(root) == JSON_NODE_ARRAY) {
                arr = json_node_get_array(root);
                array_len = json_array_get_length(arr);
            } else {
                g_warning("wb_cffi_audio_sinks: \"sinks\" config is not a JSON array");
            }
        } else {
            g_warning("wb_cffi_audio_sinks: failed to parse \"sinks\" config: %s",
                       err ? err->message : "unknown error");
            if (err) g_error_free(err);
        }
    } else {
        g_warning("wb_cffi_audio_sinks: no \"sinks\" configured");
    }

    m->num_sinks = MAX(1, (int)MIN(array_len, (guint)MAX_SINKS_HARD_CAP));
    m->sink_names = g_new0(char *, m->num_sinks);
    m->sink_labels = g_new0(char *, m->num_sinks);
    m->rows = g_new0(GtkWidget *, m->num_sinks);
    m->scales = g_new0(GtkWidget *, m->num_sinks);
    m->mute_buttons = g_new0(GtkWidget *, m->num_sinks);
    m->volume_entries = g_new0(GtkWidget *, m->num_sinks);
    m->handler_ids = g_new0(gulong, m->num_sinks);

    if (arr) {
        for (int i = 0; i < m->num_sinks; i++) {
            JsonNode *entry = json_array_get_element(arr, i);
            if (!entry || json_node_get_node_type(entry) != JSON_NODE_OBJECT) continue;
            JsonObject *obj = json_node_get_object(entry);
            if (json_object_has_member(obj, "name")) {
                const char *name = json_object_get_string_member(obj, "name");
                if (name) m->sink_names[i] = g_strdup(name);
            }
            if (json_object_has_member(obj, "label")) {
                const char *label = json_object_get_string_member(obj, "label");
                if (label) m->sink_labels[i] = g_strdup(label);
            }
        }
    }
    if (parser) g_object_unref(parser);

    for (int s = 0; s < m->num_sinks; s++) {
        if (!m->sink_names[s]) {
            m->sink_names[s] = g_strdup("");
            g_warning("wb_cffi_audio_sinks: sinks[%d].name not set in config", s);
        }
        if (!m->sink_labels[s]) {
            m->sink_labels[s] = g_strdup_printf("Sink %d", s + 1);
        }
    }
}
// ---------------------------------------------------------------------------

static int get_sink_volume(const char *sink) {
    if (!sink || !sink[0]) return 0;
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "pactl get-sink-volume '%s' 2>/dev/null", sink);
    FILE *fp = popen(cmd, "r");
    if (!fp) return 0;
    char line[512] = {0};
    int vol = 0;
    if (fgets(line, sizeof(line), fp)) {
        char *pct = strchr(line, '%');
        if (pct) {
            char *p = pct;
            while (p > line && isdigit((unsigned char)*(p - 1))) p--;
            vol = atoi(p);
        }
    }
    pclose(fp);
    return vol;
}

static void set_sink_volume(const char *sink, int vol) {
    if (!sink || !sink[0]) return;
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "pactl set-sink-volume '%s' %d%%", sink, vol);
    GError *err = NULL;
    if (!g_spawn_command_line_async(cmd, &err)) {
        if (err) {
            g_warning("wb_cffi_audio_sinks: %s", err->message);
            g_error_free(err);
        }
    }
}

static gboolean get_sink_mute(const char *sink) {
    if (!sink || !sink[0]) return FALSE;
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "pactl get-sink-mute '%s' 2>/dev/null", sink);
    FILE *fp = popen(cmd, "r");
    if (!fp) return FALSE;
    char line[128] = {0};
    gboolean muted = fgets(line, sizeof(line), fp) && strstr(line, "yes") != NULL;
    pclose(fp);
    return muted;
}

// Synchronous (unlike set_sink_volume's async spawn above): mute toggles are
// one-shot rather than fired repeatedly while dragging, and the caller wants
// to immediately re-read the resulting state to refresh the bar label.
static void toggle_sink_mute(const char *sink) {
    if (!sink || !sink[0]) return;
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "pactl set-sink-mute '%s' toggle", sink);
    GError *err = NULL;
    if (!g_spawn_command_line_sync(cmd, NULL, NULL, NULL, &err)) {
        if (err) {
            g_warning("wb_cffi_audio_sinks: %s", err->message);
            g_error_free(err);
        }
    }
}

// Set of sink names PipeWire/PulseAudio currently knows about. One `pactl`
// call for all sinks rather than a per-sink probe, since this runs on every
// periodic tick. Caller owns the returned table (NULL if pactl failed, which
// callers treat as "presence unknown" and leave everything as-is rather than
// hiding the whole module on a transient error).
static GHashTable *query_present_sinks(void) {
    FILE *fp = popen("pactl list short sinks 2>/dev/null", "r");
    if (!fp) return NULL;
    GHashTable *present = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        // Format: "<index>\t<name>\t<driver>\t<sample spec>\t<state>"
        char *first_tab = strchr(line, '\t');
        if (!first_tab) continue;
        char *name = first_tab + 1;
        char *end = strchr(name, '\t');
        if (!end) end = strchr(name, '\n');
        if (!end) continue;
        g_hash_table_add(present, g_strndup(name, (gsize)(end - name)));
    }
    pclose(fp);
    return present;
}

// Hides the popup rows of configured sinks that don't currently exist on the
// system (unplugged headset, a virtual sink whose script hasn't run yet), and
// hides the bar widget entirely when none of them exist. Also re-picks
// primary_idx — the sink the bar widget itself represents — as the first
// present one, so the bar doesn't keep showing a device that's gone.
//
// Kept separate from update_bar_label() on purpose: this costs a pactl call,
// and update_bar_label() runs on every slider drag event.
static void refresh_sink_presence(ModuleData *m) {
    GHashTable *present = query_present_sinks();
    if (!present) return;

    m->primary_idx = -1;
    for (int i = 0; i < m->num_sinks; i++) {
        gboolean exists = g_hash_table_contains(present, m->sink_names[i]);
        if (m->rows[i]) gtk_widget_set_visible(m->rows[i], exists);
        if (exists && m->primary_idx < 0) m->primary_idx = i;
    }
    gtk_widget_set_visible(m->event_box, m->primary_idx >= 0);

    g_hash_table_destroy(present);
}

// The bar widget represents primary_idx (the first configured sink that
// actually exists) — its volume/mute state drive the bar's label and
// scroll-to-adjust. The right-click popup shows/controls every present sink.
static void update_bar_label(ModuleData *m) {
    if (m->primary_idx < 0) return;  // nothing present; widget is hidden anyway
    const char *name = m->sink_names[m->primary_idx];
    int vol = get_sink_volume(name);
    gboolean muted = get_sink_mute(name);
    char *text = g_strdup_printf("%s %s %d%%", muted ? "\U0001F507" : "\U0001F50A",
                                  m->sink_labels[m->primary_idx], vol);
    gtk_label_set_text(GTK_LABEL(m->label), text);
    g_free(text);
}

// Keeps the per-row editable volume entry in sync whenever the slider moves
// (drag, scroll, double-click-to-100, or a periodic/sync_scales refresh).
static void set_volume_entry_text(GtkWidget *entry, int vol) {
    char buf[8];
    snprintf(buf, sizeof(buf), "%d", vol);
    gtk_entry_set_text(GTK_ENTRY(entry), buf);
}

static void on_scale_changed(GtkRange *range, gpointer user_data) {
    SinkRowUserData *sud = (SinkRowUserData *)user_data;
    int vol = (int)gtk_range_get_value(range);
    set_sink_volume(sud->m->sink_names[sud->idx], vol);
    set_volume_entry_text(sud->m->volume_entries[sud->idx], vol);
    if (sud->idx == sud->m->primary_idx) update_bar_label(sud->m);
}

// Double-click on a slider jumps it straight to 100%. Connected (not
// "_after") so this runs before GtkScale's own default handler; returning
// TRUE on the second click of the pair stops that default handler from also
// treating it as a second jump-to-click-position.
static gboolean on_scale_button_press(GtkWidget *widget, GdkEventButton *event,
                                       gpointer user_data) {
    (void)user_data;
    if (event->type == GDK_2BUTTON_PRESS && event->button == 1) {
        gtk_range_set_value(GTK_RANGE(widget), 100);
        return TRUE;
    }
    return FALSE;
}

// Entry lets the user type an exact volume. Enter (activate) or losing focus
// both commit the typed value; invalid/out-of-range text just reverts to the
// slider's current value instead of erroring.
static void commit_volume_entry(GtkWidget *entry, SinkRowUserData *sud) {
    const char *text = gtk_entry_get_text(GTK_ENTRY(entry));
    char *end = NULL;
    long val = strtol(text, &end, 10);
    if (end == text) {
        set_volume_entry_text(entry, (int)gtk_range_get_value(GTK_RANGE(sud->m->scales[sud->idx])));
        return;
    }
    val = CLAMP(val, 0, SLIDER_MAX_VOLUME);
    gtk_range_set_value(GTK_RANGE(sud->m->scales[sud->idx]), (double)val);
}

static void on_volume_entry_activate(GtkEntry *entry, gpointer user_data) {
    commit_volume_entry(GTK_WIDGET(entry), (SinkRowUserData *)user_data);
}

static gboolean on_volume_entry_focus_out(GtkWidget *entry, GdkEventFocus *event,
                                           gpointer user_data) {
    (void)event;
    commit_volume_entry(entry, (SinkRowUserData *)user_data);
    return FALSE;
}

// Row sliders allow scrolling directly (unlike the plain 0-100% bar-icon
// scroll in on_scroll below) up to SLIDER_MAX_VOLUME — GtkRange clamps
// gtk_range_set_value() to the scale's own [lower, upper], so no manual
// clamping is needed here; it just relies on the scale having been created
// with upper=SLIDER_MAX_VOLUME. Returning TRUE stops the scroll event from
// also being treated as "scroll the popup's device list" by the enclosing
// GtkScrolledWindow.
static gboolean on_scale_scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    (void)user_data;
    GtkRange *range = GTK_RANGE(widget);
    double val = gtk_range_get_value(range);
    if (event->direction == GDK_SCROLL_UP) {
        val += SCROLL_VOLUME_STEP;
    } else if (event->direction == GDK_SCROLL_DOWN) {
        val -= SCROLL_VOLUME_STEP;
    } else if (event->direction == GDK_SCROLL_SMOOTH) {
        if (event->delta_y < 0) val += SCROLL_VOLUME_STEP;
        else if (event->delta_y > 0) val -= SCROLL_VOLUME_STEP;
        else return TRUE;
    } else {
        return TRUE;
    }
    gtk_range_set_value(range, val);
    return TRUE;
}

static void sync_scales(ModuleData *m) {
    refresh_sink_presence(m);
    for (int i = 0; i < m->num_sinks; i++) {
        // Absent sinks have their row hidden; querying them would just spawn
        // pactl calls that fail.
        if (m->rows[i] && !gtk_widget_get_visible(m->rows[i])) continue;
        int vol = get_sink_volume(m->sink_names[i]);
        g_signal_handler_block(m->scales[i], m->handler_ids[i]);
        gtk_range_set_value(GTK_RANGE(m->scales[i]), vol);
        g_signal_handler_unblock(m->scales[i], m->handler_ids[i]);
        set_volume_entry_text(m->volume_entries[i], vol);
        gtk_button_set_label(GTK_BUTTON(m->mute_buttons[i]),
                              get_sink_mute(m->sink_names[i]) ? "\U0001F507" : "\U0001F50A");
    }
}

// GtkPopover under gtk-layer-shell is capped at the bar's own layer-shell
// surface height and can't grow past it (confirmed via a minimal diagnostic
// module on the user's real Hyprland session — the popover content was
// visibly cropped to the bar's ~28px strip regardless of widget size
// requests or CSS). So the popup here is a second, independent layer-shell
// surface (its own GtkWindow) instead of a GtkPopover, sized and positioned
// entirely by hand.
//
// Positioning: Wayland clients can't query their absolute screen position,
// so the popup can't be told "open at the module's x,y" directly. Instead we
// read the module's x offset *within the bar's own window* via
// gtk_widget_translate_coordinates() — since the bar spans the full screen
// width, that offset equals the true screen x — and anchor the popup to the
// LEFT edge with that as the margin. Clamped against the monitor's width so
// a module near the right edge (like this one, in modules-right) doesn't
// push the popup partly off-screen.
static void position_popup(ModuleData *m) {
    GtkWidget *bar_toplevel = gtk_widget_get_toplevel(m->event_box);
    int x = 0, y = 0;
    gtk_widget_translate_coordinates(m->event_box, bar_toplevel, 0, 0, &x, &y);

    GdkWindow *bar_gdk_window = gtk_widget_get_window(bar_toplevel);
    if (bar_gdk_window) {
        GdkDisplay *display = gtk_widget_get_display(bar_toplevel);
        GdkMonitor *monitor = gdk_display_get_monitor_at_window(display, bar_gdk_window);
        GdkRectangle geom;
        gdk_monitor_get_geometry(monitor, &geom);
        int max_x = geom.width - POPUP_WIDTH;
        if (x > max_x) x = max_x;
        if (x < 0) x = 0;
    }
    gtk_layer_set_anchor(GTK_WINDOW(m->popup_window), GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(m->popup_window), GTK_LAYER_SHELL_EDGE_LEFT, x);

    // The popup never calls gtk_layer_set_exclusive_zone(), so it keeps the
    // default zone of 0, which means "respect everyone else's exclusive zone":
    // the compositor already places this surface *below* waybar's own reserved
    // strip. So the margin off the anchored edge must be 0 for the popup to
    // touch the bar — any bar-height value here gets added on top of the
    // offset the compositor already applied, which is what kept pushing the
    // popup a full bar height too far down. "popup_margin" in the config is
    // therefore an extra gap beyond the bar, not the bar height itself.
    int margin = m->popup_margin;
    if (margin < 0) {
        margin = 0;
    }
    gtk_layer_set_margin(GTK_WINDOW(m->popup_window), m->bar_edge, margin);
}

// Two independent ways the popup auto-closes:
//
// 1. Pointer leaves it (on_popup_leave/on_popup_enter): a short grace-period
//    timer, not an instant close, so travelling from the module toward the
//    popup doesn't trip it. Doesn't fire on a *keyboard*-driven focus change
//    that leaves the mouse resting inside/near the popup, though — for that:
//
// 2. focus-out-event (on_popup_focus_out): fires when another window takes
//    keyboard focus, whether the user got there by mouse or a compositor
//    keybind. Needs its own grace period for a different reason: with
//    keyboard-mode ON_DEMAND, Hyprland grants the popup keyboard focus the
//    instant it maps, and — because of focus-follows-mouse — immediately
//    hands it back to whatever the pointer was still resting over while it
//    was travelling from the module toward the (correctly positioned, but
//    not yet reached) popup. Without the grace period that spurious first
//    loss closed the popup before the user's mouse could ever reach it.
static gboolean on_hide_timeout(gpointer user_data) {
    ModuleData *m = (ModuleData *)user_data;
    gtk_widget_hide(m->popup_window);
    m->hide_timeout_id = 0;
    return G_SOURCE_REMOVE;
}

static gboolean on_popup_leave(GtkWidget *widget, GdkEventCrossing *event, gpointer user_data) {
    (void)widget;
    // GDK_NOTIFY_INFERIOR fires when the pointer moves from the popup window
    // onto one of its own child widgets (a row, label, or scale) — each of
    // those has its own GdkWindow, so that transition looks like a "leave"
    // even though the pointer is still inside the popup. Only a real leave
    // (ANCESTOR/NONLINEAR/etc.) should start the auto-close timer.
    if (event->detail == GDK_NOTIFY_INFERIOR) return FALSE;
    ModuleData *m = (ModuleData *)user_data;
    if (m->hide_timeout_id) g_source_remove(m->hide_timeout_id);
    m->hide_timeout_id = g_timeout_add(POPUP_HIDE_DELAY_MS, on_hide_timeout, m);
    return FALSE;
}

static gboolean on_popup_enter(GtkWidget *widget, GdkEventCrossing *event, gpointer user_data) {
    (void)widget;
    (void)event;
    ModuleData *m = (ModuleData *)user_data;
    if (m->hide_timeout_id) {
        g_source_remove(m->hide_timeout_id);
        m->hide_timeout_id = 0;
    }
    return FALSE;
}

static gboolean on_popup_focus_out(GtkWidget *widget, GdkEventFocus *event, gpointer user_data) {
    (void)widget;
    (void)event;
    ModuleData *m = (ModuleData *)user_data;
    if (g_get_monotonic_time() - m->popup_shown_at < POPUP_FOCUS_OUT_GRACE_US) return FALSE;
    gtk_widget_hide(m->popup_window);
    return FALSE;
}

static gboolean on_button_press(GtkWidget *widget, GdkEventButton *event, gpointer user_data) {
    (void)widget;
    ModuleData *m = (ModuleData *)user_data;
    if (event->button == GDK_BUTTON_SECONDARY) {
        if (gtk_widget_get_visible(m->popup_window)) {
            gtk_widget_hide(m->popup_window);
        } else {
            sync_scales(m);
            position_popup(m);
            m->popup_shown_at = g_get_monotonic_time();
            gtk_widget_show_all(m->popup_window);
        }
        return TRUE;
    } else if (event->button == GDK_BUTTON_PRIMARY) {
        if (m->primary_idx < 0) return TRUE;
        toggle_sink_mute(m->sink_names[m->primary_idx]);
        update_bar_label(m);
        return TRUE;
    }
    return FALSE;
}

// Per-row mute button inside the popup (one per sink).
static void on_row_mute_clicked(GtkButton *button, gpointer user_data) {
    SinkRowUserData *sud = (SinkRowUserData *)user_data;
    toggle_sink_mute(sud->m->sink_names[sud->idx]);
    gboolean muted = get_sink_mute(sud->m->sink_names[sud->idx]);
    gtk_button_set_label(button, muted ? "\U0001F507" : "\U0001F50A");
    if (sud->idx == sud->m->primary_idx) update_bar_label(sud->m);
}

// The primary sink's volume, scrollable directly from the bar without opening the
// popup. GDK_SCROLL_UP/DOWN cover discrete wheel steps; GDK_SCROLL_SMOOTH
// covers touchpad/precision scrolling (delta_y sign matches wheel semantics:
// negative = up/away = louder). Capped at 100%, unlike the popup's sliders —
// see on_scale_scroll above for the 150%-capable version.
static gboolean on_scroll(GtkWidget *widget, GdkEventScroll *event, gpointer user_data) {
    (void)widget;
    ModuleData *m = (ModuleData *)user_data;
    if (m->primary_idx < 0) return TRUE;
    int vol = get_sink_volume(m->sink_names[m->primary_idx]);
    if (event->direction == GDK_SCROLL_UP) {
        vol += SCROLL_VOLUME_STEP;
    } else if (event->direction == GDK_SCROLL_DOWN) {
        vol -= SCROLL_VOLUME_STEP;
    } else if (event->direction == GDK_SCROLL_SMOOTH) {
        if (event->delta_y < 0) vol += SCROLL_VOLUME_STEP;
        else if (event->delta_y > 0) vol -= SCROLL_VOLUME_STEP;
        else return TRUE;
    } else {
        return TRUE;
    }
    vol = CLAMP(vol, 0, 100);
    set_sink_volume(m->sink_names[m->primary_idx], vol);
    update_bar_label(m);
    if (gtk_widget_get_visible(m->popup_window)) sync_scales(m);
    return TRUE;
}

static gboolean on_periodic_update(gpointer user_data) {
    ModuleData *m = (ModuleData *)user_data;
    // Picks up hotplug both ways: a sink appearing makes its row (and the bar
    // widget) come back, a sink vanishing hides them. sync_scales() already
    // refreshes presence itself, so only do it here when the popup is closed.
    if (gtk_widget_get_visible(m->popup_window)) {
        sync_scales(m);
    } else {
        refresh_sink_presence(m);
    }
    update_bar_label(m);
    return G_SOURCE_CONTINUE;
}

// Shared CSS provider for our own widgets. Kept at file scope so both
// apply_forced_style() (which loads it once) and style_widget() (which
// attaches it to each widget) can see it.
static GtkCssProvider *g_forced_style_provider = NULL;

// CSS classes this module exposes (all inside the right-click popup — the
// bar widget itself uses waybar's normal #cffi-audio_sinks / .module
// selectors in the user's own style.css, no forced style there):
//
//   .wb-audio-sinks-box          popup's outer GtkScrolledWindow: dark
//                                 background, rounded corners, fixed frame
//                                 (does not scroll/clip with the row list).
//   label.wb-audio-sinks-label   per-row sink name text.
//   scale.wb-audio-sinks-scale   the volume slider itself:
//                                   trough      unfilled track
//                                   highlight   filled (current-volume) track
//                                   slider      the drag handle
//   entry.wb-audio-sinks-entry   per-row editable volume number field.
//   button.wb-audio-sinks-mute-btn  per-row mute toggle button.
//
// These rules are loaded via GtkCssProvider at
// GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 10 (see style_widget() below),
// deliberately higher than a normal ~/.config/waybar/style.css
// (PRIORITY_APPLICATION) so the popup stays visible/legible regardless of
// what broad selectors exist in the user's global stylesheet. Because of
// that priority, style.css rules targeting these classes will normally lose
// — to customize colors/sizes, edit the `css` string below directly instead.
static void apply_forced_style(void) {
    if (g_forced_style_provider) return;  // only need to load it once, globally

    g_forced_style_provider = gtk_css_provider_new();
    const char *css =
        // No element-type prefix (not "scrolledwindow.…" or "box.…"): this is
        // applied to the popup's outer GtkScrolledWindow, which is a
        // different CSS node type than the plain GtkBox it used to sit on.
        ".wb-audio-sinks-box {"
        "  background-color: #1e1e2e;"
        "  color: #cdd6f4;"
        "  border-radius: 6px;"
        "}\n"
        "label.wb-audio-sinks-label {"
        "  color: #cdd6f4;"
        "}\n"
        "scale.wb-audio-sinks-scale trough {"
        "  min-height: 8px;"
        "  border-radius: 4px;"
        "  background-color: rgba(255, 255, 255, 0.15);"
        "}\n"
        "scale.wb-audio-sinks-scale highlight {"
        "  min-height: 8px;"
        "  border-radius: 4px;"
        "  background-color: #89b4fa;"
        "}\n"
        "scale.wb-audio-sinks-scale slider {"
        "  min-height: 14px;"
        "  min-width: 14px;"
        "  border-radius: 7px;"
        "  background-color: #f5e0dc;"
        "}\n"
        // GDK_WINDOW_TYPE_HINT_TOOLTIP (set on popup_window below) skips
        // GTK's shadow-margin *reservation*, but the active GTK theme can
        // still paint a CSD shadow/margin via the "decoration" CSS node on
        // undecorated toplevels regardless of type hint — that leftover
        // paint was the remaining visible gap. Zeroed directly here, scoped
        // to this window's own class so it can't affect any other toplevel.
        "window.wb-audio-sinks-popup, window.wb-audio-sinks-popup decoration {"
        "  box-shadow: none;"
        "  margin: 0;"
        "  border: none;"
        "  border-radius: 0;"
        "}\n"
        "entry.wb-audio-sinks-entry {"
        "  min-height: 0;"
        "  padding: 0 4px;"
        "  background-color: rgba(255, 255, 255, 0.08);"
        "  color: #cdd6f4;"
        "  border: none;"
        "  caret-color: #cdd6f4;"
        "}\n"
        "button.wb-audio-sinks-mute-btn {"
        "  padding: 0 4px;"
        "  min-width: 0;"
        "  min-height: 0;"
        "  background: none;"
        "  border: none;"
        "}\n";
    GError *err = NULL;
    if (!gtk_css_provider_load_from_data(g_forced_style_provider, css, -1, &err)) {
        g_warning("wb_cffi_audio_sinks: CSS load failed: %s", err ? err->message : "?");
        if (err) g_error_free(err);
    }
}

// Adds `klass` and installs our forced-visible style provider at a priority
// high enough to win over the rest of waybar's (shared, global) style.css,
// which otherwise can make unstyled widgets render blank/invisible.
static void style_widget(GtkWidget *widget, const char *klass) {
    apply_forced_style();
    gtk_style_context_add_class(gtk_widget_get_style_context(widget), klass);
    gtk_style_context_add_provider(gtk_widget_get_style_context(widget),
                                    GTK_STYLE_PROVIDER(g_forced_style_provider),
                                    GTK_STYLE_PROVIDER_PRIORITY_APPLICATION + 10);
}

void *wbcffi_init(const wbcffi_init_info *init_info,
                   const wbcffi_config_entry *config_entries, size_t config_entries_len) {
    ModuleData *m = g_new0(ModuleData, 1);
    m->obj = init_info->obj;

    parse_config(m, config_entries, config_entries_len);

    GtkContainer *root = init_info->get_root_widget(init_info->obj);

    m->event_box = gtk_event_box_new();
    m->label = gtk_label_new("");  // real text set by update_bar_label() below
    gtk_container_add(GTK_CONTAINER(m->event_box), m->label);
    gtk_container_add(root, m->event_box);
    update_bar_label(m);

    gtk_widget_add_events(m->event_box, GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK);
    g_signal_connect(m->event_box, "scroll-event", G_CALLBACK(on_scroll), m);
    m->update_timeout_id = g_timeout_add_seconds(2, on_periodic_update, m);

    // Own top-level layer-shell surface instead of GtkPopover — see the
    // comment above on_button_press for why.
    m->popup_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_decorated(GTK_WINDOW(m->popup_window), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(m->popup_window), FALSE);
    // GTK/Adwaita reserves an invisible CSD drop-shadow margin around
    // top-level windows even when undecorated, which showed up as an
    // unexplained extra gap between the bar and the popup (margin was
    // measured correct — matching the bar's real height exactly — but the
    // visible gap was bigger). Marking it a TOOLTIP-type window is the
    // standard gtk-layer-shell workaround: GTK skips that shadow reservation
    // for tooltip-type windows. Wayland ignores type hints for anything
    // besides this internal GTK CSS decision, so it has no effect on
    // interactivity (the sliders still work — see keyboard-mode below).
    gtk_window_set_type_hint(GTK_WINDOW(m->popup_window), GDK_WINDOW_TYPE_HINT_TOOLTIP);
    style_widget(m->popup_window, "wb-audio-sinks-popup");
    gtk_layer_init_for_window(GTK_WINDOW(m->popup_window));
    gtk_layer_set_layer(GTK_WINDOW(m->popup_window), GTK_LAYER_SHELL_LAYER_OVERLAY);
    // Anchored to the same screen edge as the bar itself (config: "bar_position",
    // default "top"); anchor/margin on both axes get set per-click in
    // position_popup() since the module's x offset and the bar's real height
    // are only known once everything is realized.
    gtk_layer_set_anchor(GTK_WINDOW(m->popup_window), m->bar_edge, TRUE);
    // ON_DEMAND: needed so a keyboard-driven window switch (e.g. a Hyprland
    // keybind, mouse never moving) can be detected via focus-out-event and
    // close the popup — see the comment above on_popup_focus_out for the
    // grace period this requires to avoid an instant spurious close.
    gtk_layer_set_keyboard_mode(GTK_WINDOW(m->popup_window),
                                 GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    gtk_widget_add_events(m->popup_window,
                           GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK | GDK_FOCUS_CHANGE_MASK);
    g_signal_connect(m->popup_window, "enter-notify-event", G_CALLBACK(on_popup_enter), m);
    g_signal_connect(m->popup_window, "leave-notify-event", G_CALLBACK(on_popup_leave), m);
    g_signal_connect(m->popup_window, "focus-out-event", G_CALLBACK(on_popup_focus_out), m);

    // Rows live in a plain, unstyled box — the dark background/border-radius
    // goes on the enclosing GtkScrolledWindow below instead (see its
    // comment): that's the part that keeps a fixed size while this box
    // scrolls past it, so putting the styling here made the background clip
    // and the rounded corners scroll out of view with the content.
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, ROW_SPACING);

    for (int i = 0; i < m->num_sinks; i++) {
        GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        gtk_widget_set_size_request(row, 200, 30);

        GtkWidget *lbl = gtk_label_new(m->sink_labels[i]);
        gtk_widget_set_size_request(lbl, 90, -1);
        gtk_label_set_xalign(GTK_LABEL(lbl), 0.0);
        style_widget(lbl, "wb-audio-sinks-label");

        // draw_value off: the built-in number readout is part of the GtkScale
        // widget itself, so scroll events over it would count as scrolling
        // the slider. Replaced below with a separate editable GtkEntry, which
        // isn't wired to on_scale_scroll — scrolling over it instead bubbles
        // up to the popup's GtkScrolledWindow and pages the sink list.
        GtkWidget *scale = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 0,
                                                     SLIDER_MAX_VOLUME, 1);
        gtk_scale_set_draw_value(GTK_SCALE(scale), FALSE);
        gtk_widget_set_size_request(scale, 150, -1);
        gtk_range_set_value(GTK_RANGE(scale), get_sink_volume(m->sink_names[i]));
        style_widget(scale, "wb-audio-sinks-scale");
        gtk_widget_add_events(scale, GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK |
                                          GDK_BUTTON_PRESS_MASK);
        g_signal_connect(scale, "scroll-event", G_CALLBACK(on_scale_scroll), NULL);
        g_signal_connect(scale, "button-press-event", G_CALLBACK(on_scale_button_press), NULL);

        m->scales[i] = scale;

        SinkRowUserData *sud = g_new(SinkRowUserData, 1);
        sud->m = m;
        sud->idx = i;
        g_object_set_data_full(G_OBJECT(scale), "scale-user-data", sud, g_free);
        m->handler_ids[i] = g_signal_connect(scale, "value-changed",
                                              G_CALLBACK(on_scale_changed), sud);

        GtkWidget *vol_entry = gtk_entry_new();
        gtk_entry_set_width_chars(GTK_ENTRY(vol_entry), 4);
        gtk_entry_set_alignment(GTK_ENTRY(vol_entry), 1.0);
        set_volume_entry_text(vol_entry, get_sink_volume(m->sink_names[i]));
        style_widget(vol_entry, "wb-audio-sinks-entry");
        g_signal_connect(vol_entry, "activate", G_CALLBACK(on_volume_entry_activate), sud);
        g_signal_connect(vol_entry, "focus-out-event",
                          G_CALLBACK(on_volume_entry_focus_out), sud);
        m->volume_entries[i] = vol_entry;

        GtkWidget *mute_btn = gtk_button_new_with_label(
            get_sink_mute(m->sink_names[i]) ? "\U0001F507" : "\U0001F50A");
        gtk_button_set_relief(GTK_BUTTON(mute_btn), GTK_RELIEF_NONE);
        style_widget(mute_btn, "wb-audio-sinks-mute-btn");
        SinkRowUserData *mute_sud = g_new(SinkRowUserData, 1);
        mute_sud->m = m;
        mute_sud->idx = i;
        g_object_set_data_full(G_OBJECT(mute_btn), "mute-user-data", mute_sud, g_free);
        g_signal_connect(mute_btn, "clicked", G_CALLBACK(on_row_mute_clicked), mute_sud);
        m->mute_buttons[i] = mute_btn;

        gtk_box_pack_start(GTK_BOX(row), lbl, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(row), scale, TRUE, TRUE, 0);
        gtk_box_pack_start(GTK_BOX(row), vol_entry, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(row), mute_btn, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(box), row, FALSE, FALSE, 0);
        m->rows[i] = row;

        g_message("wb_cffi_audio_sinks: sink %d label=\"%s\" name=\"%s\"", i,
                  m->sink_labels[i], m->sink_names[i]);
    }

    // Popup shows max_visible_sinks rows before scrolling — every configured
    // sink is loaded into the list regardless (num_sinks, above), but only
    // the first max_visible_sinks rows fit without scrolling; scrolling the
    // background (any spot that isn't a slider, which consumes its own
    // scroll events above) pages through the rest.
    //
    // Real per-row height (not a guessed constant) is measured from box's
    // own natural size now that all its rows exist: box's total natural
    // height = num_sinks*row_height + (num_sinks-1)*ROW_SPACING, solved for
    // row_height. gtk_widget_show_all() here only realizes this subtree for
    // size negotiation — the popup_window itself isn't shown, so nothing
    // becomes visible on screen yet.
    gtk_widget_show_all(box);
    // Row height below is measured with *all* rows shown, so the popup keeps a
    // stable size instead of growing/shrinking as devices come and go. From
    // here on the rows opt out of show_all so refresh_sink_presence() stays the
    // only thing deciding which of them are visible — otherwise the
    // gtk_widget_show_all(popup_window) on each right-click would un-hide rows
    // for absent sinks.
    for (int i = 0; i < m->num_sinks; i++) {
        gtk_widget_set_no_show_all(m->rows[i], TRUE);
    }
    int box_natural_height = 0;
    gtk_widget_get_preferred_height(box, NULL, &box_natural_height);
    int row_height = (box_natural_height - (m->num_sinks - 1) * ROW_SPACING) / m->num_sinks;

    int visible_rows = MIN(m->max_visible_sinks, m->num_sinks);
    int visible_content_height =
        visible_rows * row_height + MAX(visible_rows - 1, 0) * ROW_SPACING;
    int popup_height =
        MIN(visible_content_height + 2 * POPUP_BORDER, POPUP_ABS_MAX_HEIGHT);

    // Background/border-radius applied here (not on `box` above) so it
    // stays a fixed frame around the scrollable content instead of scrolling
    // — and stays a single un-clipped rounded rectangle at any scroll
    // position. border-width also moves here for the same reason: fixed
    // padding around the frame, not padding that would scroll with `box`.
    GtkWidget *scrolled = gtk_scrolled_window_new(NULL, NULL);
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolled), GTK_POLICY_NEVER,
                                    GTK_POLICY_AUTOMATIC);
    gtk_container_set_border_width(GTK_CONTAINER(scrolled), POPUP_BORDER);
    gtk_widget_set_size_request(scrolled, POPUP_WIDTH, popup_height);
    style_widget(scrolled, "wb-audio-sinks-box");
    gtk_container_add(GTK_CONTAINER(scrolled), box);
    gtk_container_add(GTK_CONTAINER(m->popup_window), scrolled);

    gtk_widget_add_events(m->event_box, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(m->event_box, "button-press-event", G_CALLBACK(on_button_press), m);

    gtk_widget_show_all(m->event_box);
    // Same reason as the rows above: waybar shows its module widgets, which
    // would override the hide when no configured sink exists.
    gtk_widget_set_no_show_all(m->event_box, TRUE);
    refresh_sink_presence(m);
    update_bar_label(m);

    return m;
}

void wbcffi_deinit(void *instance) {
    ModuleData *m = (ModuleData *)instance;
    if (m->hide_timeout_id) g_source_remove(m->hide_timeout_id);
    if (m->update_timeout_id) g_source_remove(m->update_timeout_id);
    for (int i = 0; i < m->num_sinks; i++) {
        g_free(m->sink_names[i]);
        g_free(m->sink_labels[i]);
    }
    g_free(m->sink_names);
    g_free(m->sink_labels);
    g_free(m->rows);
    g_free(m->scales);
    g_free(m->mute_buttons);
    g_free(m->volume_entries);
    g_free(m->handler_ids);
    g_free(m);
}

void wbcffi_update(void *instance) {
    (void)instance;
}

void wbcffi_refresh(void *instance, int signal) {
    (void)signal;
    sync_scales((ModuleData *)instance);
}

void wbcffi_doaction(void *instance, const char *action_name) {
    (void)instance;
    (void)action_name;
}
