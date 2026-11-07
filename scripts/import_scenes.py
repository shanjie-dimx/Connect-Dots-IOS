#!/usr/bin/env python3
"""Copies the adventure map and the 12 location backgrounds from pics/ into Assets.xcassets.

Usage: python3 scripts/import_scenes.py

Images are matched by the asset id at the end of their file name, in the order of
SCENES below (location 1 at the bottom of the map to location 12 at the top). They are
saved as JPEG to keep the app small. Requires Pillow (pip install pillow).
"""

import glob
import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PICS = os.path.join(ROOT, "pics")
ASSETS = os.path.join(ROOT, "ConnectDots", "Assets.xcassets")

MAP = "asset_dByosQhHXXxQH1J2puhfKVHz"
SCENES = [
    "asset_9TdUVJiJ7TLy3WpngaLB5PWd",  # 1 Sunny Beach: tropical beach
    "asset_p9LdiCnRsRcGya8bjiXEFXjr",  # 2 Coral Reef: underwater coral reef
    "asset_7SVygi58jsxJNQwKRMybc71F",  # 3 Pirate Wreck: sunken pirate ship
    "asset_Hgf675tnWBKaLveSBXW5ZJ2C",  # 4 Palm Oasis: tropical oasis lagoon
    "asset_fBLfNa8mkoFkKxp1QbCkoFsm",  # 5 Golden Dunes: desert sand dunes
    "asset_hZPvQDJ2mbAzGc2Sw8r42PQA",  # 6 Lost Ruins: ruins among the dunes
    "asset_fJybPAvEJ5Co5VADdgcNEhrs",  # 7 Jungle River: jungle and river
    "asset_rZbBBDjSyoRhRLuDWxAqUXVJ",  # 8 Thunder Falls: tropical waterfall
    "asset_eGkh8BUdvMs9BPpzW5ZKTG9S",  # 9 Mushroom Grove: glowing mushrooms
    "asset_T2razUsHdQKS2k2Wn8S99Bt9",  # 10 Crystal Cave: icicle cave
    "asset_VXvKnJPQ14eUyB5N7rGA2JvJ",  # 11 Aurora Peak: auroras at night
    "asset_mzn7KV2WzVw1E82ayD8uH31D",  # 12 Sky Summit: sun above the clouds
]


def find(asset_id):
    matches = glob.glob(os.path.join(PICS, "*%s*" % asset_id))
    if len(matches) != 1:
        raise SystemExit("expected one image for %s in pics/, found %d" % (asset_id, len(matches)))
    return matches[0]


def add_imageset(name, source):
    folder = os.path.join(ASSETS, name + ".imageset")
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    filename = name.lower() + ".jpg"
    Image.open(source).convert("RGB").save(os.path.join(folder, filename), quality=85, optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": [{"filename": filename, "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    print("%-14s <- %s" % (name, os.path.basename(source)))


def main():
    add_imageset("Map", find(MAP))
    for i, asset_id in enumerate(SCENES, start=1):
        add_imageset("Background%02d" % i, find(asset_id))


if __name__ == "__main__":
    main()
