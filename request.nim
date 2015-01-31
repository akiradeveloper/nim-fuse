import protocol
import channel
# import session

type Request* = ref object
  # se: Session
  header: fuse_in_header
  data: Buf

proc doInit(self: Request) =
  discard

proc nop() =
  discard

proc dispatch*(self: Request) =
  let opcode = self.header.opcode.fuse_opcode
  case opcode
  of FUSE_LOOKUP:
    nop()
  of FUSE_FORGET:
    nop()
  of FUSE_GETATTR:
    nop()
  of FUSE_SETATTR:
    nop()
  of FUSE_READLINK:
    nop()
  of FUSE_SYMLINK:
    nop()
  of FUSE_MKNOD:
    nop()
  of FUSE_MKDIR:
    nop()
  of FUSE_UNLINK:
    nop()
  of FUSE_RMDIR:
    nop()
  of FUSE_RENAME:
    nop()
  of FUSE_LINK:
    nop()
  of FUSE_OPEN:
    nop()
  of FUSE_READ:
    nop()
  of FUSE_WRITE:
    nop()
  of FUSE_STATFS:
    nop()
  of FUSE_RELEASE:
    nop()
  of FUSE_FSYNC:
    nop()
  of FUSE_SETXATTR:
    nop()
  of FUSE_GETXATTR:
    nop()
  of FUSE_LISTXATTR:
    nop()
  of FUSE_REMOVEXATTR:
    nop()
  of FUSE_FLUSH:
    nop()
  of FUSE_INIT:
    self.doInit()
    nop()
  of FUSE_OPENDIR:
    nop()
  of FUSE_READDIR:
    nop()
  of FUSE_RELEASEDIR:
    nop()
  of FUSE_FSYNCDIR:
    nop()
  of FUSE_GETLK:
    nop()
  of FUSE_SETLK:
    nop()
  of FUSE_SETLKW:
    nop()
  of FUSE_ACCESS:
    nop()
  of FUSE_CREATE:
    nop()
  of FUSE_INTERRUPT:
    nop()
  of FUSE_BMAP:
    nop()
  of FUSE_DESTROY:
    nop()
