#!/usr/bin/env python3
"""Adaptive backlight daemon: maps ambient light (iio-sensor-proxy) to screen brightness.

Runs as a system-tray icon; click it (or middle-click for a direct shortcut,
since AppIndicator trays always open the menu on left-click) to open a status
window with live sensor/brightness readings and an editable lux->brightness
curve, saved per-profile to ~/.config/adaptive-backlight/profiles.json.
"""

import json
import math
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import ClassVar

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
gi.require_version("GLibUnix", "2.0")
from gi.repository import AyatanaAppIndicator3, Gdk, GLib, GLibUnix, Gtk

BACKLIGHT_DEVICE = "intel_backlight"

# Brightness bounds and the lux reference point that maps to 100%.
MIN_PCT = 1
MAX_PCT = 100
MAX_LUX = 1000

POLL_INTERVAL_SEC = 2
EMA_ALPHA = 0.3        # smoothing factor for lux readings; lower = smoother/slower
STEP_THRESHOLD_PCT = 3  # ignore target changes smaller than this, to avoid flicker

# If the actual brightness diverges from what we last set, assume the user
# adjusted it manually (e.g. via keyboard/swayosd) and back off for a while
# instead of immediately overriding their choice.
OVERRIDE_THRESHOLD_PCT = 5
OVERRIDE_COOLDOWN_SEC = 30

SENSOR_BUS_ARGS = [
    "busctl", "--system", "--json=short",
]

TRAY_ICON_NAME = "display-brightness-symbolic"

CONFIG_PATH = (
    Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    / "adaptive-backlight" / "profiles.json"
)
DEFAULT_PROFILE_NAME = "Default"
DEFAULT_POINTS = [[0, MIN_PCT], [MAX_LUX, MAX_PCT]]


def claim_light():
    subprocess.run(
        SENSOR_BUS_ARGS + [
            "call", "net.hadess.SensorProxy", "/net/hadess/SensorProxy",
            "net.hadess.SensorProxy", "ClaimLight",
        ],
        check=True, capture_output=True,
    )


def release_light():
    subprocess.run(
        SENSOR_BUS_ARGS + [
            "call", "net.hadess.SensorProxy", "/net/hadess/SensorProxy",
            "net.hadess.SensorProxy", "ReleaseLight",
        ],
        check=False, capture_output=True,
    )


class LuxSensor:
    """Reads ambient lux straight from the kernel IIO node.

    iio-sensor-proxy's own LightLevel D-Bus property gets stuck on this
    hardware once claimed (its buffered/triggered read of the HID ALS times
    out every boot: "Buffer '/dev/iio:deviceN' did not have data within
    0.5s"), so it never reflects real changes on its own. The raw sysfs
    value, read fresh each time, does not have that problem -- it was
    verified live and accurate for hours of testing. ClaimLight still needs
    to be held once (see claim_light/release_light) to keep the sensor
    powered; re-claiming on every poll was tried and made things worse (it
    never let a reading settle, causing real light to appear to "decay"
    back down a few seconds after being detected).
    """

    IIO_ROOT = Path("/sys/bus/iio/devices")
    DEVICE_NAME = "als"

    def __init__(self):
        device_dir = self._find_device()
        self._raw_path = device_dir / "in_illuminance_raw"
        self._scale = float((device_dir / "in_illuminance_scale").read_text())
        self._offset = float((device_dir / "in_illuminance_offset").read_text())

    @classmethod
    def _find_device(cls):
        for device_dir in sorted(cls.IIO_ROOT.glob("iio:device*")):
            name_file = device_dir / "name"
            if name_file.exists() and name_file.read_text().strip() == cls.DEVICE_NAME:
                return device_dir
        raise FileNotFoundError(f"no IIO device named {cls.DEVICE_NAME!r} found under {cls.IIO_ROOT}")

    def read_lux(self):
        raw = float(self._raw_path.read_text())
        return (raw + self._offset) * self._scale


def read_current_pct():
    result = subprocess.run(
        ["brightnessctl", "-m"], check=True, capture_output=True, text=True,
    )
    # format: device,class,current,percentage,max
    return int(result.stdout.strip().split(",")[3].rstrip("%"))


def set_pct(pct):
    subprocess.run(
        #["brightnessctl", "set", f"{pct}%"]
        ["swayosd-client", "--brightness", f"{pct}"]
        , check=True, capture_output=True,
    )


