type Buf* = ref object
  pos: int
  size: int
  data: seq[uint8]

proc mkBuf*(size: int): Buf =
  var data = newSeq[uint8](size)
  var buf = Buf(
    pos: 0,
    size: size,
    data: data,
  )
  buf

proc pos(self: Buf): auto =
  self.pos

# Returns current pos as a pointer
proc asPtr(self: Buf): pointer =
  addr(self.data[self.pos])

proc inc*(self: Buf, n) =
  self.pos += n

proc dec*(self: Buf, n) =
  self.pos -= n

proc len(self: Buf): int =
  self.size

proc write[T](self: Buf, obj: T) =
  let sz = sizeof(T)
  var v = obj
  let src = cast[ptr uint8](addr(v))
  echo repr(src)
  copyMem(self.asPtr, src, sz)

proc read[T](self: Buf): T =
  cast[ptr T](self.asPtr)[]
 
when isMainModule:
  var b = mkBuf 101 
  echo repr(b)
  b.inc 10 
  b.dec 3
  echo repr(b)
  echo b.len
  echo b.pos
  echo repr(b.asPtr)

  # can't be
  # let v = b.read[uint64]() or
  # let v: uint64 = b.read
  let v = read[uint64](b)
  echo v
  
  write[uint32](b, 3)
  echo read[uint32](b)
