#
#                           A FUSE binding for Nim
#                     (c) Copyright 2015 Akira Hayakawa
#

import os
import posix
import logging
import strutils

# ------------------------------------------------------------------------------

# Darwin doesn't allow version < 25
# It's recommended to set FUSE_USE_VERSION to 26 that's somehow 21 by default.
{.passC: "-DFUSE_USE_VERSION=26".}

{.passC: gorge("pkg-config --cflags fuse").}
{.passL: gorge("pkg-config --libs fuse").}

type
  OptionKind = enum
    kSome
    kNone

  Option*[T] = object
    case kind: OptionKind
    of kSome: v: T
    of kNone: nil

proc `$`*[T](o: Option[T]): string =
  case o.kind
  of kSome:
    "Some " & $o.v
  of kNone:
    "None"

proc Some[T](v: T): Option[T] =
  Option[T](kind: kSome, v: v)

proc None[T](): Option[T] =
  Option[T](kind: kNone)

proc isSome*[T](o: Option[T]): bool =
  o.kind == kSome

proc isNone*[T](o: Option[T]): bool =
  o.kind == kNone

proc unwrap*[T](o: Option[T]): T =
  o.v

# ------------------------------------------------------------------------------

type Buf* = ref object
  data: seq[char]
  size*: int
  pos*: int

proc mkBuf*(size: int): Buf =
  ## Make a buf object of `size` bytes
  var data = newSeq[char](size)
  Buf(
    data: data,
    size: size,
    pos: 0,
  )

proc extend*(self: Buf, size: int) =
  if (self.size >= size):
    return
  var newData = newSeq[char](size)
  copyMem(addr(newData[0]), addr(self.data[0]), self.size)

proc asPtr*(self: Buf, at: int): pointer =
  addr(self.data[at])

proc asPtr*(self: Buf): pointer =
  ## Get the current pos as the pointer
  addr(self.data[self.pos])

proc asBuf*(self: Buf): Buf =
  ## Get the [pos,] buffer like slicing
  Buf(
    data: self.data[self.pos..self.size-1],
    size: self.size - self.pos,
    pos: 0,
  )

proc `$`(self: IOVec): string =
  "IOVec(base:$1 len:$2)" % [$cast[ByteAddress](self.iov_base), $self.iov_len]

proc asIOVec*(self: Buf): IOVec =
  IOVec(
    iov_base: self.asPtr,
    iov_len: (csize_t)self.size,
  )

proc mkIOVecT*[T](o: var T): IOVec =
  IOVec(
    iov_base: addr(o),
    iov_len: (csize_t)sizeof(T),
  )

proc mkIOVecS*(s: var string): IOVec =
  IOVec(
    iov_base: addr(s[0]),
    iov_len: (csize_t)len(s),
  )

proc write*(self: Buf, p: pointer, size: int) =
  copyMem(self.asPtr, p, size)

proc write*[T](self: Buf, obj: T) =
  let sz = sizeof(T)
  var v = obj
  self.write(addr(v), sizeof(T))

proc mkBufT[T](o: T): Buf {.deprecated.} =
  result = mkBuf(sizeof(T))
  result.write(o)

proc nullTerminated*(s: string): string =
  ## Returns null terminated string of `s`
  ## The length is incremented
  ## e.g. mybuf.writeS("hoge".nullTerminated)
  result = s
  result.add(chr(0))

proc writeS*(self: Buf, s: string) =
  ## Write string `s` (Only the contents. Exclude null terminator)
  var vs = s
  self.write(addr(vs[0]), len(s))

proc parseS*(self: Buf): string =
  ## Parse a null-terminated string in the buffer
  $cstring(addr(self.data[0]))

proc mkBufS(s: string): Buf {.deprecated.} =
  ## Make a buffer from a string `s`
  result = mkBuf(len(s))
  result.writeS(s)

proc read*[T](self: Buf): T =
  ## Read a value of type T from the buffer
  cast[ptr T](self.asPtr)[]

proc pop*[T](self: Buf): T =
  ## Read and advance the position
  result = read[T](self)
  self.pos += sizeof(T)

# ------------------------------------------------------------------------------

let
  FUSE_KERNEL_VERSION* = 7'i32
  FUSE_KERNEL_MINOR_VERSION* = 8'i32
  FUSE_ROOT_ID* = 1

type fuse_attr = object
  ino: int64
  size: int64
  blocks: int64
  atime: int64
  mtime: int64
  ctime: int64
  when hostOS == "macosx":
    crtime: int64
  atimensec: int32
  mtimensec: int32
  ctimensec: int32
  when hostOS == "macosx":
    crtimensec: int32
  mode: int32
  nlink: int32
  uid: int32
  gid: int32
  rdev: int32
  when hostOS == "macosx":
    flags: int32

type fuse_kstatfs* = object
  blocks*: int64
  bfree*: int64
  bavail*: int64
  files*: int64
  ffree*: int64
  bsize*: int32
  namelen*: int32
  frsize*: int32
  padding: int32
  spare: array[6, int32]

type fuse_file_lock* = object
  start*: int64
  theEnd*: int64
  theType*: int32
  pid*: int32

let
  # Bitmasks for fuse_setattr_in.valid
  FATTR_MODE = 1 shl 0
  FATTR_UID = 1 shl 1
  FATTR_GID = 1 shl 2
  FATTR_SIZE = 1 shl 3
  FATTR_ATIME = 1 shl 4
  FATTR_MTIME = 1 shl 5
  FATTR_FH = 1 shl 6
when hostOS == "macosx":
  let
    FATTR_CRTIME = 1 shl 28
    FATTR_CHGTIME = 1 shl 29
    FATTR_BKUPTIME = 1 shl 30
    FATTR_FLAGS = 1 shl 31

let
  # Flags returned by the OPEN request
  FOPEN_DIRECT_IO* = 1 shl 0
  FOPEN_KEEP_CACHE* = 1 shl 1
when hostOS == "macosx":
  let
    FOPEN_PURGE_ATTR* = 1 shl 30
    FOPEN_PURGE_UBC* = 1 shl 31

let
  # INIT request/reply flags
  FUSE_ASYNC_READ* = 1 shl 0
  FUSE_POSIX_LOCKS* = 1 shl 1
