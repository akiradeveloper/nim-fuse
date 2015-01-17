type Filesystem* = ref object of RootObj

type Request = ref object

method init[FS:Filesystem](self:FS, req:Request): c_int =
  discard     
