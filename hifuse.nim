# Will be merged to fuse.nim
# Separate files for development

import posix

{.passC: "-DFUSE_USE_VERSION=26".}
{.passC: gorge("pkg-config --cflags fuse").}
{.passL: gorge("pkg-config --libs fuse").}

{.compile: "c_bridge.c".}

proc nim_bridge_destroy(id: cint, data: pointer) {.exportc.} =
  discard

proc nim_bridge_getattr(id: cint, name: cstring, st: ptr TStat): cint {.exportc.} =
  discard

type HiFuseFs = ref object of RootObj
