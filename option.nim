# A handmade option class
# I hope some option or maybe type be included in std library

type
  OptionKind = enum
    some
    none

  Option*[T] = object
    case kind: OptionKind
    of some: v: T
    of none: nil

proc `$`*[T](o: Option[T]): string =
  case o.kind
  of some:
    "Some " & $o.v
  of none:
    "None"

proc isSome*[T](o: Option[T]): bool =
  o.kind == some

proc isNone*[T](o: Option[T]): bool =
  o.kind == none

proc unwrap*[T](o: Option[T]): T =
  o.v

when isMainModule:
  let v1 = Option[int](kind: some, v: 1)
  echo v1
  echo v1.unwrap
  let v2 = Option[int](kind: none)
  echo v2
  # echo v2.unwrap
