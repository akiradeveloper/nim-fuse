# Lowlevel server
# Interacts with fuse client in the kernel

import option
import request

type *LowlevelFs = ref object of RootObj

type Request = ref object

method init(self: LowlevelFs, req: Request) =
  discard 

method destroy(self: LowlevelFs, req: Request) =
  discard

method lookup(self: LowlevelFs, req: Request, parent: u64, name: string) =
  discard

method forget(self, req: Request, ino, nlookup)

method getattr(self, req, ino, fi)

method open(self, req, ino, fi)

method read(self, ino, size, off, fi)

method release(self, req, ino, fi)

method opendir(self, req, ino, fi)

method readdir(self, req, ino, size, off, fi)

method releasedir(self, req, ino, fi)

# sketch

# proc fuse_reply_statfs(req, stbuf: posix.TStatvfs)

proc mount(fs: LowlevelFs, mountpoint: string, mount_options: openArray[string]) =
  let chan = connect(mountpoint, options)
  let se = mkSession(fs, chan)
  se.loop
  disconnect(chan)
