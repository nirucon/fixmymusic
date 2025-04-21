# 🎶 Fix My Music

A powerful and safe Bash script to organize your music folders based on audio file metadata.  
Automatically renames folders using the format:

```
Artist - Album (Year)
```

### Example:
```
1989 - Altars Of Madness → Morbid Angel - Altars Of Madness (1989)
```

---

## ✅ Features

- Supports `.mp3`, `.flac`, `.wav`, `.ogg`, `.m4a`, `.aac`
- Reads metadata using `exiftool`
- If missing, attempts automatic tagging via MusicBrainz
- Deletes folders without any audio files
- Skips already correctly named folders
- Works on **Arch** and probably **Debian/Ubuntu**, and **macOS** too (?)
- Includes a **dry run mode** and optional **log file output**

---

## 🚀 How to Use

1. **Place the script** in the root folder containing your music directories
2. Make it executable:
   ```bash
   chmod +x fix_my_music.sh
   ```
3. Run the script:
   ```bash
   ./fix_my_music.sh
   ```

4. Choose one of the modes when prompted:
   - `1` 🔍 Dry run — preview what would be changed
   - `2` ✂️ Apply changes — rename folders and delete empty ones

5. After completion, you’ll be asked if you'd like to save a **summary log file**  
   (named like `fix_my_music_log_20250421_154512.txt`)

---

## 📝 Sample Output

```
📁 Processing: 1989 - Altars Of Madness
🟢 Renaming: '1989 - Altars Of Madness' → 'Morbid Angel - Altars Of Madness (1989)'
────────────
📁 Processing: 1990 - Cause Of Death
✅ Folder name is already correct.
────────────
📁 Processing: RandomFolder
🔴 No audio files found in folder.
🗑️  Removing folder: 'RandomFolder'
────────────
```

---

## 🧠 About `guess_and_tag.py`

This script is automatically called by `fix_my_music.sh` when audio metadata is missing.  
It tries to identify and tag the files using **acoustic fingerprinting** and metadata lookup.

### 🔧 What it does:

- Scans each audio file using [`mutagen`](https://mutagen.readthedocs.io/) and [`musicbrainzngs`](https://python-musicbrainzngs.readthedocs.io/)
- Sends a fingerprint or filename guess to MusicBrainz
- Updates missing tags (artist, album, year) in the files
- Only triggered if local metadata is incomplete

### 🐍 Dependencies (handled automatically):
- `musicbrainzngs` – for online metadata lookup
- `mutagen` – for editing audio file tags

The script is installed and run inside a **virtual Python environment** (`.venv`) created by `fix_my_music.sh`.

---

## 🔒 Safety & Compatibility

- No system Python is touched — uses a **local virtual environment**
- All dependencies are automatically detected and installed if missing
- Logging is **optional** and saved in the working directory

---

## 📄 License

MIT – Use freely, modify boldly, share with love 🤘
