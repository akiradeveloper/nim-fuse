# Will be merged to fuse.nim
# Separate files for development

import posix

{.passC: "-DFUSE_USE_VERSION=26".}
{.passC: gorge("pkg-config --cflags fuse").}
{.passL: gorge("pkg-config --libs fuse").}

{.compile: "c_bridge.c".}

type TFuseFileInfo {.importc:"struct fuse_file_info", header:"<fuse.h>".} = object
  flags: cint
  fh_old: culong
  writepage: cint
  direct_io: cuint
  keep_cache: cuint
  flush: cuint
  padding: cuint
  fh: uint64
  lock_owner: uint64

proc nim_bridge_releasedir(id: cint, name: cstring, fi: ptr TFuseFileInfo): cint {.exportc.} =
  discard

proc nim_bridge_destroy(id: cint, data: pointer) {.exportc.} =
  discard

proc nim_bridge_getattr(id: cint, name: cstring, st: ptr TStat): cint {.exportc.} =
  discard

type HiFuseFs = ref object of RootObj
