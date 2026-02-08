#!/usr/bin/env python3
"""
xhisper Toggle Button
A simple floating toggle button for xhisper dictation.
Works on any desktop including COSMIC/Wayland.
"""

import gi
import subprocess
import sys
from pathlib import Path

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Gdk

XHISPER_DIR = Path(__file__).parent
LOGFILE = Path("/tmp/xhisper.log")

class XhisperToggle:
    def __init__(self):
        self.current_mode = "auto"
        self.recording = False
        self.first_run = True

        # Create the window
        self.window = Gtk.Window(
            title="xhisper",
            type=Gtk.WindowType.TOPLEVEL,
            decorated=False,
            resizable=False,
            skip_taskbar_hint=False,
            skip_pager_hint=False
        )
        self.window.set_keep_above(True)
        self.window.stick()  # Show on all workspaces

        # Set initial size and position
        self.window.set_default_size(120, 40)
        self.window.set_position(Gtk.WindowPosition.CENTER)

        # Create button
        self.button = Gtk.Button(label="🎤 Ready")
        self.button.get_style_context().add_class("xhisper-button")
        self.button.connect("clicked", self.on_button_click)
        self.window.add(self.button)

        # Add CSS styling
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            .xhisper-button {
                font-size: 14px;
                font-weight: bold;
                border-radius: 8px;
                padding: 8px 16px;
            }
            .recording {
                background: #dc3c3c;
                color: white;
            }
            .idle {
                background: #32b478;
                color: white;
            }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Right-click menu
        self.window.connect("button-press-event", self.on_button_press)

        # Update initial state
        self.update_button()

        # Check recording state periodically
        GLib.timeout_add(500, self.check_recording_state)

        self.window.show_all()

    def update_button(self):
        """Update button appearance based on state"""
        context = self.button.get_style_context()

        if self.recording:
            self.button.set_label("⏹ Stop")
            context.remove_class("idle")
            context.add_class("recording")
            self.window.set_title("xhisper - Recording")
        else:
            mode_label = self.current_mode.capitalize()
            self.button.set_label(f"🎤 {mode_label}")
            context.remove_class("recording")
            context.add_class("idle")
            self.window.set_title(f"xhisper - {mode_label}")

    def check_recording_state(self):
        """Check if pw-record is running for xhisper"""
        try:
            result = subprocess.run(
                ["pgrep", "-f", "pw-record.*xhisper.wav"],
                capture_output=True,
                text=True
            )
            was_recording = self.recording
            self.recording = result.returncode == 0

            if was_recording != self.recording or self.first_run:
                self.update_button()
                self.first_run = False
        except Exception:
            pass

        return True

    def toggle_recording(self):
        """Toggle recording state"""
        try:
            cmd = [str(XHISPER_DIR / "xhisper.sh"), "--local"]
            if self.current_mode != "auto":
                cmd.append(f"--mode={self.current_mode}")

            subprocess.Popen(
                cmd,
                cwd=str(XHISPER_DIR),
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception as e:
            print(f"Error: {e}")

    def set_mode(self, mode):
        """Set the current mode"""
        self.current_mode = mode
        self.update_button()

    def on_button_click(self, button):
        """Handle button click"""
        self.toggle_recording()

    def on_button_press(self, window, event):
        """Handle right-click for menu"""
        if event.button == 3:  # Right click
            menu = Gtk.Menu()

            # Recording toggle
            record_label = "Stop Recording" if self.recording else "Start Recording"
            record_item = Gtk.MenuItem(label=record_label)
            record_item.connect("activate", lambda w: self.toggle_recording())
            menu.append(record_item)

            menu.append(Gtk.SeparatorMenuItem())

            # Mode submenu
            mode_item = Gtk.MenuItem(label="Mode")
            mode_menu = Gtk.Menu()

            modes = [
                ("Auto", "auto"),
                ("Standard", "standard"),
                ("Command", "command"),
                ("Email", "email"),
            ]

            for label, mode in modes:
                item = Gtk.MenuItem(label=label)
                if mode == self.current_mode:
                    item.set_label(f"● {label}")
                item.connect("activate", lambda w, m=mode: self.set_mode(m))
                mode_menu.append(item)

            mode_item.set_submenu(mode_menu)
            menu.append(mode_item)

            menu.append(Gtk.SeparatorMenuItem())

            # View log
            log_item = Gtk.MenuItem(label="View Log")
            log_item.connect("activate", self.view_log)
            menu.append(log_item)

            # Quit
            quit_item = Gtk.MenuItem(label="Quit")
            quit_item.connect("activate", self.quit)
            menu.append(quit_item)

            menu.show_all()
            menu.popup_at_pointer(None)
            return True
        return False

    def view_log(self, widget):
        """Show log file"""
        if LOGFILE.exists():
            subprocess.Popen(["xdg-open", str(LOGFILE)])

    def quit(self, widget):
        """Quit"""
        Gtk.main_quit()
        sys.exit(0)

def main():
    import signal
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    app = XhisperToggle()
    Gtk.main()

if __name__ == "__main__":
    main()
