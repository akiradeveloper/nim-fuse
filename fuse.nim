#
#                 A FUSE binding for Nim
#           (c) Copyright 2015 Akira Hayakawa
#

import os
import posix
import logging
import unsigned
import times

# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------

type Buf* = ref object
  data: seq[char]
  size*: int
  pos*: int # TODO rename to cursor

proc mkBuf*(size: int): Buf =
  ## Make a buf object of `size` bytes
  var data = newSeq[char](size)
  Buf(
    data: data,
    size: size,
    pos: 0,
  )

proc asPtr*(self: Buf): pointer =
  ## Get the current pos as the pointer
  addr(self.data[self.pos])

proc asBuf*(self: Buf): Buf =
  ## Get the [pos,] buffer like slicing
  Buf (
    data: self.data[self.pos..self.size-1],
    size: self.size - self.pos,
    pos: 0,
  )

proc write*(self: Buf, p: pointer, size: int) =
  copyMem(self.asPtr, p, size)

proc write*[T](self: Buf, obj: T) =
  let sz = sizeof(T)
  var v = obj
  self.write(addr(v), sizeof(T))

proc mkBufT*[T](o: T): Buf =
  result = mkBuf(sizeof(T))
  result.write(o)

proc nullTerminated*(s: string): string =
  ## Returns null terminated string of `s`
  ## The length is incremented
  ## e.g. mybuf.writeS("hoge".nullTerminated)
  var ss = s
  ss.safeAdd(chr(0))
  ss

proc writeS*(self: Buf, s: string) =
  ## Write string `s` (Only the contents. Exclude null terminator)
  var vs = s
  self.write(addr(vs[0]), len(s))

proc parseS*(self: Buf): string =
  ## Parse a null-terminated string in the buffer  
  $cstring(addr(self.data[0]))

proc mkBufS*(s: string): Buf =
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

# -----------------------------------------------------------------------------

let
  FUSE_KERNEL_VERSION* = 7'u32
  FUSE_KERNEL_MINOR_VERSION* = 8'u32
  FUSE_ROOT_ID* = 1

type fuse_attr* = object
  ino*: uint64
  size*: uint64
  blocks*: uint64
  atime*: uint64
  mtime*: uint64
  ctime*: uint64
  atimensec*: uint32
  mtimensec*: uint32
  ctimensec*: uint32
  mode*: uint32
  nlink*: uint32
  uid*: uint32
  gid*: uint32
  rdev*: uint32
  
type fuse_kstatfs* = object
  blocks*: uint64
  bfree*: uint64
  bavail*: uint64
  files*: uint64
  ffree*: uint64
  bsize*: uint32
  namelen*: uint32
  frsize*: uint32
  padding: uint32
  spare: array[6, uint32]

type fuse_file_lock* = object
  start*: uint64
  theEnd*: uint64
  theType*: uint32
  pid*: uint32

let
  # Bitmasks for fuse_setattr_in.valid
  FATTR_MODE* = 1'u32 shl 0
  FATTR_UID* = 1'u32 shl 1
  FATTR_GID* = 1'u32 shl 2
  FATTR_SIZE* = 1'u32 shl 3
  FATTR_ATIME* = 1'u32 shl 4
  FATTR_MTIME* = 1'u32 shl 5
  FATTR_FH* = 1'u32 shl 6

  # Flags returned by the OPEN request
  FOPEN_DIRECT_IO* = 1'u32 shl 0
  FOPEN_KEEP_CACHE* = 1'u32 shl 1

  # INIT request/reply flags
  FUSE_ASYNC_READ* = 1'u32 shl 0
  FUSE_POSIX_LOCKS* = 1'u32 shl 1

  # Release flags
  FUSE_RELEASE_FLUSH* = 1'u32 shl 0

type fuse_opcode* = enum
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

let
  FUSE_MIN_READ_BUFFER* = 8192