def lux_to_pct(points, lux):
    """Piecewise-linear interpolation of `points` ([lux, pct], sorted by lux) in log-lux space."""
    log_lux = math.log10(max(lux, 0.0) + 1)
    xs = [math.log10(point[0] + 1) for point in points]

    if log_lux <= xs[0]:
        return points[0][1]
    if log_lux >= xs[-1]:
        return points[-1][1]

    for i in range(len(points) - 1):
        if xs[i] <= log_lux <= xs[i + 1]:
            span = xs[i + 1] - xs[i]
            t = (log_lux - xs[i]) / span if span else 0.0
            return points[i][1] + t * (points[i + 1][1] - points[i][1])
    return points[-1][1]


class ProfileStore:
    """Persists named lux->brightness curves to CONFIG_PATH as JSON."""

    def __init__(self):
        self.profiles = {}
        self.active = DEFAULT_PROFILE_NAME
        self._load()

    def _load(self):
        try:
            data = json.loads(CONFIG_PATH.read_text())
            self.profiles = {
                name: [list(point) for point in points]
                for name, points in data["profiles"].items()
            }
            self.active = data["active"] if data.get("active") in self.profiles else next(iter(self.profiles))
        except (OSError, json.JSONDecodeError, KeyError, StopIteration):
            self.profiles = {DEFAULT_PROFILE_NAME: [list(point) for point in DEFAULT_POINTS]}
            self.active = DEFAULT_PROFILE_NAME
            self.save()

    def save(self):
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_PATH.write_text(json.dumps({"active": self.active, "profiles": self.profiles}, indent=2))

    def active_points(self):
        """Live reference to the active profile's points list; mutate in place, then save()."""
        return self.profiles[self.active]

    def set_active(self, name):
        if name in self.profiles and name != self.active:
            self.active = name
            self.save()

    def add_profile(self, name):
        if not name or name in self.profiles:
            return False
        self.profiles[name] = [list(point) for point in self.active_points()]
        self.active = name
        self.save()
        return True

    def delete_active(self):
        if len(self.profiles) <= 1:
            return False
        del self.profiles[self.active]
        self.active = next(iter(self.profiles))
        self.save()
        return True


