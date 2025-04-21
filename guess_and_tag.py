#!/usr/bin/env python3

"""
guess_and_tag.py
================

This script attempts to automatically identify and tag audio files
in a given folder using MusicBrainz. It is designed to work without an API key
and will only fill in metadata if tags are missing.

Supported formats: mp3, flac, wav, ogg, m4a, aac
"""

import os
import sys
import musicbrainzngs
from mutagen import File
from pathlib import Path

# Setup MusicBrainz user agent
musicbrainzngs.set_useragent("FixMyMusic", "1.0", "https://github.com/nirucon")

def guess_tags_from_folder(folder_path, dry_run=False):
    folder = Path(folder_path)
    if not folder.exists() or not folder.is_dir():
        print(f"❌ Error: '{folder}' is not a valid folder.")
        return False

    # Gather all supported audio files
    extensions = (".mp3", ".flac", ".wav", ".ogg", ".m4a", ".aac")
    audio_files = [f for f in folder.iterdir() if f.suffix.lower() in extensions]

    if not audio_files:
        print(f"🚫 No supported audio files found in '{folder.name}'.")
        return False

    # Try guessing based on folder name
    search_query = folder.name.replace("_", " ").replace("-", " ").strip()
    print(f"🔍 Searching MusicBrainz for: '{search_query}'")

    try:
        result = musicbrainzngs.search_releases(query=search_query, limit=1)
    except Exception as e:
        print(f"⚠️  MusicBrainz search failed: {e}")
        return False

    if not result.get("release-list"):
        print("❌ No matches found on MusicBrainz.")
        return False

    # Extract metadata
    release = result["release-list"][0]
    artist = release["artist-credit"][0]["artist"]["name"]
    album = release["title"]
    year = release.get("date", "").split("-")[0]

    print(f"✅ Match found: {artist} – {album} ({year})")

    if dry_run:
        print("💡 Dry run mode: no tags will be written.")
        return True

    # Apply tags to each file
    for f in audio_files:
        try:
            audio = File(f, easy=True)
            if audio is None:
                print(f"⚠️  Unsupported or unreadable file: {f.name}")
                continue

            audio["artist"] = artist
            audio["album"] = album
            if year:
                audio["date"] = year
            audio.save()
            print(f"✔️  Tagged: {f.name}")
        except Exception as e:
            print(f"⚠️  Failed to tag {f.name}: {e}")

    return True

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Automatically tag audio files in a folder using MusicBrainz."
    )
    parser.add_argument("folder", help="Path to the folder with audio files")
    parser.add_argument("--dry-run", action="store_true", help="Preview only, do not write tags")
    args = parser.parse_args()

    success = guess_tags_from_folder(args.folder, dry_run=args.dry_run)
    if not success:
        sys.exit(1)