type fuse_entry_out* = object
  nodeid*: uint64
  generation*: uint64 
  entry_valid*: uint64
  attr_valid*: uint64
  entry_valid_nsec*: uint32
  attr_valid_nsec*: uint32
  attr*: fuse_attr

type fuse_forget_in* = object
  nlookup*: uint64

type fuse_attr_out* = object
  attr_valid*: uint64
  attr_valid_nsec*: uint32
  dummy: uint32
  attr*: fuse_attr

type fuse_mknod_in* = object
  mode*: uint32
  rdev*: uint32
  
type fuse_mkdir_in* = object
  mode*: uint32
  padding: uint32

type fuse_rename_in* = object
  newdir*: uint64

type fuse_link_in* = object
  oldnodeid*: uint64

type fuse_setattr_in* = object
  valid*: uint32
  padding: uint32
  fh*: uint64
  size*: uint64
  unused1: uint64
  atime*: uint64
  mtime*: uint64
  unused2: uint64
  atimensec*: uint32
  mtimensec*: uint32
  unused3: uint32
  mode*: uint32
  unused4: uint32
  uid*: uint32
  gid*: uint32
  unused5: uint32

type fuse_open_in* = object
  flags*: uint32
  mode*: uint32

type fuse_open_out* = object
  fh*: uint64
  open_flags*: uint32
  padding: uint32

type fuse_release_in* = object
  fh*: uint64
  flags*: uint32
  release_flags*: uint32
  lock_owner*: uint64

type fuse_flush_in* = object
  fh*: uint64
  unused: uint32
  padding: uint32
  lock_owner*: uint64

type fuse_read_in* = object
  fh*: uint64
  offset*: uint64
  size*: uint32
  padding: uint32

type fuse_write_in* = object
  fh*: uint64
  offset*: uint64
  size*: uint32
  write_flags*: uint32

type fuse_write_out* = object
  size*: uint32
  padding: uint32

type fuse_statfs_out* = object
  st*: fuse_kstatfs

type fuse_fsync_in* = object
  fh*: uint64
  fsync_flags*: uint32
  padding: uint32

type fuse_setxattr_in* = object
  size*: uint32
  flags*: uint32

type fuse_getxattr_in* = object
  size*: uint32
  padding: uint32

type fuse_getxattr_out* = object
  size*: uint32
  padding: uint32

type fuse_lk_in* = object
  fh*: uint64
  owner*: uint64
  lk*: fuse_file_lock

type fuse_lk_out* = object
  lk*: fuse_file_lock

type fuse_access_in* = object
  mask*: uint32
  padding: uint32

type fuse_init_in* = object
  major*: uint32
  minor*: uint32
  max_readahead*: uint32
  flags*: uint32

type fuse_init_out* = object
  major*: uint32
  minor*: uint32
  max_readahead*: uint32
  flags*: uint32
  unused: uint32
  max_write*: uint32

type fuse_interrupt_in* = object
  unique*: uint64

type fuse_bmap_in* = object
  theBlock*: uint64
  blocksize*: uint32
  padding: uint32

type fuse_bmap_out* = object
  theBlock*: uint64

type fuse_in_header* = object
  len*: uint32
  opcode*: uint32
  unique*: uint64
  nodeid*: uint64
  uid*: uint32
  gid*: uint32
  pid*: uint32
  padding: uint32

type fuse_out_header* = object
  len*: uint32
  error*: int32
  unique*: uint64

type fuse_dirent* = object
  ino*: uint64
  off*: uint64
  namelen*: uint32
  theType*: uint32

# -----------------------------------------------------------------------------

type FileAttr* = ref object
  ino*: uint64
  size*: uint64
  blocks*: uint64
  atime*: Ttimespec
  mtime*: Ttimespec
  ctime*: Ttimespec
  mode*: TMode
  nlink*: uint32
  uid*: uint32
  gid*: uint32
  rdev*: uint32

