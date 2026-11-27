import Base

def utf8_width.high(+c: Char, small: Bool) -> Nat:
  match small:
    case True{}:
      3n
    case False{}:
      4n

def utf8_width.mid(+c: Char, small: Bool) -> Nat:
  match small:
    case True{}:
      2n
    case False{}:
      utf8_width.high(c, U32.is_lt(Char.to_u32(c), 65536))

def utf8_width.low(+c: Char, small: Bool) -> Nat:
  match small:
    case True{}:
      1n
    case False{}:
      utf8_width.mid(c, U32.is_lt(Char.to_u32(c), 2048))

def utf8_width(+c: Char) -> Nat:
  utf8_width.low(c, U32.is_lt(Char.to_u32(c), 128))

def utf8_length(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{h, t}:
      Nat.add(utf8_width(h), utf8_length(t))

def char_string(c: Char) -> String:
  SCon{c, SNil{}}

def string_has_char(s: String, +c: Char) -> Bool:
  String.contains(s, char_string(c))

def normalize_newlines(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\r', SCon{'\n', t}}:
      SCon{'\n', normalize_newlines(t)}
    case SCon{'\r', t}:
      SCon{'\n', normalize_newlines(t)}
    case SCon{h, t}:
      SCon{h, normalize_newlines(t)}

def ascii_punctuation(+c: Char) -> Bool:
  Bool.or(Bool.and(U32.is_ge(Char.to_u32(c), 33), U32.is_le(Char.to_u32(c), 47)),
    Bool.or(Bool.and(U32.is_ge(Char.to_u32(c), 58), U32.is_le(Char.to_u32(c), 64)),
      Bool.or(Bool.and(U32.is_ge(Char.to_u32(c), 91), U32.is_le(Char.to_u32(c), 96)),
        Bool.and(U32.is_ge(Char.to_u32(c), 123), U32.is_le(Char.to_u32(c), 126)))))

def is_ascii_whitespace(+c: Char) -> Bool:
  Bool.or(Char.is_eq(c, ' '), Bool.or(Char.is_eq(c, '\t'),
    Bool.or(Char.is_eq(c, '\n'), Char.is_eq(c, '\r'))))

def blank_line(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{' ', t}:
      blank_line(t)
    case SCon{'\t', t}:
      blank_line(t)
    case SCon{'\n', t}:
      blank_line(t)
    case SCon{'\r', t}:
      blank_line(t)
    case SCon{h, t}:
      False{}

def drop_prefix_if.fin(s: String, +p: String, yes: Bool) -> Maybe<&2, String>:
  match yes:
    case True{}:
      Some{String.drop(s, String.length(p))}
    case False{}:
      None{}

def drop_prefix_if(+s: String, +p: String) -> Maybe<&2, String>:
  drop_prefix_if.fin(s, p, String.starts_with(s, p))

def spaces_prefix(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{' ', t}:
      spaces_prefix(t, 1n+acc)
    case SCon{h, t}:
      acc

def strip_n_chars(s: String, n: Nat) -> String:
  String.drop(s, n)

def take_n_chars(s: String, n: Nat) -> String:
  String.take(s, n)

def concat3(a: String, b: String, c: String) -> String:
  a ++ (b ++ c)

def concat5(a: String, b: String, c: String, d: String, e: String) -> String:
  a ++ (b ++ (c ++ (d ++ e)))
