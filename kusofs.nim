## A trivial (kuso in Japanese) memory filesystem
## that contains all attr and data directly in memory.
## My attempt for dog-fooding and testing.

import fuse
import posix
import tables
import times
import logging

let TTL = Ttimespec(tv_sec: 1.Time, tv_nsec: 0)
let GEN = 0'u64

type File = ref object
  attr: FileAttr
  contents: Buf

type Dir = ref object
  attr: FileAttr
  children: TableRef[string, int]

type KusoFs = ref object of FuseFs
  id: int
  files: TableRef[int, File]
  dirs: TableRef[int, Dir]

proc getNewId(self: KusoFs): int =
  self.id += 1
  self.id

template getDir(self: KusoFs, id: uint64): Dir =
  # TODO is this correct?
  if not self.dirs.hasKey(id.int):
    debug("directory not found $1", id.int)
    reply.err(-ENOENT)
    return
  self.dirs[id.int]

method init*(self: KusoFs, req: Request): int =
  0

method destroy*(self: KusoFs, req: Request) =
  discard

method lookup*(self: KusoFs, req: Request, parent: uint64, name: string, reply: Lookup) =
  let dir = self.getDir(parent)
  let ino = dir.children[name]
  if self.files.hasKey(ino):
    let found = self.files[ino]
    reply.entry(TEntryOut (
      generation: GEN,
      entry_timeout: TTL,
      attr_timeout: TTL,
      attr: found.attr
    ))
  else:
    let found = self.dirs[ino]
    reply.entry(TEntryOut (
      generation: GEN,
      entry_timeout: TTL,
      attr_timeout: TTL,
      attr: found.attr
    ))

method forget*(self: KusoFs, req: Request, ino: uint64, nlookup: uint64) =
  discard

method getattr*(self: KusoFs, req: Request, ino: uint64, reply: GetAttr) =
  if self.files.hasKey(ino.int):
    let found = self.files[ino.int]
    reply.attr(TTL, found.attr)
  else:
    let found = self.dirs[ino.int]
    reply.attr(TTL, found.attr)

method setattr*(self: KusoFs, req: Request, ino: uint64, mode: Option[uint32], uid: Option[uint32], gid: Option[uint32], size: Option[uint64], atime: Option[Ttimespec], mtime: Option[Ttimespec], fh: Option[uint64], crtime: Option[Ttimespec], chgtime: Option[Ttimespec], bkuptime: Option[Ttimespec], flags: Option[uint32], reply: SetAttr) =
  reply.err(-ENOSYS)

method readlink*(self: KusoFs, req: Request, ino: uint64, reply: Readlink) =
  let found = self.files[ino.int]
  reply.readlink(found.contents.parseS)

method mknod*(self: KusoFs, req: Request, parent: uint64, name: string, mode: uint32, rdev: uint32, reply: Mknod) =
  let dir = self.getDir(parent)
  let newIno = self.getNewId
  dir.children[name] = newIno
  let newf = File (
    attr: FileAttr (
      ino: newIno.uint64,
      mode: mode.TMode,
      rdev: rdev
    ),
    contents: mkBuf(0)
  )
  self.files[newIno] = newf
  reply.entry(TEntryOut(
    generation: GEN,
    entry_timeout: TTL,
    attr_timeout: TTL,
    attr: newf.attr
  ))

method mkdir*(self: KusoFs, req: Request, parent: uint64, name: string, mode: uint32, reply: Mkdir) =
  let dir = self.getDir(parent)
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

method unlink*(self: KusoFs, req: Request, parent: uint64, name: string, reply: Unlink) =
  let dir = self.getDir(parent)
  dir.children.del(name)
  reply.err(0)

method rmdir*(self: KusoFs, req: Request, parent: uint64, name: string, reply: Rmdir) =
  let dir = self.getDir(parent)
  dir.children.del(name)
  reply.err(0)

method symlink*(self: KusoFs, req: Request, link: string, parent: uint64, name: string, reply: Symlink) =
  let dir = self.getDir(parent)
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

method rename*(self: KusoFs, req: Request, parent: uint64, name: string, newdir: uint64, newname: string, reply: Rename) =
  let fromDir = self.getDir(parent)
  let ino = fromDir.children[name]
  fromDir.children.del(name)

  let toDir = self.getDir(newDir)
  toDir.children[newname] = ino

