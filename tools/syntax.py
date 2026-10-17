#!/usr/bin/env python3
"""Syntax check (Lua 5.1) for every .lua file, plus: every file is listed in the TOC and vice versa."""
import pathlib
import sys

from lupa import lua51

root = pathlib.Path(__file__).resolve().parent.parent
addon = root / "Borometer"
lua = lua51.LuaRuntime()
check = lua.eval("function(p) local f, e = loadfile(p) return e end")
errors = []
for path in sorted(addon.rglob("*.lua")):
    err = check(str(path))
    if err:
        errors.append(err)

toc = [l.strip().replace("\\", "/") for l in (addon / "Borometer.toc").read_text().splitlines()
       if l.strip().endswith(".lua")]
on_disk = {p.relative_to(addon).as_posix() for p in addon.rglob("*.lua") if not p.name.startswith("_")}
for missing in sorted(on_disk - set(toc)):
    errors.append(f"{missing}: not in Borometer.toc")
for ghost in sorted(set(toc) - on_disk):
    errors.append(f"{ghost}: in Borometer.toc but missing on disk")

if errors:
    sys.exit("\n".join(errors))
print(f"syntax ok, {len(on_disk)} files in TOC")
