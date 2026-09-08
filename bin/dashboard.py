#!/usr/bin/env python3
"""
System Dashboard
A dark-themed desktop GUI showing CPU, RAM, Disk, Network, and Power Profile.
Requirements: pip install psutil --break-system-packages
"""

import tkinter as tk
from tkinter import font
import psutil
import subprocess
import threading
import time
from collections import deque

# ── Themes ────────────────────────────────────────────────────────────────────

THEMES = {
    "dark": {
        "BG":           "#0e1117",
        "CARD_BG":      "#1a1f2e",
        "BORDER":       "#2a2f3e",
        "TEXT":         "#e2e8f0",
        "MUTED":        "#64748b",
    },
    "light": {
        "BG":           "#f1f5f9",
        "CARD_BG":      "#ffffff",
        "BORDER":       "#cbd5e1",
        "TEXT":         "#0f172a",
        "MUTED":        "#94a3b8",
    },
}

# ── Accent colors (shared across themes) ─────────────────────────────────────
ACCENT_BLUE  = "#3b82f6"
ACCENT_GREEN = "#22c55e"
ACCENT_RED   = "#ef4444"
ACCENT_AMBER = "#f59e0b"
ACCENT_PURP  = "#a855f7"

REFRESH_MS  = 1000
NET_HISTORY = 60

# ── Helpers ───────────────────────────────────────────────────────────────────

