#!/bin/bash

# ==============================================
# Fix My Music (fix_my_music.sh)
# ==============================================
# This script renames audio folders based on metadata
# in the format: Artist - Album (Year)
# It supports dry run mode and automatic tagging using MusicBrainz.
# Works on Arch, Debian/Ubuntu, and macOS.
# Uses a Python virtual environment to avoid system-level pip issues.
# ==============================================

# -------- Configuration --------
PYTHON_SCRIPT="./guess_and_tag.py"
VENV_DIR=".venv"
SUPPORTED_EXTENSIONS=("mp3" "flac" "wav" "ogg" "m4a" "aac")
RENAME_COUNT=0
DELETE_COUNT=0
SKIP_COUNT=0
TOTAL_COUNT=0
SKIPPED_FOLDERS=()
RENAMED_FOLDERS=()
DELETED_FOLDERS=()
# --------------------------------

# -------- Dependency Check --------
echo "🔍 Checking dependencies..."

install_package() {
    package=$1
    if [[ "$OS" == "arch" ]]; then
        sudo pacman -S --noconfirm "$package"
    elif [[ "$OS" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y "$package"
    elif [[ "$OS" == "macos" ]]; then
        brew install "$package"
    fi
}

# Detect operating system
if [[ -f /etc/arch-release ]]; then
    OS="arch"
elif [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "❌ Unsupported OS. Only Arch, Debian/Ubuntu, and macOS are supported."
    exit 1
fi

# Check and install required system packages
for cmd in exiftool python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "📦 Installing missing package: $cmd"
        install_package "$cmd"
    fi
done

# -------- Python Virtual Environment Setup --------
if [ ! -d "$VENV_DIR" ]; then
    echo "🐍 Creating Python virtual environment in '$VENV_DIR'..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# Install required Python packages in venv
missing_modules=()
for module in musicbrainzngs mutagen; do
    python -c "import $module" 2>/dev/null || missing_modules+=("$module")
done

if [ ${#missing_modules[@]} -gt 0 ]; then
    echo "📦 Installing Python packages in virtual environment: ${missing_modules[*]}"
    pip install --upgrade pip >/dev/null
    pip install "${missing_modules[@]}"
fi

echo "✅ All dependencies are satisfied."
echo

# -------- Mode Selection --------
echo "============================================="
echo "🎶 Fix My Music"
echo "============================================="
echo "Select run mode:"
echo "1) 🔍 Dry run - Preview changes only"
echo "2) ✂️  Apply changes - Rename folders and delete empty ones"
echo
read -rp "Your choice (1 or 2): " mode

if [[ "$mode" == "1" ]]; then
    DRY_RUN=true
    MODE_LABEL="Dry run (preview only)"
elif [[ "$mode" == "2" ]]; then
    DRY_RUN=false
    MODE_LABEL="Live mode (changes applied)"
else
    echo "❌ Invalid selection. Aborting."
    exit 1
fi

# -------- Process Folders --------
for dir in */; do
    dir="${dir%/}"
    [ -d "$dir" ] || continue

    ((TOTAL_COUNT++))
    echo "📁 Processing: $dir"
    echo "────────────"

    found_file=""
    for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
        found_file=$(find "$dir" -maxdepth 1 -iname "*.${ext}" | head -n 1)
        [ -n "$found_file" ] && break
    done

    if [[ -z "$found_file" ]]; then
        echo "🔴 No audio files found in folder."
        echo "🗑️  Removing folder: '$dir'"
        DELETED_FOLDERS+=("$dir")
        ((DELETE_COUNT++))
        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$dir"
        fi
        echo "────────────"
        continue
    fi

    artist=$(exiftool -Artist "$found_file" | awk -F': ' '{print $2}' | tr -d "\"\'")
    album=$(exiftool -Album "$found_file" | awk -F': ' '{print $2}' | tr -d "\"\'")
    year=$(exiftool -Year "$found_file" | grep -o '[0-9]\{4\}')

    if [[ -z "$artist" || -z "$album" ]]; then
        echo "🟡 Missing metadata. Trying MusicBrainz..."
        "$VENV_DIR/bin/python" "$PYTHON_SCRIPT" "$dir" $([ "$DRY_RUN" = true ] && echo "--dry-run")

        found_file=$(find "$dir" -maxdepth 1 -iname "*.${ext}" | head -n 1)
        artist=$(exiftool -Artist "$found_file" | awk -F': ' '{print $2}' | tr -d "\"\'")
        album=$(exiftool -Album "$found_file" | awk -F': ' '{print $2}' | tr -d "\"\'")
        year=$(exiftool -Year "$found_file" | grep -o '[0-9]\{4\}')
    fi

    if [[ -z "$artist" || -z "$album" ]]; then
        echo "🟡 Metadata still missing. Skipping folder."
        SKIPPED_FOLDERS+=("$dir (missing metadata)")
        ((SKIP_COUNT++))
        echo "────────────"
        continue
    fi

    if [[ -n "$year" ]]; then
        new_name="${artist} - ${album} (${year})"
    else
        new_name="${artist} - ${album}"
    fi

    if [[ "$dir" == "$new_name" ]]; then
        echo "✅ Folder name is already correct."
        SKIPPED_FOLDERS+=("$dir (already correct)")
        ((SKIP_COUNT++))
        echo "────────────"
        continue
    fi

    echo "🟢 Renaming: '$dir' → '$new_name'"
    RENAMED_FOLDERS+=("$dir → $new_name")
    ((RENAME_COUNT++))
    if [[ "$DRY_RUN" == false ]]; then
        if [[ -d "$new_name" ]]; then
            echo "⚠️  Destination folder already exists. Skipping."
            SKIPPED_FOLDERS+=("$dir (target exists)")
            ((SKIP_COUNT++))
        else
            mv "$dir" "$new_name"
        fi
    fi
    echo "────────────"
done

# -------- Summary (moved to end) --------
echo
echo "============================================="
echo "📊 Operation summary:"
echo "🛠️  Mode: $MODE_LABEL"
echo "📁 Total folders scanned : $TOTAL_COUNT"
echo "🟢 Folders renamed        : $RENAME_COUNT"
echo "🔴 Folders deleted        : $DELETE_COUNT"
echo "🟡 Folders skipped        : $SKIP_COUNT"

if [ ${#SKIPPED_FOLDERS[@]} -gt 0 ]; then
    echo
    echo "🟡 Skipped folders and reasons:"
    for reason in "${SKIPPED_FOLDERS[@]}"; do
        echo "   - $reason"
    done
fi
echo "============================================="

# -------- Optional Logging --------
echo
read -rp "📝 Do you want to save a log file? (y/n): " save_log
if [[ "$save_log" =~ ^[Yy]$ ]]; then
    timestamp=$(date +"%Y%m%d_%H%M%S")
    logfile="fix_my_music_log_$timestamp.txt"
    (
        echo "📊 Operation summary:"
        echo "🛠️  Mode: $MODE_LABEL"
        echo "📁 Total folders scanned : $TOTAL_COUNT"
        echo "🟢 Folders renamed        : $RENAME_COUNT"
        echo "🔴 Folders deleted        : $DELETE_COUNT"
        echo "🟡 Folders skipped        : $SKIP_COUNT"
        echo
        if [ ${#SKIPPED_FOLDERS[@]} -gt 0 ]; then
            echo "🟡 Skipped folders and reasons:"
            for reason in "${SKIPPED_FOLDERS[@]}"; do
                echo "   - $reason"
            done
            echo
        fi
        if [ ${#DELETED_FOLDERS[@]} -gt 0 ]; then
            echo "🔴 Deleted folders:"
            for d in "${DELETED_FOLDERS[@]}"; do
                echo "   - $d"
            done
            echo
        fi
        if [ ${#RENAMED_FOLDERS[@]} -gt 0 ]; then
            echo "🟢 Renamed folders:"
            for r in "${RENAMED_FOLDERS[@]}"; do
                echo "   - $r"
            done
            echo
        fi
    ) > "$logfile"
    echo "✅ Log file saved as '$logfile'"
fi

deactivate