class CurveEditor(Gtk.DrawingArea):
    """Interactive lux -> brightness curve, plotted on a log-lux x-axis.

    Left-click+drag a point to move it; left-click empty space to add a point;
    right-click a point to remove it. The two endpoints are fixed in x (they
    anchor the 0 lux and MAX_LUX edges of the curve) and can only move vertically.
    """

    POINT_RADIUS = 6
    HIT_RADIUS = 12
    MAX_POINTS = 10

    def __init__(self, store):
        super().__init__()
        self.store = store
        self.set_size_request(360, 200)
        self.set_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
        )
        self.connect("draw", self._on_draw)
        self.connect("button-press-event", self._on_button_press)
        self.connect("button-release-event", self._on_button_release)
        self.connect("motion-notify-event", self._on_motion)

        self._drag_index = None
        self._live_lux = None
        self._live_pct = None

    def set_live_marker(self, lux, pct):
        self._live_lux = lux
        self._live_pct = pct
        self.queue_draw()

    def refresh(self):
        """Call after switching the active profile."""
        self._drag_index = None
        self.queue_draw()

    # -- coordinate transforms --

    def _plot_bounds(self):
        alloc = self.get_allocation()
        margin_left, margin_right = 40, 12
        margin_top, margin_bottom = 12, 24
        return (
            margin_left, margin_top,
            max(alloc.width - margin_left - margin_right, 1),
            max(alloc.height - margin_top - margin_bottom, 1),
        )

    def _lux_to_x(self, lux):
        left, _, width, _ = self._plot_bounds()
        ratio = math.log10(max(lux, 0.0) + 1) / math.log10(MAX_LUX + 1)
        return left + ratio * width

    def _x_to_lux(self, x):
        left, _, width, _ = self._plot_bounds()
        ratio = min(max((x - left) / width, 0.0), 1.0)
        return 10 ** (ratio * math.log10(MAX_LUX + 1)) - 1

    def _pct_to_y(self, pct):
        _, top, _, height = self._plot_bounds()
        ratio = pct / 100
        return top + (1 - ratio) * height

    def _y_to_pct(self, y):
        _, top, _, height = self._plot_bounds()
        ratio = min(max((y - top) / height, 0.0), 1.0)
        return (1 - ratio) * 100

    # -- drawing --

    def _on_draw(self, _widget, cr):
        left, top, width, height = self._plot_bounds()
        points = self.store.active_points()

        cr.set_source_rgb(0.12, 0.12, 0.13)
        cr.rectangle(left, top, width, height)
        cr.fill_preserve()
        cr.set_source_rgb(0.35, 0.35, 0.37)
        cr.set_line_width(1)
        cr.stroke()

        cr.select_font_face("sans-serif")
        cr.set_font_size(10)
        for lux_tick in (1, 10, 100, 1000):
            x = self._lux_to_x(lux_tick)
            cr.set_source_rgb(0.3, 0.3, 0.32)
            cr.move_to(x, top)
            cr.line_to(x, top + height)
            cr.stroke()
            cr.set_source_rgb(0.6, 0.6, 0.6)
            cr.move_to(x - 8, top + height + 14)
            cr.show_text(str(lux_tick))
        for pct_tick in (0, 50, 100):
            y = self._pct_to_y(pct_tick)
            cr.set_source_rgb(0.3, 0.3, 0.32)
            cr.move_to(left, y)
            cr.line_to(left + width, y)
            cr.stroke()
            cr.set_source_rgb(0.6, 0.6, 0.6)
            cr.move_to(left - 30, y + 4)
            cr.show_text(f"{pct_tick}%")

        cr.set_source_rgb(0.4, 0.7, 1.0)
        cr.set_line_width(2)
        for i, (lux, pct) in enumerate(points):
            x, y = self._lux_to_x(lux), self._pct_to_y(pct)
            if i == 0:
                cr.move_to(x, y)
            else:
                cr.line_to(x, y)
        cr.stroke()

        for lux, pct in points:
            x, y = self._lux_to_x(lux), self._pct_to_y(pct)
            cr.arc(x, y, self.POINT_RADIUS, 0, 2 * math.pi)
            cr.set_source_rgb(0.9, 0.9, 0.95)
            cr.fill_preserve()
            cr.set_source_rgb(0.4, 0.7, 1.0)
            cr.set_line_width(1.5)
            cr.stroke()

        if self._live_lux is not None:
            x = self._lux_to_x(self._live_lux)
            cr.set_source_rgba(1.0, 0.6, 0.2, 0.8)
            cr.set_line_width(1)
            cr.move_to(x, top)
            cr.line_to(x, top + height)
            cr.stroke()
            y = self._pct_to_y(self._live_pct)
            cr.arc(x, y, 4, 0, 2 * math.pi)
            cr.set_source_rgb(1.0, 0.6, 0.2)
            cr.fill()

        return False

    # -- interaction --

    def _hit_test(self, x, y):
        for i, (lux, pct) in enumerate(self.store.active_points()):
            px, py = self._lux_to_x(lux), self._pct_to_y(pct)
            if (px - x) ** 2 + (py - y) ** 2 <= self.HIT_RADIUS ** 2:
                return i
        return None

    def _on_button_press(self, _widget, event):
        index = self._hit_test(event.x, event.y)

        if event.button == 3:  # right-click: delete (endpoints are protected)
            points = self.store.active_points()
            if index is not None and 0 < index < len(points) - 1:
                points.pop(index)
                self.store.save()
                self.queue_draw()
            return True

        if event.button != 1:
            return False

        if index is None:
            points = self.store.active_points()
            if len(points) >= self.MAX_POINTS:
                return True
            new_point = [round(self._x_to_lux(event.x), 1), round(self._y_to_pct(event.y))]
            points.append(new_point)
            points.sort(key=lambda point: point[0])
            index = points.index(new_point)
            self.store.save()

        self._drag_index = index
        self.queue_draw()
        return True

    def _on_motion(self, _widget, event):
        if self._drag_index is None:
            return False

        points = self.store.active_points()
        index = self._drag_index
        pct = round(min(max(self._y_to_pct(event.y), MIN_PCT), MAX_PCT))

        if index in (0, len(points) - 1):
            lux = points[index][0]  # endpoints anchor the domain, x is fixed
        else:
            lo = points[index - 1][0] + 0.5
            hi = max(points[index + 1][0] - 0.5, lo)
            lux = round(min(max(self._x_to_lux(event.x), lo), hi), 1)

        points[index] = [lux, pct]
        self.queue_draw()
        return True

    def _on_button_release(self, _widget, _event):
        if self._drag_index is not None:
            self._drag_index = None
            self.store.save()
        return True


