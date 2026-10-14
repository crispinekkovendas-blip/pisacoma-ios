#!/usr/bin/env python3
"""Exports every attachment of an .xcresult bundle (the screenshots the UI tests attach, plus
XCTest's own failure attachments) into a folder with safe file names.
Usage: export-shots.py ui.xcresult shots"""
import json
import os
import re
import subprocess
import sys

bundle, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)


def tool(*args):
    return subprocess.run(["xcrun", "xcresulttool", *args], capture_output=True, text=True).stdout


def get(obj_id=None):
    args = ["get", "--legacy", "--path", bundle, "--format", "json"]
    if obj_id:
        args += ["--id", obj_id]
    raw = tool(*args)
    return json.loads(raw) if raw.strip() else {}


def walk(node, found):
    if isinstance(node, dict):
        if node.get("_type", {}).get("_name") == "ActionTestAttachment":
            name = node.get("name", {}).get("_value", "attachment")
            uti = node.get("uniformTypeIdentifier", {}).get("_value", "")
            ref = node.get("payloadRef", {}).get("id", {}).get("_value")
            if ref:
                found.append((name, uti, ref))
        for v in node.values():
            walk(v, found)
    elif isinstance(node, list):
        for v in node:
            walk(v, found)


refs = []


def collect_refs(node):
    if isinstance(node, dict):
        if node.get("_type", {}).get("_name") == "Reference" and "_value" in node.get("id", {}):
            refs.append(node["id"]["_value"])
        for v in node.values():
            collect_refs(v)
    elif isinstance(node, list):
        for v in node:
            collect_refs(v)


root = get()
found = []
collect_refs(root)
seen = set()
queue = list(refs)
while queue:
    r = queue.pop()
    if r in seen:
        continue
    seen.add(r)
    sub = get(r)
    walk(sub, found)
    before = len(refs)
    collect_refs(sub)
    queue.extend(refs[before:])


def safe(name):
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("_")
    return name[:80] or "attachment"


count = 0
used = set()
for name, uti, ref in found:
    ext = ".png" if "png" in uti or name.lower().endswith(".png") else (".txt" if "text" in uti else ".bin")
    base = safe(name[:-4] if name.lower().endswith(".png") else name)
    fname = base + ext
    n = 2
    while fname in used:
        fname = f"{base}-{n}{ext}"
        n += 1
    used.add(fname)
    path = os.path.join(out, fname)
    subprocess.run(["xcrun", "xcresulttool", "export", "--legacy", "--path", bundle, "--id", ref, "--type", "file", "--output-path", path], capture_output=True)
    if os.path.exists(path):
        count += 1
print(f"{count} attachments → {out}")
