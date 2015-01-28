# Lowlevel server
# Interacts with fuse client in the kernel

import option
import request
import channel

type LowlevelFs* = ref object of RootObj
import session

type Request = ref object

method init(self: LowlevelFs, req: Request): int =
  discard 

method destroy(self: LowlevelFs, req: Request) =
  discard

method lookup(self: LowlevelFs, req: Request, name: string) =
  discard

method forget(self: LowlevelFs, req: Request, ino, nlookup) =
  discard

method getattr(self: LowlevelFs, req, ino, fi) =
  discard

method open(self: LowlevelFs, req, ino, fi) =
  discard
 
method read(self: LowlevelFs, req: Request, size, off) =
  discard

method release(self: LowlevelFs, req: Request) =
  discard

method opendir(self: LowlevelFs, req: Request) =
  discard

method readdir(self: LowlevelFs, req: Request, size, off) =
  discard

method releasedir(self: LowlevelFs, req: Request) =
  discard
 
# sketch

# proc fuse_reply_statfs(req, stbuf: posix.TStatvfs)
