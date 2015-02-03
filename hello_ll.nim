import lowlevel
import session
import reply
import posix
import logging

type Hello = ref object of LowlevelFs
method lookup*(self: Hello, req: Request, parent: uint64, name: string, reply: Lookup) =
  debug("Hello")
  reply.err(-ENOSYS)

method getattr*(self: Hello, req: Request, ino: uint64, reply: GetAttr) =
  debug("Hello")
  reply.err(-ENOSYS)

method read*(self: Hello, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  debug("Hello")
  reply.err(-ENOSYS)

method readdir*(self: Hello, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  debug("Hello")
  reply.err(-ENOSYS)

if isMainModule:
  var fs = Hello()
  mount(fs, "mnt", @[])
