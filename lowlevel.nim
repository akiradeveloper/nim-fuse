# Lowlevel server
# Interacts with fuse client in the kernel

type LowlevelFs* = ref object of RootObj

type Request = ref object

method init(self: Filesystem, conn: fuse_conn_info) =
  discard 

method destroy(self: Filssystem) =
  discard

method lookup(self: Filesystem, req: Request, parent: u64, name: string) =
  discard

method forget(self, req, ino, nlookup)

method getattr(self, req, ino, fi)

method open(self, req, ino, fi)

method read(self, ino, size, off, fi)

method release(self, req, ino, fi)

method opendir(self, req, ino, fi)

method readdir(self, req, ino, size, off, fi)

method releasedir(self, req, ino, fi)

# sketch

# proc fuse_reply_statfs(req, stbuf: posix.TStatvfs)

proc mount(fs: LowlevelFs, mountpoint: string, mount_options: openArray[string]) =
  let chan = connect(mountpoint, options)
  let se = mkSession(fs, chan)
  se.loop
  disconnect(chan)
