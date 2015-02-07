import fuse

type NullFs = ref object of FuseFs

if isMainModule:
  var fs = NullFs()
  mount(fs, "mnt", @[])
