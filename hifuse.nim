# Will be merged to fuse.nim
# Separate files for development

import posix

{.passC: "-DFUSE_USE_VERSION=26".}
{.passC: gorge("pkg-config --cflags fuse").}
{.passL: gorge("pkg-config --libs fuse").}

{.compile: "c_bridge.c".}

type TFuseFileInfo* {.importc:"struct fuse_file_info", header:"<fuse.h>".} = object
  flags: cint
  fh_old: culong
  writepage: cint
  direct_io: cuint
  keep_cache: cuint
  flush: cuint
  padding: cuint
  fh: uint64
  lock_owner: uint64

type TFuseConnInfo* {.importc:"struct fuse_conn_info", header:"<fuse.h>".} = object
  proto_major: cuint
  proto_minor: cuint
  async_read: cuint
  max_write: cuint
  max_readahead: cuint
  reserved: array[27, cuint]

type TFuseFillDir* {.importc:"fuse_fill_dir_t", header:"<fuse.h>"} = proc (buf: pointer, name: cstring, st: ptr TStat, off: TOff): cint

# ------------------------------------------------------------------------------

type HiFuseFs* = ref object of RootObj

method getattr(fs: HiFuseFs, a: cstring, b: ptr TStat): cint =
  discard

method readlink(fs: HiFuseFs, a: cstring, b: int): cint =
  discard

method mknod(fs: HiFuseFs, a: cstring, b: int): cint =
  discard

method mkdir(fs: HiFuseFs, a: cstring, b: TMode): cint =
  discard

method unlink(fs: HiFuseFs, a: cstring): cint =
  discard

method rmdir(fs: HiFuseFs, a: cstring): cint =
  discard

method symlink(fs: HiFuseFs, a: cstring, b: cstring): cint =
  discard

method rename(fs: HiFuseFs, a: cstring, b: cstring): cint =
  discard

method link(fs: HiFuseFs, a: cstring, b: cstring): cint =
  discard

method chmod(fs: HiFuseFs, a: cstring, b: TMode): cint =
  discard

method chown(fs: HiFuseFs, a: cstring, b: Tuid, c: TGid): cint =
  discard

method truncate(fs: HiFuseFs, a: cstring, b: TOff): cint =
  discard

method open(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo): cint =
  discard

method read(fs: HiFuseFs, a: cstring, b: pointer, c: int, d: TOff, e: ptr TFuseFileInfo): cint =
  discard

method write(fs: HiFuseFs, a: cstring, b: cstring, c: int, d: TOff, e: ptr TFuseFileInfo): cint =
  discard

method statfs(fs: HiFuseFs, a: cstring, b: ptr TStatvfs): cint =
  discard

method flush(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo): cint =
  discard

method release(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo): cint =
  discard

method fsync(fs: HiFuseFs, a: cstring, b: cint, c: ptr TFuseFileInfo): cint =
  discard

method setxattr(fs: HiFuseFs, a: cstring, b: cstring, c: int, d: cint): cint =
  discard

method getxattr(fs: HiFuseFs, a: cstring, b: cstring, c: int): cint =
  discard

method listxattr(fs: HiFuseFs, a: cstring, b: pointer, c: int): cint =
  discard

method removexattr(fs: HiFuseFs, a: cstring, b: cstring): cint =
  discard

method opendir(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo): cint =
  discard

method readdir(fs: HiFuseFs, a: cstring, b: pointer, c: TFuseFillDir, d: TOff, e: ptr TFuseFileInfo): cint =
  discard

method releasedir(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo): cint =
  discard

method fsyncdir(fs: HiFuseFs, a: cstring, b: cint, c: ptr TFuseFileInfo): cint =
  discard

method init(fs: HiFuseFs, a: ptr TFuseConnInfo) =
  discard

method destroy(fs: HiFuseFs, a: pointer): void =
  discard

method access(fs: HiFuseFs, a: cstring, b: cint): cint =
  discard

method create(fs: HiFuseFs, a: cstring, b: TMode, c: ptr TFuseFileInfo): cint =
  discard

method ftruncate(fs: HiFuseFs, a: cstring, b: TOff, c: ptr TFuseFileInfo): cint =
  discard

method fgetattr(fs: HiFuseFs, a: cstring, b: ptr TStat, c: ptr TFuseFileInfo): cint =
  discard

method lock(fs: HiFuseFs, a: cstring, b: ptr TFuseFileInfo, c: cint, d: ptr Tflock): cint =
  discard

method utimens(fs: HiFuseFs, a: cstring, b: array[2, Ttimespec]): cint =
  discard

method bmap(fs: HiFuseFs, a: cstring, b: int, c: ptr uint64): cint =
  discard

# ------------------------------------------------------------------------------

proc getFs(id: cint): HiFuseFs =
  discard

proc nim_bridge_getattr(id: cint, a: cstring, b: ptr TStat): cint {.exportc.} =
  var fs = getFs(id)
  fs.getattr(a, b)

proc nim_bridge_readlink(id: cint, a: cstring, b: int): cint {.exportc.} =
  var fs = getFs(id)
  fs.readlink(a, b)

