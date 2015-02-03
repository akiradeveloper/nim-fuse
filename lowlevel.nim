# Lowlevel server
# Interacts with fuse client in the kernel

import posix
import protocol
import option
import Buf
import reply

type Request* = ref object
  header*: fuse_in_header
  data*: Buf

type LowlevelFs* = ref object of RootObj

method init*(self: LowlevelFs, req: Request): int =
  0

method destroy*(self: LowlevelFs, req: Request) =
  discard

method lookup*(self: LowlevelFs, req: Request, parent: uint64, name: string, reply: Lookup) =
  reply.err(-ENOSYS)

method forget*(self: LowlevelFs, req: Request, ino: uint64, nlookup: uint64) =
  discard

method getattr*(self: LowlevelFs, req: Request, ino: uint64, reply: GetAttr) =
  reply.err(-ENOSYS)

method setattr*(self: LowlevelFs, req: Request, ino: uint64, mode: TOption[uint32], uid: TOption[uint32], gid: TOption[uint32], size: TOption[uint64], atime: TOption[Ttimespec], mtime: TOption[Ttimespec], fh: TOption[uint64], crtime: TOption[Ttimespec], chgtime: TOption[Ttimespec], bkuptime: TOption[Ttimespec], flags: TOption[uint32], reply: SetAttr) =
  reply.err(-ENOSYS)

method readlink*(self: LowlevelFs, req: Request, ino: uint64, reply: Readlink) =
  reply.err(-ENOSYS)

method mknod*(self: LowlevelFs, req: Request, parent: uint64, name: string, mode: uint32, rdev: uint32, reply: Mknod) =
  reply.err(-ENOSYS)

method mkdir*(self: LowlevelFs, req: Request, parent: uint64, name: string, mode: uint32, reply: Mkdir) =
  reply.err(-ENOSYS)

method unlink*(self: LowlevelFs, req: Request, parent: uint64, name: string, reply: Unlink) =
  reply.err(-ENOSYS)

method rmdir*(self: LowlevelFs, req: Request, parent: uint64, name: string, reply: Rmdir) =
  reply.err(-ENOSYS)

method symlink*(self: LowlevelFs, req: Request, parent: uint64, name: string, link: string, reply: Symlink) =
  reply.err(-ENOSYS)

method rename*(self: LowlevelFs, req: Request, parent: uint64, name: string, newdir: uint64, newname: string, reply: Rename) =
  reply.err(-ENOSYS)

method link*(self: LowlevelFs, req: Request, ino: uint64, newparent: uint64, newname: string, reply: Link) =
  reply.err(-ENOSYS)

method open*(self: LowlevelFs, req: Request, ino: uint64, flags: uint32, reply: Open) =
  reply.err(-ENOSYS)
 
method read*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  reply.err(-ENOSYS)

method write*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, offset: uint64, data: Buf, flags: uint32, reply: Write) =
  reply.err(-ENOSYS)

method flush*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, reply: Flush) =
  reply.err(-ENOSYS)

method release*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, flags: uint32, lock_owner: uint64, flush: bool, reply: Release) =
  reply.err(-ENOSYS)

method fsync*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsync) =
  reply.err(-ENOSYS)

method opendir*(self: LowlevelFs, req: Request, ino: uint64, flags: uint32, reply: Opendir) =
  reply.err(-ENOSYS)

method readdir*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  reply.err(-ENOSYS)

method releasedir*(self: LowlevelFs, req: Request, fh: uint64, flags: uint32, reply: Releasedir) =
  reply.err(-ENOSYS)

method fsyncdir*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsyncdir) =
  reply.err(-ENOSYS)

method statfs*(self: LowlevelFs, req: Request, ino: uint64, reply: Statfs) =
  reply.err(-ENOSYS)

method setxattr*(self: LowlevelFs, req: Request, ino: uint64, key: string, value: Buf, flags: uint32, position: uint32, reply: SetXAttr) =
  reply.err(-ENOSYS)

method getxattr*(self: LowlevelFs, req: Request, ino: uint64, key: string, reply: GetXAttr) =
  reply.err(-ENOSYS)

method listxattr*(self: LowlevelFs, req: Request, ino: uint64, reply: ListXAttr) =
  reply.err(-ENOSYS)

method removexattr*(self: LowlevelFs, req: Request, ino: uint64, name: string, reply: RemoveXAttr) =
  reply.err(-ENOSYS)

method access*(self: LowlevelFs, req: Request, ino: uint64, mask: uint32, reply: Access) =
  reply.err(-ENOSYS)

method create*(self: LowlevelFs, req: Request, parent: uint64, name: string, mode: uint32, flags: uint32, reply: Create) =
  reply.err(-ENOSYS)

method getlk*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, reply: Getlk) =
  reply.err(-ENOSYS)

method setlk*(self: LowlevelFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, sleep: bool, reply: Setlk) =
  reply.err(-ENOSYS)

method bmap*(self: LowlevelFs, req: Request, ino: uint64, idx: uint64, blocksize: uint32, reply: Bmap) =
  reply.err(-ENOSYS)
