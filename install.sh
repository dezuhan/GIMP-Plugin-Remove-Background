#!/usr/bin/env bash
# GIMP AI Plugins — Shared Engine Setup
# Creates ~/.gimp-plugin-shared-venv/venv used by all AI plugins (remove-bg, smart-select).
# Run this ONCE. Then install each plugin by copying its files.
set -e

INSTALL_DIR="$HOME/.gimp-plugin-shared-venv"
VENV_DIR="$INSTALL_DIR/venv"

echo "============================================"
echo " GIMP AI Plugins — Shared Engine Setup"
echo "============================================"

# 1. Check NVIDIA driver
if command -v nvidia-smi &> /dev/null; then
    echo ""
    echo "[✓] NVIDIA driver detected:"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    echo ""
    echo "[!] nvidia-smi not found. GPU features may not work."
    echo "    Install NVIDIA driver: sudo apt install nvidia-driver-<version>"
fi

# 2. Ensure python3-venv is available
if ! python3 -c "import venv" &> /dev/null; then
    echo ""
    echo "[→] Installing python3-venv..."
    sudo apt update && sudo apt install -y python3-venv
fi

# 3. Create or reuse venv
if [ -d "$VENV_DIR" ]; then
    echo ""
    echo "[✓] Venv already exists, updating packages..."
else
    echo ""
    echo "[→] Creating Python venv at $VENV_DIR..."
    mkdir -p "$INSTALL_DIR"
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install "onnxruntime-gpu" "rembg[gpu]" pillow "numpy>=2.0,<2.5"
# Workaround: onnxruntime-gpu may link against CUDA 13, but venv has CUDA 12 libs.
# CUDA runtime is backward-compatible, so symlink 13 → 12.
CUDA_LIB=$(find "$VENV_DIR" -path "*/cuda_runtime/lib" -type d 2>/dev/null | head -1)
if [ -n "$CUDA_LIB" ] && [ -f "$CUDA_LIB/libcudart.so.12" ] && [ ! -f "$CUDA_LIB/libcudart.so.13" ]; then
    ln -sf libcudart.so.12 "$CUDA_LIB/libcudart.so.13"
    echo "[✓] CUDA runtime symlinked"
fi
deactivate

# 4. Grant Flatpak D-Bus permission
if command -v flatpak &> /dev/null && flatpak info org.gimp.GIMP &> /dev/null; then
    echo ""
    echo "[→] Granting Flatpak host access permission..."
    flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP
fi

echo ""
echo "============================================"
echo " Shared engine ready at: $INSTALL_DIR"
echo " Now install the plugins you want:"
echo ""
echo "  Remove Background:"
echo "    mkdir -p ~/.config/GIMP/3.2/plug-ins/remove-background"
echo "    cp remove-background.py run_worker.sh bg_remove_worker.py \\"
echo "       ~/.config/GIMP/3.2/plug-ins/remove-background/"
echo "    chmod +x ~/.config/GIMP/3.2/plug-ins/remove-background/*.py"
echo "    chmod +x ~/.config/GIMP/3.2/plug-ins/remove-background/*.sh"
echo ""
echo "  Smart Object Selection:"
echo "    mkdir -p ~/.config/GIMP/3.2/plug-ins/smart-object-selection"
echo "    cp smart-object-selection.py run_worker.sh bg_remove_worker.py \\"
echo "       ~/.config/GIMP/3.2/plug-ins/smart-object-selection/"
echo "    chmod +x ~/.config/GIMP/3.2/plug-ins/smart-object-selection/*.py"
echo ""
echo "  AI Upscaler (needs extra step — see its README):"
echo "    mkdir -p ~/.config/GIMP/3.2/plug-ins/ai-upscaler/bin"
echo "    # Download realesrgan-ncnn-vulkan into bin/"
echo "    cp ai-upscaler.py run_upscaler.sh \\"
echo "       ~/.config/GIMP/3.2/plug-ins/ai-upscaler/"
echo ""
echo " Restart GIMP after installing plugins."
echo "============================================"
