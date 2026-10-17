#!/usr/bin/env python3
"""Runs tools/smoke_test.lua under Lua 5.1 (the client's dialect) via lupa."""
import pathlib
import sys

from lupa import lua51

root = pathlib.Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute("print = print")
try:
    chunk = lua.eval("loadfile")(str(root / "tools" / "smoke_test.lua"))
    if chunk is None:
        sys.exit("cannot load smoke_test.lua")
    chunk(str(root))
except lua51.LuaError as exc:
    sys.exit(str(exc))
