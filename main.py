import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import argparse
import tarfile
from pathlib import Path
from tkinter import filedialog

import customtkinter as ctk

# (light, dark) palette: neutral grays + a calm blue accent
BG       = ("#F4F5F7", "#1B1C1F")
CARD     = ("#FFFFFF", "#25272B")
FIELD    = ("#FFFFFF", "#1F2023")
LINE     = ("#D5D9E0", "#363940")
TEXT     = ("#1D2025", "#E4E6EA")
SUB      = ("#5F6672", "#9AA1AD")
ACCENT   = ("#2F6DB5", "#4C8BD6")
ACCENT_H = ("#285C9A", "#3F78BC")
SOFT     = ("#E6E9EE", "#30333A")
SOFT_H   = ("#D9DDE4", "#3A3E46")
ERROR    = ("#B3261E", "#F2B8B5")
R = 6  # minimal corner radius

IS_WIN = sys.platform == "win32"
NOWIN = getattr(subprocess, "CREATE_NO_WINDOW", 0)  # hides console flash on Windows only
MONO = {"win32": "Consolas", "darwin": "Menlo"}.get(sys.platform, "DejaVu Sans Mono")
FONT_PATTERNS = ("*.ttf", "*.otf", "*.woff", "*.woff2", "*.svg", "*.eot")


IS_WIN = sys.platform == "win32"


def search_dirs():
    dirs = []
    if getattr(sys, "frozen", False):
        if hasattr(sys, "_MEIPASS"):                      # onefile / onedir
            dirs.append(Path(sys._MEIPASS))
        exe = Path(sys.executable).resolve().parent       # macOS .app layout
        dirs += [exe, exe.parent / "Resources", exe.parent / "Frameworks"]
    else:
        dirs.append(Path(__file__).resolve().parent)
    return dirs

def unpack_tools(archive):
    """macOS builds ship the Perl tools inside a tar.gz (PyInstaller would try to
    re-sign them as Mach-O and fail). Unpack once into a per-user cache."""
    st = archive.stat()
    base = Path.home() / ("Library/Caches" if sys.platform == "darwin" else ".cache") / "CLD-Tool"
    cache = base / f"tools-{st.st_size}-{int(st.st_mtime)}"

    def ready(d):
        return (d / "cld_extract").is_file() and (d / "cld_repack").is_file()

    if ready(cache):
        return cache
    try:
        base.mkdir(parents=True, exist_ok=True)
        tmp = Path(tempfile.mkdtemp(prefix="unpack_", dir=base))
        try:
            with tarfile.open(archive) as tf:
                tf.extractall(tmp, filter="data")
            for f in tmp.iterdir():
                f.chmod(0o755)
            try:
                tmp.rename(cache)
            except OSError:                       # another process unpacked first
                pass
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    except Exception:
        return None
    return cache if ready(cache) else None

def find_tool(name):
    """Returns the command prefix for 'cld_extract' / 'cld_repack', or None."""
    exe = name + (".exe" if IS_WIN else "")
    for d in search_dirs():
        p = d / "tools" / exe
        if p.is_file():
            if not IS_WIN and not os.access(p, os.X_OK):
                try:
                    p.chmod(p.stat().st_mode | 0o111)
                except OSError:
                    continue
            return [str(p)]
        arc = d / "tools" / "tools.tar.gz"          # macOS bundle layout
        if arc.is_file():
            folder = unpack_tools(arc)
            if folder:
                return [str(folder / name)]
    # Development fallback: run the .pl directly if Perl happens to be installed
    perl = shutil.which("perl")
    script = Path(__file__).resolve().parent / f"{name}.pl"
    if perl and script.is_file():
        return [perl, str(script)]
    return None


def absolute(p):
    return os.path.abspath(os.path.expanduser(p)) if p else ""

def extract_args(src, tpl, out):
    src, tpl, out = absolute(src), absolute(tpl), absolute(out)
    if not src:
        raise ValueError("Select a CLD file.")
    if not os.path.isfile(src):
        raise ValueError(f"CLD file not found: {src}")
    if tpl and not os.path.isfile(tpl):
        raise ValueError(f"Template CSV not found: {tpl}")
    out = out or str(Path(src).with_suffix(""))
    if tpl and os.path.normcase(os.path.realpath(os.path.join(out, "dialogue.csv"))) \
            == os.path.normcase(os.path.realpath(tpl)):
        raise ValueError("Output would overwrite the template. Pick another folder.")
    return (["--template", tpl] if tpl else []) + [src, out]


