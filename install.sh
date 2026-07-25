#!/usr/bin/env bash
# Shared engine setup for GIMP AI plugins.
# Detects GPU and installs the correct ONNX Runtime package.
# Run this ONCE. Works on Linux, macOS, Windows (Git Bash).
set -e

# --- Platform detection ---
case "$(uname -s)" in
    Linux*)
        IS_LINUX=1
        GIMP_PLUGINS="$HOME/.config/GIMP/3.2/plug-ins"
        VENV_PYTHON_REL="bin/python3"
        VENV_PIP_REL="bin/pip"
        ;;
    Darwin*)
        IS_MACOS=1
        GIMP_PLUGINS="$HOME/Library/Application Support/GIMP/3.2/plug-ins"
        VENV_PYTHON_REL="bin/python3"
        VENV_PIP_REL="bin/pip"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        IS_WINDOWS=1
        GIMP_PLUGINS="$APPDATA/GIMP/3.2/plug-ins"
        GIMP_PLUGINS="$(echo "$GIMP_PLUGINS" | sed 's|\\|/|g' | sed 's|C:|/c|')"
        VENV_PYTHON_REL="Scripts/python.exe"
        VENV_PIP_REL="Scripts/pip.exe"
        ;;
esac

# macOS readlink fallback
if readlink -f "$0" &>/dev/null; then
    PLUGIN_DIR="$(dirname "$(readlink -f "$0")")"
else
    PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Find a working Python 3.10+ (tries python3, python, py)
detect_python() {
    for cmd in python3 python py; do
        if command -v "$cmd" &> /dev/null; then
            if "$cmd" -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" 2>/dev/null; then
                echo "$cmd"
                return
            fi
        fi
    done
    echo ""
}

PYTHON_CMD=$(detect_python)

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

INSTALL_DIR="$HOME/.gimp-plugin-shared-venv"
VENV_DIR="$INSTALL_DIR/venv"
VENV_PYTHON="$VENV_DIR/$VENV_PYTHON_REL"
VENV_PIP="$VENV_DIR/$VENV_PIP_REL"

echo "============================================"
echo " GIMP AI Plugins — Shared Engine Setup"
echo "============================================"

# --- Check Python ---
if [ -z "$PYTHON_CMD" ]; then
    echo ""
    echo "[!] Python 3.10+ not found. Install it first:"
    echo "    Linux:   sudo apt install python3 python3-venv"
    echo "    macOS:   brew install python3"
    echo "    Windows: https://python.org/downloads/"
    exit 1
fi
echo "[✓] Found: $PYTHON_CMD ($($PYTHON_CMD --version 2>&1))"

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
        if [ -n "$IS_LINUX" ]; then
            echo "[i] AMD GPU detected. ROCm onnxruntime is not available via pip; using CPU fallback."
            ONNX_PKG="onnxruntime"
        else
            echo "[✓] AMD GPU detected. DirectML acceleration will be used (onnxruntime-directml)."
            ONNX_PKG="onnxruntime-directml"
        fi
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

# --- Check venv module ---
if ! "$PYTHON_CMD" -c "import venv" &> /dev/null; then
    echo ""
    echo "[!] python venv module not available. Install it first:"
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
    "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

echo "[→] Installing: $ONNX_PKG  $REMBG_PKG  pillow  numpy ..."
"$VENV_PYTHON" -m pip install --upgrade pip --quiet
"$VENV_PYTHON" -m pip install "$ONNX_PKG" "$REMBG_PKG" pillow "numpy>=2.0,<2.5"

# --- Flatpak permission (Linux only) ---
if command -v flatpak &> /dev/null && flatpak info org.gimp.GIMP &> /dev/null 2>/dev/null; then
    echo ""
    echo "[→] Granting Flatpak host access permission..."
    flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP
fi

# --- Copy Remove Background plugin files ---
PLUGIN_TARGET="$GIMP_PLUGINS/remove-background"
echo ""
echo "[→] Installing Remove Background plugin to $PLUGIN_TARGET ..."
mkdir -p "$PLUGIN_TARGET"
cp "$PLUGIN_DIR/remove-background.py" "$PLUGIN_TARGET/"
cp "$PLUGIN_DIR/run_worker.sh" "$PLUGIN_TARGET/"
cp "$PLUGIN_DIR/bg_remove_worker.py" "$PLUGIN_TARGET/"
chmod +x "$PLUGIN_TARGET/remove-background.py" 2>/dev/null || true
chmod +x "$PLUGIN_TARGET/run_worker.sh" 2>/dev/null || true

echo ""
echo "============================================"
echo " Shared engine ready at: $INSTALL_DIR"
echo " Installed:        $ONNX_PKG + $REMBG_PKG"
echo " Plugin installed: $PLUGIN_TARGET"
echo ""
echo " Restart GIMP → Filters → Enhance → Remove Background"
echo "============================================"