proc fuse_attr_of(at: FileAttr): fuse_attr =
  result = fuse_attr(
    ino: at.ino,
    size: at.size,
    atime: at.atime.tv_sec.uint64,
    atimensec: at.atime.tv_nsec.uint32,
    mtime: at.mtime.tv_sec.uint64,
    mtimensec: at.mtime.tv_nsec.uint32,
    ctime: at.ctime.tv_sec.uint64,
    ctimensec: at.ctime.tv_nsec.uint32,
    mode: at.mode.uint32,
    nlink: at.nlink,
    uid: at.uid,
    gid: at.gid,
    rdev: at.rdev,
  )
  debug("attr:$1", expr(result))

type Sender = ref object of RootObj
method send(self: Sender, dataSeq: openArray[Buf]): int =
  debug("NULLSender.send")
  0

type Raw = ref object
  sender: Sender
  unique: uint64

proc newRaw(sender: Sender, unique: uint64): Raw =
  Raw(sender: sender, unique: unique)

proc send(self: Raw, err: int, dataSeq: openArray[Buf]) =
  var bufs = newSeq[Buf](len(dataSeq) + 1)
  var sumLen = sizeof(fuse_out_header)
  for i, data in dataSeq:
    assert(data.pos == 0)
    bufs[i+1] = data
    sumLen += data.size

  var outH: fuse_out_header
  outH.unique = self.unique
  outH.error = err.int32
  outH.len = sumLen.uint32
  debug("COMMON OUT:$1", expr(outH))
  bufs[0] = mkBufT(outH)

  discard self.sender.send(bufs)

proc ok(self: Raw, dataSeq: openArray[Buf]) =
  self.send(0, dataSeq)

proc err(self: Raw, e: int) =
  self.send(e, @[])

template defWrapper(typ: expr) =
  type `typ`* {. inject .} = ref object
    raw: Raw
  proc sendOk[T](self: `typ`, a: T) =
    self.raw.ok(@[mkBufT(a)])

template defOk(typ: typedesc) =
  proc ok*(self: typ, dataSeq: openArray[Buf]) =
    self.raw.ok(dataSeq)

template defErr(typ: typedesc) =
  proc err*(self: `typ`, e: int) =
    self.raw.err(e)

type TEntryOut* = ref object
  generation*: uint64
  entry_timeout*: Ttimespec
  attr_timeout*: Ttimespec
  attr*: FileAttr

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
  proc attr*(self: typ, timeout: Ttimespec, at: FileAttr) =
    self.attr(
      fuse_attr_out(
        attr_valid: timeout.tv_sec.uint64,
        attr_valid_nsec: timeout.tv_nsec.uint32,
        attr: fuse_attr_of(at)))

template defReadlink(typ: typedesc) =
  proc readlink*(self: typ, li: string) =
    self.raw.ok(@[mkBufS(li)])

template defOpen(typ: typedesc) =
  proc open*(self: `typ`, hd: fuse_open_out) =
    self.sendOk(hd)

template defWrite(typ: typedesc) =
  proc write*(self: `typ`, hd: fuse_write_out) =
    self.sendOk(hd)

template defBuf(typ: typedesc) =
  proc buf*(self: `typ`, data: Buf) =
    self.raw.ok(@[data])

template defIov(typ: typedesc) =
  proc iov*(self: typ, iov: openArray[TIOVec]) =
    var dataSeq = newSeq[Buf](len(iov))
    for i, io in iov:
      dataSeq[i] = mkBuf(io.iov_len)
      write(dataSeq[i], io.iov_base, io.iov_len)
    self.raw.ok(dataSeq)

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

proc tryAdd(self: Readdir, ino: uint64, off: uint64, st_mode: uint32, name: string): bool =
  proc align(x:int): int =
    let sz = sizeof(uint64)
    (x + sz - 1) and not(sz - 1)

  let namelen = len(name)
  let entlen = sizeof(fuse_dirent) + namelen
  let entsize = align(entlen)
  if self.data.pos + entsize > self.data.size:
    return false

  let hd = fuse_dirent(
    ino: ino,
    off: off,
    namelen: namelen.uint32,
    theType: (st_mode and 0170000) shr 12
  )
  write[fuse_dirent](self.data, hd)
  self.data.pos += sizeof(fuse_dirent)

  self.data.writeS(name)
  self.data.pos += len(name)
  let padlen = entsize - entlen
  if (padlen > 0):
    zeroMem(self.data.asPtr(), padlen.int)

  return true

