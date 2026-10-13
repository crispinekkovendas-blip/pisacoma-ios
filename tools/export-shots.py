#!/usr/bin/env python3
"""Exports every PNG attachment of an .xcresult bundle (the screenshots the UI tests attach)
into a folder, named after the attachment name. Usage: export-shots.py ui.xcresult shots"""
import json
import os
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
            name = node.get("name", {}).get("_value", "shot")
            ref = node.get("payloadRef", {}).get("id", {}).get("_value")
            if ref:
                found.append((name, ref))
        for v in node.values():
            walk(v, found)
    elif isinstance(node, list):
        for v in node:
            walk(v, found)


root = get()
found = []
# Follow every summaryRef / testsRef reference to the test summaries where attachments live.
refs = []


def collect_refs(node):
    if isinstance(node, dict):
        if "id" in node and "_value" in node.get("id", {}) and node.get("_type", {}).get("_name") == "Reference":
            refs.append(node["id"]["_value"])
        for v in node.values():
            collect_refs(v)
    elif isinstance(node, list):
        for v in node:
            collect_refs(v)


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

count = 0
for name, ref in found:
    if not name.lower().endswith(".png"):
        name += ".png"
    path = os.path.join(out, name)
    subprocess.run(["xcrun", "xcresulttool", "export", "--legacy", "--path", bundle, "--id", ref, "--type", "file", "--output-path", path], capture_output=True)
    if os.path.exists(path):
        count += 1
print(f"{count} screenshots → {out}")