when hostOS == "macosx":
  let
    FUSE_CASE_INSENSITIVE* = 1 shl 29
    FUSE_VOL_RENAME* = 1 shl 30
    FUSE_XTIMES* = 1 shl 31

let
  # Release flags
  FUSE_RELEASE_FLUSH = 1 shl 0

type fuse_opcode = enum
  FUSE_LOOKUP = 1
  FUSE_FORGET = 2
  FUSE_GETATTR = 3
  FUSE_SETATTR = 4
  FUSE_READLINK = 5
  FUSE_SYMLINK = 6
  FUSE_MKNOD = 8
  FUSE_MKDIR = 9
  FUSE_UNLINK = 10
  FUSE_RMDIR = 11
  FUSE_RENAME = 12
  FUSE_LINK = 13
  FUSE_OPEN = 14
  FUSE_READ = 15
  FUSE_WRITE = 16
  FUSE_STATFS = 17
  FUSE_RELEASE = 18
  FUSE_FSYNC = 20
  FUSE_SETXATTR = 21
  FUSE_GETXATTR = 22
  FUSE_LISTXATTR = 23
  FUSE_REMOVEXATTR = 24
  FUSE_FLUSH = 25
  FUSE_INIT = 26
  FUSE_OPENDIR = 27
  FUSE_READDIR = 28
  FUSE_RELEASEDIR = 29
  FUSE_FSYNCDIR = 30
  FUSE_GETLK = 31
  FUSE_SETLK = 32
  FUSE_SETLKW = 33
  FUSE_ACCESS = 34
  FUSE_CREATE = 35
  FUSE_INTERRUPT = 36
  FUSE_BMAP = 37
  FUSE_DESTROY = 38
  FUSE_SETVOLNAME = 61 # macosx
  FUSE_GETXTIMES = 62 # macosx
  FUSE_EXCHANGE = 63 # macosx

let
  FUSE_MIN_READ_BUFFER = 8192

type fuse_entry_out = object
  nodeid: int64
  generation: int64
  entry_valid: int64
  attr_valid: int64
  entry_valid_nsec: int32
  attr_valid_nsec: int32
  attr: fuse_attr

type fuse_forget_in = object
  nlookup: int64

type fuse_attr_out = object
  attr_valid: int64
  attr_valid_nsec: int32
  dummy: int32
  attr: fuse_attr

when hostOS == "macosx":
  type fuse_getxtimes_out = object
    bkuptime: int64
    crtime: int64
    bkuptimensec: int32
    crtimensec: int32

type fuse_mknod_in = object
  mode: int32
  rdev: int32

type fuse_mkdir_in = object
  mode: int32
  padding: int32

type fuse_rename_in = object
  newdir: int64

when hostOS == "macosx":
  type fuse_exchange_in = object
    olddir: int64
    newdir: int64
    options: int64

type fuse_link_in = object
  oldnodeid: int64

type fuse_setattr_in = object
  valid: int32
  padding: int32
  fh: int64
  size: int64
  unused1: int64
  atime: int64
  mtime: int64
  unused2: int64
  atimensec: int32
  mtimensec: int32
  unused3: int32
  mode: int32
  unused4: int32
  uid: int32
  gid: int32
  unused5: int32
  when hostOS == "macosx":
    bkuptime: int64
    chgtime: int64
    crtime: int64
    bkuptimensec: int32
    chgtimensec: int32
    crtimensec: int32
    flags: int32

type fuse_open_in = object
  flags: int32
  mode: int32

type fuse_open_out* = object
  fh*: int64
  open_flags*: int32
  padding: int32

type fuse_release_in = object
  fh: int64
  flags: int32
  release_flags: int32
  lock_owner: int64

type fuse_flush_in = object
  fh: int64
  unused: int32
  padding: int32
  lock_owner: int64

type fuse_read_in = object
  fh: int64
  offset: int64
  size: int32
  padding: int32

type fuse_write_in = object
  fh: int64
  offset: int64
  size: int32
  write_flags: int32

type fuse_write_out* = object
  size*: int32
  padding: int32

type fuse_statfs_out = object
  st: fuse_kstatfs

type fuse_fsync_in = object
  fh: int64
  fsync_flags: int32
  padding: int32

type fuse_setxattr_in = object
  size: int32
  flags: int32
  when hostOS == "macosx":
    position: int32
    padding: int32

type fuse_getxattr_in = object
  size: int32
  padding: int32
  when hostOS == "macosx":
    position: int32
    padding2: int32

type fuse_getxattr_out* = object
  size*: int32 ## request of in-kernel buffer size (byte)
  padding: int32

type fuse_lk_in = object
  fh: int64
  owner: int64
  lk: fuse_file_lock

type fuse_lk_out = object
  lk: fuse_file_lock

type fuse_access_in = object
  mask: int32
  padding: int32

type fuse_init_in = object
  major: int32
  minor: int32
  max_readahead: int32
  flags: int32

type fuse_init_out = object
  major: int32
  minor: int32
  max_readahead: int32
  flags: int32
  unused: int32
  max_write: int32

type fuse_interrupt_in = object
  unique: int64

type fuse_bmap_in = object
  theBlock: int64
  blocksize: int32
  padding: int32

type fuse_bmap_out* = object
  theBlock*: int64

type fuse_in_header* = object
  len*: int32
  opcode*: int32
  unique*: int64
  nodeid*: int64
  uid*: int32
  gid*: int32
  pid*: int32
  padding: int32

type fuse_out_header = object
  len: int32
  error: int32
  unique: int64

type fuse_dirent = object
  ino: int64
  off: int64
  namelen: int32
  theType: int32

# ------------------------------------------------------------------------------

type Timespec* = object
  sec*: int64
  nsec*: int32

type FileAttr* = ref object
  ino*: int64 # Tino?
  size*: int64 # int? Tblksize?
  blocks*: int64 # Tblkcnt?
  atime*: Timespec
  mtime*: Timespec
  ctime*: Timespec
  crtime*: Timespec # macosx
  mode*: int32
  nlink*: int32 ## number of hard links. TNlink?
  uid*: int32 # T
  gid*: int32 # TGid?
  rdev*: int32 # TDev?
  flags*: int32 # macosx

