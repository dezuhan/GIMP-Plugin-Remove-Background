#!/usr/bin/env bash
# Shared engine setup for GIMP AI plugins.
# Detects GPU and installs the correct ONNX Runtime package.
# Run this ONCE. Works on Linux, macOS, Windows (Git Bash).
set -e

# --- GPU detection ---
detect_gpu() {
    case "$(uname -s)" in
        Linux*)
            if command -v nvidia-smi &> /dev/null; then
                echo "nvidia"
            elif [ -e /dev/kfd ] && (command -v rocminfo &> /dev/null || command -v rocm-smi &> /dev/null); then
                echo "amd"
            else
                echo "cpu"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            local gpu_info
            gpu_info=$(wmic path win32_VideoController get name 2>/dev/null | tr '[:upper:]' '[:lower:]')
            if echo "$gpu_info" | grep -qi "nvidia"; then
                echo "nvidia"
            elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
                echo "amd"
            elif echo "$gpu_info" | grep -qi "intel"; then
                echo "intel"
            else
                echo "cpu"
            fi
            ;;
        Darwin*)
            if system_profiler SPDisplaysDataType 2>/dev/null | grep -qi "Apple M"; then
                echo "apple"
            elif system_profiler SPDisplaysDataType 2>/dev/null | grep -qi "AMD\|Radeon"; then
                echo "amd-macos"
            else
                echo "cpu"
            fi
            ;;
    esac
}

# --- Platform paths ---
case "$(uname -s)" in
    Linux*)
        GIMP_PLUGINS="$HOME/.config/GIMP/3.2/plug-ins"
        ;;
    Darwin*)
        GIMP_PLUGINS="$HOME/Library/Application Support/GIMP/3.2/plug-ins"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        GIMP_PLUGINS="$APPDATA/GIMP/3.2/plug-ins"
        GIMP_PLUGINS="$(echo "$GIMP_PLUGINS" | sed 's|\\|/|g' | sed 's|C:|/c|')"
        ;;
esac

INSTALL_DIR="$HOME/.gimp-plugin-shared-venv"
VENV_DIR="$INSTALL_DIR/venv"

echo "============================================"
echo " GIMP AI Plugins — Shared Engine Setup"
echo "============================================"

# --- GPU info ---
GPU=$(detect_gpu)
echo ""
case "$GPU" in
    nvidia)
        echo "[✓] NVIDIA GPU detected (CUDA acceleration):"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
        ONNX_PKG="onnxruntime-gpu"
        REMBG_PKG="rembg[gpu]"
        ;;
    amd)
        if [ "$(uname -s)" = "Linux" ]; then
            echo "[i] AMD GPU detected. ROCm onnxruntime is not available via pip; using CPU fallback."
        else
            echo "[✓] AMD GPU detected. DirectML acceleration will be used (onnxruntime-directml)."
        fi
        ONNX_PKG="onnxruntime"
        REMBG_PKG="rembg"
        ;;
    intel)
        echo "[✓] Intel GPU detected. DirectML acceleration will be used (onnxruntime-directml)."
        ONNX_PKG="onnxruntime-directml"
        REMBG_PKG="rembg"
        ;;
    apple)
        echo "[✓] Apple Silicon detected (CoreML acceleration)."
        ONNX_PKG="onnxruntime-silicon"
        REMBG_PKG="rembg"
        ;;
    amd-macos|*)
        echo "[i] No compatible GPU acceleration detected. Plugin will work on CPU."
        ONNX_PKG="onnxruntime"
        REMBG_PKG="rembg"
        ;;
esac

# --- Check Python 3 ---
if ! command -v python3 &> /dev/null; then
    echo ""
    echo "[!] Python 3 not found. Install it first:"
    echo "    Linux:   sudo apt install python3 python3-venv"
    echo "    macOS:   brew install python3"
    echo "    Windows: https://python.org/downloads/"
    exit 1
fi

if ! python3 -c "import venv" &> /dev/null; then
    echo ""
    echo "[!] python3-venv not available. Install it first:"
    echo "    Linux:   sudo apt install python3-venv"
    echo "    macOS:   pip3 install virtualenv"
    echo "    Windows: re-run Python installer and check 'pip' and 'tcl/tk'"
    exit 1
fi

# --- Create or reuse venv ---
if [ -d "$VENV_DIR" ]; then
    echo ""
    echo "[✓] Venv already exists. Updating packages..."
else
    echo ""
    echo "[→] Creating Python venv at $VENV_DIR..."
    mkdir -p "$INSTALL_DIR"
    python3 -m venv "$VENV_DIR"
fi

echo "[→] Installing: $ONNX_PKG  $REMBG_PKG  pillow  numpy ..."
"$VENV_DIR/bin/python3" -m pip install --upgrade pip --quiet
"$VENV_DIR/bin/python3" -m pip install "$ONNX_PKG" "$REMBG_PKG" pillow "numpy>=2.0,<2.5"

# --- Flatpak permission (Linux only) ---
if command -v flatpak &> /dev/null && flatpak info org.gimp.GIMP &> /dev/null 2>/dev/null; then
    echo ""
    echo "[→] Granting Flatpak host access permission..."
    flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP
fi

echo ""
echo "============================================"
echo " Shared engine ready at: $INSTALL_DIR"
echo " Installed: $ONNX_PKG + $REMBG_PKG"
echo ""
echo " To install a plugin, copy its files to:"
echo "   $GIMP_PLUGINS/<plugin-name>/"
echo ""
echo " Restart GIMP after installing plugins."
echo "============================================"
