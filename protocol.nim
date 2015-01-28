## **************************************
#         Nim binding for FUSE
#        (C) 2015 Akira Hayakawa
# **************************************

# C to Nim port of fuse_kernel.h

let
  FUSE_KERNEL_VERSION* = 7
  FUSE_KERNEL_MINOR_VERSION* = 8
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
  padding: uint32
  
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
  # end, type and block are reserved by Nim compiler but
  # (By Araq)
  # as a workaround, we can add backticks.
  # (By dom96)
  # If Nim compiler discard this support, use the prefix (e.g. theEnd)
  `end`*: uint64
  `type`*: uint32
  pid*: uint32 # tgid

let
  # Bitmasks for fuse_setattr_in.valid
  FATTR_MODE* = 1 shl 0
  FATTR_UID* = 1 shl 1
  FATTR_GID* = 1 shl 2
  FATTR_SIZE* = 1 shl 3
  FATTR_ATIME* = 1 shl 4
  FATTR_MTIME* = 1 shl 5
  FATTR_FH* = 1 shl 6

  # Flags returned by the OPEN request
  FOPEN_DIRECT_IO* = 1 shl 0
  FOPEN_KEEP_CACHE* = 1 shl 1

  # INIT request/reply flags
  FUSE_ASYNC_READ* = 1 shl 0
  FUSE_POSIX_LOCKS* = 1 shl 1

  # Release flags
  FUSE_RELEASE_FLUSH* = 1 shl 0

type fuse_opcode = enum
  FUSE_LOOKUP = 1
  FUSE_FORGET = 2 # no reply
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
  unused: uint32

type fuse_create_in* = object
  flags*: uint32
  mode*: uint32
  umask*: uint32
  padding: uint32

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
  `block`*: uint64
  blocksize*: uint32
  padding: uint32

type fuse_bmap_out* = object
  `block`*: uint64

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
  `type`*: uint32
  # name[]