when hostOS == "macosx":
  proc fuse_attr_of(at: FileAttr): fuse_attr =
    result = fuse_attr (
      ino: at.ino,
      size: at.size,
      blocks: at.blocks,
      atime: at.atime.sec,
      mtime: at.mtime.sec,
      ctime: at.ctime.sec,
      crtime: at.crtime.sec,
      atimensec: at.atime.nsec,
      mtimensec: at.mtime.nsec,
      ctimensec: at.ctime.nsec,
      crtimensec: at.crtime.nsec,
      nlink: at.nlink,
      uid: at.uid,
      gid: at.gid,
      rdev: at.rdev,
      flags: at.flags,
    )
    debug("attr:$1", repr(result))
else:
  proc fuse_attr_of(at: FileAttr): fuse_attr =
    result = fuse_attr(
      ino: at.ino,
      size: at.size,
      blocks: at.blocks,
      atime: at.atime.sec,
      mtime: at.mtime.sec,
      ctime: at.ctime.sec,
      atimensec: at.atime.nsec,
      mtimensec: at.mtime.nsec,
      ctimensec: at.ctime.nsec,
      mode: at.mode,
      nlink: at.nlink,
      uid: at.uid,
      gid: at.gid,
      rdev: at.rdev,
    )
    debug("attr:$1", repr(result))

type Sender = ref object of RootObj
method send(self: Sender, iovs: var openArray[IOVec]): int =
  debug("NULLSender.send")
  0

type Raw = ref object
  sender: Sender
  unique: int64

proc newRaw(sender: Sender, unique: int64): Raw =
  Raw(sender: sender, unique: unique)

proc send(self: Raw, err: int, iovs: openArray[IOVec]) =
  assert(err <= 0)

  var iovL = newSeq[IOVec](len(iovs) + 1)
  var sumLen = sizeof(fuse_out_header)
  for i, iov in iovs:
    iovL[i+1] = iov
    debug("iov[$1]:$2", i, iov)
    sumLen += iov.iov_len.int

  var outH: fuse_out_header
  outH.unique = self.unique
  outH.error = err.int32
  outH.len = sumLen.int32
  debug("COMMON OUT:$1", repr(outH))
  iovL[0] = mkIOVecT(outH)

  discard self.sender.send(iovL)

proc ok(self: Raw, iovs: openArray[IOVec]) =
  self.send(0, iovs)

proc err(self: Raw, e: int) =
  self.send(e, @[])

template defWrapper(typ: untyped) =
  type `typ`* {. inject .} = ref object
    raw: Raw
  proc sendOk[T](self: `typ`, a: T) =
    var aa = a
    self.raw.ok(@[mkIOVecT(aa)])

template defOk(typ: typedesc) =
  proc ok*(self: typ, iovs: openArray[IOVec]) =
    self.raw.ok(iovs)

template defErr(typ: typedesc) =
  proc err*(self: `typ`, e: int) =
    assert(e <= 0)
    self.raw.err(e)

type TEntryOut* = ref object
  generation*: int64 ## (`ino`, `generation`) should be unique for the filesystem's lifetime.
  entry_timeout*: Timespec ## Validity timeout for the name.
  attr_timeout*: Timespec ## Validity timeout for the attributes.
  attr*: FileAttr

proc fuse_entry_out_of(eout: TEntryOut): fuse_entry_out =
  fuse_entry_out(
    nodeid: eout.attr.ino,
    generation: eout.generation,
    entry_valid: eout.entry_timeout.sec,
    entry_valid_nsec: eout.entry_timeout.nsec,
    attr_valid: eout.attr_timeout.sec,
    attr_valid_nsec: eout.attr_timeout.nsec,
    attr: fuse_attr_of(eout.attr)
  )

template defEntry(typ: typedesc) =
  proc entry(self: `typ`, hd: fuse_entry_out) =
    self.sendOk(hd)
  proc entry*(self: typ, eout: TEntryOut) =
    self.entry(fuse_entry_out_of(eout))

type fuse_create_out = object
  hd0: fuse_entry_out
  hd1: fuse_open_out

template defCreate(typ: typedesc) =
  proc create(self: typ, hd0: fuse_entry_out, hd1: fuse_open_out) =
    let hd = fuse_create_out(hd0: hd0, hd1:hd1)
    # TODO self.raw.ok(@[hd0, hd1])?
    self.sendOk(hd)
  proc create*(self: typ, eout: TEntryOut, oout: fuse_open_out) =
    self.create(fuse_entry_out_of(eout), oout)

template defAttr(typ: typedesc) =
  proc attr(self: `typ`, hd: fuse_attr_out) =
    self.sendOk(hd)
  proc attr*(self: typ, timeout: Timespec, at: FileAttr) =
    self.attr(
      fuse_attr_out(
        attr_valid: timeout.sec,
        attr_valid_nsec: timeout.nsec,
        attr: fuse_attr_of(at)))

template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, s: string) =
    var ss = s
    self.raw.ok(@[mkIOVecS(ss)])

template defOpen(typ: typedesc) =
  proc open*(self: `typ`, hd: fuse_open_out) =
    self.sendOk(hd)

template defWrite(typ: typedesc) =
  proc write*(self: `typ`, hd: fuse_write_out) =
    self.sendOk(hd)

template defBuf(typ: typedesc) =
  proc buf*(self: `typ`, iov: IOVec) =
    self.raw.ok(@[iov])

template defIov(typ: typedesc) =
  proc iov*(self: typ, iovs: openArray[IOVec]) =
    self.raw.ok(iovs)

template defStatfs(typ: typedesc) =
  proc statfs(self: typ, hd: fuse_statfs_out) =
    self.sendOk(hd)
  proc statfs*(self: typ, hd: fuse_kstatfs) =
    self.statfs(fuse_statfs_out(st:hd))

template defXAttr(typ: typedesc) =
  proc xattr*(self: `typ`, hd: fuse_getxattr_out) =
    self.sendOk(hd)

template defLock(typ: typedesc) =
  proc lock(self: typ, hd: fuse_lk_out) =
    self.sendOk(hd)
  proc lock*(self: typ, hd: fuse_file_lock) =
    lock(self, fuse_lk_out(lk: hd))

template defBmap(typ: typedesc) =
  proc bmap*(self: typ, hd: fuse_bmap_out) =
    self.sendOk(hd)