def repack_args(src, out, csv, img, font, no_img, no_font, face):
    src, out = absolute(src), absolute(out)
    csv, img, font = absolute(csv), absolute(img), absolute(font)
    face = (face or "").strip()
    if not src:
        raise ValueError("Select a source CLD file.")
    if not os.path.isfile(src):
        raise ValueError(f"Source CLD not found: {src}")
    if not src.lower().endswith(".cld"):
        raise ValueError("Source file must have a .cld extension.")
    if not out or not out.lower().endswith(".cld"):
        raise ValueError("Output file must have a .cld extension.")
    if os.path.normcase(os.path.realpath(src)) == os.path.normcase(os.path.realpath(out)):
        raise ValueError("Output must differ from the source file.")
    if face.lower() == "gamefont":
        raise ValueError("GameFont is reserved. Use another name.")
    if no_img and img:
        raise ValueError("--no-images cannot be combined with --images.")
    if no_font and font:
        raise ValueError("--no-font cannot be combined with --font.")
    for value, kind, check in ((csv, "CSV file", os.path.isfile),
                               (img, "Image folder", os.path.isdir),
                               (font, "Font file", os.path.isfile)):
        if value and not check(value):
            raise ValueError(f"{kind} not found: {value}")

    args = []
    if no_img:
        args.append("--no-images")
    if no_font:
        args.append("--no-font")
    if face:
        args += ["--font-face", face]
    args += [src, out]
    tail = [csv, img, font]          # positional order; empty strings fill gaps
    while tail and not tail[-1]:
        tail.pop()
    return args + tail

class PathRow(ctk.CTkFrame):
    def __init__(self, master, label, mode, filetypes=None, hint="", on_pick=None):
        super().__init__(master, fg_color="transparent")
        self.mode, self.filetypes, self.on_pick = mode, filetypes or [], on_pick
        self.var = ctk.StringVar()
        self.columnconfigure(1, weight=1)
        ctk.CTkLabel(self, text=label, width=92, anchor="w", text_color=TEXT).grid(
            row=0, column=0, padx=(0, 6))
        self.entry = ctk.CTkEntry(self, textvariable=self.var, placeholder_text=hint,
                                  height=30, corner_radius=R, fg_color=FIELD,
                                  border_color=LINE, text_color=TEXT)
        self.entry.grid(row=0, column=1, sticky="ew")
        self.btn = ctk.CTkButton(self, text="Browse", width=64, height=30, corner_radius=R,
                                 fg_color=SOFT, hover_color=SOFT_H, text_color=TEXT,
                                 command=self.pick)
        self.btn.grid(row=0, column=2, padx=(6, 0))

    def pick(self):
        if self.mode == "open":
            p = filedialog.askopenfilename(filetypes=self.filetypes)
        elif self.mode == "save":
            p = filedialog.asksaveasfilename(filetypes=self.filetypes, defaultextension=".cld")
        else:
            p = filedialog.askdirectory()
        if p:
            self.var.set(os.path.normpath(p))
            if self.on_pick:
                self.on_pick(p)

    def get(self):
        return self.var.get().strip()

    def enable(self, on):
        state = "normal" if on else "disabled"
        self.entry.configure(state=state)
        self.btn.configure(state=state)


