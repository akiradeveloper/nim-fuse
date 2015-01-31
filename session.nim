import lowlevel
import protocol
import channel
import buf
import reply

type Session* = ref object 
  fs: LowlevelFs
  chan: Channel
  proto_major: uint32
  proto_minor: uint32
  initialized: bool
  destroyed: bool

proc doInit(self: Request) =
  discard

proc nop =
  discard

proc parseStr(self: Buf): string =
  var sq = cast[seq[char]](self.asPtr)
  $cstring(addr sq[0])

template defNew(typ: typedesc) =
  proc `new typ`(req: Request, se: Session): `typ` =
    typ (
      raw: newRaw(se.chan.mkSender, req.header.unique)
    )

defNew(Lookup)
defNew(Forget)
defNew(GetAttr)
defNew(SetAttr)
defNew(Readlink)
defNew(Mknod)
defNew(Mkdir)
defNew(Unlink)
defNew(Rmdir)
defNew(Symlink)
defNew(Rename)
defNew(Link)
defNew(Open)
defNew(Read)
defNew(Write)
defNew(Flush)
defNew(Release)
defNew(Fsync)
defNew(Opendir)
  
proc dispatch*(req: Request, se: Session) =
  let opcode = req.header.opcode.fuse_opcode

  # if destroyed, any requests are discarded.
  if se.destroyed:
    return

  # before initialized, only FUSE_INIT is accepted.
  if not se.initialized:
    if opcode != FUSE_INIT:
      return

  case opcode
  of FUSE_LOOKUP:
    let name = req.data.parseStr
    se.fs.lookup(req, name, newLookup(req, se))
  of FUSE_FORGET:
    nop()
  of FUSE_GETATTR:
    nop()
  of FUSE_SETATTR:
    nop()
  of FUSE_READLINK:
    nop()
  of FUSE_SYMLINK:
    let name = req.data.parseStr
    req.data.advance(len(name) + 1)
    let link = req.data.parseStr
    se.fs.symlink(req, name, link)
  of FUSE_MKNOD:
    nop()
  of FUSE_MKDIR:
    nop()
  of FUSE_UNLINK:
    let name = req.data.parseStr
    se.fs.unlink(req, name)
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
    req.doInit()
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

proc mkSession*(fs:LowlevelFs, chan: Channel): Session =
  Session (
    fs: fs,
    chan: chan,
    initialized: false,
    destroyed: false,
  )

let
  MAX_WRITE_BUFSIZE* = 16 * 1024 * 1024

proc processBuf(self: Session, buf: Buf) =
  var hd = pop[fuse_in_header](buf)
  var req = Request (
    header: hd,
    data: buf.asBuf
  )
  req.dispatch(self)

proc loop*(self: Session) =
  # Always alloc max sized buffer but 100 bytes as safety mergin
  var buf = mkBuf(MAX_WRITE_BUFSIZE + 100)
  while not self.destroyed:
    if self.chan.fetch(buf) != 0:
      # TODO
      # ENODEV -> quit the loop by set 1 to se.destroyed
      discard
    else:
      self.processBuf(buf)

proc mount*(fs: LowlevelFs, mountpoint: string, options: openArray[string]) =
  let chan = connect(mountpoint, options)
  let se = mkSession(fs, chan)
  se.loop
  disconnect(chan)
