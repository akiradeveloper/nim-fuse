type Buf* = ref object
  pos: int
  size: int
  data: seq[uint8]

proc mkBuf*(size: int): Buf =
  var data = newSeq[uint8](size)
  var buf = Buf(
    pos: 0,
    size: size,
    data: data
  )
  buf

proc pos(self) =
  self.pos

proc inc*(self, n) =
  self.pos += n

proc dec*(self, n) =
  self.pos -= n
  
when isMainModule:
  var b = mkBuf 101 
  echo repr(b)
  b.inc 10 
  b.dec 3
  echo repr(b)
