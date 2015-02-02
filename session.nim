import lowlevel
import protocol
import option
import channel
import buf
import reply
import unsigned
import posix
import times

type Session* = ref object 
  fs: LowlevelFs
  chan: Channel
  # proto_major: uint32
  # proto_minor: uint32
  initialized: bool
  destroyed: bool

proc doInit(self: Request) =
  discard

proc parseStr(self: Buf): string =
  var sq = cast[seq[char]](self.asPtr)
  $cstring(addr sq[0])

proc mkRaw(req: Request, se: Session): Raw =
  newRaw(se.chan.mkSender, req.header.unique)

template defNew(typ: typedesc) =
  proc `new typ`(req: Request, se: Session): `typ` =
    typ (
      raw: mkRaw(req, se)
    )

defNew(Any)
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
proc newReaddir(req: Request, se: Session, size: int): Readdir =
  Readdir (
    raw: mkRaw(req, se),
    data: mkBuf(size)
  )
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
      # newAny(req, se).err(-IOError)
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
    let mode = if (arg.valid and FATTR_MODE) != 0: Some(arg.mode) else: None[uint32]()
    let uid = if (arg.valid and FATTR_UID) != 0: Some(arg.uid) else: None[uint32]()
    let gid = if (arg.valid and FATTR_GID) != 0: Some(arg.gid) else: None[uint32]()
    let size = if (arg.valid and FATTR_SIZE) != 0: Some(arg.size) else: None[uint64]()
    let atime = if (arg.valid and FATTR_ATIME) != 0: Some(Ttimespec(tv_sec:arg.atime.Time, tv_nsec:arg.atimensec.int)) else: None[Ttimespec]()
    let mtime = if (arg.valid and FATTR_MTIME) != 0: Some(Ttimespec(tv_sec:arg.mtime.Time, tv_nsec:arg.mtimensec.int)) else: None[Ttimespec]()
    let fh = if (arg.valid and FATTR_FH) != 0: Some(arg.fh) else: None[uint64]()

    # TODO linux only
    fs.setattr(req, req.header.nodeid, mode, uid, gid, size, atime, mtime, fh, None[Ttimespec](), None[Ttimespec](), None[Ttimespec](), None[uint32](), newSetAttr(req, se))

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
    fs.mknod(req, req.header.nodeid, name, arg.mode, arg.rdev, newMknod(req, se))
  of FUSE_MKDIR:
    let arg = pop[fuse_mkdir_in](req.data)
    let name = req.data.parseStr
  of FUSE_UNLINK:
    let name = req.data.parseStr
    se.fs.unlink(req, req.header.nodeid, name, newUnlink(req, se))
  of FUSE_RMDIR:
    let name = req.data.parseStr
    fs.rmdir(req, req.header.nodeid, name, newRmdir(req, se))
  of FUSE_RENAME:
    let arg = pop[fuse_rename_in](req.data)
    let name = req.data.parseStr
    req.data.advance(len(name) + 1)
    let newname = req.data.parseStr
    fs.rename(req, req.header.nodeid, name, arg.newdir, newname, newRename(req, se))
  of FUSE_LINK:
    let arg = pop[fuse_link_in](req.data)
    let newname = req.data.parseStr
    fs.link(req, arg.oldnodeid, req.header.nodeid, newname, newLink(req, se))
  of FUSE_OPEN:
    let arg = read[fuse_open_in](req.data)
    fs.open(req, req.header.nodeid, arg.flags, newOpen(req, se))
  of FUSE_READ:
    let arg = read[fuse_read_in](req.data)
    fs.read(req, req.header.nodeid, arg.fh, arg.offset, arg.size, newRead(req, se))
  of FUSE_WRITE:
    let arg = pop[fuse_write_in](req.data)
    let data = req.data.mkBuf # get the remaining buffer
    assert(data.len == arg.size.int)
    fs.write(req, req.header.nodeid, arg.fh, arg.offset, data, arg.write_flags, newWrite(req, se))
  of FUSE_STATFS:
    fs.statfs(req, req.header.nodeid, newStatfs(req, se))
  of FUSE_RELEASE:
    let arg = read[fuse_release_in](req.data)
    let flush = if (arg.release_flags and FUSE_RELEASE_FLUSH) == 0: false else: true
    fs.release(req, req.header.nodeid, arg.fh, arg.flags, arg.lock_owner, flush, newRelease(req, se))
  of FUSE_FSYNC:
    let arg = read[fuse_fsync_in](req.data)
    let datasync = if (arg.fsync_flags and 1'u32) == 0: false else: true
    fs.fsync(req, req.header.nodeid, arg.fh, datasync, newFsync(req, se))
  of FUSE_SETXATTR:
    let arg = pop[fuse_setxattr_in](req.data)
    let key = req.data.parseStr
    req.data.advance(len(key) + 1)
    let value = req.data.mkBuf
    let pos = 0'u32
    fs.setxattr(req, req.header.nodeid, key, value, arg.flags, pos, newSetXAttr(req, se))
  of FUSE_GETXATTR:
    let arg = pop[fuse_getxattr_in](req.data)
    let key = req.data.parseStr
    fs.getxattr(req, req.header.nodeid, key, newGetXAttr(req, se))
  of FUSE_LISTXATTR:
    let arg = read[fuse_getxattr_in](req.data)
    fs.listxattr(req, req.header.nodeid, newListXAttr(req, se))
  of FUSE_REMOVEXATTR:
    let name = req.data.parseStr
    fs.removexattr(req, req.header.nodeid, name, newRemoveXAttr(req, se))
  of FUSE_FLUSH:
    let arg = read[fuse_flush_in](req.data)
    fs.flush(req, req.header.nodeid, arg.fh, arg.lock_owner, newFlush(req, se))
  of FUSE_INIT:
    let reply = newAny(req, se)
    var init = fuse_init_out (
      major: FUSE_KERNEL_VERSION,
      minor: FUSE_KERNEL_MINOR_VERSION,
    )
    reply.ok(@[mkBuf[fuse_init_out](init)])
  of FUSE_OPENDIR:
    let arg = read[fuse_open_in](req.data)
    fs.opendir(req, req.header.nodeid, arg.flags, newOpendir(req, se))
  of FUSE_READDIR:
    let arg = read[fuse_read_in](req.data)
    fs.readdir(req, req.header.nodeid, arg.fh, arg.offset, newReaddir(req, se, arg.size.int))
  of FUSE_RELEASEDIR:
    let arg = read[fuse_release_in](req.data)
    fs.releasedir(req, arg.fh, arg.flags, newReleasedir(req, se))
  of FUSE_FSYNCDIR:
    let arg = read[fuse_fsync_in](req.data)
    let datasync = if (arg.fsync_flags and 1'u32) == 0: false else: true
    fs.fsyncdir(req, req.header.nodeid, arg.fh, datasync, newFsyncdir(req, se))
  of FUSE_GETLK:
    let arg = read[fuse_lk_in](req.data)
    fs.getlk(req, req.header.nodeid, arg.fh, arg.owner, arg.lk.start, arg.lk.theEnd, arg.lk.theType, arg.lk.pid, newGetlk(req, se))
  of FUSE_SETLK, FUSE_SETLKW:
    let arg = read[fuse_lk_in](req.data)
    let sleep = if (opcode == FUSE_SETLKW): true else: false
    fs.setlk(req, req.header.nodeid, arg.fh, arg.owner, arg.lk.start, arg.lk.theEnd, arg.lk.theType, arg.lk.pid, sleep, newSetlk(req, se))
  of FUSE_ACCESS:
    let arg = read[fuse_access_in](req.data)
    fs.access(req, req.header.nodeid, arg.mask, newAccess(req, se))
  of FUSE_CREATE:
    let arg = pop[fuse_open_in](req.data)
    let name = req.data.parseStr
    fs.create(req, req.header.nodeid, name, arg.mode, arg.flags, newCreate(req, se))
  of FUSE_INTERRUPT:
    let arg = read[fuse_interrupt_in](req.data)
    newAny(req, se).err(-ENOSYS)
  of FUSE_BMAP:
    let arg = read[fuse_bmap_in](req.data)
    fs.bmap(req, req.header.nodeid, arg.theBlock, arg.blocksize, newBmap(req, se))
  of FUSE_DESTROY:
    fs.destroy(req)
    se.destroyed = true
    newAny(req, se).ok(@[])

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
