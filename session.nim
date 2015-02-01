import lowlevel
import protocol
import channel
import buf
import reply
import unsigned

type Session* = ref object 
  fs: LowlevelFs
  chan: Channel
  # proto_major: uint32
  # proto_minor: uint32
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

# init
# destroy
defNew(Lookup)
# defNew(Forget)
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
# readdir
defNew(Releasedir)
defNew(Fsyncdir)
defNew(Statfs)
defNew(SetXAttr)
defNew(GetXAttr)
defNew(ListXAttr)
defNew(RemoveXAttr)
defNew(Access)
defNew(Create)
defNew(Getlk)
defNew(Setlk)
defNew(Bmap)
  
proc dispatch*(req: Request, se: Session) =
  let opcode = req.header.opcode.fuse_opcode

  # if destroyed, any requests are discarded.
  if se.destroyed:
    return

  # before initialized, only FUSE_INIT is accepted.
  if not se.initialized:
    if opcode != FUSE_INIT:
      return

  let fs = se.fs

  case opcode
  of FUSE_LOOKUP:
    let name = req.data.parseStr
    fs.lookup(req, req.header.nodeid, name, newLookup(req, se))
  of FUSE_FORGET:
    let arg = read[fuse_forget_in](req.data)
    fs.forget(req, req.header.nodeid, arg.nlookup)
  of FUSE_GETATTR:
    fs.getattr(req, req.header.nodeid, newGetAttr(req, se))
  of FUSE_SETATTR:
    let arg = pop[fuse_setattr_in](req.data)
    nop()
  of FUSE_READLINK:
    fs.readlink(req, req.header.nodeid, newReadlink(req, se))
  of FUSE_SYMLINK:
    let name = req.data.parseStr
    req.data.advance(len(name) + 1)
    let link = req.data.parseStr
    se.fs.symlink(req, req.header.nodeid, name, link, newSymlink(req, se))
  of FUSE_MKNOD:
    let arg = pop[fuse_mknod_in](req.data)
    let name = req.data.parseStr
    nop()
  of FUSE_MKDIR:
    let arg = pop[fuse_mkdir_in](req.data)
    let name = req.data.parseStr
  of FUSE_UNLINK:
    let name = req.data.parseStr
    se.fs.unlink(req, req.header.nodeid, name, newUnlink(req, se))
  of FUSE_RMDIR:
    let name = req.data.parseStr
    nop()
  of FUSE_RENAME:
    let arg = pop[fuse_rename_in](req.data)
    let name = req.data.parseStr
    req.data.advance(len(name) + 1)
    let newname = req.data.parseStr
    nop()
  of FUSE_LINK:
    let arg = pop[fuse_link_in](req.data)
    let newname = req.data.parseStr
    fs.link(req, arg.oldnodeid, req.header.nodeid, newname, newLink(req, se))
  of FUSE_OPEN:
    let arg = read[fuse_open_in](req.data)
    nop()
  of FUSE_READ:
    let arg = read[fuse_read_in](req.data)
    nop()
  of FUSE_WRITE:
    let arg = pop[fuse_write_in](req.data)
    let data = req.data.mkBuf # get the remaining buffer
    assert(data.len == arg.size.int)
    nop()
  of FUSE_STATFS:
    fs.statfs(req, req.header.nodeid, newStatfs(req, se))
    nop()
  of FUSE_RELEASE:
    let arg = pop[fuse_release_in](req.data)
    let flush = if (arg.release_flags and FUSE_RELEASE_FLUSH) == 0: false else: true
    nop()
  of FUSE_FSYNC:
    let arg = pop[fuse_fsync_in](req.data)
    let datasync = if (arg.fsync_flags and 1'u32) == 0: false else: true
    nop()
  of FUSE_SETXATTR:
    let arg = pop[fuse_setxattr_in](req.data)
    let key = req.data.parseStr
    req.data.advance(len(key) + 1)
    let value = req.data.mkBuf
    let pos = 0'u32
    fs.setxattr(req, req.header.nodeid, key, value, arg.flags, pos, newSetXAttr(req, se))
    nop()
  of FUSE_GETXATTR:
    let arg = pop[fuse_getxattr_in](req.data)
    let key = req.data.parseStr
    fs.getxattr(req, req.header.nodeid, key, newGetXAttr(req, se))
  of FUSE_LISTXATTR:
    let arg = pop[fuse_getxattr_in](req.data)
    fs.listxattr(req, req.header.nodeid, newListXAttr(req, se))
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
    let arg = read[fuse_release_in](req.data)
    fs.releasedir(req, arg.fh, arg.flags, newReleasedir(req, se))
  of FUSE_FSYNCDIR:
    nop()
  of FUSE_GETLK:
    nop()
  of FUSE_SETLK, FUSE_SETLKW:
    let sleep = if (opcode == FUSE_SETLKW): true else: false
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
    fs.destroy(req)
    se.destroyed = true
    # TODO
  else:
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
      # FIXME Don't use the whole buffer. Must shrink
      self.processBuf(buf)

proc mount*(fs: LowlevelFs, mountpoint: string, options: openArray[string]) =
  let chan = connect(mountpoint, options)
  let se = mkSession(fs, chan)
  se.loop
  disconnect(chan)
