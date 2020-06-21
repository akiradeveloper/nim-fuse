import hifuse
import os
import posix

let TXT = "Hello World!\n"
let PATH = "/hello.txt"

type HelloHiFs = ref object of HiFuseFs

method getattr(fs: HelloHiFs, path: cstring, stbuf: ptr Stat): cint =
  discard

method readdir(fs: HelloHiFs, path: cstring, buf: pointer, filler: TFuseFillDir, offset: Off, fi: ptr TFuseFileInfo): cint =
  discard

method open(fs: HelloHiFs, path: cstring, fi: ptr TFuseFileInfo): cint =
  discard

method read(fs: HelloHiFs, path: cstring, buf: pointer, size: int, offset: Off, fi: ptr TFuseFileInfo): cint =
  discard

if isMainModule:
  var fs = HelloHiFs()
  let args = commandLineParams()
  mount(fs, args[0..high(args)])
