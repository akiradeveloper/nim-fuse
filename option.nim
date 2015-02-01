# A handmade option class
# I hope some option or maybe type be included in std library

type
  OptionKind = enum
    kSome
    kNone

  TOption*[T] = object
    case kind: OptionKind
    of kSome: v: T
    of kNone: nil

proc `$`*[T](o: TOption[T]): string =
  case o.kind
  of kSome:
    "Some " & $o.v
  of kNone:
    "None"

proc Some*[T](v: T): TOption[T] =
  TOption[T](kind: kSome, v: v)

proc None*[T](): TOption[T] =
  TOption[T](kind: kNone)

proc isSome*[T](o: TOption[T]): bool =
  o.kind == kSome

proc isNone*[T](o: TOption[T]): bool =
  o.kind == kNone

proc unwrap*[T](o: TOption[T]): T =
  o.v

when isMainModule:
  let v1 = Some(1)
  echo v1
  echo v1.unwrap
  let v2 = None[int]()
  echo v2
  # echo v2.unwrap