proc nim_bridge_mknod(id: cint, a: cstring, b: int): cint {.exportc.} =
  var fs = getFs(id)
  fs.mknod(a, b)

proc nim_bridge_mkdir(id: cint, a: cstring, b: TMode): cint {.exportc.} =
  var fs = getFs(id)
  fs.mkdir(a, b)

proc nim_bridge_unlink(id: cint, a: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.unlink(a)

proc nim_bridge_rmdir(id: cint, a: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.rmdir(a)

proc nim_bridge_symlink(id: cint, a: cstring, b: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.symlink(a, b)

proc nim_bridge_rename(id: cint, a: cstring, b: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.rename(a, b)

proc nim_bridge_link(id: cint, a: cstring, b: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.link(a, b)

proc nim_bridge_chmod(id: cint, a: cstring, b: TMode): cint {.exportc.} =
  var fs = getFs(id)
  fs.chmod(a, b)

proc nim_bridge_chown(id: cint, a: cstring, b: Tuid, c: TGid): cint {.exportc.} =
  var fs = getFs(id)
  fs.chown(a, b, c)

proc nim_bridge_truncate(id: cint, a: cstring, b: TOff): cint {.exportc.} =
  var fs = getFs(id)
  fs.truncate(a, b)

proc nim_bridge_open(id: cint, a: cstring, b: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.open(a, b)

proc nim_bridge_read(id: cint, a: cstring, b: pointer, c: int, d: TOff, e: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.read(a, b, c, d, e)

proc nim_bridge_write(id: cint, a: cstring, b: cstring, c: int, d: TOff, e: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.write(a, b, c, d, e)

proc nim_bridge_statfs(id: cint, a: cstring, b: ptr TStatvfs): cint {.exportc.} =
  var fs = getFs(id)
  fs.statfs(a, b)

proc nim_bridge_flush(id: cint, a: cstring, b: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.flush(a, b)

proc nim_bridge_release(id: cint, a: cstring, b: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.release(a, b)

proc nim_bridge_fsync(id: cint, a: cstring, b: cint, c: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.fsync(a, b, c)

proc nim_bridge_setxattr(id: cint, a: cstring, b: cstring, c: int, d: cint): cint {.exportc.} =
  var fs = getFs(id)
  fs.setxattr(a, b, c, d)

proc nim_bridge_getxattr(id: cint, a: cstring, b: cstring, c: int): cint {.exportc.} =
  var fs = getFs(id)
  fs.getxattr(a, b, c)

proc nim_bridge_listxattr(id: cint, a: cstring, b: pointer, c: int): cint {.exportc.} =
  var fs = getFs(id)
  fs.listxattr(a, b, c)

proc nim_bridge_removexattr(id: cint, a: cstring, b: cstring): cint {.exportc.} =
  var fs = getFs(id)
  fs.removexattr(a, b)

proc nim_bridge_opendir(id: cint, a: cstring, b: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.opendir(a, b)

proc nim_bridge_readdir(id: cint, a: cstring, b: pointer, c: TFuseFillDir, d: TOff, e: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.readdir(a, b, c, d, e)

proc nim_bridge_releasedir(id: cint, a: cstring, b: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.releasedir(a, b)

proc nim_bridge_fsyncdir(id: cint, a: cstring, b: cint, c: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.fsyncdir(a, b, c)

proc nim_bridge_init(id: cint, a: ptr TFuseConnInfo): void {.exportc.} =
  var fs = getFs(id)
  fs.init(a)

proc nim_bridge_destroy(id: cint, a: pointer): void {.exportc.} =
  var fs = getFs(id)
  fs.destroy(a)

proc nim_bridge_access(id: cint, a: cstring, b: cint): cint {.exportc.} =
  var fs = getFs(id)
  fs.access(a, b)

proc nim_bridge_create(id: cint, a: cstring, b: TMode, c: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.create(a, b, c)

proc nim_bridge_ftruncate(id: cint, a: cstring, b: TOff, c: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.ftruncate(a, b, c)

proc nim_bridge_fgetattr(id: cint, a: cstring, b: ptr TStat, c: ptr TFuseFileInfo): cint {.exportc.} =
  var fs = getFs(id)
  fs.fgetattr(a, b, c)

proc nim_bridge_lock(id: cint, a: cstring, b: ptr TFuseFileInfo, c: cint, d: ptr Tflock): cint {.exportc.} =
  var fs = getFs(id)
  fs.lock(a, b, c, d)

proc nim_bridge_utimens(id: cint, a: cstring, b: array[2, Ttimespec]): cint {.exportc.} =
  var fs = getFs(id)
  fs.utimens(a, b)

proc nim_bridge_bmap(id: cint, a: cstring, b: int, c: ptr uint64): cint {.exportc.} =
  var fs = getFs(id)
  fs.bmap(a, b, c)

proc c_bridge_main(id: cint, argc: cint, argv: cstringArray) {.importc:"c_bridge_main".}
proc mount*(fs: HiFuseFs, options: openArray[string]) =
  let id = 0
  var argv = allocCStringArray(options)
  c_bridge_main(id.cint, options.len.cint, argv)
  deallocCStringArray(argv)
