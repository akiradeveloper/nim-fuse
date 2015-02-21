import fuse
import posix
import os
import logging

let
  TTL = Timespec(sec:1, nsec:0)
  CREATE_TIME = Timespec(sec: 1381237736, nsec: 0)
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
  TXT = "Hello World\n"

type HelloFs = ref object of FuseFs
method lookup*(self: HelloFs, req: Request, parent: int64, name: string, reply: Lookup) =
  if parent == 1 and name == "hello.txt":
    reply.entry(TEntryOut(
      entry_timeout: TTL,
      attr_timeout: TTL,
      attr: TXT_ATTR,
      generation: 0))
  else:
    reply.err(-ENOENT)
       
method getattr*(self: HelloFs, req: Request, ino: int64, reply: GetAttr) =
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

method read*(self: HelloFs, req: Request, ino: int64, fh: int64, offset: int64, size: int32, reply: Read) =
  if ino == 2:
    var t = TXT
    reply.buf(mkTIOVecS(t))
  else:
    reply.err(-ENOENT)

method readdir*(self: HelloFs, req: Request, ino: int64, fh: int64, offset: int64, reply: Readdir) =
  if ino == 1:
    if offset == 0:
      debug("offset:$1", offset)
      discard reply.tryAdd(1, 0, S_IFDIR, ".")
      discard reply.tryAdd(1, 1, S_IFDIR, "..")
      discard reply.tryAdd(2, 2, S_IFREG, "hello.txt")
    reply.ok
  else:
    reply.err(-ENOENT)

if isMainModule:
  var fs = HelloFs()
  let cl = commandLineParams()
  let mp = cl[0]
  mount(fs, mp, cl[1..mp.high])