defWrapper(Any)
defOk(Any)
defErr(Any)

defWrapper(Lookup)
defEntry(Lookup)
defErr(Lookup)

defWrapper(Forget)

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
defIov(Read)
defErr(Read)

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

type Readdir* = ref object
  raw: Raw
  data: Buf

proc tryAdd*(self: Readdir, ino: int64, off: int64, st_mode: int32, name: string): bool =
  ## Try to add the entry
  ## If the buffer is too small for the entry then it returns false
  proc align(x:int): int =
    let sz = sizeof(int64)
    (x + sz - 1) and not(sz - 1)

  let namelen = len(name)
  let entlen = sizeof(fuse_dirent) + namelen
  let entsize = align(entlen)
  if self.data.pos + entsize > self.data.size:
    return false

  let pos0 = self.data.pos

  let hd = fuse_dirent(
    ino: ino,
    off: off,
    namelen: namelen.int32,
    theType: (st_mode and 0170000) shr 12
  )
  write[fuse_dirent](self.data, hd)
  self.data.pos += sizeof(fuse_dirent)

  let pos1 = self.data.pos

  self.data.writeS(name)
  self.data.pos += len(name)
  let pos2 = self.data.pos

  let padlen = entsize - entlen
  if padlen > 0:
    zeroMem(self.data.asPtr(), padlen.int)
    self.data.pos += padlen

  let pos3 = self.data.pos

  debug("try add dirent. name:$1 entlen:$2 entsize:$3 pos:$4->$5->$6->$7", name, entlen, entsize, pos0, pos1, pos2, pos3)
  return true

proc ok*(self: Readdir) =
  ## Ack by the current buffer contents
  ## If nothing is in the buffer it notifies the end of the stream.
  self.data.size = self.data.pos
  self.data.pos = 0
  self.raw.ok(@[self.data.asIOVec])
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
defXAttr(GetXAttr)
defErr(GetXAttr)

type GetXAttrData = ref object
  raw: Raw
  size: uint
proc ok*(self: GetXAttrData, data: IOVec) =
  if self.size < data.iov_len:
    self.raw.err(-ERANGE)
    return
  self.raw.ok(@[data])
defErr(GetXAttrData)

defWrapper(ListXAttr)
defXAttr(ListXAttr)
defErr(ListXAttr)

type ListXAttrData = ref object
  raw: Raw
  size: uint
proc ok*(self: ListXAttrData, keys: openArray[string]) =
  var ss = newSeq[string](len(keys))
  var size: uint
  for i, k in keys:
    ss[i] = k.nullTerminated
    size += (uint)len(ss[i])
  if self.size < size:
    self.raw.err(-ERANGE)
    return

  var iovs = newSeq[IOVec](len(ss))
  for i, s in ss:
    iovs[i] = ss[i].mkIOVecS
  self.raw.ok(iovs)

defErr(ListXAttrData)

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

defWrapper(Setlk)
defErr(Setlk)

defWrapper(Bmap)
defBmap(Bmap)
defErr(Bmap)

when hostOS == "macosx":
  defWrapper(SetVolname)
  defErr(SetVolname)

  defWrapper(Exchange)
  defErr(Exchange)

  defWrapper(GetXTimes)
  discard """
    ERROR: proc getxtimes() does not compile on OSX!

    fuse.nim(911, 12) Error: type mismatch: got (Raw, fuse_getxtimes_out)
      but expected one of:
      fuse.ok(self: Raw, iovs: openarray[IOVec])
      fuse.ok(self: Any, iovs: openarray[IOVec])
      fuse.ok(self: Readdir)
      fuse.ok(self: GetXAttrData, data: IOVec)
      fuse.ok(self: ListXAttrData, keys: openarray[string])
  """
  proc getxtimes(self: GetXTimes, bkuptime: Timespec, crtime: Timespec) =
    self.sendOk(fuse_get_xtimes_out (
      bkuptime: bkuptime.sec,
      crtime: crtime.sec,
      bkuptimensec: bkuptime.nsec,
      crtimensec: crtime.nsec,
    ))
  defErr(GetXTimes)

# ------------------------------------------------------------------------------


type fuse_args {. importc:"struct fuse_args", header:"<fuse.h>" .} = object
  argc: cint
  argv: cstringArray
  allocated: cint

proc fuse_mount_compat25(mountpoint: cstring, args: ptr fuse_args): cint {. importc, header:"<fuse.h>" .}
proc fuse_unmount_compat22(mountpoint: cstring) {. importc, header: "<fuse.h>" .}

type Channel = ref object
  mount_point: string
  fd: cint

proc connect(mount_point: string, mount_options: openArray[string]): Channel =
  var args = fuse_args(
    argc: mount_options.len.cint,
    argv: allocCStringArray(mount_options),
    allocated: 0, # control freeing by ourselves
  )
  let fd = fuse_mount_compat25(mount_point, addr(args))
  deallocCStringArray(args.argv)
  Channel(mount_point:mount_point, fd:fd)

proc disconnect(chan: Channel) =
  # FIXME only linux
  fuse_unmount_compat22(chan.mount_point)

proc fetch(chan: Channel, buf: Buf): int =
  assert(buf.pos == 0)

  debug("---------- START FETHCING ----------")
  let n = posix.read(chan.fd, buf.asPtr, buf.size)
  if n > 0:
    buf.size = n # drop remaining buffer
    result = 0
  else:
    result = osLastError().int
  debug("fetch result. fd:$1 err:$2", chan.fd, result)

type ChannelSender = ref object of Sender
  chan: Channel

method send(self: ChannelSender, iovs: var openArray[IOVec]): int =
  let n = iovs.len.cint
  var sumLen: uint
  for iov in iovs:
    sumLen += iov.iov_len
  let bytes = posix.writev(self.chan.fd, addr(iovs[0]), n)
  if bytes.uint != sumLen:
    debug("send NG. actual:$1(byte) expected:$2 error:$3 msg:$4", bytes, sumLen, osLastError(), osErrorMsg(osLastError()))
    result = -posix.EIO
  else:
    debug("send OK")
    result = 0

proc mkSender(self: Channel): ChannelSender =
  ChannelSender(chan: self)

# ------------------------------------------------------------------------------

