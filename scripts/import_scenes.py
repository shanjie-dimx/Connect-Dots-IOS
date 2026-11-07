#!/usr/bin/env python3
"""Copies the adventure map and the 12 chapter backgrounds into Assets.xcassets.

Usage:
  python3 scripts/import_scenes.py MAP_IMAGE BG1 BG2 ... BG12
  python3 scripts/import_scenes.py FOLDER

With a folder, the image whose name contains "map" becomes the map and the remaining
images, sorted by file name, become chapters 1 to 12.
"""

import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "ColorLink", "Assets.xcassets")
IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg")


def add_imageset(name, source):
    folder = os.path.join(ASSETS, name + ".imageset")
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    filename = name.lower() + os.path.splitext(source)[1].lower()
    shutil.copyfile(source, os.path.join(folder, filename))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)
    print("%-14s <- %s" % (name, source))


def main(args):
    if len(args) == 1 and os.path.isdir(args[0]):
        files = sorted(
            os.path.join(args[0], f) for f in os.listdir(args[0]) if f.lower().endswith(IMAGE_EXTENSIONS)
        )
        maps = [f for f in files if "map" in os.path.basename(f).lower()]
        if len(maps) != 1:
            sys.exit("expected exactly one image with 'map' in its name, found %d" % len(maps))
        backgrounds = [f for f in files if f != maps[0]]
        args = [maps[0]] + backgrounds
    if len(args) != 13:
        sys.exit("expected 1 map and 12 backgrounds, got %d images" % len(args))
    add_imageset("Map", args[0])
    for i, path in enumerate(args[1:], start=1):
        add_imageset("Background%02d" % i, path)


if __name__ == "__main__":
    main(sys.argv[1:])
