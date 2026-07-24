# Remove Background for GIMP 3.2

AI-powered background removal using [rembg](https://github.com/danielgatis/rembg) + ONNX Runtime with GPU acceleration. Cross-platform: Linux, Windows, macOS.

## Requirements

- GIMP 3.2+
- NVIDIA GPU (CUDA) on Linux/Windows, Apple Silicon on macOS
- Python 3.10+

## Install

### Linux / macOS

```bash
chmod +x install.sh && ./install.sh
```

### Windows

Install [Git Bash](https://git-scm.com/downloads/win), right-click the plugin folder → **Git Bash Here**, then run:

```bash
chmod +x install.sh && ./install.sh
```

This creates the shared Python environment at `~/.gimp-plugin-shared-venv/venv`, installs all dependencies, grants Flatpak permissions, and copies the plugin to the correct GIMP folder.

### Manual

```bash
# 1. Create venv and install dependencies
python3 -m venv ~/.gimp-plugin-shared-venv/venv
source ~/.gimp-plugin-shared-venv/venv/bin/activate
pip install onnxruntime-gpu rembg[gpu] pillow
deactivate

# 2. Copy plugin files
mkdir -p ~/.config/GIMP/3.2/plug-ins/remove-background
cp remove-background.py run_worker.sh bg_remove_worker.py \
   ~/.config/GIMP/3.2/plug-ins/remove-background/
chmod +x ~/.config/GIMP/3.2/plug-ins/remove-background/remove-background.py
chmod +x ~/.config/GIMP/3.2/plug-ins/remove-background/run_worker.sh

# 3. Flatpak only
flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP
```

## Usage

1. Open an image in GIMP
2. Select a layer
3. **Filters > Enhance > Remove Background**
4. New layer `[name] (bg removed)` appears with transparent background

First run downloads the AI model (~176 MB). Subsequent runs use the cached model.

## How it works

```
Layer → Export PNG → rembg (onnxruntime-gpu + CUDA) → Cutout PNG → New layer
```

On Flatpak GIMP, `flatpak-spawn --host` escapes the sandbox to reach the host GPU.

## Troubleshooting

**Plugin not in menu:** `chmod +x ~/.config/GIMP/3.2/plug-ins/remove-background/*.py`

**ModuleNotFoundError: onnxruntime:** re-run `install.sh`

**CUDA not detected:** verify `nvidia-smi`, re-run `install.sh`

## Related Plugins

- [Smart Object Selection](https://github.com/dezuhan/GIMP-Plugin-Smart-Object-Selection) — AI-powered object selection tool
- [AI Upscaler](https://github.com/dezuhan/GIMP-Plugin-AI-Upscaler) — Real-ESRGAN upscaling

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).

## Support

If this plugin helps your workflow, consider donating to support further development.

[Support on Ko-fi](https://ko-fi.com/dezuhan)
