## A trivial memory filesystem
## that contains all attr and data directly in memory.
## My attempt for dog-fooding and testing.

import fuse
import posix
import tables
import logging
import os

let TTL = Timespec(sec: 1, nsec: 0)
let GEN = 0

type File = ref object
  ## file or symlink
  attr: FileAttr
  contents: Buf

type Dir = ref object
  ## directory
  attr: FileAttr
  children: TableRef[string, int]

# list of ops stay in default:
# - forget
# - link (hard link not supported)
# - release
# - releasedir
# - xattr stuffs
# - statfs
# - set/get lk
# - bmap
# - create (not supp. then mknod/open is used)
# - mac only stuffs
type Memfs = ref object of FuseFs
  id: int
  files: TableRef[int, File]
  dirs: TableRef[int, Dir]

proc getNewId(self: Memfs): int =
  self.id += 1
  self.id

proc mkMemfs(): Memfs =
  result = Memfs(
    id: 0,
    files: newTable[int, File](),
    dirs: newTable[int, Dir](),
  )
  let rootId = result.getNewId() # get root id
  let rootDir = Dir(
    attr: FileAttr (
      ino: rootId.int64,
      size: 4096,
      nlink: 0,
    ),
    children: newTable[string, int]()
  )
  result.dirs.add(rootId, rootDir)

template checkFile(self: Memfs, id: int64) =
  if not self.files.hasKey(id.int):
    debug("file not found $1", id.int)
    reply.err(-ENOENT)
    return

template checkDir(self: Memfs, id: int64) =
  if not self.dirs.hasKey(id.int):
    debug("directory not found $1", id.int)
    reply.err(-ENOENT)
    return

proc getFileAttr(self: Memfs, ino: int): FileAttr =
  if self.files.hasKey(ino.int):
    return self.files[ino.int].attr
  elif self.dirs.hasKey(ino.int):
    return self.dirs[ino.int].attr

method init*(self: Memfs, req: Request): int =
  0

method destroy*(self: Memfs, req: Request) =
  discard

method lookup*(self: Memfs, req: Request, parent: int64, name: string, reply: Lookup) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  let ino = dir.children[name]
  if self.files.hasKey(ino):
    let found = self.files[ino]
    reply.entry(TEntryOut(
      generation: GEN,
      entry_timeout: TTL,
      attr_timeout: TTL,
      attr: found.attr
    ))
  elif self.dirs.hasKey(ino):
    let found = self.dirs[ino]
    reply.entry(TEntryOut(
      generation: GEN,
      entry_timeout: TTL,
      attr_timeout: TTL,
      attr: found.attr
    ))
  else:
    reply.err(-ENOENT)

method getattr*(self: Memfs, req: Request, ino: int64, reply: GetAttr) =
  if self.files.hasKey(ino.int):
    let found = self.files[ino.int]
    reply.attr(TTL, found.attr)
  elif self.dirs.hasKey(ino.int):
    let found = self.dirs[ino.int]
    reply.attr(TTL, found.attr)
  else:
    reply.err(-ENOENT)

method setattr*(self: Memfs, req: Request, ino: int64, mode: Option[int32], uid: Option[int32], gid: Option[int32], size: Option[int64], atime: Option[Timespec], mtime: Option[Timespec], fh: Option[int64], crtime: Option[Timespec], chgtime: Option[Timespec], bkuptime: Option[Timespec], flags: Option[int32], reply: SetAttr) =
  let attr = self.getFileAttr(ino.int)
  if mode.isSome:
    attr.mode = mode.unwrap
  if uid.isSome:
    attr.uid = uid.unwrap
  if gid.isSome:
    attr.gid = gid.unwrap
  if size.isSome:
    attr.size = size.unwrap
  if atime.isSome:
    attr.atime = atime.unwrap
  if mtime.isSome:
    attr.mtime = mtime.unwrap
  # if fh.isSome:
  #   attr.fh = fh.unwrap
  if crtime.isSome:
    attr.crtime = crtime.unwrap
  # if chgtime.isSome:
  #   attr.chgtime = chgtime.unwrap
  # if bkuptime.isSome:
  #   attr.bkuptime = bkuptime.unwrap
  if flags.isSome:
    attr.flags = flags.unwrap
  reply.attr(TTL, attr)

method readlink*(self: Memfs, req: Request, ino: int64, reply: Readlink) =
  self.checkFile(ino)
  let found = self.files[ino.int]
  reply.readlink(found.contents.parseS)

method symlink*(self: Memfs, req: Request, link: string, parent: int64, name: string, reply: Symlink) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]

  let newIno = self.getNewId()
  let newf = File (
    attr: FileAttr (
      ino: newIno.int64,
      # TODO ?
    ),
    contents: mkBuf(len(name) + 1)
  )
  newf.contents.writeS(name.nullTerminated)
  self.files.add(newIno, newf)
  dir.children[name] = newIno
  reply.entry(TEntryOut(
    generation: GEN,
    entry_timeout: TTL,
    attr_timeout: TTL,
    attr: newf.attr,
  ))

