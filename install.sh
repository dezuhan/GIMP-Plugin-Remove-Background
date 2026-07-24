#!/usr/bin/env bash
# Shared engine setup for GIMP AI plugins.
# Run this ONCE. Works on Linux, macOS, Windows (Git Bash).
set -e

# --- Platform detection ---
case "$(uname -s)" in
    Linux*)
        GIMP_PLUGINS="$HOME/.config/GIMP/3.2/plug-ins"
        ;;
    Darwin*)
        GIMP_PLUGINS="$HOME/Library/Application Support/GIMP/3.2/plug-ins"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        GIMP_PLUGINS="$APPDATA/GIMP/3.2/plug-ins"
        # Convert Windows path to Unix-style for Git Bash
        GIMP_PLUGINS="$(echo "$GIMP_PLUGINS" | sed 's|\\|/|g' | sed 's|C:|/c|')"
        ;;
esac

INSTALL_DIR="$HOME/.gimp-plugin-shared-venv"
VENV_DIR="$INSTALL_DIR/venv"

echo "============================================"
echo " GIMP AI Plugins — Shared Engine Setup"
echo "============================================"

# 1. GPU detection (optional — CPU fallback works)
if command -v nvidia-smi &> /dev/null; then
    echo ""
    echo "[✓] NVIDIA GPU detected (CUDA acceleration available):"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
else
    echo ""
    echo "[i] No NVIDIA GPU detected. The plugin will work on CPU."
fi

# 2. Check Python 3
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

"$VENV_DIR/bin/python3" -m pip install --upgrade pip --quiet
"$VENV_DIR/bin/python3" -m pip install "onnxruntime-gpu==1.19.2" "rembg[gpu]" pillow "numpy>=2.0,<2.5"

# 4. Grant Flatpak permission (Linux only)
if command -v flatpak &> /dev/null && flatpak info org.gimp.GIMP &> /dev/null 2>/dev/null; then
    echo ""
    echo "[→] Granting Flatpak host access permission..."
    flatpak override --user --talk-name=org.freedesktop.Flatpak org.gimp.GIMP
fi

echo ""
echo "============================================"
echo " Shared engine ready at: $INSTALL_DIR"
echo ""
echo " To install a plugin, copy its files to:"
echo "   $GIMP_PLUGINS/<plugin-name>/"
echo ""
echo " Restart GIMP after installing plugins."
echo "============================================"
