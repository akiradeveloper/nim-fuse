type Filesystem* = ref object of RootObj

type Request = ref object

type fuse_file_info = ref object
  flags: int
  # ...
 
type fuse_conn_info = ref object

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

