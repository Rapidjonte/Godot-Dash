#!/usr/bin/env python3
"""
Run from your Godot project root:
    python generate_index.py

Generates:
    res://prefabs/index.txt   - list of all .tscn filenames
    res://images/index.txt    - list of all image paths (res:// format)
"""

import os

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

def write_prefab_index():
    prefabs_dir = os.path.join(PROJECT_ROOT, "prefabs")
    if not os.path.isdir(prefabs_dir):
        print("WARNING: prefabs/ folder not found")
        return
    files = sorted(f for f in os.listdir(prefabs_dir) if f.endswith(".tscn"))
    out_path = os.path.join(prefabs_dir, "index.txt")
    with open(out_path, "w") as f:
        f.write("\n".join(files))
    print(f"prefabs/index.txt: {len(files)} entries")

def write_image_index():
    images_dir = os.path.join(PROJECT_ROOT, "images")
    if not os.path.isdir(images_dir):
        print("WARNING: images/ folder not found")
        return
    extensions = {".png", ".jpg", ".jpeg", ".webp"}
    files = []
    for root, dirs, filenames in os.walk(images_dir):
        dirs.sort()
        for fname in sorted(filenames):
            if os.path.splitext(fname)[1].lower() in extensions:
                full = os.path.join(root, fname)
                # Convert to res:// path
                rel = os.path.relpath(full, PROJECT_ROOT).replace("\\", "/")
                files.append("res://" + rel)
    out_path = os.path.join(images_dir, "index.txt")
    with open(out_path, "w") as f:
        f.write("\n".join(files))
    print(f"images/index.txt: {len(files)} entries")

if __name__ == "__main__":
    write_prefab_index()
    write_image_index()
    print("Done!")