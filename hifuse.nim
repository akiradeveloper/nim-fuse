# Will be merged to fuse.nim
# Separate files for development

{.passC: "-DFUSE_USE_VERSION=26".}
{.passC: gorge("pkg-config --cflags fuse").}
{.passL: gorge("pkg-config --libs fuse").}

{. compile: "c_bridge.c" .}

proc nim_bridge_destroy(id: int, data: ptr) =
  discard

type HiFuseFs = ref object of RootObj
