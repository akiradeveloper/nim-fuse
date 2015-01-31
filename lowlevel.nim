# Lowlevel server
# Interacts with fuse client in the kernel

import protocol
import option
import Buf
import reply

type Request* = ref object
  header*: fuse_in_header
  data*: Buf

type LowlevelFs* = ref object of RootObj

method init*(self: LowlevelFs, req: Request): int =
  discard 

method destroy*(self: LowlevelFs, req: Request) =
  discard

method lookup*(self: LowlevelFs, req: Request, name: string, reply: Lookup) =
  discard

method forget*(self: LowlevelFs, req: Request, nlookup: uint64, reply: Forget) =
  discard

method getattr*(self: LowlevelFs, req: Request, reply: GetAttr) =
  discard

method open*(self: LowlevelFs, req: Request, reply: Open) =
  discard
 
method read*(self: LowlevelFs, req: Request, size, off, reply: Read) =
  discard

method release*(self: LowlevelFs, req: Request, reply: Release) =
  discard

method opendir*(self: LowlevelFs, req: Request, reply: Opendir) =
  discard

method readdir*(self: LowlevelFs, req: Request, size, off) =
  discard

method releasedir*(self: LowlevelFs, req: Request, fh: uint64, flags: uint32, reply: Releasedir) =
  discard

method symlink*(self: LowlevelFs, req: Request, name: string, link: string, reply: Symlink) =
  discard

method unlink*(self: LowlevelFs, req: Request, name: string, reply: Unlink) =
  discard

 
# sketch

# proc fuse_reply_statfs(req, stbuf: posix.TStatvfs)
