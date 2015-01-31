# fuse_lowlevel.h describes the reply protocols

import posix
import buf
import protocol
import unsigned

type FileAttr = ref object
  ino: uint64
  size: uint64
  blocks: uint64
  atime: Ttimespec
  mtime: Ttimespec
  ctime: Ttimespec
  mode: TMode
  nlink: uint32
  uid: uint32
  gid: uint32
  rdev: uint32

proc fuse_attr_of(at: FileAttr): fuse_attr =
  fuse_attr(
    ino: at.ino,
    size: at.size,
    atime: at.atime.tv_sec.uint64,
    atimensec: at.atime.tv_nsec.uint32,
    mtime: at.mtime.tv_sec.uint64,
    mtimensec: at.mtime.tv_nsec.uint32,
    ctime: at.ctime.tv_nsec.uint64,
    ctimensec: at.ctime.tv_nsec.uint32,
    mode: at.mode.uint32,
    nlink: at.nlink,
    uid: at.uid,
    gid: at.gid,
    rdev: at.rdev,
  )

type Sender* = ref object of RootObj
proc send(self: Sender, dataSeq: openArray[Buf]): int =
  discard

type Raw = ref object
  sender: Sender
  unique: uint64

proc newRaw*(sender: Sender, unique: uint64): Raw =
  Raw(sender: sender, unique: unique)

proc send(self: Raw, err: int, dataSeq: openArray[Buf]) =
  var bufs = newSeq[Buf](len(dataSeq) + 1)
  var sumLen = sizeof(fuse_out_header)
  for i, data in dataSeq:
    bufs[i+1] = data
    sumLen += len(data)
  var outH: fuse_out_header
  outH.unique = self.unique
  outH.error = err.int32
  outH.len = sumLen.uint32
  bufs[0] = mkBuf[fuse_out_header](outH)
  discard self.sender.send(bufs)

proc ok(self: Raw, dataSeq: openArray[Buf]) =
  self.send(0, dataSeq)

proc err(self: Raw, e: int) =
  self.send(e, @[])

template defWrapper(typ: expr) =
  type `typ`* {. inject .} = ref object
    raw: Raw
  proc sendOk[T](self: `typ`, a: T) =
    var b = a
    self.raw.ok(@[mkBuf[T](b)])

template defErr(typ: typedesc) =
  proc err*(self: `typ`, e: int) =
    self.raw.err(e)

template defNone(typ: typedesc) =
  proc none*(self: `typ`) =
    self.raw.ok(@[])

type TEntryOut = ref object
  generation: uint64
  entry_timeout: Ttimespec
  attr_timeout: Ttimespec
  attr: FileAttr

proc fuse_entry_out_of(eout: TEntryOut): fuse_entry_out =
  fuse_entry_out (
    nodeid: eout.attr.ino,
    generation: eout.generation,
    entry_valid: eout.entry_timeout.tv_sec.uint64,
    entry_valid_nsec: eout.entry_timeout.tv_nsec.uint32,
    attr_valid: eout.attr_timeout.tv_sec.uint64,
    attr_valid_nsec: eout.attr_timeout.tv_nsec.uint32,
    attr: fuse_attr_of(eout.attr)
  )

# ok
template defEntry(typ: typedesc) =
  proc entry(self: `typ`, hd: fuse_entry_out) =
    self.sendOk(hd)
  proc entry*(self: typ, eout: TEntryOut) =
    self.entry(fuse_entry_out_of(eout))

type fuse_create_out = object
  hd0: fuse_entry_out
  hd1: fuse_open_out

# ok
template defCreate(typ: typedesc) =
  # I think these raw reply interface should be remained for simple replies
  # but some other bit complicated ones need human-friendly wrapper.
  proc create(self: typ, hd0: fuse_entry_out, hd1: fuse_open_out) =
    let hd = fuse_create_out(hd0: hd0, hd1:hd1)
    # TODO use [hd0, hd1]
    self.sendOk(hd)
  proc create*(self: typ, eout: TEntryOut, oout: fuse_open_out) =
    self.create(fuse_entry_out_of(eout), oout)

# ok
template defAttr(typ: typedesc) =
  proc attr(self: `typ`, hd: fuse_attr_out) =
    self.sendOk(hd)
  proc attr*(self: typ, timeout: Ttimespec, at: FileAttr) =
    self.attr(
      fuse_attr_out(
        attr_valid: timeout.tv_sec.uint64,
        attr_valid_nsec: timeout.tv_nsec.uint32,
        attr: fuse_attr_of(at)))

# ok
template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, li: string) =
    var s = li
    self.raw.ok(@[mkBuf(addr(s), len(s))])

# ok
template defOpen(typ: typedesc) =
  proc open*(self: `typ`, hd: fuse_open_out) =
    self.sendOk(hd)

# ok
template defWrite(typ: typedesc) =
  proc write*(self: `typ`, hd: fuse_write_out) =
    self.sendOk(hd)

# ok
template defBuf(typ: typedesc) =
  proc buf*(self: `typ`, data: Buf) =
    self.raw.ok(@[data])

