import lowlevel
import session

type Hello = ref object of LowlevelFs

if isMainModule:
  var fs = Hello()
  mount(fs, "mnt_hello", @[])