class StatusWindow(Gtk.Window):
    FIELDS: ClassVar[list[tuple[str, str]]] = [
        ("lux", "Ambient light (lux)"),
        ("smoothed_lux", "Smoothed lux"),
        ("current_pct", "Current brightness"),
        ("target_pct", "Target brightness"),
        ("status", "Status"),
    ]

    def __init__(self, store):
        super().__init__(title="Adaptive Backlight")
        self.store = store
        self.set_default_size(400, 420)
        self.set_resizable(False)
        self.set_icon_name(TRAY_ICON_NAME)
        self.connect("delete-event", self._hide_instead_of_close)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin=12)
        self.add(outer)

        status_grid = Gtk.Grid(column_spacing=16, row_spacing=8)
        outer.pack_start(status_grid, False, False, 0)
        self._value_labels = {}
        for row, (key, caption) in enumerate(self.FIELDS):
            status_grid.attach(Gtk.Label(label=caption, xalign=0), 0, row, 1, 1)
            value_label = Gtk.Label(label="—", xalign=0)
            status_grid.attach(value_label, 1, row, 1, 1)
            self._value_labels[key] = value_label

        outer.pack_start(Gtk.Separator(), False, False, 0)

        profile_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        outer.pack_start(profile_row, False, False, 0)
        profile_row.pack_start(Gtk.Label(label="Profile:"), False, False, 0)

        self._profile_combo = Gtk.ComboBoxText()
        self._profile_combo.connect("changed", self._on_profile_changed)
        profile_row.pack_start(self._profile_combo, True, True, 0)

        new_button = Gtk.Button(label="New")
        new_button.connect("clicked", self._on_new_profile)
        profile_row.pack_start(new_button, False, False, 0)

        self._delete_button = Gtk.Button(label="Delete")
        self._delete_button.connect("clicked", self._on_delete_profile)
        profile_row.pack_start(self._delete_button, False, False, 0)

        self._refresh_profile_combo()

        self.curve_editor = CurveEditor(store)
        outer.pack_start(self.curve_editor, True, True, 0)

        hint = Gtk.Label(
            label="Drag points to reshape the curve. Click empty space to add a "
                  "point, right-click a point to remove it.",
            xalign=0, wrap=True,
        )
        hint.get_style_context().add_class("dim-label")
        outer.pack_start(hint, False, False, 0)

    def _refresh_profile_combo(self):
        self._profile_combo.handler_block_by_func(self._on_profile_changed)
        self._profile_combo.remove_all()
        names = list(self.store.profiles)
        for name in names:
            self._profile_combo.append_text(name)
        self._profile_combo.set_active(names.index(self.store.active))
        self._profile_combo.handler_unblock_by_func(self._on_profile_changed)
        self._delete_button.set_sensitive(len(self.store.profiles) > 1)

    def _on_profile_changed(self, combo):
        name = combo.get_active_text()
        if name and name != self.store.active:
            self.store.set_active(name)
            self.curve_editor.refresh()

    def _on_new_profile(self, _button):
        dialog = Gtk.Dialog(title="New Profile", transient_for=self, modal=True)
        dialog.add_buttons("_Cancel", Gtk.ResponseType.CANCEL, "_OK", Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.OK)

        entry = Gtk.Entry()
        entry.set_activates_default(True)
        content = dialog.get_content_area()
        content.set_spacing(6)
        content.set_border_width(12)
        content.add(Gtk.Label(label="Profile name (starts as a copy of the current curve):"))
        content.add(entry)
        dialog.show_all()

        response = dialog.run()
        name = entry.get_text().strip()
        dialog.destroy()

        if response == Gtk.ResponseType.OK and self.store.add_profile(name):
            self._refresh_profile_combo()
            self.curve_editor.refresh()

    def _on_delete_profile(self, _button):
        if self.store.delete_active():
            self._refresh_profile_combo()
            self.curve_editor.refresh()

    def _hide_instead_of_close(self, window, _event):
        window.hide()
        return True  # keep the window alive, just hide it

    def update(self, *, lux, smoothed_lux, current_pct, target_pct, status):
        self._value_labels["lux"].set_text(f"{lux:.1f}")
        self._value_labels["smoothed_lux"].set_text(f"{smoothed_lux:.1f}")
        self._value_labels["current_pct"].set_text(f"{current_pct}%")
        self._value_labels["target_pct"].set_text(f"{target_pct}%")
        self._value_labels["status"].set_text(status)
        self.curve_editor.set_live_marker(smoothed_lux, target_pct)

    def show_and_raise(self):
        self.show_all()
        self.present()


