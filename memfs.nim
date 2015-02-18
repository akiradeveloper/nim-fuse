## A trivial memory filesystem
## that contains all attr and data directly in memory.
## My attempt for dog-fooding and testing.

import fuse
import posix
import tables
import times
import logging
import os

let TTL = Ttimespec(tv_sec: 1.Time, tv_nsec: 0)
let GEN = 0'u64

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
      ino: rootId.uint64,
      size: 4096,
      nlink: 0,
    ),
    children: newTable[string, int]()
  )
  result.dirs.add(rootId, rootDir)

template checkFile(self: Memfs, id: uint64) =
  if not self.files.hasKey(id.int):
    debug("file not found $1", id.int)
    reply.err(-ENOENT)
    return

template checkDir(self: Memfs, id: uint64) =
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

method lookup*(self: Memfs, req: Request, parent: uint64, name: string, reply: Lookup) =
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

method getattr*(self: Memfs, req: Request, ino: uint64, reply: GetAttr) =
  if self.files.hasKey(ino.int):
    let found = self.files[ino.int]
    reply.attr(TTL, found.attr)
  elif self.dirs.hasKey(ino.int):
    let found = self.dirs[ino.int]
    reply.attr(TTL, found.attr)
  else:
    reply.err(-ENOENT)

method setattr*(self: Memfs, req: Request, ino: uint64, mode: Option[uint32], uid: Option[uint32], gid: Option[uint32], size: Option[uint64], atime: Option[Ttimespec], mtime: Option[Ttimespec], fh: Option[uint64], crtime: Option[Ttimespec], chgtime: Option[Ttimespec], bkuptime: Option[Ttimespec], flags: Option[uint32], reply: SetAttr) =
  reply.err(-ENOSYS)

method readlink*(self: Memfs, req: Request, ino: uint64, reply: Readlink) =
  self.checkFile(ino)
  let found = self.files[ino.int]
  reply.readlink(found.contents.parseS)

method symlink*(self: Memfs, req: Request, link: string, parent: uint64, name: string, reply: Symlink) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]

  let newIno = self.getNewId()
  let newf = File (
    attr: FileAttr (
      ino: newIno.uint64,
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

method mknod*(self: Memfs, req: Request, parent: uint64, name: string, mode: uint32, rdev: uint32, reply: Mknod) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  let newIno = self.getNewId()
  dir.children[name] = newIno
  echo mode
  let mo = mode.TMode
  let newFile = File (
    attr: FileAttr (
      ino: newIno.uint64,
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

method mkdir*(self: Memfs, req: Request, parent: uint64, name: string, mode: uint32, reply: Mkdir) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  let newIno = self.getNewId()
  let newDir = Dir (
    attr: FileAttr (
      ino: newIno.uint64,
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

method unlink*(self: Memfs, req: Request, parent: uint64, name: string, reply: Unlink) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  dir.children.del(name)
  # TODO remove from files
  reply.err(0)

method rmdir*(self: Memfs, req: Request, parent: uint64, name: string, reply: Rmdir) =
  self.checkDir(parent)
  let dir = self.dirs[parent.int]
  dir.children.del(name)
  # TODO remove from dirs
  reply.err(0)

method rename*(self: Memfs, req: Request, parent: uint64, name: string, newdir: uint64, newname: string, reply: Rename) =
  self.checkDir(parent)
  let fromDir = self.dirs[parent.int]
  let ino = fromDir.children[name]
  fromDir.children.del(name)

  self.checkDir(newDir)
  let toDir = self.dirs[newDir.int]
  toDir.children[newname] = ino

method open*(self: Memfs, req: Request, ino: uint64, flags: uint32, reply: Open) =
  if self.files.hasKey(ino.int):
    reply.open(
      fuse_open_out (
        fh: 0,
        open_flags: 0,
      ))
  else:
    reply.err(-ENOENT)

method read*(self: Memfs, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  self.checkFile(ino)
  let file = self.files[ino.int]
  # TODO error if the range isn't included
  reply.buf(TIOVec(
    iov_base: file.contents.asPtr(offset.int),
    iov_len: size.int))

# FIXME what's in flags?
method write*(self: Memfs, req: Request, ino: uint64, fh: uint64, offset: uint64, data: Buf, flags: uint32, reply: Write) =
  self.checkFile(ino)
  let file = self.files[ino.int]
  file.contents.extend(data.size + offset.int)
  copyMem(file.contents.asPtr(offset.int), data.asPtr(0), data.size)
  reply.write(fuse_write_out(
    size: data.size.uint32
  ))

method flush*(self: Memfs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, reply: Flush) =
  # FIXME just return -ENOSYS because this is a volatile filesystem?
  reply.err(0)

method fsync*(self: Memfs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsync) =
  reply.err(0)

method fsyncdir*(self: Memfs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsyncdir) =
  reply.err(0)

method opendir*(self: Memfs, req: Request, ino: uint64, flags: uint32, reply: Opendir) =
  if self.dirs.hasKey(ino.int):
    reply.open(
      fuse_open_out (
        fh: 0,
        open_flags: 0,
      ))
  else:
    reply.err(-EACCES)

method readdir*(self: Memfs, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  self.checkDir(ino)
  let dir = self.dirs[ino.int]
  discard reply.tryAdd(ino, 0, S_IFDIR, ".")
  discard reply.tryAdd(1, 1, S_IFDIR, "..") # FIXME (ino)
  var i = 0
  for name, chIno in dir.children.pairs:
    let attr = self.getFileAttr(chIno)
    discard reply.tryAdd(chIno.uint64, (2+i).uint64, attr.mode, name)
    i += 1
  reply.ok

method access*(self: Memfs, req: Request, ino: uint64, mask: uint32, reply: Access) =
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
  mount(fs, "mnt", @[])
