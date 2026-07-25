# Remove Background for GIMP 3.2

AI-powered background removal using [rembg](https://github.com/danielgatis/rembg) + ONNX Runtime with GPU acceleration. Cross-platform: Linux, Windows, macOS.

## Requirements

- GIMP 3.2+
- Python 3.10+ with `python3-venv`
- **GPU (optional):** see [Hardware / Provider Mapping](#hardware--provider-mapping) below

## Dependencies

### Direct (pip-installed by `install.sh`)

| Package | Required | Size | Notes |
|---------|:--------:|------|-------|
| `onnxruntime-gpu` | NVIDIA only | ~300 MB | CUDA acceleration (Linux/Windows) |
| `onnxruntime-directml` | Windows GPU | ~150 MB | AMD, Intel, NVIDIA via DirectML |
| `onnxruntime-silicon` | Apple only | ~50 MB | CoreML acceleration (M-series) |
| `onnxruntime` (CPU) | Fallback | ~30 MB | Universal CPU — much smaller |
| `rembg` | Required | ~10 MB | AI background removal engine |
| `rembg[gpu]` | With CUDA | — | Meta-extra for GPU-enabled rembg |
| `pillow` | Required | ~5 MB | Image I/O |
| `numpy>=2.0,<2.5` | Required | ~20 MB | Array computation |

Only one `onnxruntime-*` package is installed — `install.sh` auto-detects your hardware.

### Sub-dependencies (pulled automatically by `rembg`)

| Package | Size | Purpose |
|---------|------|---------|
| `opencv-python-headless` | ~25 MB | Image processing, alpha matting |
| `scikit-image` | ~20 MB | Image filtering |
| `scipy` | ~25 MB | Scientific computation |
| `pymatting` | ~5 MB | Alpha matting algorithm |
| `pooch` | ~1 MB | Model download manager |
| `onnx` / `protobuf` | ~5 MB | ONNX model parsing |
| `huggingface_hub` | ~10 MB | Model hub access |

**Total install size**: ~200–500 MB (package-dependent). First run downloads the AI model (~176 MB) and caches it.

### Hardware / Provider Mapping

| Hardware | Package Installed | Execution Provider |
|----------|------------------|-------------------|
| NVIDIA Linux | `onnxruntime-gpu` | `CUDAExecutionProvider` |
| NVIDIA Windows | `onnxruntime-directml` | `DmlExecutionProvider` |
| AMD Windows | `onnxruntime-directml` | `DmlExecutionProvider` |
| AMD Linux | `onnxruntime` (CPU) | `CPUExecutionProvider` |
| Intel Arc/iGPU Windows | `onnxruntime-directml` | `DmlExecutionProvider` |
| Intel iGPU Linux | `onnxruntime` (CPU) | `CPUExecutionProvider` |
| Apple Silicon | `onnxruntime-silicon` | `CoreMLExecutionProvider` |
| CPU-only | `onnxruntime` (CPU) | `CPUExecutionProvider` |

> **Windows NVIDIA note:** install.sh defaults to DirectML (zero-config) instead of CUDA to avoid requiring a separate CUDA Toolkit installation. Falling back to CPU is always automatic.

## Install

### Automatic (recommended)

`install.sh` detects your GPU and installs the correct ONNX Runtime package automatically.

**Linux / macOS:**
```bash
chmod +x install.sh && ./install.sh
```

**Windows:** Install [Git Bash](https://git-scm.com/downloads/win), right-click the plugin folder → **Git Bash Here**, then:
```bash
chmod +x install.sh && ./install.sh
```

---

### Manual Install

Pick the `onnxruntime-*` package for your hardware (see [Hardware / Provider Mapping](#hardware--provider-mapping)).

#### Linux / macOS

```bash
# 1. Install system dependencies (if missing)
#    Debian/Ubuntu:
sudo apt install python3 python3-venv
#    macOS:
brew install python3

# 2. Create shared venv
python3 -m venv ~/.gimp-plugin-shared-venv/venv

# 3. Install packages (pick ONE onnxruntime package for your GPU)
source ~/.gimp-plugin-shared-venv/venv/bin/activate
pip install --upgrade pip

#    NVIDIA GPU:
pip install onnxruntime-gpu rembg[gpu] pillow "numpy>=2.0,<2.5"

#    Apple Silicon:
pip install onnxruntime-silicon rembg pillow "numpy>=2.0,<2.5"

#    CPU / AMD Linux / Intel Linux:
pip install onnxruntime rembg pillow "numpy>=2.0,<2.5"

deactivate

# 4. Copy plugin files
PLUGINS=~/.config/GIMP/3.2/plug-ins/remove-background
mkdir -p "$PLUGINS"
cp remove-background.py run_worker.sh bg_remove_worker.py "$PLUGINS/"
chmod +x "$PLUGINS/remove-background.py"
chmod +x "$PLUGINS/run_worker.sh"

# 5. Flatpak only — grant host access
flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP

# 6. Restart GIMP → Filters → Enhance → Remove Background
```

#### Windows

Run all commands in **Git Bash**:

```bash
# 1. Install Python 3.10+ from https://python.org/downloads/
#    Check "Add Python to PATH" during install.
#    Verify:
py --version

# 2. Create shared venv
mkdir -p ~/.gimp-plugin-shared-venv
py -m venv ~/.gimp-plugin-shared-venv/venv

# 3. Install packages (pick ONE onnxruntime package for your GPU)
source ~/.gimp-plugin-shared-venv/venv/Scripts/activate
pip install --upgrade pip

#    NVIDIA / AMD / Intel GPU (DirectML):
pip install onnxruntime-directml rembg pillow "numpy>=2.0,<2.5"

#    CPU only:
pip install onnxruntime rembg pillow "numpy>=2.0,<2.5"

deactivate

# 4. Copy plugin files
PLUGINS="$APPDATA/GIMP/3.2/plug-ins/remove-background"
PLUGINS="$(echo "$PLUGINS" | sed 's|\\\\|/|g' | sed 's|C:|/c|')"
mkdir -p "$PLUGINS"
cp remove-background.py run_worker.sh bg_remove_worker.py "$PLUGINS/"

# 5. Restart GIMP → Filters → Enhance → Remove Background
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