method link*(self: KusoFs, req: Request, ino: uint64, newparent: uint64, newname: string, reply: Link) =
  # not supp
  reply.err(-ENOSYS)

method open*(self: KusoFs, req: Request, ino: uint64, flags: uint32, reply: Open) =
  reply.open(
    fuse_open_out (
      fh: 0,
      open_flags: 0,
    )
  )

method read*(self: KusoFs, req: Request, ino: uint64, fh: uint64, offset: uint64, size: uint32, reply: Read) =
  let file = self.files[ino.int]
  reply.buf(TIOVec(
    iov_base: file.contents.asPtr(offset.int),
    iov_len: size.int))

# FIXME what's in flags?
method write*(self: KusoFs, req: Request, ino: uint64, fh: uint64, offset: uint64, data: Buf, flags: uint32, reply: Write) =
  let file = self.files[ino.int]
  file.contents.extend(data.size + offset.int)
  copyMem(file.contents.asPtr(offset.int), data.asPtr(0), data.size)
  reply.write(fuse_write_out(
    size: data.size.uint32
  ))

method flush*(self: KusoFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, reply: Flush) =
  reply.err(-ENOSYS)

method release*(self: KusoFs, req: Request, ino: uint64, fh: uint64, flags: uint32, lock_owner: uint64, flush: bool, reply: Release) =
  reply.err(0)

method fsync*(self: KusoFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsync) =
  reply.err(-ENOSYS)

method opendir*(self: KusoFs, req: Request, ino: uint64, flags: uint32, reply: Opendir) =
  reply.open(
    fuse_open_out (
      fh: 0,
      open_flags: 0,
    )
  )

method readdir*(self: KusoFs, req: Request, ino: uint64, fh: uint64, offset: uint64, reply: Readdir) =
  let dir = self.getDir(ino)
  discard reply.tryAdd(ino, 0, S_IFDIR, ".")
  discard reply.tryAdd(1, 1, S_IFDIR, "..") # FIXME (ino)
  for i, name, ino in dir.children: # FIXME (iterator)
    discard reply.tryAdd(ino, 2+i, S_IFREG, name) # FIXME (type)
  reply.ok

method releasedir*(self: KusoFs, req: Request, fh: uint64, flags: uint32, reply: Releasedir) =
  reply.err(0)

method fsyncdir*(self: KusoFs, req: Request, ino: uint64, fh: uint64, datasync: bool, reply: Fsyncdir) =
  reply.err(-ENOSYS)

method statfs*(self: KusoFs, req: Request, ino: uint64, reply: Statfs) =
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

method setxattr*(self: KusoFs, req: Request, ino: uint64, key: string, value: Buf, flags: uint32, position: uint32, reply: SetXAttr) =
  reply.err(-ENOSYS)

method getxattr*(self: KusoFs, req: Request, ino: uint64, key: string, reply: GetXAttr) =
  reply.err(-ENOSYS)

method listxattr*(self: KusoFs, req: Request, ino: uint64, reply: ListXAttr) =
  reply.err(-ENOSYS)

method removexattr*(self: KusoFs, req: Request, ino: uint64, name: string, reply: RemoveXAttr) =
  reply.err(-ENOSYS)

method access*(self: KusoFs, req: Request, ino: uint64, mask: uint32, reply: Access) =
  reply.err(-ENOSYS)

method create*(self: KusoFs, req: Request, parent: uint64, name: string, mode: uint32, flags: uint32, reply: Create) =
  reply.err(-ENOSYS)

method getlk*(self: KusoFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, reply: Getlk) =
  reply.err(-ENOSYS)

method setlk*(self: KusoFs, req: Request, ino: uint64, fh: uint64, lock_owner: uint64, start: uint64, theEnd: uint64, theType: uint64, pid: uint32, sleep: bool, reply: Setlk) =
  reply.err(-ENOSYS)

method bmap*(self: KusoFs, req: Request, ino: uint64, blocksize: uint32, idx: uint64, reply: Bmap) =
  reply.err(-ENOSYS)

when hostOS == "macosx":
  method setvolname(self: KusoFs, req: Request, name: string, reply: SetVolname) =
    reply.err(-ENOSYS)

  method exchange(self: KusoFs, req: Request, parent: uint64, name: string, newparent: uint64, newname: string, options: uint64, reply: Exchange) =
    reply.err(-ENOSYS)

  method getxtimes(self: KusoFs, req: Request, ino: uint64, reply: GetXTimes) =
    reply.err(-ENOSYS)
