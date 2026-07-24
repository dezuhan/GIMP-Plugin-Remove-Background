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