def bytes_to_human(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"

def get_power_profile():
    try:
        return subprocess.check_output(
            ["powerprofilesctl", "get"], stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        try:
            return subprocess.check_output(
                ["cat", "/sys/firmware/acpi/platform_profile"],
                stderr=subprocess.DEVNULL
            ).decode().strip()
        except Exception:
            return "unavailable"

def profile_color(profile):
    p = profile.lower()
    if "performance" in p:
        return ACCENT_RED
    if "power" in p or "saver" in p or "low" in p:
        return ACCENT_GREEN
    return ACCENT_AMBER

# ── Card widget ───────────────────────────────────────────────────────────────

class Card(tk.Frame):
    def __init__(self, parent, title, accent=ACCENT_BLUE, theme=None, **kwargs):
        t = theme or {}
        super().__init__(parent, bg=t.get("CARD_BG", "#1a1f2e"),
                         highlightbackground=t.get("BORDER", "#2a2f3e"),
                         highlightthickness=1, **kwargs)
        self.accent = accent
        self._theme = t
        self._accent_bar = tk.Frame(self, bg=accent, height=3)
        self._accent_bar.pack(fill="x")
        self._title_lbl = tk.Label(
            self, text=title,
            bg=t.get("CARD_BG", "#1a1f2e"),
            fg=t.get("MUTED", "#64748b"),
            font=("SF Pro Display", 10, "bold")
        )
        self._title_lbl.pack(anchor="w", padx=14, pady=(8, 0))

    def apply_theme(self, t):
        self._theme = t
        self.config(bg=t["CARD_BG"], highlightbackground=t["BORDER"])
        self._title_lbl.config(bg=t["CARD_BG"], fg=t["MUTED"])
        # Recursively update all child frames/labels that aren't accent-colored
        self._retheme_children(self, t)

    def _retheme_children(self, widget, t):
        for child in widget.winfo_children():
            cls = child.winfo_class()
            if cls == "Frame":
                # Don't recolor the accent bar
                if child is not self._accent_bar:
                    child.config(bg=t["CARD_BG"])
                self._retheme_children(child, t)
            elif cls == "Label":
                fg = child.cget("fg")
                # Preserve accent-colored labels (stats, values)
                if fg not in (t["TEXT"], t["MUTED"], THEMES["dark"]["TEXT"],
                              THEMES["dark"]["MUTED"], THEMES["light"]["TEXT"],
                              THEMES["light"]["MUTED"]):
                    child.config(bg=t["CARD_BG"])
                else:
                    child.config(bg=t["CARD_BG"])
            elif cls == "Canvas":
                child.config(bg=t["CARD_BG"])

# ── Progress bar ──────────────────────────────────────────────────────────────

class ProgressBar(tk.Canvas):
    def __init__(self, parent, color=ACCENT_BLUE, height=6, theme=None, **kwargs):
        t = theme or {}
        super().__init__(parent, height=height,
                         bg=t.get("CARD_BG", "#1a1f2e"),
                         highlightthickness=0, **kwargs)
        self.color = color
        self._border_color = t.get("BORDER", "#2a2f3e")
        self.bind("<Configure>", self._on_resize)
        self._pct = 0

    def _on_resize(self, e):
        self.set(self._pct)

    def set(self, pct):
        self._pct = max(0, min(100, pct))
        self.delete("all")
        w = self.winfo_width()
        h = self.winfo_height()
        if w < 2:
            return
        self.create_rectangle(0, 0, w, h, fill=self._border_color, outline="")
        fill_w = int(w * self._pct / 100)
        if fill_w > 0:
            self.create_rectangle(0, 0, fill_w, h, fill=self.color, outline="")

    def apply_theme(self, t):
        self._border_color = t["BORDER"]
        self.config(bg=t["CARD_BG"])
        self.set(self._pct)

# ── Settings Window ───────────────────────────────────────────────────────────

class SettingsWindow(tk.Toplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.parent = parent
        self.title("Settings")
        self.resizable(False, False)
        self.configure(bg=parent.theme["BG"])

        # Keep on top, center over parent
        self.transient(parent)
        self.grab_set()
        self.geometry("300x200")
        self._center()
        self._build()

    def _center(self):
        self.update_idletasks()
        px = self.parent.winfo_x() + self.parent.winfo_width() // 2 - 150
        py = self.parent.winfo_y() + self.parent.winfo_height() // 2 - 100
        self.geometry(f"+{px}+{py}")

    def _build(self):
        t = self.parent.theme
        pad = {"padx": 20, "pady": 10}

        tk.Label(self, text="SETTINGS", bg=t["BG"], fg=t["MUTED"],
                 font=("SF Pro Display", 10, "bold")).pack(anchor="w", padx=20, pady=(16, 4))

        # Divider
        tk.Frame(self, bg=t["BORDER"], height=1).pack(fill="x", padx=20)

        # Theme toggle
        row1 = tk.Frame(self, bg=t["BG"])
        row1.pack(fill="x", **pad)
        tk.Label(row1, text="Theme", bg=t["BG"], fg=t["TEXT"],
                 font=("SF Pro Display", 11)).pack(side="left")

        self._theme_var = tk.StringVar(value=self.parent.current_theme)
        theme_btn = tk.Button(
            row1, textvariable=self._theme_var,
            bg=ACCENT_BLUE, fg="#ffffff",
            font=("SF Pro Display", 10),
            relief="flat", padx=12, pady=4,
            cursor="hand2",
            command=self._toggle_theme
        )
        theme_btn.pack(side="right")

        # Graph toggle
        row2 = tk.Frame(self, bg=t["BG"])
        row2.pack(fill="x", **pad)
        tk.Label(row2, text="Network Graph", bg=t["BG"], fg=t["TEXT"],
                 font=("SF Pro Display", 11)).pack(side="left")

        self._graph_var = tk.StringVar(value="on" if self.parent.show_graph else "off")
        graph_btn = tk.Button(
            row2, textvariable=self._graph_var,
            bg=ACCENT_GREEN if self.parent.show_graph else ACCENT_RED,
            fg="#ffffff",
            font=("SF Pro Display", 10),
            relief="flat", padx=12, pady=4,
            cursor="hand2",
            command=self._toggle_graph
        )
        self._graph_btn = graph_btn
        graph_btn.pack(side="right")

        # Close button
        tk.Button(
            self, text="Close",
            bg=t["CARD_BG"], fg=t["MUTED"],
            font=("SF Pro Display", 10),
            relief="flat", padx=12, pady=4,
            cursor="hand2",
            command=self.destroy
        ).pack(side="bottom", pady=16)

    def _toggle_theme(self):
        new = "light" if self.parent.current_theme == "dark" else "dark"
        self.parent.apply_theme(new)
        self._theme_var.set(new)
        # Update settings window bg to match
        t = self.parent.theme
        self.configure(bg=t["BG"])
        for w in self.winfo_children():
            self._recolor(w, t)

    def _recolor(self, widget, t):
        cls = widget.winfo_class()
        if cls in ("Frame",):
            try: widget.config(bg=t["BG"])
            except: pass
        elif cls == "Label":
            try: widget.config(bg=t["BG"])
            except: pass
        for child in widget.winfo_children():
            self._recolor(child, t)

    def _toggle_graph(self):
        self.parent.toggle_graph()
        is_on = self.parent.show_graph
        self._graph_var.set("on" if is_on else "off")
        self._graph_btn.config(bg=ACCENT_GREEN if is_on else ACCENT_RED)

# ── Main App ──────────────────────────────────────────────────────────────────

class Dashboard(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("System Dashboard")
        self.resizable(True, True)
        self.geometry("820x620")
        self.minsize(700, 520)

        # App state
        self.current_theme = "dark"
        self.theme = THEMES["dark"]
        self.show_graph = True
        self.configure(bg=self.theme["BG"])

        # Stat state
        self._net_prev = psutil.net_io_counters()
        self._disk_prev = psutil.disk_io_counters()
        self._prev_time = time.time()
        self._net_recv_hist = deque([0] * NET_HISTORY, maxlen=NET_HISTORY)
        self._net_sent_hist = deque([0] * NET_HISTORY, maxlen=NET_HISTORY)

        # Track all progress bars and cards for theme updates
        self._progress_bars = []
        self._cards = []

        self._build_ui()
        self._schedule_update()

    # ── Theme ─────────────────────────────────────────────────────────────────

    def apply_theme(self, name):
        self.current_theme = name
        self.theme = THEMES[name]
        t = self.theme
        self.configure(bg=t["BG"])
        self._hdr.config(bg=t["BG"])
        self._clock_lbl.config(bg=t["BG"], fg=t["MUTED"])
        self._title_lbl.config(bg=t["BG"], fg=t["TEXT"])
        self._gear_btn.config(bg=t["BG"], fg=t["MUTED"], activebackground=t["BG"])
        self._grid.config(bg=t["BG"])
        for card in self._cards:
            card.apply_theme(t)
        for pb in self._progress_bars:
            pb.apply_theme(t)

    # ── Graph toggle ──────────────────────────────────────────────────────────

    def toggle_graph(self):
        self.show_graph = not self.show_graph
        if self.show_graph:
            self._spark.pack(fill="x", pady=(10, 0))
        else:
            self._spark.pack_forget()

    # ── UI Construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        t = self.theme

        # Header
        self._hdr = tk.Frame(self, bg=t["BG"])
        self._hdr.pack(fill="x", padx=20, pady=(16, 8))
        self._title_lbl = tk.Label(
            self._hdr, text="⬡  SYSTEM DASHBOARD",
            bg=t["BG"], fg=t["TEXT"],
            font=("SF Pro Display", 14, "bold")
        )
        self._title_lbl.pack(side="left")

        self._gear_btn = tk.Button(
            self._hdr, text="⚙",
            bg=t["BG"], fg=t["MUTED"],
            font=("SF Pro Display", 16),
            relief="flat", cursor="hand2",
            activebackground=t["BG"],
            command=self._open_settings
        )
        self._gear_btn.pack(side="right")

        self._clock_lbl = tk.Label(
            self._hdr, text="",
            bg=t["BG"], fg=t["MUTED"],
            font=("SF Pro Display", 10)
        )
        self._clock_lbl.pack(side="right", padx=(0, 8))

        # Grid
        self._grid = tk.Frame(self, bg=t["BG"])
        self._grid.pack(fill="both", expand=True, padx=20, pady=(0, 20))
        self._grid.columnconfigure(0, weight=1)
        self._grid.columnconfigure(1, weight=1)

        self._cpu_card = self._build_cpu_card(self._grid)
        self._cpu_card.grid(row=0, column=0, sticky="nsew", padx=(0, 8), pady=(0, 8))

        self._ram_card = self._build_ram_card(self._grid)
        self._ram_card.grid(row=0, column=1, sticky="nsew", padx=(8, 0), pady=(0, 8))

        self._disk_card = self._build_disk_card(self._grid)
        self._disk_card.grid(row=1, column=0, sticky="nsew", padx=(0, 8), pady=(0, 8))

        self._power_card = self._build_power_card(self._grid)
        self._power_card.grid(row=1, column=1, sticky="nsew", padx=(8, 0), pady=(0, 8))

        self._grid.rowconfigure(2, weight=1)
        self._net_card = self._build_net_card(self._grid)
        self._net_card.grid(row=2, column=0, columnspan=2, sticky="nsew")

    def _open_settings(self):
        SettingsWindow(self)

    # ── CPU Card ──────────────────────────────────────────────────────────────

    def _build_cpu_card(self, parent):
        t = self.theme
        card = Card(parent, "CPU", accent=ACCENT_BLUE, theme=t)
        self._cards.append(card)
        body = tk.Frame(card, bg=t["CARD_BG"])
        body.pack(fill="both", expand=True, padx=14, pady=10)

        top = tk.Frame(body, bg=t["CARD_BG"])
        top.pack(fill="x")
        self._cpu_pct_lbl = tk.Label(top, text="0%", bg=t["CARD_BG"], fg=t["TEXT"],
                                     font=("SF Pro Display", 28, "bold"))
        self._cpu_pct_lbl.pack(side="left")
        self._cpu_freq_lbl = tk.Label(top, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                      font=("SF Pro Display", 10))
        self._cpu_freq_lbl.pack(side="right", anchor="s", pady=6)

        self._cpu_bar = ProgressBar(body, color=ACCENT_BLUE, theme=t)
        self._cpu_bar.pack(fill="x", pady=(6, 8))
        self._progress_bars.append(self._cpu_bar)

        cores = tk.Frame(body, bg=t["CARD_BG"])
        cores.pack(fill="x")
        count = psutil.cpu_count(logical=True)
        physical = psutil.cpu_count(logical=False)
        tk.Label(cores, text=f"{physical} cores  /  {count} threads",
                 bg=t["CARD_BG"], fg=t["MUTED"], font=("SF Pro Display", 9)).pack(side="left")
        self._cpu_temp_lbl = tk.Label(cores, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                      font=("SF Pro Display", 9))
        self._cpu_temp_lbl.pack(side="right")
        return card

    # ── RAM Card ──────────────────────────────────────────────────────────────

    def _build_ram_card(self, parent):
        t = self.theme
        card = Card(parent, "MEMORY", accent=ACCENT_PURP, theme=t)
        self._cards.append(card)
        body = tk.Frame(card, bg=t["CARD_BG"])
        body.pack(fill="both", expand=True, padx=14, pady=10)

        top = tk.Frame(body, bg=t["CARD_BG"])
        top.pack(fill="x")
        self._ram_pct_lbl = tk.Label(top, text="0%", bg=t["CARD_BG"], fg=t["TEXT"],
                                     font=("SF Pro Display", 28, "bold"))
        self._ram_pct_lbl.pack(side="left")
        self._ram_used_lbl = tk.Label(top, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                      font=("SF Pro Display", 10))
        self._ram_used_lbl.pack(side="right", anchor="s", pady=6)

        self._ram_bar = ProgressBar(body, color=ACCENT_PURP, theme=t)
        self._ram_bar.pack(fill="x", pady=(6, 8))
        self._progress_bars.append(self._ram_bar)

        self._ram_detail_lbl = tk.Label(body, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                        font=("SF Pro Display", 9))
        self._ram_detail_lbl.pack(anchor="w")
        return card

    # ── Disk Card ─────────────────────────────────────────────────────────────

    def _build_disk_card(self, parent):
        t = self.theme
        card = Card(parent, "STORAGE", accent=ACCENT_AMBER, theme=t)
        self._cards.append(card)
        body = tk.Frame(card, bg=t["CARD_BG"])
        body.pack(fill="both", expand=True, padx=14, pady=10)

        top = tk.Frame(body, bg=t["CARD_BG"])
        top.pack(fill="x")
        self._disk_pct_lbl = tk.Label(top, text="0%", bg=t["CARD_BG"], fg=t["TEXT"],
                                      font=("SF Pro Display", 28, "bold"))
        self._disk_pct_lbl.pack(side="left")
        self._disk_size_lbl = tk.Label(top, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                       font=("SF Pro Display", 10))
        self._disk_size_lbl.pack(side="right", anchor="s", pady=6)

        self._disk_bar = ProgressBar(body, color=ACCENT_AMBER, theme=t)
        self._disk_bar.pack(fill="x", pady=(6, 8))
        self._progress_bars.append(self._disk_bar)

        io = tk.Frame(body, bg=t["CARD_BG"])
        io.pack(fill="x")
        self._disk_read_lbl = tk.Label(io, text="↓ --", bg=t["CARD_BG"], fg=t["MUTED"],
                                       font=("SF Pro Display", 9))
        self._disk_read_lbl.pack(side="left")
        self._disk_write_lbl = tk.Label(io, text="↑ --", bg=t["CARD_BG"], fg=t["MUTED"],
                                        font=("SF Pro Display", 9))
        self._disk_write_lbl.pack(side="right")
        return card

    # ── Power Card ────────────────────────────────────────────────────────────

    def _build_power_card(self, parent):
        t = self.theme
        card = Card(parent, "POWER PROFILE", accent=ACCENT_GREEN, theme=t)
        self._cards.append(card)
        body = tk.Frame(card, bg=t["CARD_BG"])
        body.pack(fill="both", expand=True, padx=14, pady=10)

        self._power_lbl = tk.Label(body, text="—", bg=t["CARD_BG"], fg=ACCENT_GREEN,
                                   font=("SF Pro Display", 22, "bold"))
        self._power_lbl.pack(anchor="w", pady=(4, 0))
        self._power_dot = tk.Label(body, text="● active", bg=t["CARD_BG"], fg=t["MUTED"],
                                   font=("SF Pro Display", 9))
        self._power_dot.pack(anchor="w", pady=(4, 0))
        return card

    # ── Network Card ──────────────────────────────────────────────────────────

    def _build_net_card(self, parent):
        t = self.theme
        card = Card(parent, "NETWORK", accent=ACCENT_GREEN, theme=t)
        self._cards.append(card)
        body = tk.Frame(card, bg=t["CARD_BG"])
        body.pack(fill="both", expand=True, padx=14, pady=10)

        stats = tk.Frame(body, bg=t["CARD_BG"])
        stats.pack(fill="x")

        dl = tk.Frame(stats, bg=t["CARD_BG"])
        dl.pack(side="left", padx=(0, 30))
        tk.Label(dl, text="↓  DOWNLOAD", bg=t["CARD_BG"], fg=t["MUTED"],
                 font=("SF Pro Display", 9)).pack(anchor="w")
        self._net_dl_lbl = tk.Label(dl, text="0 B/s", bg=t["CARD_BG"], fg=ACCENT_GREEN,
                                    font=("SF Pro Display", 20, "bold"))
        self._net_dl_lbl.pack(anchor="w")

        ul = tk.Frame(stats, bg=t["CARD_BG"])
        ul.pack(side="left")
        tk.Label(ul, text="↑  UPLOAD", bg=t["CARD_BG"], fg=t["MUTED"],
                 font=("SF Pro Display", 9)).pack(anchor="w")
        self._net_ul_lbl = tk.Label(ul, text="0 B/s", bg=t["CARD_BG"], fg=ACCENT_BLUE,
                                    font=("SF Pro Display", 20, "bold"))
        self._net_ul_lbl.pack(anchor="w")

        totals = tk.Frame(stats, bg=t["CARD_BG"])
        totals.pack(side="right")
        self._net_total_lbl = tk.Label(totals, text="", bg=t["CARD_BG"], fg=t["MUTED"],
                                       font=("SF Pro Display", 9), justify="right")
        self._net_total_lbl.pack(anchor="e")

        self._spark = tk.Canvas(body, bg=t["CARD_BG"], highlightthickness=0, height=60)
        self._spark.pack(fill="x", pady=(10, 0))
        self._spark.bind("<Configure>", lambda e: self._draw_sparkline())

        return card

    # ── Sparkline ─────────────────────────────────────────────────────────────

    def _draw_sparkline(self):
        c = self._spark
        c.delete("all")
        w = c.winfo_width()
        h = c.winfo_height()
        if w < 2 or h < 2:
            return

        def draw_line(history, color):
            mx = max(max(history), 1)
            pts = []
            for i, v in enumerate(history):
                x = int(i * w / (NET_HISTORY - 1))
                y = h - int(v / mx * h)
                pts.append((x, y))
            if len(pts) > 1:
                flat = [coord for pt in pts for coord in pt]
                c.create_line(*flat, fill=color, width=1, smooth=True)

        draw_line(self._net_recv_hist, ACCENT_GREEN)
        draw_line(self._net_sent_hist, ACCENT_BLUE)

    # ── Data Collection ───────────────────────────────────────────────────────

    def _collect(self):
        now = time.time()
        elapsed = max(now - self._prev_time, 0.001)
        self._prev_time = now

        cpu_pct = psutil.cpu_percent()
        try:
            freq = psutil.cpu_freq()
            freq_str = f"{freq.current:.0f} MHz"
        except Exception:
            freq_str = ""
        try:
            temps = psutil.sensors_temperatures()
            temp_val = None
            for key in ("coretemp", "k10temp", "cpu_thermal", "acpitz"):
                if key in temps and temps[key]:
                    temp_val = temps[key][0].current
                    break
            temp_str = f"{temp_val:.0f}°C" if temp_val else ""
        except Exception:
            temp_str = ""

        ram = psutil.virtual_memory()

        disk = psutil.disk_usage("/")
        try:
            disk_io = psutil.disk_io_counters()
            read_rate  = (disk_io.read_bytes  - self._disk_prev.read_bytes)  / elapsed
            write_rate = (disk_io.write_bytes - self._disk_prev.write_bytes) / elapsed
            self._disk_prev = disk_io
        except Exception:
            read_rate = write_rate = 0

        net = psutil.net_io_counters()
        recv_rate = (net.bytes_recv - self._net_prev.bytes_recv) / elapsed
        sent_rate = (net.bytes_sent - self._net_prev.bytes_sent) / elapsed
        self._net_prev = net
        self._net_recv_hist.append(recv_rate)
        self._net_sent_hist.append(sent_rate)

        profile = get_power_profile()

        return {
            "cpu_pct": cpu_pct, "freq": freq_str, "temp": temp_str,
            "ram_pct": ram.percent,
            "ram_used": bytes_to_human(ram.used),
            "ram_total": bytes_to_human(ram.total),
            "ram_avail": bytes_to_human(ram.available),
            "disk_pct": disk.percent,
            "disk_used": bytes_to_human(disk.used),
            "disk_total": bytes_to_human(disk.total),
            "disk_read": bytes_to_human(read_rate) + "/s",
            "disk_write": bytes_to_human(write_rate) + "/s",
            "net_recv": bytes_to_human(recv_rate) + "/s",
            "net_sent": bytes_to_human(sent_rate) + "/s",
            "net_total_recv": bytes_to_human(net.bytes_recv),
            "net_total_sent": bytes_to_human(net.bytes_sent),
            "profile": profile,
        }

    # ── UI Update ─────────────────────────────────────────────────────────────

    def _update_ui(self, d):
        t = self.theme
        self._clock_lbl.config(text=time.strftime("%H:%M:%S"))

        pct = d["cpu_pct"]
        color = ACCENT_RED if pct > 80 else ACCENT_AMBER if pct > 50 else ACCENT_BLUE
        self._cpu_pct_lbl.config(text=f"{pct:.0f}%", fg=color)
        self._cpu_freq_lbl.config(text=d["freq"])
        self._cpu_bar.color = color
        self._cpu_bar.set(pct)
        self._cpu_temp_lbl.config(text=d["temp"])

        rpct = d["ram_pct"]
        rcolor = ACCENT_RED if rpct > 85 else ACCENT_AMBER if rpct > 65 else ACCENT_PURP
        self._ram_pct_lbl.config(text=f"{rpct:.0f}%", fg=rcolor)
        self._ram_used_lbl.config(text=f"{d['ram_used']} / {d['ram_total']}")
        self._ram_bar.color = rcolor
        self._ram_bar.set(rpct)
        self._ram_detail_lbl.config(text=f"Available: {d['ram_avail']}")

        dpct = d["disk_pct"]
        dcolor = ACCENT_RED if dpct > 90 else ACCENT_AMBER if dpct > 70 else ACCENT_AMBER
        self._disk_pct_lbl.config(text=f"{dpct:.0f}%", fg=dcolor)
        self._disk_size_lbl.config(text=f"{d['disk_used']} / {d['disk_total']}")
        self._disk_bar.color = dcolor
        self._disk_bar.set(dpct)
        self._disk_read_lbl.config(text=f"↓ {d['disk_read']}")
        self._disk_write_lbl.config(text=f"↑ {d['disk_write']}")

        pc = profile_color(d["profile"])
        self._power_lbl.config(text=d["profile"].replace("-", " ").title(), fg=pc)
        self._power_dot.config(fg=pc)

        self._net_dl_lbl.config(text=d["net_recv"])
        self._net_ul_lbl.config(text=d["net_sent"])
        self._net_total_lbl.config(
            text=f"Total ↓ {d['net_total_recv']}  ↑ {d['net_total_sent']}"
        )
        if self.show_graph:
            self._draw_sparkline()

    def _schedule_update(self):
        def _worker():
            data = self._collect()
            self.after(0, lambda: self._update_ui(data))
            self.after(REFRESH_MS, self._schedule_update)
        threading.Thread(target=_worker, daemon=True).start()

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app = Dashboard()
    app.mainloop()