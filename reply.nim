# fuse_lowlevel.h describes the reply protocols

import posix
import buf
import protocol

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
  
type Sender* = ref object of RootObj
proc send(self: Sender, dataSeq: openArray[Buf]): int =
  discard

type Raw = ref object
  sender: Sender
  unique: uint64

proc newRaw*(sender: Sender, unique: uint64): Raw =
  Raw(sender: sender, unique: unique)

proc ack(self: Raw, err: int, dataSeq: openArray[Buf]) =
  var bufs = newSeq[Buf](len(dataSeq) + 1)
  var sumLen = sizeof(fuse_out_header)
  for i, data in dataSeq:
    bufs[i+1] = data
    sumLen += len(data)
  var outH: fuse_out_header
  outH.unique = self.unique
  outH.error = cast[int32](err)
  outH.len = cast[uint32](sumLen)
  bufs[0] = mkBuf[fuse_out_header](outH)
  discard self.sender.send(bufs)

proc ok(self: Raw, dataSeq: openArray[Buf]) =
  self.ack(0, dataSeq)

proc err(self: Raw, e: int) =
  self.ack(e, @[])

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

template defEntry(typ: typedesc) =
  proc entry*(self: `typ`, hd: fuse_entry_out) =
    self.sendOk(hd)

type fuse_create_out = object
  hd0: fuse_entry_out
  hd1: fuse_open_out

template defCreate(typ: typedesc) =
  # I think these raw reply interface should be remained for simple replies
  # but some other bit complicated ones need human-friendly wrapper.
  proc create*(self: typ, hd0: fuse_entry_out, hd1: fuse_open_out) =
    let hd = fuse_create_out(hd0: hd0, hd1:hd1)
    # TODO use [hd0, hd1]
    self.sendOk(hd)

template defAttr(typ: typedesc) =
  proc attr*(self: `typ`, hd: fuse_attr_out) =
    self.sendOk(hd)

template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, li: string) =
    var s = li
    self.raw.ok(@[mkBuf(addr(s), len(s))])

template defOpen(typ: typedesc) =
  proc open*(self: `typ`, hd: fuse_open_out) =
    self.sendOk(hd)

template defWrite(typ: typedesc) =
  proc write*(self: `typ`, hd: fuse_write_out) =
    self.sendOk(hd)

template defBuf(typ: typedesc) =
  proc buf*(self: `typ`, data: Buf) =
    self.raw.ok(@[data])

# template defData(typ: typedesc) =
#   proc data*(self: `typ`, data: Buf) =
#     discard

template defIov(typ: typedesc) =
  proc iov*(self: typ, iov: openArray[TIOVec]) =
    var dataSeq = newSeq[Buf](len(iov))
    for i, io in iov:
      dataSeq[i] = mkBuf(io.iov_base, io.iov_len)
    self.raw.ok(dataSeq)

template defStatfs(typ: typedesc) =
  proc statfs*(self: typ, hd: fuse_statfs_out) =
    self.sendOk(hd)

template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`, hd: fuse_getxattr_out) =
    self.sendOk(hd)

template defLock(typ: typedesc) =
  proc lock*(self: typ, hd: fuse_lk_out) =
    self.sendOk(hd)

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

proc add*(Self: Readdir, ino: uint64, off: uint64, st_mode: uint32, theType: uint32, name: string) =
  proc align(x: int64): uint64 =
    let sz = cast[int64](sizeof(uint64))
    let y = (x + sz - 1) and not(sz - 1)
    cast[uint64](y)

  let namelen = cast[uint32](len(name))
  let entlen = sizeof(fuse_dirent) + namelen
  let entsize = align(entlen)
  let hd = fuse_dirent (
    ino: ino,
    off: off,
    namelen: namelen,
    `type`: (st_mode & 0170000) shr 12,
    )
  data.append[fuse_dirent](hd)
  var s = name
  copyMem(data.asPtr(), addr(s), len(s)) # FIXME null termination?
  data.advance(len(s))
  let padlen = entsize - entlen
  if (padlen > 0):
    zeroMem(data.asPtr(), padlen)

defBuf(Readdir)
# defData(Readdir)
defErr(Readdir)

defWrapper(Releasedir)
defErr(Releasedir)

defWrapper(Fsyncdir)
defErr(Fsyncdir)

defWrapper(Statfs)
defStatfs(Statfs)
defErr(Statfs)

defWrapper(SetXAttr)
defErr(SetXAttr)

defWrapper(GetXAttr)
defBuf(GetXAttr)
# defData(GetXAttr)
defXAttr(GetXAttr)
defErr(GetXAttr)

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