class App(ctk.CTk):
    def __init__(self):
        ctk.set_appearance_mode("system")  # follows the OS light/dark theme live
        super().__init__(fg_color=BG)
        self.title("CLD Tool")
        self.geometry("580x610")
        self.minsize(520, 560)
        self.q = queue.Queue()
        self.busy = False

        tabs = ctk.CTkTabview(
            self, corner_radius=R, fg_color=CARD, border_width=1, border_color=LINE,
            segmented_button_fg_color=SOFT, segmented_button_selected_color=ACCENT,
            segmented_button_selected_hover_color=ACCENT_H,
            segmented_button_unselected_color=SOFT,
            segmented_button_unselected_hover_color=SOFT_H, text_color=TEXT)
        tabs.pack(fill="x", padx=12, pady=(12, 8))
        self.build_extract(tabs.add("Extract"))
        self.build_repack(tabs.add("Repack"))

        bar = ctk.CTkFrame(self, fg_color="transparent")
        bar.pack(fill="x", padx=14)
        self.status = ctk.CTkLabel(bar, text="", text_color=SUB, anchor="w")
        self.status.pack(side="left")
        ctk.CTkButton(bar, text="Clear log", width=80, height=24, corner_radius=R,
                      fg_color="transparent", hover_color=SOFT, text_color=SUB,
                      command=lambda: self.log.delete("1.0", "end")).pack(side="right")

        self.log = ctk.CTkTextbox(self, corner_radius=R, fg_color=FIELD, border_width=1,
                                  border_color=LINE, text_color=TEXT,
                                  font=ctk.CTkFont(family=MONO, size=12), wrap="word")
        self.log.pack(fill="both", expand=True, padx=12, pady=(4, 12))

        if find_tool("cld_extract") and find_tool("cld_repack"):
            self.set_status("Ready")
        else:
            self.set_status("Bundled tools not found.", error=True)
        self.after(50, self.poll)

    # ---------- Extract ----------
    def build_extract(self, tab):
        self.e_in = PathRow(tab, "CLD file", "open", [("CLD", "*.cld"), ("All files", "*")],
                            on_pick=self.fill_extract_out)
        self.e_tpl = PathRow(tab, "Template CSV", "open", [("CSV", "*.csv")],
                             hint="Optional: dialogue.csv from Translator.exe")
        self.e_out = PathRow(tab, "Output folder", "dir",
                             hint="Blank = folder next to the CLD file")
        for row in (self.e_in, self.e_tpl, self.e_out):
            row.pack(fill="x", padx=8, pady=3)
        self.b_ext = self.run_button(tab, "Extract", self.do_extract)

    def fill_extract_out(self, p):
        if not self.e_out.get():
            self.e_out.var.set(os.path.normpath(str(Path(p).with_suffix(""))))

    def do_extract(self):
        try:
            args = extract_args(self.e_in.get(), self.e_tpl.get(), self.e_out.get())
        except ValueError as e:
            return self.set_status(str(e), error=True)
        self.launch("cld_extract", args)

    # ---------- Repack ----------
    def build_repack(self, tab):
        self.r_in = PathRow(tab, "Source CLD", "open", [("CLD", "*.cld")],
                            on_pick=self.fill_repack_out)
        self.r_out = PathRow(tab, "Output CLD", "save", [("CLD", "*.cld")])
        self.r_csv = PathRow(tab, "CSV", "open", [("CSV", "*.csv")], hint="Optional")
        self.r_img = PathRow(tab, "Image folder", "dir", hint="Optional (PNG only)")
        self.r_font = PathRow(tab, "Font file", "open",
                              [("Font files", FONT_PATTERNS), ("All files", "*")], hint="Optional")
        for row in (self.r_in, self.r_out, self.r_csv, self.r_img, self.r_font):
            row.pack(fill="x", padx=8, pady=3)

        opt = ctk.CTkFrame(tab, fg_color="transparent")
        opt.pack(fill="x", padx=8, pady=(4, 0))
        self.no_img = ctk.CTkSwitch(opt, text="Remove images", text_color=TEXT,
                                    progress_color=ACCENT,
                                    command=lambda: self.r_img.enable(not self.no_img.get()))
        self.no_font = ctk.CTkSwitch(opt, text="Remove font", text_color=TEXT,
                                     progress_color=ACCENT,
                                     command=lambda: self.r_font.enable(not self.no_font.get()))
        self.no_img.pack(side="left", padx=(0, 16))
        self.no_font.pack(side="left")
        self.face = ctk.CTkEntry(opt, placeholder_text="fontFace (optional)", width=150,
                                 height=28, corner_radius=R, fg_color=FIELD,
                                 border_color=LINE, text_color=TEXT)
        self.face.pack(side="right")
        self.b_rep = self.run_button(tab, "Repack", self.do_repack)

    def fill_repack_out(self, p):
        if not self.r_out.get():
            self.r_out.var.set(os.path.normpath(
                str(Path(p).with_name(Path(p).stem + "_new.cld"))))


    def do_repack(self):
        try:
            args = repack_args(
                self.r_in.get(), self.r_out.get(), self.r_csv.get(),
                "" if self.no_img.get() else self.r_img.get(),
                "" if self.no_font.get() else self.r_font.get(),
                self.no_img.get(), self.no_font.get(), self.face.get())
        except ValueError as e:
            return self.set_status(str(e), error=True)
        self.launch("cld_repack", args)

    # ---------- Shared ----------
    def run_button(self, parent, text, command):
        b = ctk.CTkButton(parent, text=text, height=34, corner_radius=R, fg_color=ACCENT,
                          hover_color=ACCENT_H, text_color="#FFFFFF", command=command)
        b.pack(fill="x", padx=8, pady=(10, 6))
        return b

    def set_status(self, msg, error=False):
        self.status.configure(text=msg, text_color=ERROR if error else SUB)

    def launch(self, name, args):
        if self.busy:
            return
        tool = find_tool(name)
        if not tool:
            return self.set_status(f"Bundled tool missing: {name}", error=True)
        self.busy = True
        self.b_ext.configure(state="disabled")
        self.b_rep.configure(state="disabled")
        self.set_status("Running...")
        self.log.insert("end", "> " + " ".join([name, *args]) + "\n")
        threading.Thread(target=self.worker, args=(tool, args), daemon=True).start()

    def worker(self, tool, args):
        # Run in an empty temp dir so ./img and ./font are never picked up implicitly.
        tmp = tempfile.mkdtemp(prefix="cldtool_")
        try:
            proc = subprocess.Popen([*tool, *args], cwd=tmp,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    creationflags=NOWIN)
            for line in iter(proc.stdout.readline, b""):
                self.q.put(line.decode("utf-8", "replace"))
            self.q.put(proc.wait())
        except Exception as e:
            self.q.put(f"Error: {e}\n")
            self.q.put(-1)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def poll(self):
        try:
            while True:
                item = self.q.get_nowait()
                if isinstance(item, int):
                    self.busy = False
                    self.b_ext.configure(state="normal")
                    self.b_rep.configure(state="normal")
                    if item == 0:
                        self.set_status("Done")
                    else:
                        self.set_status(f"Failed (exit code {item})", error=True)
                    self.log.insert("end", "\n")
                else:
                    self.log.insert("end", item)
                self.log.see("end")
        except queue.Empty:
            pass
        self.after(50, self.poll)


