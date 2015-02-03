import lowlevel
import session
import reply
import posix
import logging
import times

let
  TTL = Ttimespec(tv_sec:1.Time, tv_nsec:0)
  CREATE_TIME = Ttimespec(tv_sec: 1381237736.Time, tv_nsec: 0)
  DIR_ATTR = FileAttr (
    ino: 1,
    size: 0,
    blocks: 0,
    atime: CREATE_TIME,
    mtime: CREATE_TIME,
    ctime: CREATE_TIME,
    mode: S_IFDIR or S_IRUSR,
    nlink: 2,
    uid: 501,
    gid: 20,
    rdev: 0,
  )
  TXT_ATTR = FileAttr (
    ino: 2,
    size: 13,
    blocks: 1,
    atime: CREATE_TIME,
    mtime: CREATE_TIME,
    ctime: CREATE_TIME,
    mode: S_IFREG or S_IRUSR,
    nlink: 1,
    uid: 501,
    gid: 20,
    rdev: 0
  )

type Hello = ref object of LowlevelFs
method lookup*(self: Hello, req: Request, parent: uint64, name: string, reply: Lookup) =
  debug("Hello")
  reply.err(-ENOSYS)

method getattr*(self: Hello, req: Request, ino: uint64, reply: GetAttr) =
  debug("Hello")
  case ino.int
  of 1:
    debug("1")
    # debug("IFDIR:$1, IRUSR:$2", S_IFDIR, S_IRUSR)
    reply.attr(TTL, DIR_ATTR)
  of 2:
    debug("2")
    reply.attr(TTL, TXT_ATTR)
  else:
    reply.err(-ENOENT)

method read*(self: Hello, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  debug("Hello")
  reply.err(-ENOSYS)

method readdir*(self: Hello, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  debug("Hello")
  reply.err(-ENOSYS)

if isMainModule:
  var fs = Hello()
  mount(fs, "mnt", @[])