proc tryAdd*(self: Readdir, ino: uint64, idx: uint64, mode: TMode, name: string): bool =
  ## Try to add the entry 
  ## If the buffer is too small for the entry then it returns false
  tryAdd(self, ino, idx, mode.uint32, name)

proc ok*(self: Readdir) =
  ## Ack by the current buffer contents
  ## If nothing is in the buffer it notifies the end of the stream.
  self.data.size = self.data.pos
  self.data.pos = 0
  self.raw.ok(@[self.data])
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

# FIXME
defWrapper(GetXAttr)
defBuf(GetXAttr)
defXAttr(GetXAttr)
defErr(GetXAttr)

# FIXME
defWrapper(ListXAttr)
defBuf(ListXAttr)
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

defWrapper(Setlk)
defErr(Setlk)

defWrapper(Bmap)
defBmap(Bmap)
defErr(Bmap)

# -----------------------------------------------------------------------------

{. passC: gorge("pkg-config --cflags fuse") .}
{. passL: gorge("pkg-config --libs fuse") .}

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
  var args = fuse_args (
    argc: mount_options.len.cint,
    argv: allocCStringArray(mount_options),
    allocated: 0, # control freeing by ourselves
  )
  let fd = fuse_mount_compat25(mount_point, addr(args))
  deallocCStringArray(args.argv)
  Channel(mount_point:mount_point, fd:fd)

proc disconnect(chan: Channel) =
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

method send(self: ChannelSender, dataSeq: openArray[Buf]): int =
  let n = dataSeq.len.cint
  var iov = newSeq[TIOVec](n)
  var sumLen = 0
  for i in 0..n-1:
    let data = dataSeq[i]
    assert(data.pos == 0)
    iov[i].iov_base = data.asPtr
    iov[i].iov_len = data.size
    sumLen += data.size
  let bytes = posix.writev(self.chan.fd, addr(iov[0]), n)
  if bytes != sumLen:
    debug("send NG. actual:$1(byte) expected:$2 error:$3 msg:$4", bytes, sumLen, osLastError(), osErrorMsg())
    result = -posix.EIO
  else:
    debug("send OK")
    result = 0

proc mkSender*(self: Channel): ChannelSender =
  ChannelSender(chan: self)

# -----------------------------------------------------------------------------

type Request* = ref object
  header*: fuse_in_header
  data: Buf

type FuseFs* = ref object of RootObj

method init*(self: FuseFs, req: Request): int =
  0

method destroy*(self: FuseFs, req: Request) =
  discard

method lookup*(self: FuseFs, req: Request, parent: uint64, name: string, reply: Lookup) =
  reply.err(-ENOSYS)

method forget*(self: FuseFs, req: Request, ino: uint64, nlookup: uint64) =
  discard

method getattr*(self: FuseFs, req: Request, ino: uint64, reply: GetAttr) =
  reply.err(-ENOSYS)

method setattr*(self: FuseFs, req: Request, ino: uint64, mode: Option[uint32], uid: Option[uint32], gid: Option[uint32], size: Option[uint64], atime: Option[Ttimespec], mtime: Option[Ttimespec], fh: Option[uint64], crtime: Option[Ttimespec], chgtime: Option[Ttimespec], bkuptime: Option[Ttimespec], flags: Option[uint32], reply: SetAttr) =
  reply.err(-ENOSYS)

method readlink*(self: FuseFs, req: Request, ino: uint64, reply: Readlink) =
  reply.err(-ENOSYS)

