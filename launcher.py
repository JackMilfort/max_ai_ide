# launcher.py
"""Dedicated entrypoint for the standalone Windows portable launcher.

Handles:
- Immediate GUI splash screen creation using tkinter.
- Suppressing console stream crashes in windowed GUI mode via NullWriter.
- Spawning system tray icon via pystray and Pillow (lazy-loaded).
- Auto-opening default browser pointing to the running backend.
- Launching the FastAPI server (importing and running app.py).
"""
import os
import sys
import threading
import time
import webbrowser

# Auto-updater (silent, background)
try:
    from src.auto_updater import start_background_updater, check_applied_on_startup
except ImportError:
    def start_background_updater(): pass
    def check_applied_on_startup(): return None

# Define a dummy NullWriter to suppress standard stream crashes (isatty etc.) in GUI mode
class NullWriter:
    def write(self, text):
        pass
    def flush(self):
        pass
    def isatty(self):
        return False

if sys.stdout is None:
    sys.stdout = NullWriter()
if sys.stderr is None:
    sys.stderr = NullWriter()


splash_root = None

# If running from a frozen PyInstaller bundle, launch the splash screen IMMEDIATELY
if getattr(sys, 'frozen', False):
    import subprocess
    import tkinter as tk

    # Auto-Update Executable Swap Logic
    # If MAX.new was downloaded by the background updater, replace ourselves
    _exe_path = sys.executable
    _exe_dir = os.path.dirname(_exe_path)
    _new_exe = os.path.join(_exe_dir, "MAX.new")
    _old_exe = os.path.join(_exe_dir, "MAX.old")

    # Clean up previous old executable if it exists
    if os.path.exists(_old_exe):
        try: os.remove(_old_exe)
        except Exception: pass

    # Swap and restart if update is pending
    if os.path.exists(_new_exe):
        try:
            os.rename(_exe_path, _old_exe)  # Rename currently running file (Windows allows this!)
            os.rename(_new_exe, _exe_path)  # Put the new version in place
            # Start the new version and exit immediately
            subprocess.Popen([_exe_path] + sys.argv[1:])
            os._exit(0)
        except Exception:
            pass # If swap fails, just launch the old version as normal


    def show_splash_instantly():
        global splash_root
        try:
            splash_root = tk.Tk()
            splash_root.title("MAX")
            splash_root.overrideredirect(True)
            splash_root.configure(bg="#1a1c23")

            # Accented borders
            splash_root.config(highlightbackground="#e06c75", highlightcolor="#e06c75", highlightthickness=1)

            w, h = 360, 160
            ws = splash_root.winfo_screenwidth()
            hs = splash_root.winfo_screenheight()
            x = (ws - w) // 2
            y = (hs - h) // 2
            splash_root.geometry(f"{w}x{h}+{x}+{y}")

            tk.Label(splash_root, text="⛵ MAX", font=("Segoe UI", 22, "bold"), bg="#1a1c23", fg="#e06c75").pack(pady=(22, 2))
            tk.Label(splash_root, text="Launching background services...", font=("Segoe UI", 10), bg="#1a1c23", fg="#d1d4e0").pack(pady=2)
            tk.Label(splash_root, text="Please wait, this will take a few seconds.", font=("Segoe UI", 8, "italic"), bg="#1a1c23", fg="#5c6370").pack(pady=(12, 0))

            splash_root.attributes("-topmost", True)
            splash_root.mainloop()
        except Exception:
            pass

    # Launch the GUI splash screen immediately on a background thread
    threading.Thread(target=show_splash_instantly, daemon=True).start()


def create_tray_image():
    # Load our custom 192x192 PNG icon for MAX
    from PIL import Image, ImageDraw
    import sys
    try:
        if getattr(sys, 'frozen', False):
            base_dir = sys._MEIPASS
        else:
            base_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(base_dir, "static", "icons", "icon-192.png")
        if os.path.exists(icon_path):
            return Image.open(icon_path)
    except Exception:
        pass
    
    # Fallback to a simple drawn shape
    image = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    dc = ImageDraw.Draw(image)
    dc.ellipse([8, 8, 56, 56], fill=(30, 144, 255, 255))
    return image


def on_open_browser(icon, item, url):
    try:
        import webview
        if webview.windows:
            webview.windows[0].restore()
            webview.windows[0].show()
    except Exception:
        pass


def on_exit(icon, item):
    icon.stop()
    os._exit(0)


def setup_system_tray(url):
    try:
        import pystray
        icon_img = create_tray_image()
        menu = (
            pystray.MenuItem('Open MAX', lambda icon, item: on_open_browser(icon, item, url), default=True),
            pystray.MenuItem('Exit', on_exit)
        )
        tray_icon = pystray.Icon(
            "MAX",
            icon_img,
            "MAX",
            menu
        )
        tray_icon.run()
    except Exception:
        pass


def open_browser(url):
    # Allow uvicorn and app lifecycles to complete warmups
    time.sleep(3.5)

    # Safely close the splash screen
    try:
        global splash_root
        if splash_root:
            splash_root.after(0, splash_root.destroy)
    except Exception:
        pass

    try:
        import webview
        webview.create_window("MAX", url, width=1200, height=800)
        webview.start(private_mode=False) # Keep local storage
    except Exception:
        import webbrowser
        webbrowser.open(url)
    
    os._exit(0)



if __name__ == "__main__":
    import uvicorn
    # Verificar si en ESTE inicio se aplicó una actualización automática
    applied_version = check_applied_on_startup()

    # Import the FastAPI app from app.py
    from app import app

    bind_host = os.getenv("APP_BIND", "127.0.0.1")
    bind_port = int(os.getenv("APP_PORT", "7000"))
    url = f"http://{bind_host}:{bind_port}"

    if getattr(sys, 'frozen', False):
        # Start uvicorn server in a background thread
        threading.Thread(target=uvicorn.run, args=(app,), kwargs={"host": bind_host, "port": bind_port, "log_level": "info"}, daemon=True).start()
        # Start system tray manager thread
        threading.Thread(target=setup_system_tray, args=(url,), daemon=True).start()
        # Start the silent background auto-updater
        threading.Thread(target=start_background_updater, daemon=True).start()
        
        # Start the native window on the main thread (blocks until window is closed)
        open_browser(url)
    else:
        # Development mode
        uvicorn.run(app, host=bind_host, port=bind_port, log_level="info")