method mknod*(self: Memfs, req: Request, parent: int64, name: string, mode: int32, rdev: int32, reply: Mknod) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  let newIno = self.getNewId()
  dir.children[name] = newIno
  echo mode
  let mo = mode.TMode
  let newFile = File (
    attr: FileAttr (
      ino: newIno.int64,
      mode: mo,
      rdev: rdev
    ),
    contents: mkBuf(0)
  )
  self.files[newIno] = newFile
  reply.entry(TEntryOut(
    generation: GEN,
    entry_timeout: TTL,
    attr_timeout: TTL,
    attr: newFile.attr
  ))

method mkdir*(self: Memfs, req: Request, parent: int64, name: string, mode: int32, reply: Mkdir) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  let newIno = self.getNewId()
  let newDir = Dir (
    attr: FileAttr (
      ino: newIno.int64,
      mode: mode.TMode,
    ),
    children: newTable[string, int](0)
  )
  dir.children[name] = newIno
  reply.entry(TEntryOut(
    generation: GEN,
    entry_timeout: TTL,
    attr_timeout: TTL,
    attr: newDir.attr
  ))

method unlink*(self: Memfs, req: Request, parent: int64, name: string, reply: Unlink) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  dir.children.del(name)
  # TODO remove from files
  reply.err(0)

method rmdir*(self: Memfs, req: Request, parent: int64, name: string, reply: Rmdir) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  dir.children.del(name)
  # TODO remove from dirs
  reply.err(0)

method rename*(self: Memfs, req: Request, parent: int64, name: string, newdir: int64, newname: string, reply: Rename) =
  self.checkDir(parent)
  let fromDir = self.dirs[parent.int]
  let ino = fromDir.children[name]
  fromDir.children.del(name)

  self.checkDir(newDir)
  let toDir = self.dirs[newDir.int]
  toDir.children[newname] = ino

method open*(self: Memfs, req: Request, ino: int64, flags: int32, reply: Open) =
  if self.files.hasKey(ino.int):
    reply.open(
      fuse_open_out (
        fh: 0,
        open_flags: 0,
      ))
  else:
    reply.err(-ENOENT)

method read*(self: Memfs, req: Request, ino: int64, fh: int64, offset: int64, size: int32, reply: Read) =
  self.checkFile(ino)
  let file = self.files[ino.int]
  # TODO error if the range isn't included
  reply.buf(IOVec(
    iov_base: file.contents.asPtr(offset.int),
    iov_len: size.int))

# FIXME what's in flags?
method write*(self: Memfs, req: Request, ino: int64, fh: int64, offset: int64, data: Buf, flags: int32, reply: Write) =
  self.checkFile(ino)
  let file = self.files[ino.int]
  file.contents.extend(data.size + offset.int)
  copyMem(file.contents.asPtr(offset.int), data.asPtr(0), data.size)
  reply.write(fuse_write_out(
    size: data.size.int32
  ))

method flush*(self: Memfs, req: Request, ino: int64, fh: int64, lock_owner: int64, reply: Flush) =
  # FIXME just return -ENOSYS because this is a volatile filesystem?
  reply.err(0)

method fsync*(self: Memfs, req: Request, ino: int64, fh: int64, datasync: bool, reply: Fsync) =
  reply.err(0)

method fsyncdir*(self: Memfs, req: Request, ino: int64, fh: int64, datasync: bool, reply: Fsyncdir) =
  reply.err(0)

method opendir*(self: Memfs, req: Request, ino: int64, flags: int32, reply: Opendir) =
  if self.dirs.hasKey(ino.int):
    reply.open(
      fuse_open_out (
        fh: 0,
        open_flags: 0,
      ))
  else:
    reply.err(-EACCES)

method readdir*(self: Memfs, req: Request, ino: int64, fh: int64, offset: int64, reply: Readdir) =
  self.checkDir(ino)
  let dir = self.dirs[ino.int]
  discard reply.tryAdd(ino, 0, S_IFDIR, ".")
  discard reply.tryAdd(1, 1, S_IFDIR, "..") # FIXME (ino)
  var i = 0
  for name, chIno in dir.children.pairs:
    let attr = self.getFileAttr(chIno)
    discard reply.tryAdd(chIno.int64, (2+i).int64, attr.mode, name)
    i += 1
  reply.ok

method access*(self: Memfs, req: Request, ino: int64, mask: int32, reply: Access) =
  self.checkFile(ino)
  let file = self.files[ino.int]
  if (file.attr.mode and mask.TMode) > 0:
    reply.err(0)
  else:
    reply.err(-EACCES)

if isMainModule:
  var fs = mkMemfs()
  let cl = commandLineParams()
  let mp = cl[0]
  debug("mount point $1", mp)
  # mount(fs, mp, cl[1..mp.high])
  mount(fs, "mnt", cl[1..high(cl)])