method mknod*(self: FuseFs, req: Request, parent: uint64, name: string, mode: uint32, rdev: uint32, reply: Mknod) =
  reply.err(-ENOSYS)

method mkdir*(self: FuseFs, req: Request, parent: uint64, name: string, mode: uint32, reply: Mkdir) =
  reply.err(-ENOSYS)

method unlink*(self: FuseFs, req: Request, parent: uint64, name: string, reply: Unlink) =
  reply.err(-ENOSYS)

method rmdir*(self: FuseFs, req: Request, parent: uint64, name: string, reply: Rmdir) =
  reply.err(-ENOSYS)

method symlink*(self: FuseFs, req: Request, parent: uint64, name: string, link: string, reply: Symlink) =
  reply.err(-ENOSYS)

method rename*(self: FuseFs, req: Request, parent: uint64, name: string, newdir: uint64, newname: string, reply: Rename) =
  reply.err(-ENOSYS)

method link*(self: FuseFs, req: Request, ino: uint64, newparent: uint64, newname: string, reply: Link) =
  reply.err(-ENOSYS)

method open*(self: FuseFs, req: Request, ino: uint64, flags: uint32, reply: Open) =
  reply.err(-ENOSYS)
 
method read*(self: FuseFs, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  reply.err(-ENOSYS)

method write*(self: FuseFs, req: Request, ino: uint64, fh: uint64, offset: uint64, data: Buf, flags: uint32, reply: Write) =
  reply.err(-ENOSYS)

method flush*(self: FuseFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, reply: Flush) =
  reply.err(-ENOSYS)

method release*(self: FuseFs, req: Request, ino: uint64, fh: uint64, flags: uint32, lock_owner: uint64, flush: bool, reply: Release) =
  reply.err(-ENOSYS)

method fsync*(self: FuseFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsync) =
  reply.err(-ENOSYS)

method opendir*(self: FuseFs, req: Request, ino: uint64, flags: uint32, reply: Opendir) =
  reply.err(-ENOSYS)

method readdir*(self: FuseFs, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  reply.err(-ENOSYS)

method releasedir*(self: FuseFs, req: Request, fh: uint64, flags: uint32, reply: Releasedir) =
  reply.err(-ENOSYS)

method fsyncdir*(self: FuseFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsyncdir) =
  reply.err(-ENOSYS)

method statfs*(self: FuseFs, req: Request, ino: uint64, reply: Statfs) =
  reply.err(-ENOSYS)

method setxattr*(self: FuseFs, req: Request, ino: uint64, key: string, value: Buf, flags: uint32, position: uint32, reply: SetXAttr) =
  reply.err(-ENOSYS)

method getxattr*(self: FuseFs, req: Request, ino: uint64, key: string, reply: GetXAttr) =
  reply.err(-ENOSYS)

method listxattr*(self: FuseFs, req: Request, ino: uint64, reply: ListXAttr) =
  reply.err(-ENOSYS)

method removexattr*(self: FuseFs, req: Request, ino: uint64, name: string, reply: RemoveXAttr) =
  reply.err(-ENOSYS)

method access*(self: FuseFs, req: Request, ino: uint64, mask: uint32, reply: Access) =
  reply.err(-ENOSYS)

method create*(self: FuseFs, req: Request, parent: uint64, name: string, mode: uint32, flags: uint32, reply: Create) =
  reply.err(-ENOSYS)

method getlk*(self: FuseFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, reply: Getlk) =
  reply.err(-ENOSYS)

method setlk*(self: FuseFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, sleep: bool, reply: Setlk) =
  reply.err(-ENOSYS)

method bmap*(self: FuseFs, req: Request, ino: uint64, blocksize: uint32, idx: uint64, reply: Bmap) =
  reply.err(-ENOSYS)

# -----------------------------------------------------------------------------

type Session* = ref object 
  fs: FuseFs
  chan: Channel
  # proto_major: uint32
  # proto_minor: uint32
  initialized: bool
  destroyed: bool

let
  MAX_WRITE_BUFSIZE* = 16 * 1024 * 1024

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

proc dispatch(req: Request, se: Session) =
  let anyReply = newAny(req, se)

  let opcode = req.header.opcode.fuse_opcode

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
    let mode = if (arg.valid and FATTR_MODE) != 0: Some(arg.mode) else: None[uint32]()
    let uid = if (arg.valid and FATTR_UID) != 0: Some(arg.uid) else: None[uint32]()
    let gid = if (arg.valid and FATTR_GID) != 0: Some(arg.gid) else: None[uint32]()
    let size = if (arg.valid and FATTR_SIZE) != 0: Some(arg.size) else: None[uint64]()
    let atime = if (arg.valid and FATTR_ATIME) != 0: Some(Ttimespec(tv_sec:arg.atime.Time, tv_nsec:arg.atimensec.int)) else: None[Ttimespec]()
    let mtime = if (arg.valid and FATTR_MTIME) != 0: Some(Ttimespec(tv_sec:arg.mtime.Time, tv_nsec:arg.mtimensec.int)) else: None[Ttimespec]()
    let fh = if (arg.valid and FATTR_FH) != 0: Some(arg.fh) else: None[uint64]()

    # FIXME this is linux only
    fs.setattr(req, hd.nodeid, mode, uid, gid, size, atime, mtime, fh, None[Ttimespec](), None[Ttimespec](), None[Ttimespec](), None[uint32](), newSetAttr(req, se))

  of FUSE_READLINK:
    fs.readlink(req, hd.nodeid, newReadlink(req, se))
  of FUSE_SYMLINK:
    let name = data.parseS
    data.pos += (len(name) + 1)
    let link = data.parseS
    se.fs.symlink(req, hd.nodeid, name, link, newSymlink(req, se))
  of FUSE_MKNOD:
    let arg = pop[fuse_mknod_in](data)
    let name = data.parseS
    fs.mknod(req, hd.nodeid, name, arg.mode, arg.rdev, newMknod(req, se))
  of FUSE_MKDIR:
    let arg = pop[fuse_mkdir_in](data)
    let name = data.parseS
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
    let datasync = if (arg.fsync_flags and 1'u32) == 0: false else: true
    fs.fsync(req, hd.nodeid, arg.fh, datasync, newFsync(req, se))
  of FUSE_SETXATTR:
    let arg = pop[fuse_setxattr_in](req.data)
    let key = req.data.parseS
    req.data.pos += (len(key) + 1)
    let value = req.data.asBuf
    let pos = 0'u32
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
    debug("INIT IN:$1", expr(arg))
    if (arg.major < 7) or (arg.minor < 6):
      anyReply.err(-EPROTO)
      return
    let res = fs.init(req)
    debug("INIT res:$1", res)
    if res != 0:
      anyReply.err(res)
      return
    var init = fuse_init_out (
      major: FUSE_KERNEL_VERSION,
      minor: FUSE_KERNEL_MINOR_VERSION,
      max_readahead: arg.max_readahead,
      flags: arg.flags,
      max_write: MAX_WRITE_BUFSIZE.uint32,
    )
    debug("INIT OUT:$1", expr(init))
    se.initialized = true
    anyReply.ok(@[mkBufT(init)])
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

proc mkSession*(fs: FuseFs, chan: Channel): Session =
  Session (
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
  debug("COMMON IN:$1", expr(hd))
  if buf.size != hd.len.int:
    error("fetched buffer is too short")
    return

  var req = Request (
    header: hd,
    data: buf.asBuf
  )
  req.dispatch(self)

proc loop*(self: Session) =
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
  # disconnect(se.chan)

proc mount*(fs: FuseFs, mountpoint: string, options: openArray[string]) =
  var Lc = newConsoleLogger()
  logging.handlers.add(Lc)

  let chan = connect(mountpoint, options)
  try:
    se = mkSession(fs, chan)
    setControlCHook(handler)
    se.loop
  finally:
    disconnect(chan)