type Request* = ref object
  header*: fuse_in_header
  data: Buf

type FuseFs* = ref object of RootObj
  ## Base class for FUSE filesystem
  ## User needs to implement a subclass
  ## These methods corrospond to fuse_lowlevel_ops in libfuse. Reasonable default
  ## implementations are provided here to get a mountable filesystem that does
  ## nothing.

method init*(self: FuseFs, req: Request): int =
  ## Initialize filesystem
  ## Called before any other filesystem method.
  0

method destroy*(self: FuseFs, req: Request) =
  ## Clean up filesystem
  ## Called on filesystem exit.
  discard

method lookup*(self: FuseFs, req: Request, parent: int64, name: string, reply: Lookup) =
  ## Look up a directory entry by name and get its attributes.
  reply.err(-ENOSYS)

method forget*(self: FuseFs, req: Request, ino: int64, nlookup: int64) =
  ## Forget about an inode
  ## The nlookup parameter indicates the number of lookups previously performed on
  ## this inode. If the filesystem implements inode lifetimes, it is recommended that
  ## inodes acquire a single reference on each lookup, and lose nlookup references on
  ## each forget. The filesystem may ignore forget calls, if the inodes don't need to
  ## have a limited lifetime. On unmount it is not guaranteed, that all referenced
  ## inodes will receive a forget message.
  discard

method getattr*(self: FuseFs, req: Request, ino: int64, reply: GetAttr) =
  ## Get file attributes
  reply.err(-ENOSYS)

method setattr*(self: FuseFs, req: Request, ino: int64, mode: Option[int32], uid: Option[int32], gid: Option[int32], size: Option[int64], atime: Option[Timespec], mtime: Option[Timespec], fh: Option[int64], crtime: Option[Timespec], chgtime: Option[Timespec], bkuptime: Option[Timespec], flags: Option[int32], reply: SetAttr) =
  ## Set file attributes
  reply.err(-ENOSYS)

method readlink*(self: FuseFs, req: Request, ino: int64, reply: Readlink) =
  ## Read symbolic link
  reply.err(-ENOSYS)

method mknod*(self: FuseFs, req: Request, parent: int64, name: string, mode: int32, rdev: int32, reply: Mknod) =
  ## Create file node
  ## Create a regular file, character device, block device, fifo or socket node.
  reply.err(-ENOSYS)

method mkdir*(self: FuseFs, req: Request, parent: int64, name: string, mode: int32, reply: Mkdir) =
  ## Create a directory
  reply.err(-ENOSYS)

method unlink*(self: FuseFs, req: Request, parent: int64, name: string, reply: Unlink) =
  ## Remove a file
  reply.err(-ENOSYS)

method rmdir*(self: FuseFs, req: Request, parent: int64, name: string, reply: Rmdir) =
  ## Remove a directory
  reply.err(-ENOSYS)

method symlink*(self: FuseFs, req: Request, link: string, parent: int64, name: string, reply: Symlink) =
  ## Create a symboilc link (`parent`, `name`) which, when evaluated, will lead to `link`
  ## ~= ln -s `link` (`parent`, `name`)
  reply.err(-ENOSYS)

method rename*(self: FuseFs, req: Request, parent: int64, name: string, newdir: int64, newname: string, reply: Rename) =
  ## Rename a file (`parent`, `name`) to (`newdir`, `newname`)
  reply.err(-ENOSYS)

method link*(self: FuseFs, req: Request, ino: int64, newparent: int64, newname: string, reply: Link) =
  ## Create a hard link (`newparent`, `newname`) to `ino`
  ## ~= ln `ino` (`newparent`, `newname`)
  ## Hard links aren't required for a working filesystem, and many successful filesystems don't support them.
  reply.err(-ENOSYS)

method open*(self: FuseFs, req: Request, ino: int64, flags: int32, reply: Open) =
  ## Open a file
  ## Open flags (with the exception of O_CREAT, O_EXCL, O_NOCTTY and O_TRUNC) are
  ## available in flags. Filesystem may store an arbitrary file handle (pointer, index,
  ## etc) in fh, and use this in other all other file operations (read, write, flush,
  ## release, fsync). Filesystem may also implement stateless file I/O and not store
  ## anything in fh. There are also some flags (direct_io, keep_cache) which the
  ## filesystem may set, to change the way the file is opened. See fuse_file_info
  ## structure in <fuse_common.h> for more details.
  reply.open(
    fuse_open_out(
      fh: 0,
      open_flags: 0,
    )
  )

method read*(self: FuseFs, req: Request, ino: int64, fh: int64, offset: int64, size: int32, reply: Read) =
  ## Read data
  ## Read should send exactly the number of bytes requested except on EOF or error,
  ## otherwise the rest of the data will be substituted with zeroes. An exception to
  ## this is when the file has been opened in 'direct_io' mode, in which case the
  ## return value of the read system call will reflect the return value of this
  ## operation. fh will contain the value set by the open method, or will be undefined
  ## if the open method didn't set any value.
  reply.err(-ENOSYS)

method write*(self: FuseFs, req: Request, ino: int64, fh: int64, offset: int64, data: Buf, flags: int32, reply: Write) =
  ## Write data
  ## Write should return exactly the number of bytes requested except on error. An
  ## exception to this is when the file has been opened in 'direct_io' mode, in
  ## which case the return value of the write system call will reflect the return
  ## value of this operation. fh will contain the value set by the open method, or
  ## will be undefined if the open method didn't set any value.
  reply.err(-ENOSYS)

method flush*(self: FuseFs, req: Request, ino: int64, fh: int64, lock_owner: int64, reply: Flush) =
  ## Flush method
  ## This is called on each close() of the opened file. Since file descriptors can
  ## be duplicated (dup, dup2, fork), for one open call there may be many flush
  ## calls. Filesystems shouldn't assume that flush will always be called after some
  ## writes, or that if will be called at all. fh will contain the value set by the
  ## open method, or will be undefined if the open method didn't set any value.
  ## NOTE: the name of the method is misleading, since (unlike fsync) the filesystem
  ## is not forced to flush pending writes. One reason to flush data, is if the
  ## filesystem wants to return write errors. If the filesystem supports file locking
  ## operations (setlk, getlk) it should remove all locks belonging to 'lock_owner'.
  reply.err(-ENOSYS)

