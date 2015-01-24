# fuse_lowlevel.h describes the reply protocols

import buf
import posix
import protocol

type TFileAttrObj = object
  mode: TMode

type TFileAttr = ref TFileAttrObj

proc fuse_attr_of(attr: TFileAttr): fuse_attr =
  discard

type TEntryParam = ref object 
  ino: Tino
  generation: uint64
  attr: TFileAttrObj
  attr_timeout: posix.Ttimespec
  entry_timeout: posix.Ttimespec

type Ttimespec = ref posix.Ttimespec
type TStatvfs = ref posix.TStatvfs
type Tflock = ref posix.Tflock

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

template defErr(typ: typedesc) =
  proc err*(self: `typ`, e: int) =
    self.raw.err(e)

template defNone(typ: typedesc) =
  proc none*(self: `typ`) =
    self.raw.ok(@[])

template defEntry(typ: typedesc) =
  proc entry*(self: `typ`, e: TEntryParam) =
    discard

template defCreate(typ: typedesc) =
  proc create*(self: typ, e: TEntryParam) =
    discard

template defAttr(typ: typedesc) =
  proc attr*(self: `typ`, attr: TFileAttr, ttl: Ttimespec) =
    discard

template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, li: string) =
    var s = li
    self.raw.ok(@[mkBuf[string](s)])

template defOpen(typ: typedesc) =
  proc open*(self: `typ`, fh: uint64, flags: uint32) =
    discard

template defWrite(typ: typedesc) =
  proc write*(self: `typ`, count: uint32) =
    var o = fuse_write_out(size:cast[uint32](count), padding:0)
    self.raw.ok(@[mkBuf(o)])

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
  proc statfs*(self: Statfs, s: TStatvfs) =
    discard

template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`, count: uint32) =
    discard

template defLock(typ: typedesc) =
  proc lock*(self: typ, lock: Tflock) =
    discard

template defBmap(typ: typedesc) =
  proc bmap(self: typ, idx: uint64) =
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
