#!/usr/bin/env python3
"""
GIMP 3.2 plugin: Remove Background
Cross-platform: Linux, Windows, macOS.
AI background removal via rembg + ONNX Runtime with CUDA.
"""
import gi
gi.require_version('Gimp', '3.0')
gi.require_version('GimpUi', '3.0')
from gi.repository import Gimp, GimpUi, GLib, Gio, GObject

import os
import shutil
import subprocess
import sys
import tempfile
import time

PLUGIN_DIR = os.path.dirname(os.path.abspath(__file__))
IS_FLATPAK = os.path.exists("/.flatpak-info")
IS_WINDOWS = sys.platform == "win32"

_BASH_EXE = None  # cached result of _find_bash()


def _find_bash():
    """Locate bash.exe on Windows (Git Bash / MSYS2)."""
    global _BASH_EXE
    if _BASH_EXE is not None:
        return _BASH_EXE
    bash = shutil.which("bash")
    if bash:
        _BASH_EXE = bash
        return _BASH_EXE
    for candidate in [
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files (x86)\Git\bin\bash.exe",
        r"C:\Git\bin\bash.exe",
        r"C:\msys64\usr\bin\bash.exe",
    ]:
        if os.path.exists(candidate):
            _BASH_EXE = candidate
            return _BASH_EXE
    _BASH_EXE = "bash"  # last-resort fallback
    return _BASH_EXE


def _build_command(script, args):
    """Build the subprocess command, handling Flatpak sandbox and Windows."""
    if IS_FLATPAK:
        return ["flatpak-spawn", "--host", script] + args
    if IS_WINDOWS:
        return [_find_bash(), script] + args
    return [script] + args


def _run_worker_with_progress(title, args):
    script = os.path.join(PLUGIN_DIR, "run_worker.sh")
    Gimp.progress_init(title)
    proc = subprocess.Popen(
        _build_command(script, args),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    while proc.poll() is None:
        Gimp.progress_pulse()
        time.sleep(0.12)
    stdout, stderr = proc.communicate()
    Gimp.progress_end()
    return proc.returncode, stdout, stderr


def _(s):
    return s


class RemoveBackgroundGPU(Gimp.PlugIn):

    def do_query_procedures(self):
        return ["plug-in-remove-bg-gpu"]

    def do_create_procedure(self, name):
        procedure = Gimp.ImageProcedure.new(
            self, name, Gimp.PDBProcType.PLUGIN, self.run, None
        )
        procedure.set_image_types("*")
        procedure.set_sensitivity_mask(Gimp.ProcedureSensitivityMask.DRAWABLE)
        procedure.set_menu_label(_("Remove Background"))
        procedure.add_menu_path("<Image>/Filters/Enhance")
        procedure.set_documentation(
            _("Remove background using AI (rembg) with NVIDIA CUDA"),
            _("Exports the active layer, runs rembg with high-accuracy "
              "alpha matting and post-processing, and imports the cutout "
              "back as a new layer with alpha."),
            name,
        )
        procedure.set_attribution("Dzuhan", "Dzuhan", "2026")
        return procedure

    def run(self, procedure, run_mode, image, drawables, config, data):
        if not drawables:
            Gimp.message("No active layer selected.")
            return procedure.new_return_values(
                Gimp.PDBStatusType.CALLING_ERROR, GLib.Error())

        drawable = drawables[0]

        Gimp.context_push()
        image.undo_group_start()

        try:
            tmp_dir = tempfile.mkdtemp(prefix="gimp-bg-remove-")
            in_path = os.path.join(tmp_dir, "input.png")
            out_path = os.path.join(tmp_dir, "output.png")

            # Export active layer only (not whole project)
            tmp_img = Gimp.Image.new(drawable.get_width(), drawable.get_height(), Gimp.ImageBaseType.RGB)
            tmp_layer = Gimp.Layer.new_from_drawable(drawable, tmp_img)
            tmp_img.insert_layer(tmp_layer, None, 0)
            in_file = Gio.File.new_for_path(in_path)
            Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, tmp_img, in_file, None)
            tmp_img.delete()

            rc, stdout, stderr = _run_worker_with_progress(
                "Removing background with AI...",
                [in_path, out_path, "high"]
            )
            if rc != 0 or not os.path.exists(out_path):
                Gimp.message("Background removal failed:\n" + (stderr or "unknown error"))
                return procedure.new_return_values(
                    Gimp.PDBStatusType.EXECUTION_ERROR, GLib.Error())

            out_file = Gio.File.new_for_path(out_path)
            loaded_img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, out_file)
            loaded_layer = loaded_img.get_layers()[0]

            new_layer = Gimp.Layer.new_from_drawable(loaded_layer, image)
            new_layer.set_name(drawable.get_name() + " (bg removed)")
            image.insert_layer(new_layer, None, -1)

            loaded_img.delete()
            Gimp.displays_flush()

        finally:
            image.undo_group_end()
            Gimp.context_pop()

        return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())


Gimp.main(RemoveBackgroundGPU.__gtype__, __import__("sys").argv)