def build_parser():
    p = argparse.ArgumentParser(
        prog="CLD-Tool",
        description="Extract and repack CLD files. Run without arguments to open the GUI.")
    sub = p.add_subparsers(dest="cmd", required=True, metavar="{extract,repack,gui}")

    e = sub.add_parser("extract", help="extract images, font and dialogue.csv from a CLD file")
    e.add_argument("input", help="input .cld file")
    e.add_argument("output", nargs="?", help="output folder (default: next to the CLD file)")
    e.add_argument("-t", "--template", help="dialogue.csv made by Translator.exe")

    r = sub.add_parser("repack", help="write edited CSV, images and font back into a CLD file")
    r.add_argument("source", help="source .cld file")
    r.add_argument("output", help="output .cld file (must differ from the source)")
    r.add_argument("--csv", help="edited dialogue.csv")
    r.add_argument("--images", help="folder with replacement PNG images")
    r.add_argument("--font", help="replacement font file")
    r.add_argument("--no-images", action="store_true", help="empty imgFiles")
    r.add_argument("--no-font", action="store_true", help="remove the embedded font")
    r.add_argument("--font-face", help="override fontFace")

    sub.add_parser("gui", help="open the GUI")
    return p

def run_cli(argv):
    parser = build_parser()
    ns = parser.parse_args(argv)
    if ns.cmd == "gui":
        return run_gui()
    try:
        if ns.cmd == "extract":
            name, args = "cld_extract", extract_args(ns.input, ns.template, ns.output)
        else:
            name, args = "cld_repack", repack_args(
                ns.source, ns.output, ns.csv, ns.images, ns.font,
                ns.no_images, ns.no_font, ns.font_face)
    except ValueError as e:
        parser.error(str(e))                     # prints usage + message, exit code 2
    tool = find_tool(name)
    if not tool:
        print(f"Bundled tool missing: {name}", file=sys.stderr)
        return 1
    # Empty temp cwd so ./img and ./font are never picked up implicitly.
    with tempfile.TemporaryDirectory(prefix="cldtool_") as tmp:
        return subprocess.run([*tool, *args], cwd=tmp).returncode


def run_gui():
    App().mainloop()
    return 0


def windows_exe_kind():
    """'cli' / 'gui' for the frozen Windows builds, None everywhere else."""
    if IS_WIN and getattr(sys, "frozen", False):
                return "cli" if "-cli" in Path(sys.executable).stem.lower() else "gui"
    return None


if __name__ == "__main__":
    argv = [a for a in sys.argv[1:] if not a.startswith("-psn_")]   # macOS launch arg
    kind = windows_exe_kind()
    if kind == "gui":                 # windowed exe has no console: always open the GUI
        sys.exit(run_gui())
    if kind == "cli":                 # console exe: never open the GUI by default
        sys.exit(run_cli(argv or ["--help"]))
    sys.exit(run_cli(argv) if argv else run_gui())
