import lowlevel
import session

type Null = ref object of LowlevelFs

if isMainModule:
  var fs = Null
  mount(fs, "mnt", @[])