method release*(self: FuseFs, req: Request, ino: int64, fh: int64, flags: int32, lock_owner: int64, flush: bool, reply: Release) =
  ## Release an open file
  ## Release is called when there are no more references to an open file: all file
  ## descriptors are closed and all memory mappings are unmapped. For every open
  ## call there will be exactly one release call. The filesystem may reply with an
  ## error, but error values are not returned to close() or munmap() which triggered
  ## the release. fh will contain the value set by the open method, or will be undefined
  ## if the open method didn't set any value. flags will contain the same flags as for
  ## open.
  reply.err(0)

method fsync*(self: FuseFs, req: Request, ino: int64, fh: int64, datasync: bool, reply: Fsync) =
  ## Synchronize file contents
  ## If the datasync parameter is non-zero, then only the user data should be flushed,
  ## not the meta data.
  reply.err(-ENOSYS)

method opendir*(self: FuseFs, req: Request, ino: int64, flags: int32, reply: Opendir) =
  ## Open a directory
  ## Filesystem may store an arbitrary file handle (pointer, index, etc) in fh, and
  ## use this in other all other directory stream operations (readdir, releasedir,
  ## fsyncdir). Filesystem may also implement stateless directory I/O and not store
  ## anything in fh, though that makes it impossible to implement standard conforming
  ## directory stream operations in case the contents of the directory can change
  ## between opendir and releasedir.
  reply.open(
    fuse_open_out(
      fh: 0,
      open_flags: 0,
    )
  )

method readdir*(self: FuseFs, req: Request, ino: int64, fh: int64, offset: int64, reply: Readdir) =
  ## Read directory
  ## Send a buffer filled using buffer.fill(), with size not exceeding the
  ## requested size. Send an empty buffer on end of stream. fh will contain the
  ## value set by the opendir method, or will be undefined if the opendir method
  ## didn't set any value.
  reply.err(-ENOSYS)

method releasedir*(self: FuseFs, req: Request, fh: int64, flags: int32, reply: Releasedir) =
  ## Release an open directory
  ## For every opendir call there will be exactly one releasedir call. fh will
  ## contain the value set by the opendir method, or will be undefined if the
  ## opendir method didn't set any value.
  reply.err(0)

method fsyncdir*(self: FuseFs, req: Request, ino: int64, fh: int64, datasync: bool, reply: Fsyncdir) =
  ## Synchronize directory contents
  ## If the datasync parameter is set, then only the directory contents should
  ## be flushed, not the meta data. fh will contain the value set by the opendir
  ## method, or will be undefined if the opendir method didn't set any value.
  reply.err(-ENOSYS)

method statfs*(self: FuseFs, req: Request, ino: int64, reply: Statfs) =
  ## Get file system statistics
  reply.statfs(fuse_kstatfs(
    blocks: 0,
    bfree: 0,
    bavail: 0,
    files: 0,
    ffree: 0,
    bsize: 512,
    namelen: 255,
    frsize: 0,
  ))

method setxattr*(self: FuseFs, req: Request, ino: int64, key: string, value: Buf, flags: int32, position: int32, reply: SetXAttr) =
  ## Set an extended attribute
  reply.err(-ENOSYS)

method getxattr*(self: FuseFs, req: Request, ino: int64, key: string, reply: GetXAttr) =
  ## Get an extended attribute
  reply.err(-ENOSYS)

method listxattr*(self: FuseFs, req: Request, ino: int64, reply: ListXAttr) =
  ## List extended attribute names
  reply.err(-ENOSYS)

method removexattr*(self: FuseFs, req: Request, ino: int64, name: string, reply: RemoveXAttr) =
  ## Remove an extended attribute
  reply.err(-ENOSYS)

method access*(self: FuseFs, req: Request, ino: int64, mask: int32, reply: Access) =
  ## Check file access permissions
  ## This will be called for the access() system call. If the 'default_permissions'
  ## mount option is given, this method is not called. This method is not called
  ## under Linux kernel versions 2.4.x
  reply.err(-ENOSYS)

method create*(self: FuseFs, req: Request, parent: int64, name: string, mode: int32, flags: int32, reply: Create) =
  ## Create and open a file
  ## If the file does not exist, first create it with the specified mode, and then
  ## open it. Open flags (with the exception of O_NOCTTY) are available in flags.
  ## Filesystem may store an arbitrary file handle (pointer, index, etc) in fh,
  ## and use this in other all other file operations (read, write, flush, release,
  ## fsync). There are also some flags (direct_io, keep_cache) which the
  ## filesystem may set, to change the way the file is opened. See fuse_file_info
  ## structure in <fuse_common.h> for more details. If this method is not
  ## implemented or under Linux kernel versions earlier than 2.6.15, the mknod()
  ## and open() methods will be called instead.
  reply.err(-ENOSYS)

method getlk*(self: FuseFs, req: Request, ino: int64, fh: int64, lock_owner: int64, start: int64, theEnd: int64, theType: int64, pid: int32, reply: Getlk) =
  ## Test for a POSIX file lock
  reply.err(-ENOSYS)

method setlk*(self: FuseFs, req: Request, ino: int64, fh: int64, lock_owner: int64, start: int64, theEnd: int64, theType: int64, pid: int32, sleep: bool, reply: Setlk) =
  ## Acquire, modify or release a POSIX file lock
  ## For POSIX threads (NPTL) there's a 1-1 relation between pid and owner, but
  ## otherwise this is not always the case.  For checking lock ownership,
  ## 'fi->owner' must be used. The l_pid field in 'struct flock' should only be
  ## used to fill in this field in getlk(). Note: if the locking methods are not
  ## implemented, the kernel will still allow file locking to work locally.
  ## Hence these are only interesting for network filesystems and similar.
  reply.err(-ENOSYS)

method bmap*(self: FuseFs, req: Request, ino: int64, blocksize: int32, idx: int64, reply: Bmap) =
  ## Map block index within file to block index within device
  ## Note: This makes sense only for block device backed filesystems mounted
  ## with the 'blkdev' option
  reply.err(-ENOSYS)