# template defData(typ: typedesc) =
#   proc data*(self: `typ`, data: Buf) =
#     discard

# FIXME use openArray[Buf]
template defIov(typ: typedesc) =
  proc iov*(self: typ, iov: openArray[TIOVec]) =
    var dataSeq = newSeq[Buf](len(iov))
    for i, io in iov:
      dataSeq[i] = mkBuf(io.iov_base, io.iov_len)
    self.raw.ok(dataSeq)

# ok
template defStatfs(typ: typedesc) =
  proc statfs*(self: typ, hd: fuse_statfs_out) =
    self.sendOk(hd)
  proc statfs(self: typ, hd: fuse_kstatfs) =
    self.statfs(fuse_statfs_out(st:hd))

# ok
template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`, hd: fuse_getxattr_out) =
    self.sendOk(hd)

# ok
template defLock(typ: typedesc) =
  proc lock(self: typ, hd: fuse_lk_out) =
    self.sendOk(hd)
  proc lock*(self: typ, hd: fuse_file_lock) =
    lock(self, fuse_lk_out(lk: hd))

# ok
template defBmap(typ: typedesc) =
  proc bmap*(self: typ, hd: fuse_bmap_out) =
    self.sendOk(hd)

defWrapper(Lookup)
defEntry(Lookup)
defErr(Lookup)

defWrapper(Forget)
defNone(Forget)

defWrapper(GetAttr)
defAttr(GetAttr)
defErr(GetAttr)

defWrapper(SetAttr)
defAttr(SetAttr)
defErr(SetAttr)

defWrapper(Readlink)
defReadlink(Readlink)
defErr(Readlink)

defWrapper(Mknod)
defEntry(Mknod)
defErr(Mknod)

defWrapper(Mkdir)
defEntry(Mkdir)
defErr(Mkdir)

defWrapper(Unlink)
defErr(Unlink)

defWrapper(Rmdir)
defErr(Rmdir)

defWrapper(Symlink)
defEntry(Symlink)
defErr(Symlink)

defWrapper(Rename)
defErr(Rename)

defWrapper(Link)
defEntry(Link)
defErr(Link)

defWrapper(Open)
defOpen(Open)
defErr(Open)

defWrapper(Read)
defBuf(Read)
# defData(Read)
defIov(Read)

defWrapper(Write)
defWrite(Write)
defErr(Write)

defWrapper(Flush)
defErr(Flush)

defWrapper(Release)
defErr(Release)

defWrapper(Fsync)
defErr(Fsync)

defWrapper(Opendir)
defOpen(Opendir)
defErr(Opendir)

type Readdir = ref object
  raw: Raw
  data: Buf

proc resized(self: Readdir, newsize: int): Readdir =
  self.data = mkBuf(newsize)
  self

proc tryAdd(self: Readdir, ino: uint64, off: uint64, st_mode: uint32, name: string): bool =
  proc align(x:int): int =
    let sz = sizeof(uint64)
    (x + sz - 1) and not(sz - 1)

  let namelen = len(name)
  let entlen = sizeof(fuse_dirent) + namelen
  let entsize = align(entlen)
  if self.data.pos + entsize > self.data.len:
    return false

  let hd = fuse_dirent(
    ino: ino,
    off: off,
    namelen: namelen.uint32,
    theType: (st_mode and 0170000) shr 12
  )
  append[fuse_dirent](self.data, hd)
  var s = name
  copyMem(self.data.asPtr(), addr(s), len(s))
  self.data.advance(len(s))
  let padlen = entsize - entlen
  if (padlen > 0):
    zeroMem(self.data.asPtr(), padlen.int)

  return true

# if not reply.tryAdd(...):
#   reply.ok()
proc tryAdd*(self: Readdir, ino: uint64, idx: uint64, mode: TMode, name: string): bool =
  tryAdd(self, ino, idx, mode.uint32, name)

defBuf(Readdir) # should not be called by client
# defData(Readdir)
defErr(Readdir)

proc ok*(self: Readdir) =
  # send an empty buffer on end of the stream
  self.data.dropUnused()
  self.buf(self.data)
 
defWrapper(Releasedir)
defErr(Releasedir)

defWrapper(Fsyncdir)
defErr(Fsyncdir)

defWrapper(Statfs)
defStatfs(Statfs)
defErr(Statfs)

defWrapper(SetXAttr)
defErr(SetXAttr)

# FIXME not available
# TODO (if size > 0)
defWrapper(GetXAttr)
defBuf(GetXAttr)
# defData(GetXAttr)
defXAttr(GetXAttr)
defErr(GetXAttr)

# FIXME not available
# TODO (if size > 0)
defWrapper(ListXAttr)
defBuf(ListXAttr)
# defData(ListXAttr)
defXAttr(ListXAttr)
defErr(ListXAttr)

defWrapper(RemoveXAttr)
defErr(RemoveXAttr)

defWrapper(Access)
defErr(Access)

defWrapper(Create)
defCreate(Create)
defErr(Create)

defWrapper(Getlk)
defLock(Getlk)
defErr(Getlk)