class BacklightController:
    """Holds the polling state that used to be local variables in the main loop."""

    def __init__(self, window, store, sensor):
        self.window = window
        self.store = store
        self.sensor = sensor
        self.smoothed_lux = None
        self.last_set_pct = None
        self.override_until = 0.0

    def poll(self):
        try:
            lux = self.sensor.read_lux()
        except (OSError, ValueError) as exc:
            print(f"lux read failed: {exc}", file=sys.stderr)
            return GLib.SOURCE_CONTINUE

        self.smoothed_lux = lux if self.smoothed_lux is None else (
            EMA_ALPHA * lux + (1 - EMA_ALPHA) * self.smoothed_lux
        )
        target_pct = round(lux_to_pct(self.store.active_points(), self.smoothed_lux))

        try:
            current_pct = read_current_pct()
        except (subprocess.CalledProcessError, ValueError, IndexError) as exc:
            print(f"brightness read failed: {exc}", file=sys.stderr)
            return GLib.SOURCE_CONTINUE

        now = time.monotonic()
        if self.last_set_pct is not None and abs(current_pct - self.last_set_pct) > OVERRIDE_THRESHOLD_PCT:
            self.override_until = now + OVERRIDE_COOLDOWN_SEC
            self.last_set_pct = current_pct

        if now < self.override_until:
            status = f"manual override ({self.override_until - now:.0f}s cooldown)"
        else:
            status = "adaptive"
            if self.last_set_pct is None or abs(target_pct - current_pct) >= STEP_THRESHOLD_PCT:
                try:
                    set_pct(target_pct)
                    self.last_set_pct = target_pct
                    print(f"lux={lux:.1f} (smoothed={self.smoothed_lux:.1f}) -> {target_pct}%")
                except subprocess.CalledProcessError as exc:
                    print(f"brightness set failed: {exc.stderr.decode().strip()}", file=sys.stderr)

        if self.window.get_visible():
            self.window.update(
                lux=lux, smoothed_lux=self.smoothed_lux,
                current_pct=current_pct, target_pct=target_pct, status=status,
            )

        return GLib.SOURCE_CONTINUE


def build_indicator(window):
    indicator = AyatanaAppIndicator3.Indicator.new(
        "adaptive-backlight",
        TRAY_ICON_NAME,
        AyatanaAppIndicator3.IndicatorCategory.HARDWARE,
    )
    indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)
    indicator.set_title("Adaptive Backlight")

    menu = Gtk.Menu()

    show_item = Gtk.MenuItem(label="Show Status")
    show_item.connect("activate", lambda _item: window.show_and_raise())
    menu.append(show_item)

    menu.append(Gtk.SeparatorMenuItem())

    quit_item = Gtk.MenuItem(label="Quit")
    quit_item.connect("activate", lambda _item: Gtk.main_quit())
    menu.append(quit_item)

    menu.show_all()
    indicator.set_menu(menu)
    # AppIndicator trays always open the menu on left-click; wire middle-click
    # ("secondary activate") straight to Show Status as a one-click shortcut.
    indicator.set_secondary_activate_target(show_item)
    return indicator


def main():
    try:
        claim_light()
    except subprocess.CalledProcessError as exc:
        print(f"failed to claim light sensor: {exc.stderr.decode().strip()}", file=sys.stderr)
        sys.exit(1)

    try:
        sensor = LuxSensor()
    except (FileNotFoundError, ValueError) as exc:
        print(f"failed to find ambient light sensor: {exc}", file=sys.stderr)
        release_light()
        sys.exit(1)

    store = ProfileStore()
    window = StatusWindow(store)
    controller = BacklightController(window, store, sensor)
    indicator = build_indicator(window)  # noqa: F841 (must stay alive for the GObject/D-Bus registration)

    GLib.timeout_add(POLL_INTERVAL_SEC * 1000, controller.poll)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, Gtk.main_quit)

    try:
        Gtk.main()
    finally:
        release_light()


if __name__ == "__main__":
    main()
