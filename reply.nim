# fuse_lowlevel.h describes the reply protocols

import buf
import posix
import protocol
# import request

type Sender = ref object of RootObj
proc send(self: Sender, dataSeq: openArray[Buf]) =
  discard

type Raw = ref object
  unique: uint64
  sender: Sender

proc newRaw(sender: Sender, unique: uint64): Raw =
  discard

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
  self.sender.send(bufs)

proc ok(self: Raw, dataSeq: openArray[Buf]) =
  self.ack(0, dataSeq)

proc err(self: Raw, err: int) =
  self.ack(err, @[])

template mkWrapper(typ: expr) =
  type `typ` {. inject .} = ref object
    raw: Raw

template mkEntry(typ: typedesc) =
  proc entry*(self: `typ`) =
    discard

template mkErr(typ: typedesc) =
  proc err*(self: `typ`) =
    discard

template mkNone(typ: typedesc) =
  proc none(self: `typ`) =
    discard

template mkAttr(typ: typedesc) =
  proc attr(self: `typ`) =
    discard

template mkData(typ: typedesc) =
  proc data(self: `typ`) =
    discard

template mkOpen(typ: typedesc) =
  proc open(self: `typ`) =
    discard

template mkWrite(typ: typedesc) =
  proc write(self: `typ`) =
    discard

template mkXAttr(typ: typedesc) =
  proc xattr(self: `typ`) =
    discard

mkWrapper(Lookup)
mkEntry(Lookup)
mkErr(Lookup)

mkWrapper(Forget)
mkNone(Forget)

mkWrapper(GetAttr)
mkAttr(GetAttr)
mkErr(GetAttr)

mkWrapper(SetAttr)
mkAttr(SetAttr)
mkErr(SetAttr)

mkWrapper(Readlink)
proc readlink(self: Readlink, link: string) =
  var s = link
  self.raw.ok(@[mkBuf[string](s)])
mkErr(Readlink)

mkWrapper(Mknod)
mkEntry(Mknod)
mkErr(Mknod)

mkWrapper(Mkdir)
mkEntry(Mkdir)
mkErr(Mkdir)

mkWrapper(Unlink)
mkErr(Unlink)

mkWrapper(Rmdir)
mkErr(Rmdir)

mkWrapper(Symlink)
mkEntry(Symlink)
mkErr(Symlink)

mkWrapper(Rename)
mkErr(Rename)

mkWrapper(Link)
mkEntry(Link)
mkErr(Link)

mkWrapper(Open)
mkOpen(Open)
mkErr(Open)

mkWrapper(Read)
# mkBuf(Read)
mkData(Read)
proc iov(self: Read) =
  discard

mkWrapper(Write)
mkWrite(Write)
mkErr(Write)

mkWrapper(Flush)
mkErr(Flush)

mkWrapper(Release)
mkErr(Release)

mkWrapper(Fsync)
mkErr(Fsync)

mkWrapper(Opendir)
mkOpen(Opendir)
mkErr(Opendir)

type Readdir = ref object
  raw: Raw
  data: Buf
proc add*(Self: Readdir, ino: TIno, offset: TOff, kind: TMode, name: string): bool =
  discard
# mkBuf(Directory)
mkData(Readdir)
mkErr(Readdir)

mkWrapper(Releasedir)
mkErr(Releasedir)

mkWrapper(Fsyncdir)
mkErr(Fsyncdir)

mkWrapper(Statfs)
proc statfs(self: Statfs) =
  discard
mkErr(Statfs)

mkWrapper(SetXAttr)
mkErr(SetXAttr)

mkWrapper(GetXAttr)
# mkBuf(GetXAttr)
mkData(GetXAttr)
mkXAttr(GetXAttr)
mkErr(GetXAttr)

mkWrapper(ListXAttr)
mkData(ListXAttr)
mkXAttr(ListXAttr)
mkErr(ListXAttr)

mkWrapper(RemoveXAttr)
mkErr(RemoveXAttr)

mkWrapper(Access)
mkErr(Access)

mkWrapper(Create)
proc create(self: Create) =
  discard
mkErr(Create)

mkWrapper(Getlk)
proc lock(self: Getlk) =
  discard
mkErr(Getlk)