when hostOS == "macosx":
  method setvolname(self: FuseFs, req: Request, name: string, reply: SetVolname) =
    reply.err(-ENOSYS)

  method exchange(self: FuseFs, req: Request, parent: int64, name: string, newparent: int64, newname: string, options: int64, reply: Exchange) =
    reply.err(-ENOSYS)

  # ERROR ON OSX: `XTimes` is unknown!
  method getxtimes(self: FuseFs, req: Request, ino: int64, reply: GetXTimes) =
    reply.err(-ENOSYS)

# ------------------------------------------------------------------------------

type Session = ref object
  fs: FuseFs
  chan: Channel
  initialized: bool
  destroyed: bool

let
  MAX_WRITE_BUFSIZE = 16 * 1024 * 1024

proc mkRaw(req: Request, se: Session): Raw =
  newRaw(se.chan.mkSender, req.header.unique)

template defNew(typ: typedesc) =
  proc `new typ`(req: Request, se: Session): `typ` =
    typ(
      raw: mkRaw(req, se)
    )

defNew(Any)
# init
# destroy
defNew(Lookup)
# forget
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
  Readdir(
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

when hostOS == "macosx":
  defNew(SetVolname)
  defNew(Exchange)
  defNew(GetXTimes)

proc dispatch(req: Request, se: Session) =
  let anyReply = newAny(req, se)

  let opcode = req.header.opcode.fuse_opcode
  debug("opcode:$1", opcode)

  # if destroyed, any requests are discarded.
  if se.destroyed:
    debug("Session is destroyed")
    anyReply.err(-posix.EIO)
    return

  # before initialized, only FUSE_INIT is accepted.
  if not se.initialized:
    if opcode != FUSE_INIT:
      debug("Session isn't initialized yet but received opcode other than FUSE_INIT")
      anyReply.err(-posix.EIO)
      return

  let fs = se.fs
  let hd = req.header
  let data = req.data

  case opcode
  of FUSE_LOOKUP:
    debug("parseS start")
    let name = data.parseS
    debug("parseS done")
    fs.lookup(req, hd.nodeid, name, newLookup(req, se))
  of FUSE_FORGET:
    let arg = read[fuse_forget_in](req.data)
    fs.forget(req, hd.nodeid, arg.nlookup)
  of FUSE_GETATTR:
    fs.getattr(req, hd.nodeid, newGetAttr(req, se))
  of FUSE_SETATTR:
    let arg = pop[fuse_setattr_in](data)
    let mode = if (arg.valid and FATTR_MODE) != 0: Some(arg.mode) else: None[int32]()
    let uid = if (arg.valid and FATTR_UID) != 0: Some(arg.uid) else: None[int32]()
    let gid = if (arg.valid and FATTR_GID) != 0: Some(arg.gid) else: None[int32]()
    let size = if (arg.valid and FATTR_SIZE) != 0: Some(arg.size) else: None[int64]()
    let atime = if (arg.valid and FATTR_ATIME) != 0: Some(Timespec(sec:arg.atime, nsec:arg.atimensec)) else: None[Timespec]()
    let mtime = if (arg.valid and FATTR_MTIME) != 0: Some(Timespec(sec:arg.mtime, nsec:arg.mtimensec)) else: None[Timespec]()
    let fh = if (arg.valid and FATTR_FH) != 0: Some(arg.fh) else: None[int64]()
    when hostOS == "macosx":
      let crtime = if (arg.valid and FATTR_CRTIME) != 0: Some(Timespec(sec:arg.crtime, nsec:arg.crtimensec)) else: None[Timespec]()
      let chgtime = if (arg.valid and FATTR_CHGTIME) != 0: Some(Timespec(sec:arg.chgtime, nsec:arg.chgtimensec)) else: None[Timespec]()
      let bkuptime = if (arg.valid and FATTR_BKUPTIME) != 0: Some(Timespec(sec:arg.bkuptime, nsec:arg.bkuptimensec)) else: None[Timespec]()
      let flags = if (arg.valid and FATTR_FLAGS) != 0: Some(arg.flags) else: None[int32]()
      fs.setattr(req, hd.nodeid, mode, uid, gid, size, atime, mtime, fh, crtime, chgtime, bkuptime, flags, newSetAttr(req, se))
    else:
      fs.setattr(req, hd.nodeid, mode, uid, gid, size, atime, mtime, fh, None[Timespec](), None[Timespec](), None[Timespec](), None[int32](), newSetAttr(req, se))
  of FUSE_READLINK:
    fs.readlink(req, hd.nodeid, newReadlink(req, se))
  of FUSE_SYMLINK:
    let name = data.parseS
    data.pos += (len(name) + 1)
    let link = data.parseS
    se.fs.symlink(req, link, hd.nodeid, name, newSymlink(req, se))
  of FUSE_MKNOD:
    let arg = pop[fuse_mknod_in](data)
    let name = data.parseS
    fs.mknod(req, hd.nodeid, name, arg.mode, arg.rdev, newMknod(req, se))
  of FUSE_MKDIR:
    let arg = pop[fuse_mkdir_in](data)
    let name = data.parseS
    fs.mkdir(req, hd.nodeid, name, arg.mode, newMkdir(req, se))
  of FUSE_UNLINK:
    let name = data.parseS
    se.fs.unlink(req, hd.nodeid, name, newUnlink(req, se))
  of FUSE_RMDIR:
    let name = data.parseS
    fs.rmdir(req, hd.nodeid, name, newRmdir(req, se))
  of FUSE_RENAME:
    let arg = pop[fuse_rename_in](data)
    let name = data.parseS
    data.pos += (len(name) + 1)
    let newname = data.parseS
    fs.rename(req, hd.nodeid, name, arg.newdir, newname, newRename(req, se))
  of FUSE_LINK:
    let arg = pop[fuse_link_in](data)
    let newname = data.parseS
    fs.link(req, arg.oldnodeid, req.header.nodeid, newname, newLink(req, se))
  of FUSE_OPEN:
    let arg = read[fuse_open_in](data)
    fs.open(req, hd.nodeid, arg.flags, newOpen(req, se))
  of FUSE_READ:
    let arg = read[fuse_read_in](data)
    fs.read(req, hd.nodeid, arg.fh, arg.offset, arg.size, newRead(req, se))
  of FUSE_WRITE:
    let arg = pop[fuse_write_in](data)
    let remainingBuf = data.asBuf
    assert(remainingBuf.size == arg.size.int)
    fs.write(req, hd.nodeid, arg.fh, arg.offset, remainingBuf, arg.write_flags, newWrite(req, se))
  of FUSE_STATFS:
    fs.statfs(req, hd.nodeid, newStatfs(req, se))
  of FUSE_RELEASE:
    let arg = read[fuse_release_in](data)
    let flush = if (arg.release_flags and FUSE_RELEASE_FLUSH) == 0: false else: true
    fs.release(req, hd.nodeid, arg.fh, arg.flags, arg.lock_owner, flush, newRelease(req, se))
  of FUSE_FSYNC:
    let arg = read[fuse_fsync_in](data)
    let datasync = if (arg.fsync_flags and 1) == 0: false else: true
    fs.fsync(req, hd.nodeid, arg.fh, datasync, newFsync(req, se))
  of FUSE_SETXATTR:
    let arg = pop[fuse_setxattr_in](req.data)
    let key = req.data.parseS
    req.data.pos += (len(key) + 1)
    let value = req.data.asBuf
    when hostOS == "macosx":
      let pos = arg.position.int32
    else:
      let pos = 0.int32
    fs.setxattr(req, req.header.nodeid, key, value, arg.flags, pos, newSetXAttr(req, se))
  of FUSE_GETXATTR:
    # FIXME
    let arg = pop[fuse_getxattr_in](req.data)
    let key = req.data.parseS
    fs.getxattr(req, req.header.nodeid, key, newGetXAttr(req, se))
  of FUSE_LISTXATTR:
    # FIXME
    let arg = read[fuse_getxattr_in](req.data)
    fs.listxattr(req, req.header.nodeid, newListXAttr(req, se))
  of FUSE_REMOVEXATTR:
    let name = req.data.parseS
    fs.removexattr(req, req.header.nodeid, name, newRemoveXAttr(req, se))
  of FUSE_FLUSH:
    let arg = read[fuse_flush_in](req.data)
    fs.flush(req, req.header.nodeid, arg.fh, arg.lock_owner, newFlush(req, se))
  of FUSE_INIT:
    let arg = read[fuse_init_in](req.data)
    debug("INIT IN:$1", repr(arg))
    if (arg.major < 7) or (arg.minor < 6):
      anyReply.err(-EPROTO)
      return
    let res = fs.init(req)
    debug("INIT res:$1", res)
    if res != 0:
      anyReply.err(res)
      return
    var init = fuse_init_out(
      major: FUSE_KERNEL_VERSION,
      minor: FUSE_KERNEL_MINOR_VERSION,
      max_readahead: arg.max_readahead,
      flags: arg.flags,
      max_write: MAX_WRITE_BUFSIZE.int32,
    )
    debug("INIT OUT:$1", repr(init))
    se.initialized = true
    var initVar = init
    anyReply.ok(@[mkIOVecT(initVar)])
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
    let datasync = if (arg.fsync_flags and 1) == 0: false else: true
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
    let name = req.data.parseS
    fs.create(req, req.header.nodeid, name, arg.mode, arg.flags, newCreate(req, se))
  of FUSE_INTERRUPT:
    let arg = read[fuse_interrupt_in](req.data)
    newAny(req, se).err(-ENOSYS)
  of FUSE_BMAP:
    let arg = read[fuse_bmap_in](req.data)
    fs.bmap(req, req.header.nodeid, arg.blocksize, arg.theBlock, newBmap(req, se))
  of FUSE_DESTROY:
    fs.destroy(req)
    se.destroyed = true
    newAny(req, se).ok(@[])
  of FUSE_SETVOLNAME:
    when hostOS == "macosx":
      let name = data.parseS
      fs.setvolname(req, name, newSetVolname(req, se))
    else:
      discard
  of FUSE_GETXTIMES:
    when hostOS == "macosx":
      fs.getxtimes(req, hd.nodeid, newGetXTimes(req, se))
    else:
      discard
  of FUSE_EXCHANGE:
    when hostOS == "macosx":
      let arg = read[fuse_exchange_in](data)
      let oldname = data.parseS
      data.pos += (len(oldname) + 1)
      let newname = data.parseS
      fs.exchange(req, arg.olddir, oldname, arg.newdir, newname, arg.options, newExchange(req, se))
    else:
      discard

proc mkSession(fs: FuseFs, chan: Channel): Session =
  Session(
    fs: fs,
    chan: chan,
    initialized: false,
    destroyed: false,
  )

proc processBuf(self: Session, buf: Buf) =
  if buf.size < sizeof(fuse_in_header):
    error("fetched buffer doesn't contain header")
    return

  var hd = pop[fuse_in_header](buf)
  debug("COMMON IN:$1", repr(hd))
  if buf.size != hd.len.int:
    error("fetched buffer is too short")
    return

  var req = Request(
    header: hd,
    data: buf.asBuf
  )
  req.dispatch(self)

proc loop(self: Session) =
  # always alloc max sized buffer but 100 bytes as safety mergin
  let initsize = MAX_WRITE_BUFSIZE + 100
  var buf = mkBuf(initsize)
  while not self.destroyed:
    # reset for the next fetch
    buf.pos = 0
    buf.size = initsize
    let err = self.chan.fetch(buf)
    if err == 0:
      self.processBuf(buf)
    elif err == -EINTR or
         err == -EAGAIN or
         err == -ENOENT:
      discard
    elif err == -ENODEV:
      error("device not found")
      self.destroyed = true
    else:
      # raise
      discard # tmp

var se: Session = nil
proc handler() {.noconv.} =
  se.destroyed = true
  raiseOsError(osLastError()) # raising error from interrupt context is dangerous?

proc mount*(fs: FuseFs, mountpoint: string, options: openArray[string]) =
  ## Mount the given filesystem `fs` to the given mountpoint `mountpoint`
  var Lc = newConsoleLogger()
  # devel hides handler variable and instead use addHandler()
  when declared(logging.handlers):
    logging.handlers.add(Lc)
  else:
    logging.addHandler(Lc)

  let chan = connect(mountpoint, options)
  try:
    se = mkSession(fs, chan)
    setControlCHook(handler)
    se.loop
  finally:
    disconnect(chan)
