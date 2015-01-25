# fuse_lowlevel.h describes the reply protocols

import posix
import buf
import protocol

# type TFileAttr* = ref object
#   ino*: uint64
#   size*: uint64
#   blocks*: uint64
#   atime*: Ttimespec
#   mtime*: Ttimespec
#   ctime*: Ttimespec
#   mode*: uint32
#   nlink*: uint32
#   uid*: uint32
#   gid*: uint32
#   rdev*: uint32
#   blksize*: uint32
#
# proc fuse_attr_of(st: TFileAttr): fuse_attr =
#   fuse_attr (
#     ino: st.ino,
#     size: st.st_size,
#     blocks: st.st_blocks,
#     atime: st.st_atime.tv_sec,
#     mtime: st.st_mtime.tv_sec,
#     ctime: st.st_ctime.tv_sec,
#     atimensec: st.st_atime.tv_nsec,
#     mtimensec: st.st_mtime.tv_nsec,
#     ctimensec: st.st_ctime.tv_nsec,
#     mode: st.st_mode,
#     nlink: st.st_nlink,
#     uid: st.st_uid,
#     gid: st.st_gid,
#     rdev: st.st_rdev,
#     blksize: st.st_blksize,
#   )
#
# proc fuse_kstatfs_of(st: TStatvfs): fuse_kstatfs =
#   fuse_kstatfs (
#     blocks: st.f_blocks,
#     bfree: st.f_bfree,
#     bavail: st.f_bavail,
#     files: st.f_files,
#     ffree: st.f_ffree,
#     bsize: st.f_bsize,
#     namelen: st.f_namemax,
#     frsize: st.f_frsize,
#   )

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

template defCreate(typ: typedesc) =
  proc create*(self: typ, hd0: fuse_entry_out, hd1: fuse_open_out) =
    discard

template defAttr(typ: typedesc) =
  proc attr*(self: `typ`, hd: fuse_attr_out) =
    self.sendOk(hd)

template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, li: string) =
    self.sendOk(li)

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
    discard

template defStatfs(typ: typedesc) =
  proc statfs*(self: typ, hd: fuse_kstatfs) =
    self.sendOk(hd)

template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`, hd: fuse_getxattr_out) =
    self.sendOk(hd)

template defLock(typ: typedesc) =
  proc lock*(self: typ, hd: fuse_lk_out) =
    self.sendOk(hd)

template defBmap(typ: typedesc) =
  proc bmap(self: typ, hd: fuse_bmap_out) =
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

# only few of the member in TStat input is used but comforming to c-fuse
# makes it easy to be backward-compatible.
proc add*(Self: Readdir, name: string, stat: TStat, off: posix.TOff) =
  discard

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
