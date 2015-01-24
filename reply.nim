# fuse_lowlevel.h describes the reply protocols

import buf
import posix
import protocol
# import request

type Sender = ref object of RootObj
proc send(self: Sender, dataSeq: openArray[Buf]) =
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
  self.sender.send(bufs)

proc ok(self: Raw, dataSeq: openArray[Buf]) =
  self.ack(0, dataSeq)

proc err(self: Raw, e: int) =
  self.ack(e, @[])

template defWrapper(typ: expr) =
  type `typ`* {. inject .} = ref object
    raw: Raw

template defEntry(typ: typedesc) =
  proc entry*(self: `typ`) =
    discard

template defErr(typ: typedesc) =
  proc err*(self: `typ`, e: int) =
    self.raw.err(e)

template defNone(typ: typedesc) =
  proc none*(self: `typ`) =
    self.raw.ok(@[])

template defAttr(typ: typedesc) =
  proc attr*(self: `typ`) =
    discard

# template defData(typ: typedesc) =
#   proc data*(self: `typ`, data: Buf) =
#     discard

template defBuf(typ: typedesc) =
  proc buf*(self: `typ`, data: Buf) =
    self.raw.ok(@[data])

template defOpen(typ: typedesc) =
  proc open*(self: `typ`) =
    discard

template defWrite(typ: typedesc) =
  proc write*(self: `typ`, count: uint32) =
    var o = fuse_write_out(size:cast[uint32](count), padding:0)
    self.raw.ok(@[mkBuf(o)])

template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`) =
    discard

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
proc readlink*(self: Readlink, link: string) =
  var s = link
  self.raw.ok(@[mkBuf[string](s)])
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
proc iov(self: Read) =
  discard

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
proc add*(Self: Readdir, ino: TIno, offset: TOff, kind: TMode, name: string): bool =
  discard
defBuf(Readdir)
# defData(Readdir)
defErr(Readdir)

defWrapper(Releasedir)
defErr(Releasedir)

defWrapper(Fsyncdir)
defErr(Fsyncdir)

defWrapper(Statfs)
proc statfs*(self: Statfs) =
  discard
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
proc create*(self: Create) =
  discard
defErr(Create)

defWrapper(Getlk)
proc lock*(self: Getlk) =
  discard
defErr(Getlk)
