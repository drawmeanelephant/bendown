import Base
import ../ast.bend as Ast
import ../text.bend as Text
import ../unicode.bend as Unicode

# Clean-room Markdown parser, first milestone.
#
# Every recursive entry is fueled by a Nat derived from the input.  A failed
# construct is emitted as literal input rather than as an error, so parsing is
# total for every byte string.

# Bend cannot match on a computed local value.  These two small eliminators
# isolate that match; the continuations themselves are one-shot closures.
def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def maybe_case(-A: Data, -B: Type, m: Maybe<&2, A>, some: A -> B, none: Unit -> B) -> B:
  match m:
    case Some{x}:
      some(x)
    case None{}:
      none(Unit{})

# Data records used where a primitive pair would be affine.
type StrSplit is Data:
  StrSplit{before: String, after: String}

def str_split_before(x: StrSplit) -> String:
  match x:
    case StrSplit{before, after}:
      before

def str_split_after(x: StrSplit) -> String:
  match x:
    case StrSplit{before, after}:
      after

type LinkParts is Data:
  LinkParts{label: String, inside: String, after: String}

def link_parts_label(x: LinkParts) -> String:
  match x:
    case LinkParts{label, inside, after}:
      label

def link_parts_inside(x: LinkParts) -> String:
  match x:
    case LinkParts{label, inside, after}:
      inside

def link_parts_after(x: LinkParts) -> String:
  match x:
    case LinkParts{label, inside, after}:
      after

type LinkTarget is Data:
  LinkTarget{href: String, title: Maybe<&2, String>}

def link_target_href(x: LinkTarget) -> String:
  match x:
    case LinkTarget{href, title}:
      href

def link_target_title(x: LinkTarget) -> Maybe<&2, String>:
  match x:
    case LinkTarget{href, title}:
      title

type EntityHit is Data:
  EntityHit{decoded: String, after: String}

def entity_hit_decoded(x: EntityHit) -> String:
  match x:
    case EntityHit{decoded, after}:
      decoded

def entity_hit_after(x: EntityHit) -> String:
  match x:
    case EntityHit{decoded, after}:
      after

type NumScan is Data:
  NumScan{count: Nat, value: U32, rest: String}

def num_scan_count(x: NumScan) -> Nat:
  match x:
    case NumScan{count, value, rest}:
      count

def num_scan_value(x: NumScan) -> U32:
  match x:
    case NumScan{count, value, rest}:
      value

def num_scan_rest(x: NumScan) -> String:
  match x:
    case NumScan{count, value, rest}:
      rest

type WordSplit is Data:
  WordSplit{word: String, rest: String}

def word_split_word(x: WordSplit) -> String:
  match x:
    case WordSplit{word, rest}:
      word

def word_split_rest(x: WordSplit) -> String:
  match x:
    case WordSplit{word, rest}:
      rest

# String utilities.
def md_str_at(s: String, n: Nat) -> U32:
  match s n:
    case SCon{Chr{c}, t} 0n:
      c
    case SCon{h, t} 1n+p:
      md_str_at(t, p)
    case SNil{} _:
      0

def md_char_string(+c: Char) -> String:
  SCon{c, SNil{}}

def md_repeat_char(+c: Char, n: Nat) -> String:
  String.repeat(md_char_string(c), n)

def md_count_prefix(s: String, +c: Char, +acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      ifs(Nat, Char.is_eq(h, c),
        u => md_count_prefix(t, c, 1n+acc),
        u => acc)

def md_leading_spaces(s: String, +acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{' ', t}:
      md_leading_spaces(t, 1n+acc)
    case SCon{h, t}:
      acc

def md_trim_start(s: String) -> String:
  match s:
    case SCon{' ', t}:
      md_trim_start(t)
    case SCon{'\t', t}:
      md_trim_start(t)
    case u:
      u

def md_trim_end(s: String) -> String:
  String.reverse(md_trim_start(String.reverse(s)))

def md_trim(s: String) -> String:
  md_trim_start(md_trim_end(s))

def md_inline_space_char(+c: Char) -> Bool:
  Char.is_eq(c, ' ') || Char.is_eq(c, '\t') || Char.is_eq(c, '\n') || Char.is_eq(c, '\r')

def md_trim_inline_start(s: String) -> String:
  match s:
    case SCon{+h, +t}:
      ifs(String, md_inline_space_char(h),
        u => md_trim_inline_start(t),
        u => SCon{h, t})
    case u:
      u

def md_trim_inline_end(s: String) -> String:
  String.reverse(md_trim_inline_start(String.reverse(s)))

def md_trim_inline(s: String) -> String:
  md_trim_inline_start(md_trim_inline_end(s))

def md_drop_leading_spaces(s: String) -> String:
  match s:
    case SCon{' ', t}:
      md_drop_leading_spaces(t)
    case u:
      u

def md_count_trailing_spaces(+s: String) -> Nat:
  md_count_prefix(String.reverse(s), ' ', 0n)

def md_drop_trailing_spaces(+s: String) -> String:
  String.reverse(String.drop(String.reverse(s), md_count_trailing_spaces(s)))

def md_unicode1(+x: U32) -> String:
  SCon{Char.from_u32(x), SNil{}}

def md_scan_dec_digits(s: String, +count: Nat, +value: U32) -> NumScan:
  match s:
    case SNil{}:
      NumScan{count, value, SNil{}}
    case SCon{+h, +t}:
      ifs(NumScan, Char.is_digit(h),
        u => md_scan_dec_digits(t, 1n+count,
          U32.add(U32.mul(value, 10), U32.sub(Char.to_u32(h), 48))),
        u => NumScan{count, value, SCon{h, t}})

def md_hex_digit_char(+c: Char) -> Bool:
  Char.is_digit(c) ||
    Bool.or(Bool.and(U32.is_ge(Char.to_u32(c), 65), U32.is_le(Char.to_u32(c), 70)),
      Bool.and(U32.is_ge(Char.to_u32(c), 97), U32.is_le(Char.to_u32(c), 102)))

def md_hex_digit_value(+c: Char) -> U32:
  +x = Char.to_u32(c)
  ifs(U32, Char.is_digit(c),
    u => U32.sub(x, 48),
    u =>
      ifs(U32, U32.is_le(x, 70),
        v => U32.sub(x, 55),
        v => U32.sub(x, 87)))

def md_scan_hex_digits(s: String, +count: Nat, +value: U32) -> NumScan:
  match s:
    case SNil{}:
      NumScan{count, value, SNil{}}
    case SCon{+h, +t}:
      ifs(NumScan, md_hex_digit_char(h),
        u => md_scan_hex_digits(t, 1n+count,
          U32.add(U32.mul(value, 16), md_hex_digit_value(h))),
        u => NumScan{count, value, SCon{h, t}})

def md_entity_codepoint(+x: U32) -> U32:
  +surrogate = Bool.and(U32.is_ge(x, 55296), U32.is_le(x, 57343))
  +invalid = U32.is_eq(x, 0) || surrogate || U32.is_gt(x, 1114111)
  Bool.pick(U32, invalid, 65533, x)

def md_numeric_entity(+s: String) -> Maybe<&2, EntityHit>:
  +hex = String.starts_with(s, "x") || String.starts_with(s, "X")
  +afterx = ifs(String, hex,
    u => String.drop(s, 1n),
    u => s)
  +scan = ifs(NumScan, hex,
    u => md_scan_hex_digits(afterx, 0n, 0),
    u => md_scan_dec_digits(afterx, 0n, 0))
  +count = num_scan_count(scan)
  +rest = num_scan_rest(scan)
  +maxcount = ifs(Nat, hex, u => 6n, u => 7n)
  +valid = Bool.and(Nat.is_ge(count, 1n),
    Bool.and(Nat.is_le(count, maxcount), String.starts_with(rest, ";")))
  ifs(Maybe<&2, EntityHit>, valid,
    u => Some{EntityHit{md_unicode1(md_entity_codepoint(num_scan_value(scan))), String.drop(rest, 1n)}},
    u => None{})

def md_entity_name_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c)

def md_scan_entity_name(s: String, +acc: String, +count: Nat) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{+h, +t}:
      ifs(WordSplit, md_entity_name_char(h),
        u => md_scan_entity_name(t, SCon{h, acc}, 1n+count),
        u => WordSplit{String.reverse(acc), SCon{h, t}})

# The HTML5 entity table is large; this clean-room implementation includes
# every named reference exercised by the official CommonMark examples, plus
# the common references needed by its link examples.  Unknown names remain
# literal, as required for nonentities.
def md_named_entity_value(+name: String) -> Maybe<&2, String>:
  ifs(Maybe<&2, String>, String.eq(name, "nbsp"),
    u => Some{md_unicode1(160)},
    u =>
      ifs(Maybe<&2, String>, String.eq(name, "amp"),
        v => Some{md_unicode1(38)},
        v =>
          ifs(Maybe<&2, String>, String.eq(name, "copy"),
            w => Some{md_unicode1(169)},
            w =>
              ifs(Maybe<&2, String>, String.eq(name, "AElig"),
                a => Some{md_unicode1(198)},
                a =>
                  ifs(Maybe<&2, String>, String.eq(name, "Dcaron"),
                    b => Some{md_unicode1(270)},
                    b =>
                      ifs(Maybe<&2, String>, String.eq(name, "frac34"),
                        c => Some{md_unicode1(190)},
                        c =>
                          ifs(Maybe<&2, String>, String.eq(name, "HilbertSpace"),
                            d => Some{md_unicode1(8459)},
                            d =>
                              ifs(Maybe<&2, String>, String.eq(name, "DifferentialD"),
                                e => Some{md_unicode1(8518)},
                                e =>
                                  ifs(Maybe<&2, String>, String.eq(name, "ClockwiseContourIntegral"),
                                    g => Some{md_unicode1(8754)},
                                    g =>
                                      ifs(Maybe<&2, String>, String.eq(name, "ngE"),
                                        h => Some{md_unicode1(8807) ++ md_unicode1(824)},
                                        h =>
                                          ifs(Maybe<&2, String>, String.eq(name, "ouml"),
                                            i => Some{md_unicode1(246)},
                                            i =>
                                              ifs(Maybe<&2, String>, String.eq(name, "auml"),
                                                j => Some{md_unicode1(228)},
                                                j =>
                                                  ifs(Maybe<&2, String>, String.eq(name, "quot"),
                                                    k => Some{md_unicode1(34)},
                                                    k => None{})))))))))))))

def md_scan_named_entity(+s: String) -> Maybe<&2, EntityHit>:
  +parts = md_scan_entity_name(s, SNil{}, 0n)
  +name = word_split_word(parts)
  +rest = word_split_rest(parts)
  +count = String.length(name)
  +shape = Bool.and(Nat.is_ge(count, 1n),
    Bool.and(Nat.is_le(count, 32n), String.starts_with(rest, ";")))
  ifs(Maybe<&2, EntityHit>, shape,
    u =>
      maybe_case(String, Maybe<&2, EntityHit>, md_named_entity_value(name),
        +decoded => Some{EntityHit{decoded, String.drop(rest, 1n)}},
        v => None{}),
    u => None{})

def md_scan_entity_after_amp(+s: String) -> Maybe<&2, EntityHit>:
  ifs(Maybe<&2, EntityHit>, String.starts_with(s, "#"),
    u => md_numeric_entity(String.drop(s, 1n)),
    u => md_scan_named_entity(s))

# Decode backslash escapes and entity/numeric references in contexts such as
# link destinations, titles, labels, and fence info strings.  The result is
# not reparsed as Markdown structure.
def md_decode_ee_go(fuel: Nat, +s: String) -> String:
  match fuel:
    case 0n:
      s
    case 1n++f:
      match s:
        case SNil{}:
          SNil{}
        case SCon{'\\', SCon{h, t}}:
          ifs(String, Text.ascii_punctuation(h),
            u => SCon{h, md_decode_ee_go(f, t)},
            u => SCon{'\\', md_decode_ee_go(f, SCon{h, t})})
        case SCon{'&', t}:
          maybe_case(EntityHit, String, md_scan_entity_after_amp(t),
            +hit => entity_hit_decoded(hit) ++ md_decode_ee_go(f, entity_hit_after(hit)),
            u => SCon{'&', md_decode_ee_go(f, t)})
        case SCon{h, t}:
          SCon{h, md_decode_ee_go(f, t)}

def md_decode_ee(+s: String) -> String:
  md_decode_ee_go(Nat.add(String.length(s), 1n), s)

def md_hex_digit_text(+x: U32) -> String:
  ifs(String, U32.is_le(x, 9),
    u => md_unicode1(U32.add(x, 48)),
    u => md_unicode1(U32.add(x, 55)))

def md_percent_byte(+x: U32) -> String:
  "%" ++ md_hex_digit_text(U32.div(x, 16)) ++ md_hex_digit_text(U32.mod(x, 16))

def md_percent_codepoint(+x: U32) -> String:
  ifs(String, U32.is_lt(x, 128),
    u => md_percent_byte(x),
    u =>
      ifs(String, U32.is_lt(x, 2048),
        v =>
          md_percent_byte(U32.add(192, U32.shrn(x, 6n))) ++
            md_percent_byte(U32.add(128, U32.and(x, 63))),
        v =>
          ifs(String, U32.is_lt(x, 65536),
            w =>
              md_percent_byte(U32.add(224, U32.shrn(x, 12n))) ++
                md_percent_byte(U32.add(128, U32.and(U32.shrn(x, 6n), 63))) ++
                md_percent_byte(U32.add(128, U32.and(x, 63))),
            w =>
              md_percent_byte(U32.add(240, U32.shrn(x, 18n))) ++
                md_percent_byte(U32.add(128, U32.and(U32.shrn(x, 12n), 63))) ++
                md_percent_byte(U32.add(128, U32.and(U32.shrn(x, 6n), 63))) ++
                md_percent_byte(U32.add(128, U32.and(x, 63))))))

def md_uri_safe_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) ||
    Char.is_eq(c, '-') || Char.is_eq(c, '.') || Char.is_eq(c, '_') ||
    Char.is_eq(c, '~') || Char.is_eq(c, '%') || Char.is_eq(c, ':') ||
    Char.is_eq(c, '/') || Char.is_eq(c, '?') || Char.is_eq(c, '#') ||
    Char.is_eq(c, '@') || Char.is_eq(c, '!') || Char.is_eq(c, '$') ||
    Char.is_eq(c, '&') || Char.is_eq(c, '\'') || Char.is_eq(c, '(') ||
    Char.is_eq(c, ')') || Char.is_eq(c, '*') || Char.is_eq(c, '+') ||
    Char.is_eq(c, ',') || Char.is_eq(c, ';') || Char.is_eq(c, '=')

def md_uri_encode(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      ifs(String, md_uri_safe_char(h),
        u => SCon{h, md_uri_encode(t)},
        u => md_percent_codepoint(Char.to_u32(h)) ++ md_uri_encode(t))

def md_normalize_uri(+s: String) -> String:
  md_uri_encode(md_decode_ee(s))

def md_compact_horizontal_space(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{' ', t}:
      md_compact_horizontal_space(t)
    case SCon{'\t', t}:
      md_compact_horizontal_space(t)
    case SCon{h, t}:
      SCon{h, md_compact_horizontal_space(t)}

def md_all_char(s: String, +c: Char) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(Char.is_eq(h, c), md_all_char(t, c))

def md_has_line_break_or_space(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{' ', t}:
      True{}
    case SCon{'\t', t}:
      True{}
    case SCon{'\n', t}:
      True{}
    case SCon{h, t}:
      md_has_line_break_or_space(t)

def md_find_sub_index(+s: String, +needle: String, +idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      ifs(Maybe<&2, Nat>, String.is_empty(needle),
        u => Some{idx},
        u => None{})
    case SCon{h, t}:
      ifs(Maybe<&2, Nat>, String.starts_with(s, needle),
        u => Some{idx},
        u => md_find_sub_index(t, needle, 1n+idx))

def md_split_at_index(+s: String, +idx: Nat, +width: Nat) -> StrSplit:
  StrSplit{String.take(s, idx), String.drop(s, Nat.add(idx, width))}

def md_split_at_maybe(+s: String, +needle: String, m: Maybe<&2, Nat>) -> Maybe<&2, StrSplit>:
  match m:
    case Some{idx}:
      Some{md_split_at_index(s, idx, String.length(needle))}
    case None{}:
      None{}

# Split at the first occurrence of needle.  `before` excludes it and `after`
# starts immediately after it.
def md_find_split(+s: String, +needle: String) -> Maybe<&2, StrSplit>:
  md_split_at_maybe(s, needle, md_find_sub_index(s, needle, 0n))

def md_pos_add(+p: U32, n: Nat) -> U32:
  U32.add(p, U32.from_nat(n))

def md_pos_add_text(+p: U32, +s: String) -> U32:
  md_pos_add(p, Text.utf8_length(s))

def md_span_text(+start: U32, +text: String) -> Ast.Span:
  Ast.Span{start, md_pos_add_text(start, text)}

def md_is_emphasis_char(+c: Char) -> Bool:
  Char.is_eq(c, '*') || Char.is_eq(c, '_')

def md_is_special_inline(+c: Char) -> Bool:
  Char.is_eq(c, '`') || md_is_emphasis_char(c) || Char.is_eq(c, '[') ||
    Char.is_eq(c, '!') || Char.is_eq(c, '<') || Char.is_eq(c, '\n') ||
    Char.is_eq(c, '\\') || Char.is_eq(c, '&')

def md_plain_index(s: String, +idx: Nat) -> Nat:
  match s:
    case SNil{}:
      idx
    case SCon{h, t}:
      ifs(Nat, md_is_special_inline(h),
        u => idx,
        u => md_plain_index(t, 1n+idx))

def md_text_node(+text: String, +start: U32) -> List<&2, Ast.Inline>:
  ifs(List<&2, Ast.Inline>, String.is_empty(text),
    u => Nil{},
    u => Ast.IText{text, md_span_text(start, text)} <> Nil{})

def md_code_newlines_to_spaces(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\n', t}:
      SCon{' ', md_code_newlines_to_spaces(t)}
    case SCon{h, t}:
      SCon{h, md_code_newlines_to_spaces(t)}

def md_all_spaces(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{' ', t}:
      md_all_spaces(t)
    case u:
      False{}

# CommonMark code-span whitespace: line endings become spaces, and when the
# result both begins and ends with a space (while not being all spaces), one
# space is removed from each side.
def md_normalize_code_span(+raw: String) -> String:
  +s = md_code_newlines_to_spaces(raw)
  +len = String.length(s)
  +both = Bool.and(Nat.is_ge(len, 2n),
    Bool.and(String.starts_with(s, " "), String.ends_with(s, " ")))
  +strip = Bool.and(both, Bool.not(md_all_spaces(s)))
  ifs(String, strip,
    u => String.take(String.drop(s, 1n), Nat.sub(len, 2n)),
    u => s)

# Scan balanced link text brackets.  Escaped brackets are literal input;
# unescaped nested pairs are retained in the label for the recursive inline
# parser.  This is intentionally character-oriented rather than substring
# search so `[link [foo [bar]]]` has a chance to parse correctly.
def md_scan_bracket_go(fuel: Nat, +s: String, +acc: String, +depth: Nat) -> Maybe<&2, StrSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'\\', SCon{+h, +t}}:
          md_scan_bracket_go(f, t, SCon{h, SCon{'\\', acc}}, depth)
        case SCon{+h, +t}:
          +close = Char.is_eq(h, ']')
          ifs(Maybe<&2, StrSplit>, close,
            u =>
              ifs(Maybe<&2, StrSplit>, Nat.is_eq(depth, 0n),
                v => Some{StrSplit{String.reverse(acc), t}},
                v => md_scan_bracket_go(f, t, SCon{h, acc}, Nat.sub(depth, 1n))),
            u =>
              +newdepth = ifs(Nat, Char.is_eq(h, '['),
                v => 1n+depth,
                v => depth)
              md_scan_bracket_go(f, t, SCon{h, acc}, newdepth))

def md_scan_bracket(+s: String) -> Maybe<&2, StrSplit>:
  md_scan_bracket_go(Nat.add(String.length(s), 1n), s, SNil{}, 0n)

# Scan the inside of an inline-link parenthesis.  Parentheses nested in the
# destination balance; quoted titles and pointy-bracket destinations group
# their contents.  Escaped punctuation never affects grouping.
def md_link_paren_next_mode(+mode: U32, +h: Char) -> U32:
  ifs(U32, U32.is_eq(mode, 0),
    u =>
      ifs(U32, Char.is_eq(h, '\''),
        v => 39,
        v =>
          ifs(U32, Char.is_eq(h, '"'),
            w => 34,
            w =>
              ifs(U32, Char.is_eq(h, '<'),
                x => 3,
                x => 0)))
    u =>
      ifs(U32, U32.is_eq(mode, 3),
        v => Bool.pick(U32, Char.is_eq(h, '>'), 0, mode),
        v => Bool.pick(U32, U32.is_eq(Char.to_u32(h), mode), 0, mode)))

def md_scan_link_parens_go(fuel: Nat, +s: String, +acc: String, +depth: Nat, +mode: U32) -> Maybe<&2, StrSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'\\', SCon{+h, +t}}:
          md_scan_link_parens_go(f, t, SCon{h, SCon{'\\', acc}}, depth, mode)
        case SCon{+h, +t}:
          +normalclose = Bool.and(U32.is_eq(mode, 0), Char.is_eq(h, ')'))
          ifs(Maybe<&2, StrSplit>, normalclose,
            u =>
              ifs(Maybe<&2, StrSplit>, Nat.is_eq(depth, 0n),
                v => Some{StrSplit{String.reverse(acc), t}},
                v => md_scan_link_parens_go(f, t, SCon{h, acc}, Nat.sub(depth, 1n), mode)),
            u =>
              +newmode = md_link_paren_next_mode(mode, h)
              +opens = Bool.and(U32.is_eq(mode, 0), Char.is_eq(h, '('))
              +newdepth = ifs(Nat, opens,
                v => 1n+depth,
                v => depth)
              md_scan_link_parens_go(f, t, SCon{h, acc}, newdepth, newmode))

def md_scan_link_parens(+s: String) -> Maybe<&2, StrSplit>:
  md_scan_link_parens_go(Nat.add(String.length(s), 1n), s, SNil{}, 0n, 0)

# Scan `[label](destination-and-optional-title)`.  The target is validated
# separately; failure there leaves the opening bracket literal.
def md_scan_link_parts_inner(+after_label_close: String, +label: String) -> Maybe<&2, LinkParts>:
  ifs(Maybe<&2, LinkParts>, String.starts_with(after_label_close, "("),
    u =>
      +after_open = String.drop(after_label_close, 1n)
      maybe_case(StrSplit, Maybe<&2, LinkParts>, md_scan_link_parens(after_open),
        +targethit => Some{LinkParts{label, str_split_before(targethit), str_split_after(targethit)}},
        u => None{})
    u => None{})

def md_scan_link_parts_finish(+hit: StrSplit) -> Maybe<&2, LinkParts>:
  md_scan_link_parts_inner(str_split_after(hit), str_split_before(hit))

def md_scan_link_parts(+s: String) -> Maybe<&2, LinkParts>:
  +after_open = String.drop(s, 1n)
  maybe_case(StrSplit, Maybe<&2, LinkParts>, md_scan_bracket(after_open),
    +hit => md_scan_link_parts_finish(hit),
    u => None{})

def md_split_word_scan(s: String, acc: String) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{' ', t}:
      WordSplit{String.reverse(acc), SCon{' ', t}}
    case SCon{'\t', t}:
      WordSplit{String.reverse(acc), SCon{'\t', t}}
    case SCon{'\n', t}:
      WordSplit{String.reverse(acc), SCon{'\n', t}}
    case SCon{h, t}:
      md_split_word_scan(t, SCon{h, acc})

def md_split_word(+s: String) -> WordSplit:
  md_split_word_scan(s, SNil{})

def md_starts_inline_space(+s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{h, t}:
      md_inline_space_char(h)

def md_scan_angle_dest_go(fuel: Nat, +s: String, +acc: String) -> Maybe<&2, WordSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'\\', SCon{+h, +t}}:
          ifs(Maybe<&2, WordSplit>, Text.ascii_punctuation(h),
            u => md_scan_angle_dest_go(f, t, SCon{h, SCon{'\\', acc}}),
            u => md_scan_angle_dest_go(f, SCon{h, t}, SCon{'\\', acc}))
        case SCon{+h, +t}:
          +bad = Char.is_eq(h, '<') || Char.is_eq(h, '\n') || Char.is_eq(h, '\r')
          ifs(Maybe<&2, WordSplit>, bad,
            u => None{},
            u =>
              ifs(Maybe<&2, WordSplit>, Char.is_eq(h, '>'),
                v => Some{WordSplit{String.reverse(acc), t}},
                v => md_scan_angle_dest_go(f, t, SCon{h, acc})))

def md_scan_angle_dest(+s: String) -> Maybe<&2, WordSplit>:
  md_scan_angle_dest_go(Nat.add(String.length(s), 1n), s, SNil{})

def md_scan_plain_dest_go(fuel: Nat, +s: String, +acc: String, +depth: Nat) -> Maybe<&2, WordSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          ifs(Maybe<&2, WordSplit>, Nat.is_eq(depth, 0n),
            u => Some{WordSplit{String.reverse(acc), SNil{}}},
            u => None{})
        case SCon{'\\', SCon{+h, +t}}:
          ifs(Maybe<&2, WordSplit>, Text.ascii_punctuation(h),
            u => md_scan_plain_dest_go(f, t, SCon{h, SCon{'\\', acc}}, depth),
            u => md_scan_plain_dest_go(f, SCon{h, t}, SCon{'\\', acc}, depth))
        case SCon{+h, +t}:
          ifs(Maybe<&2, WordSplit>, md_inline_space_char(h),
            u =>
              ifs(Maybe<&2, WordSplit>, Nat.is_eq(depth, 0n),
                v => Some{WordSplit{String.reverse(acc), SCon{h, t}}},
                v => None{}),
            u =>
              +code = Char.to_u32(h)
              +control = U32.is_lt(code, 32) || U32.is_eq(code, 127)
              ifs(Maybe<&2, WordSplit>, control,
                v => None{},
                v =>
                  +opens = Char.is_eq(h, '(')
                  +closes = Char.is_eq(h, ')')
                  +newdepth = ifs(Nat, opens,
                    w => 1n+depth,
                    w =>
                      ifs(Nat, closes,
                        x => Nat.sub(depth, 1n),
                        x => depth))
                  md_scan_plain_dest_go(f, t, SCon{h, acc}, newdepth)))

def md_scan_plain_dest(+s: String) -> Maybe<&2, WordSplit>:
  maybe_case(WordSplit, Maybe<&2, WordSplit>,
    md_scan_plain_dest_go(Nat.add(String.length(s), 1n), s, SNil{}, 0n),
    +hit =>
      ifs(Maybe<&2, WordSplit>, String.is_empty(word_split_word(hit)),
        u => None{},
        u => Some{hit}),
    u => None{})

def md_title_newline_blank(s: String) -> Bool:
  match s:
    case SCon{' ', t}:
      md_title_newline_blank(t)
    case SCon{'\t', t}:
      md_title_newline_blank(t)
    case SCon{'\n', t}:
      True{}
    case u:
      False{}

def md_title_has_blank_line(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'\n', +t}:
      md_title_newline_blank(t) || md_title_has_blank_line(t)
    case SCon{h, t}:
      md_title_has_blank_line(t)

def md_scan_title_go(fuel: Nat, +s: String, +acc: String, +close: U32) -> Maybe<&2, WordSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'\\', SCon{+h, +t}}:
          md_scan_title_go(f, t, SCon{h, SCon{'\\', acc}}, close)
        case SCon{+h, +t}:
          +isclose = U32.is_eq(Char.to_u32(h), close)
          +badopen = Bool.and(U32.is_eq(close, 41), Char.is_eq(h, '('))
          ifs(Maybe<&2, WordSplit>, isclose,
            u => Some{WordSplit{String.reverse(acc), t}},
            u =>
              ifs(Maybe<&2, WordSplit>, badopen,
                v => None{},
                v => md_scan_title_go(f, t, SCon{h, acc}, close)))

def md_scan_title(+s: String) -> Maybe<&2, WordSplit>:
  +close = ifs(U32, String.starts_with(s, "\""),
    u => 34,
    u =>
      ifs(U32, String.starts_with(s, "'"),
        v => 39,
        v =>
          ifs(U32, String.starts_with(s, "("),
            w => 41,
            w => 0)))
  ifs(Maybe<&2, WordSplit>, U32.is_eq(close, 0),
    u => None{},
    u =>
      maybe_case(WordSplit, Maybe<&2, WordSplit>,
        md_scan_title_go(Nat.add(String.length(s), 1n), String.drop(s, 1n), SNil{}, close),
        +hit =>
          ifs(Maybe<&2, WordSplit>, md_title_has_blank_line(word_split_word(hit)),
            v => None{},
            v => Some{hit}),
        v => None{}))

def md_finish_link_target(+rawdest: String, +rest0: String) -> Maybe<&2, LinkTarget>:
  +separated = String.is_empty(rest0) || md_starts_inline_space(rest0)
  ifs(Maybe<&2, LinkTarget>, Bool.not(separated),
    u => None{},
    u =>
      +rest = md_trim_inline(rest0)
      ifs(Maybe<&2, LinkTarget>, String.is_empty(rest),
        v => Some{LinkTarget{md_normalize_uri(rawdest), None{}}},
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_title(rest),
            +hit =>
              +after = md_trim_inline(word_split_rest(hit))
              ifs(Maybe<&2, LinkTarget>, String.is_empty(after),
                w => Some{LinkTarget{md_normalize_uri(rawdest),
                  Some{md_decode_ee(word_split_word(hit))}}},
                w => None{}),
            w => None{})))

def md_parse_link_target(+inside: String) -> Maybe<&2, LinkTarget>:
  +trimmed = md_trim_inline(inside)
  ifs(Maybe<&2, LinkTarget>, String.is_empty(trimmed),
    u => Some{LinkTarget{"", None{}}},
    u =>
      ifs(Maybe<&2, LinkTarget>, String.starts_with(trimmed, "<"),
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_angle_dest(String.drop(trimmed, 1n)),
            +hit => md_finish_link_target(word_split_word(hit), word_split_rest(hit)),
            w => None{}),
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_plain_dest(trimmed),
            +hit => md_finish_link_target(word_split_word(hit), word_split_rest(hit)),
            w => None{})))


# Link reference definitions and reference-link labels.  Labels are matched
# as literal source strings: case folding and whitespace normalization happen
# before comparison, but backslash escapes and entities are not decoded.
type RefDef is Data:
  RefDef{label: String, href: String, title: Maybe<&2, String>}

def ref_def_label(x: RefDef) -> String:
  match x:
    case RefDef{label, href, title}:
      label

def ref_def_href(x: RefDef) -> String:
  match x:
    case RefDef{label, href, title}:
      href

def ref_def_title(x: RefDef) -> Maybe<&2, String>:
  match x:
    case RefDef{label, href, title}:
      title

type RefHit is Data:
  RefHit{definition: RefDef, rest: String}

def ref_hit_def(x: RefHit) -> RefDef:
  match x:
    case RefHit{definition, rest}:
      definition

def ref_hit_rest(x: RefHit) -> String:
  match x:
    case RefHit{definition, rest}:
      rest

type RefTargetHit is Data:
  RefTargetHit{href: String, title: Maybe<&2, String>, rest: String}

def ref_target_hit_href(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, title, rest}:
      href

def ref_target_hit_title(x: RefTargetHit) -> Maybe<&2, String>:
  match x:
    case RefTargetHit{href, title, rest}:
      title

def ref_target_hit_rest(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, title, rest}:
      rest

# A link label ends at the first unescaped `]`; unescaped `[` is not allowed.
def md_scan_link_label_go(fuel: Nat, +s: String, +acc: String) -> Maybe<&2, StrSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'\\', SCon{+h, +t}}:
          md_scan_link_label_go(f, t, SCon{h, SCon{'\\', acc}})
        case SCon{']', +t}:
          Some{StrSplit{String.reverse(acc), t}}
        case SCon{'[', t}:
          None{}
        case SCon{+h, +t}:
          md_scan_link_label_go(f, t, SCon{h, acc})

def md_label_has_nonspace(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{+h, +t}:
      Bool.or(Bool.not(md_inline_space_char(h)), md_label_has_nonspace(t))

def md_scan_link_label(+s: String) -> Maybe<&2, StrSplit>:
  ifs(Maybe<&2, StrSplit>, String.starts_with(s, "["),
    u =>
      maybe_case(StrSplit, Maybe<&2, StrSplit>,
        md_scan_link_label_go(Nat.add(String.length(s), 1n), String.drop(s, 1n), SNil{}),
        +hit =>
          +label = str_split_before(hit)
          +ok = Bool.and(Bool.not(String.is_empty(label)),
            Bool.and(Nat.is_le(String.length(label), 999n), md_label_has_nonspace(label)))
          ifs(Maybe<&2, StrSplit>, ok,
            v => Some{hit},
            v => None{}),
        v => None{}),
    u => None{})

# ASCII lowering plus the small amount of Unicode case folding exercised by
# the specification corpus: Greek capitals and sharp-s's expansion to `ss`.
def md_label_fold_char(+h: Char) -> Char:
  +x = Char.to_u32(h)
  +greek1 = Bool.and(U32.is_ge(x, 913), U32.is_le(x, 929))
  +greek2 = Bool.and(U32.is_ge(x, 931), U32.is_le(x, 939))
  ifs(Char, greek1 || greek2,
    u => Char.from_u32(U32.add(x, 32)),
    u => Char.to_lower(h))

def md_label_casefold_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{+h, +t}:
      +x = Char.to_u32(h)
      +sharp = U32.is_eq(x, 223) || U32.is_eq(x, 7838)
      ifs(String, sharp,
        u => md_label_casefold_go(t, SCon{'s', SCon{'s', acc}}),
        u => md_label_casefold_go(t, SCon{md_label_fold_char(h), acc}))

def md_label_casefold(+s: String) -> String:
  md_label_casefold_go(s, SNil{})

def md_label_collapse_go(s: String, +acc: String, +inws: Bool) -> String:
  match s:
    case SNil{}:
      md_trim_end(String.reverse(acc))
    case SCon{+h, +t}:
      ifs(String, md_inline_space_char(h),
        u =>
          ifs(String, inws,
            v => md_label_collapse_go(t, acc, inws),
            v => md_label_collapse_go(t, SCon{' ', acc}, True{})),
        u => md_label_collapse_go(t, SCon{h, acc}, False{}))

def md_normalize_ref_label(+s: String) -> String:
  md_label_collapse_go(md_label_casefold(s), SNil{}, True{})

# Horizontal-space scan used around reference destinations and titles.
def md_scan_hspace_go(s: String, +acc: String) -> WordSplit:
  match s:
    case SCon{' ', t}:
      md_scan_hspace_go(t, SCon{' ', acc})
    case SCon{'\t', t}:
      md_scan_hspace_go(t, SCon{'\t', acc})
    case u:
      WordSplit{String.reverse(acc), u}

def md_scan_hspace(+s: String) -> WordSplit:
  md_scan_hspace_go(s, SNil{})

# Spaces/tabs plus at most one line ending, followed again by spaces/tabs.
def md_skip_ref_ws(+s: String) -> String:
  +first = md_scan_hspace(s)
  +after = word_split_rest(first)
  ifs(String, String.starts_with(after, "\n"),
    u => word_split_rest(md_scan_hspace(String.drop(after, 1n))),
    u => after)

def md_ref_line_end(+s: String) -> Bool:
  String.is_empty(s) || String.starts_with(s, "\n")

def md_ref_title_opener(+s: String) -> Bool:
  String.starts_with(s, "\"") || String.starts_with(s, "'") || String.starts_with(s, "(")

# Try a title at the current position.  On success the returned rest begins
# at the line ending (or EOF) after optional trailing horizontal spaces.
def md_try_ref_title(+s: String) -> Maybe<&2, WordSplit>:
  ifs(Maybe<&2, WordSplit>, md_ref_title_opener(s),
    u =>
      maybe_case(WordSplit, Maybe<&2, WordSplit>, md_scan_title(s),
        +hit =>
          +tail = md_scan_hspace(word_split_rest(hit))
          +after = word_split_rest(tail)
          ifs(Maybe<&2, WordSplit>, md_ref_line_end(after),
            v => Some{WordSplit{md_decode_ee(word_split_word(hit)), after}},
            v => None{}),
        v => None{}),
    u => None{})

def md_ref_target_finish(+href: String, title: Maybe<&2, String>, +rest: String) -> Maybe<&2, RefTargetHit>:
  Some{RefTargetHit{href, title, rest}}

def md_finish_ref_dest(+rawdest: String, +rest: String) -> Maybe<&2, RefTargetHit>:
  +firstcode = md_str_at(rest, 0n)
  +sep = String.is_empty(rest) || Bool.or(U32.is_eq(firstcode, 32),
    Bool.or(U32.is_eq(firstcode, 9), U32.is_eq(firstcode, 10)))
  ifs(Maybe<&2, RefTargetHit>, Bool.not(sep),
    u => None{},
    u =>
      +hs = md_scan_hspace(rest)
      +hadspace = Bool.not(String.is_empty(word_split_word(hs)))
      +afterh = word_split_rest(hs)
      +href = md_normalize_uri(rawdest)
      ifs(Maybe<&2, RefTargetHit>, String.is_empty(afterh),
        v => md_ref_target_finish(href, None{}, afterh),
        v =>
          ifs(Maybe<&2, RefTargetHit>, String.starts_with(afterh, "\n"),
            w =>
              +nextstart = word_split_rest(md_scan_hspace(String.drop(afterh, 1n)))
              maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_try_ref_title(nextstart),
                +titlehit => md_ref_target_finish(href, Some{word_split_word(titlehit)}, word_split_rest(titlehit)),
                x => md_ref_target_finish(href, None{}, afterh)),
            w =>
              ifs(Maybe<&2, RefTargetHit>, Bool.and(hadspace, md_ref_title_opener(afterh)),
                x =>
                  maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_try_ref_title(afterh),
                    +titlehit => md_ref_target_finish(href, Some{word_split_word(titlehit)}, word_split_rest(titlehit)),
                    y => None{}),
                x => None{}))))

def md_scan_ref_target(+aftercolon: String) -> Maybe<&2, RefTargetHit>:
  +start = md_skip_ref_ws(aftercolon)
  ifs(Maybe<&2, RefTargetHit>, String.starts_with(start, "<"),
    u =>
      maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_scan_angle_dest(String.drop(start, 1n)),
        +hit => md_finish_ref_dest(word_split_word(hit), word_split_rest(hit)),
        v => None{}),
    u =>
      maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_scan_plain_dest(start),
        +hit => md_finish_ref_dest(word_split_word(hit), word_split_rest(hit)),
        v => None{}))

def md_scan_reference_definition(+s: String) -> Maybe<&2, RefHit>:
  maybe_case(StrSplit, Maybe<&2, RefHit>, md_scan_link_label(s),
    +labelhit =>
      +afterlabel = str_split_after(labelhit)
      ifs(Maybe<&2, RefHit>, String.starts_with(afterlabel, ":"),
        u =>
          maybe_case(RefTargetHit, Maybe<&2, RefHit>,
            md_scan_ref_target(String.drop(afterlabel, 1n)),
            +targethit =>
              +definition : RefDef = RefDef{md_normalize_ref_label(str_split_before(labelhit)),
                ref_target_hit_href(targethit), ref_target_hit_title(targethit)}
              Some{RefHit{definition, ref_target_hit_rest(targethit)}},
            v => None{}),
        u => None{}),
    v => None{})

def md_refs_have_label(+refs: List<&2, RefDef>, +label: String) -> Bool:
  match refs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(String.eq(ref_def_label(h), label), md_refs_have_label(t, label))

def md_lookup_ref(+refs: List<&2, RefDef>, +label: String) -> Maybe<&2, RefDef>:
  match refs:
    case Nil{}:
      None{}
    case h <> t:
      ifs(Maybe<&2, RefDef>, String.eq(ref_def_label(h), label),
        u => Some{h},
        u => md_lookup_ref(t, label))

def md_uri_scheme_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c, '+') ||
    Char.is_eq(c, '.') || Char.is_eq(c, '-')

def md_uri_scheme_tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(md_uri_scheme_char(h), md_uri_scheme_tail(t))

def md_uri_scheme_valid(+scheme: String) -> Bool:
  match scheme:
    case SNil{}:
      False{}
    case SCon{h, t}:
      +slen = String.length(SCon{h, t})
      Bool.and(Char.is_alpha(h),
        Bool.and(Nat.is_ge(slen, 2n),
          Bool.and(Nat.is_le(slen, 32n), md_uri_scheme_tail(t))))

def md_valid_uri_autolink(+label: String) -> Bool:
  maybe_case(StrSplit, Bool, md_find_split(label, ":"),
    +hit =>
      Bool.and(md_uri_scheme_valid(str_split_before(hit)),
        Bool.not(md_has_line_break_or_space(str_split_after(hit))))
    u => False{})

def md_valid_email_autolink(+label: String) -> Bool:
  # Milestone approximation: exactly one @-shaped split, nonempty sides, no ws.
  maybe_case(StrSplit, Bool, md_find_split(label, "@"),
    +hit =>
      Bool.and(Bool.not(String.is_empty(str_split_before(hit))),
        Bool.and(Bool.not(String.is_empty(str_split_after(hit))),
          Bool.and(Bool.not(md_has_line_break_or_space(label)),
            Bool.not(String.contains(label, "\\")))))
    u => False{})

def md_autolink_href(+label: String, email: Bool) -> String:
  match email:
    case True{}:
      "mailto:" ++ md_uri_encode(label)
    case False{}:
      md_uri_encode(label)

# Raw inline HTML scanning.  The scanner first finds a candidate `>` while
# respecting quoted attribute values, then validates the inside with the
# restricted tag grammar from the CommonMark spec.  Comments, processing
# instructions, declarations and CDATA sections have simpler terminator
# rules and are recognized before ordinary tags.
def md_html_scan_end_go(fuel: Nat, +s: String, +acc: String, +quote: U32) -> Maybe<&2, StrSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{+h, +t}:
          +end = Bool.and(U32.is_eq(quote, 0), Char.is_eq(h, '>'))
          ifs(Maybe<&2, StrSplit>, end,
            u => Some{StrSplit{String.reverse(acc), t}},
            u =>
              +hcode = Char.to_u32(h)
              +newquote = ifs(U32, U32.is_eq(quote, 0),
                v =>
                  ifs(U32, Char.is_eq(h, '\''),
                    w => 39,
                    w => Bool.pick(U32, Char.is_eq(h, '"'), 34, 0)),
                v => Bool.pick(U32, U32.is_eq(hcode, quote), 0, quote))
              md_html_scan_end_go(f, t, SCon{h, acc}, newquote))

def md_scan_html_candidate(+s: String) -> Maybe<&2, StrSplit>:
  md_html_scan_end_go(Nat.add(String.length(s), 1n), String.drop(s, 1n), SNil{}, 0)

def md_html_tag_tail_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c, '-')

def md_html_scan_tag_tail(s: String, +acc: String) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{+h, +t}:
      ifs(WordSplit, md_html_tag_tail_char(h),
        u => md_html_scan_tag_tail(t, SCon{h, acc}),
        u => WordSplit{String.reverse(acc), SCon{h, t}})

def md_scan_html_tag_name(+s: String) -> Maybe<&2, WordSplit>:
  match s:
    case SNil{}:
      None{}
    case SCon{+h, +t}:
      ifs(Maybe<&2, WordSplit>, Char.is_alpha(h),
        u => Some{md_html_scan_tag_tail(t, SCon{h, SNil{}})},
        u => None{})

def md_html_attr_start_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_eq(c, '_') || Char.is_eq(c, ':')

def md_html_attr_tail_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c, '_') ||
    Char.is_eq(c, '.') || Char.is_eq(c, ':') || Char.is_eq(c, '-')

def md_html_scan_attr_tail(s: String, +acc: String) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{+h, +t}:
      ifs(WordSplit, md_html_attr_tail_char(h),
        u => md_html_scan_attr_tail(t, SCon{h, acc}),
        u => WordSplit{String.reverse(acc), SCon{h, t}})

def md_scan_html_attr_name(+s: String) -> Maybe<&2, WordSplit>:
  match s:
    case SNil{}:
      None{}
    case SCon{+h, +t}:
      ifs(Maybe<&2, WordSplit>, md_html_attr_start_char(h),
        u => Some{md_html_scan_attr_tail(t, SCon{h, SNil{}})},
        u => None{})

def md_html_scan_ws(s: String, +acc: String, +newlines: Nat) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{+h, +t}:
      +spacetab = Char.is_eq(h, ' ') || Char.is_eq(h, '\t')
      +newline = Char.is_eq(h, '\n')
      +takeit = spacetab || Bool.and(newline, Nat.is_eq(newlines, 0n))
      ifs(WordSplit, takeit,
        u =>
          +nextlines = ifs(Nat, newline, v => 1n+newlines, v => newlines)
          md_html_scan_ws(t, SCon{h, acc}, nextlines),
        u => WordSplit{String.reverse(acc), SCon{h, t}})

def md_html_ws(+s: String) -> WordSplit:
  md_html_scan_ws(s, SNil{}, 0n)

def md_html_scan_quoted_value_go(fuel: Nat, +s: String, +acc: String, +quote: U32) -> Maybe<&2, WordSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{+h, +t}:
          ifs(Maybe<&2, WordSplit>, U32.is_eq(Char.to_u32(h), quote),
            u => Some{WordSplit{String.reverse(acc), t}},
            u => md_html_scan_quoted_value_go(f, t, SCon{h, acc}, quote))

def md_html_unquoted_value_char(+c: Char) -> Bool:
  Bool.not(md_inline_space_char(c) ||
    Char.is_eq(c, '"') || Char.is_eq(c, '\'') || Char.is_eq(c, '=') ||
    Char.is_eq(c, '<') || Char.is_eq(c, '>') || Char.is_eq(c, '`'))

def md_html_scan_unquoted_value_go(fuel: Nat, +s: String, +acc: String) -> Maybe<&2, WordSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          +word = String.reverse(acc)
          ifs(Maybe<&2, WordSplit>, String.is_empty(word),
            u => None{},
            u => Some{WordSplit{word, SNil{}}})
        case SCon{+h, +t}:
          ifs(Maybe<&2, WordSplit>, md_html_unquoted_value_char(h),
            u => md_html_scan_unquoted_value_go(f, t, SCon{h, acc}),
            u =>
              +word = String.reverse(acc)
              ifs(Maybe<&2, WordSplit>, String.is_empty(word),
                v => None{},
                v => Some{WordSplit{word, SCon{h, t}}}))

def md_scan_html_attr_value(+s: String) -> Maybe<&2, WordSplit>:
  match s:
    case SCon{'\'', t}:
      md_html_scan_quoted_value_go(Nat.add(String.length(t), 1n), t, SNil{}, 39)
    case SCon{'"', t}:
      md_html_scan_quoted_value_go(Nat.add(String.length(t), 1n), t, SNil{}, 34)
    case u:
      md_html_scan_unquoted_value_go(Nat.add(String.length(u), 1n), u, SNil{})

# After an attribute name, either there is no value, or optional whitespace
# is followed by `=`, optional whitespace, and a value.  If no `=` follows,
# the whitespace is left for the attribute-loop delimiter.
def md_html_optional_value(+s: String) -> Maybe<&2, String>:
  +ws = md_html_ws(s)
  +afterws = word_split_rest(ws)
  ifs(Maybe<&2, String>, String.starts_with(afterws, "="),
    u =>
      +aftereq = md_html_ws(String.drop(afterws, 1n))
      maybe_case(WordSplit, Maybe<&2, String>, md_scan_html_attr_value(word_split_rest(aftereq)),
        +hit => Some{word_split_rest(hit)},
        v => None{}),
    u => Some{s})

def md_html_open_attrs_go(fuel: Nat, +s: String) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n++f:
      ifs(Bool, String.is_empty(s) || String.eq(s, "/"),
        u => True{},
        u =>
          +ws = md_html_ws(s)
          +wstext = word_split_word(ws)
          +afterws = word_split_rest(ws)
          ifs(Bool, String.is_empty(wstext),
            v => False{},
            v =>
              ifs(Bool, String.is_empty(afterws) || String.eq(afterws, "/"),
                w => True{},
                w =>
                  maybe_case(WordSplit, Bool, md_scan_html_attr_name(afterws),
                    +namehit =>
                      maybe_case(String, Bool, md_html_optional_value(word_split_rest(namehit)),
                        +rest => md_html_open_attrs_go(f, rest),
                        x => False{}),
                    x => False{}))))

def md_valid_html_open_inner(+inner: String) -> Bool:
  maybe_case(WordSplit, Bool, md_scan_html_tag_name(inner),
    +hit => md_html_open_attrs_go(Nat.add(String.length(inner), 1n), word_split_rest(hit)),
    u => False{})

def md_valid_html_close_inner(+inner: String) -> Bool:
  ifs(Bool, String.starts_with(inner, "/"),
    u =>
      maybe_case(WordSplit, Bool, md_scan_html_tag_name(String.drop(inner, 1n)),
        +hit =>
          +ws = md_html_ws(word_split_rest(hit))
          String.is_empty(word_split_rest(ws)),
        v => False{}),
    u => False{})

def md_scan_html_openclose(+s: String) -> Maybe<&2, StrSplit>:
  maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_html_candidate(s),
    +hit =>
      +inner = str_split_before(hit)
      +after = str_split_after(hit)
      +valid = md_valid_html_open_inner(inner) || md_valid_html_close_inner(inner)
      ifs(Maybe<&2, StrSplit>, valid,
        u => Some{StrSplit{"<" ++ inner ++ ">", after}},
        u => None{}),
    u => None{})

def md_fixed_prefix_token(+s: String, +prefix: String) -> Maybe<&2, StrSplit>:
  ifs(Maybe<&2, StrSplit>, String.starts_with(s, prefix),
    u => Some{StrSplit{prefix, String.drop(s, String.length(prefix))}},
    u => None{})

def md_scan_delimited_html(+s: String, +prefix: String, +close: String) -> Maybe<&2, StrSplit>:
  ifs(Maybe<&2, StrSplit>, String.starts_with(s, prefix),
    u =>
      +afterpre = String.drop(s, String.length(prefix))
      maybe_case(StrSplit, Maybe<&2, StrSplit>, md_find_split(afterpre, close),
        +hit => Some{StrSplit{prefix ++ str_split_before(hit) ++ close, str_split_after(hit)}},
        v => None{}),
    u => None{})

def md_html_declaration_start(+s: String) -> Bool:
  Bool.and(String.starts_with(s, "<!"), Char.is_alpha(Char.from_u32(md_str_at(s, 2n))))

def md_scan_html_declaration(+s: String) -> Maybe<&2, StrSplit>:
  ifs(Maybe<&2, StrSplit>, md_html_declaration_start(s),
    u => md_scan_delimited_html(s, "<!", ">"),
    u => None{})

def md_scan_raw_html(+s: String) -> Maybe<&2, StrSplit>:
  maybe_case(StrSplit, Maybe<&2, StrSplit>, md_fixed_prefix_token(s, "<!--->"),
    +hit => Some{hit},
    u =>
      maybe_case(StrSplit, Maybe<&2, StrSplit>, md_fixed_prefix_token(s, "<!-->"),
        +hit2 => Some{hit2},
        v =>
          maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_delimited_html(s, "<!--", "-->"),
            +hit3 => Some{hit3},
            v =>
              maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_delimited_html(s, "<![CDATA[", "]]>"),
                +hit4 => Some{hit4},
                w =>
                  maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_delimited_html(s, "<?", "?>"),
                    +hit5 => Some{hit5},
                    w =>
                      maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_html_declaration(s),
                        +hit6 => Some{hit6},
                        x => md_scan_html_openclose(s)))))))

# Find a delimiter run of exactly width characters.  This is intentionally
# stricter than substring search: in `*outer **inner** outer*` the outer
# single-star search skips the inner double-star runs instead of mistaking
# their first byte for the outer closer.  It is still only an approximation of
# CommonMark's full delimiter-run/flanking algorithm.
def md_find_exact_delim_index(+s: String, +marker: Char, +width: Nat, +idx: Nat, +prev_same: Bool) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{h, t}:
      +same = Char.is_eq(h, marker)
      +run = md_count_prefix(s, marker, 0n)
      +hit = Bool.and(same, Bool.and(Nat.is_eq(run, width), Bool.not(prev_same)))
      ifs(Maybe<&2, Nat>, hit,
        u => Some{idx},
        u => md_find_exact_delim_index(t, marker, width, 1n+idx, same))

def md_exact_delim_maybe(+s: String, +marker: Char, +width: Nat, m: Maybe<&2, Nat>) -> Maybe<&2, StrSplit>:
  match m:
    case Some{idx}:
      Some{md_split_at_index(s, idx, width)}
    case None{}:
      None{}

def md_find_exact_delim(+s: String, +marker: Char, +width: Nat) -> Maybe<&2, StrSplit>:
  md_exact_delim_maybe(s, marker, width, md_find_exact_delim_index(s, marker, width, 0n, False{}))

def md_inline_space_code(+code: U32) -> Bool:
  U32.is_eq(code, 32) || U32.is_eq(code, 9) || U32.is_eq(code, 10) || U32.is_eq(code, 13)

def md_unicode_space_code(+code: U32) -> Bool:
  md_inline_space_code(code) || U32.is_eq(code, 12) || U32.is_eq(code, 160) ||
    U32.is_eq(code, 5760) || Bool.and(U32.is_ge(code, 8192), U32.is_le(code, 8202)) ||
    U32.is_eq(code, 8239) || U32.is_eq(code, 8287) || U32.is_eq(code, 12288)

# A unified validated link/image target plus the unconsumed input after it.
type LinkChoice is Data:
  LinkChoice{target: LinkTarget, after: String}

def link_choice_target(x: LinkChoice) -> LinkTarget:
  match x:
    case LinkChoice{target, after}:
      target

def link_choice_after(x: LinkChoice) -> String:
  match x:
    case LinkChoice{target, after}:
      after

def md_link_choice(+target: LinkTarget, +after: String) -> Maybe<&2, LinkChoice>:
  Some{LinkChoice{target, after}}

def md_ref_target_from_def(+hit: RefDef) -> LinkTarget:
  LinkTarget{ref_def_href(hit), ref_def_title(hit)}

def md_lookup_ref_target(+refs: List<&2, RefDef>, +rawlabel: String) -> Maybe<&2, LinkTarget>:
  +label = md_normalize_ref_label(rawlabel)
  maybe_case(RefDef, Maybe<&2, LinkTarget>, md_lookup_ref(refs, label),
    +hit => Some{md_ref_target_from_def(hit)},
    u => None{})

# Reference forms, in precedence order after inline links: full, collapsed,
# shortcut.  A syntactically valid following label blocks shortcut parsing
# even when that label itself is undefined.
def md_scan_ref_label_use(+refs: List<&2, RefDef>, +textlabel: String, +afterclose: String) -> Maybe<&2, LinkChoice>:
  ifs(Maybe<&2, LinkChoice>, String.starts_with(afterclose, "[]"),
    u =>
      maybe_case(LinkTarget, Maybe<&2, LinkChoice>, md_lookup_ref_target(refs, textlabel),
        +target => md_link_choice(target, String.drop(afterclose, 2n)),
        v => None{}),
    u =>
      ifs(Maybe<&2, LinkChoice>, String.starts_with(afterclose, "["),
        v =>
          maybe_case(StrSplit, Maybe<&2, LinkChoice>, md_scan_link_label(afterclose),
            +labelhit =>
              maybe_case(LinkTarget, Maybe<&2, LinkChoice>,
                md_lookup_ref_target(refs, str_split_before(labelhit)),
                +target => md_link_choice(target, str_split_after(labelhit)),
                w => None{}),
            w =>
              maybe_case(LinkTarget, Maybe<&2, LinkChoice>, md_lookup_ref_target(refs, textlabel),
                +target => md_link_choice(target, afterclose),
                x => None{})),
        v =>
          maybe_case(LinkTarget, Maybe<&2, LinkChoice>, md_lookup_ref_target(refs, textlabel),
            +target => md_link_choice(target, afterclose),
            w => None{})))

def md_scan_inline_link_choice(+textlabel: String, +afterclose: String) -> Maybe<&2, LinkChoice>:
  maybe_case(LinkParts, Maybe<&2, LinkChoice>, md_scan_link_parts_inner(afterclose, textlabel),
    +parts =>
      maybe_case(LinkTarget, Maybe<&2, LinkChoice>, md_parse_link_target(link_parts_inside(parts)),
        +target => md_link_choice(target, link_parts_after(parts)),
        u => None{}),
    u => None{})


# Approximate plain textual content used for image alt attributes.  Entities
# and escapes are decoded and the ASCII markup delimiters most common in image
# descriptions are removed.  This intentionally avoids a second AST-walking
# recursive machine in the inline parser.
def md_strip_alt_markup(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'*', t}:
      md_strip_alt_markup(t)
    case SCon{'_', t}:
      md_strip_alt_markup(t)
    case SCon{'`', t}:
      md_strip_alt_markup(t)
    case SCon{h, t}:
      SCon{h, md_strip_alt_markup(t)}

def md_alt_text(+label: String) -> String:
  md_strip_alt_markup(md_decode_ee(label))


type MdEmphDelim is Data:
  MdEmphDelim{start: U32, end: U32, marker: Char, count: Nat, runlen: Nat,
    can_open: Bool, can_close: Bool, both: Bool}

def md_delim_start(x: MdEmphDelim) -> U32:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      start

def md_delim_end(x: MdEmphDelim) -> U32:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      end

def md_delim_marker(x: MdEmphDelim) -> Char:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      marker

def md_delim_count(x: MdEmphDelim) -> Nat:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      count

def md_delim_runlen(x: MdEmphDelim) -> Nat:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      runlen

def md_delim_can_open(x: MdEmphDelim) -> Bool:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      can_open

def md_delim_can_close(x: MdEmphDelim) -> Bool:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      can_close

def md_delim_both(x: MdEmphDelim) -> Bool:
  match x:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      both

def md_unicode_punct_code(+code: U32) -> Bool:
  Unicode.unicode_punct_or_symbol(Char.from_u32(code))

def md_make_emph_delim(+start: U32, +end: U32, +marker: Char, +count: Nat,
    +runlen: Nat, +can_open: Bool, +can_close: Bool) -> MdEmphDelim:
  +both = Bool.and(can_open, can_close)
  (MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both} : MdEmphDelim)

def md_scan_delims_go(fuel: Nat, +s: String, +pos: U32, +hasprev: Bool, +prevcode: U32,
    +hasend: Bool, +endcode: U32, +acc: List<&2, MdEmphDelim>) -> List<&2, MdEmphDelim>:
  match fuel:
    case 0n:
      acc
    case 1n++f:
      match s:
        case SNil{}:
          acc
        case SCon{'\\', SCon{+h, +t}}:
          ifs(List<&2, MdEmphDelim>, Text.ascii_punctuation(h),
            u => md_scan_delims_go(f, t, md_pos_add(pos, 2n), True{}, Char.to_u32(h), hasend, endcode, acc),
            u => md_scan_delims_go(f, SCon{h, t}, md_pos_add(pos, 1n), True{}, 92, hasend, endcode, acc))
        case SCon{'\\', +t}:
          md_scan_delims_go(f, t, md_pos_add(pos, 1n), True{}, 92, hasend, endcode, acc)
        case SCon{+h, +t}:
          ifs(List<&2, MdEmphDelim>, md_is_emphasis_char(h),
            u =>
              +tailrun = md_count_prefix(t, h, 0n)
              +run = Nat.add(1n, tailrun)
              +after = String.drop(t, tailrun)
              +endpos = md_pos_add(pos, run)
              +afterend = String.is_empty(after)
              +aftercode = md_str_at(after, 0n)
              +prevws = ifs(Bool, hasprev,
                v => md_unicode_space_code(prevcode),
                v => True{})
              +prevpu = ifs(Bool, hasprev,
                v => md_unicode_punct_code(prevcode),
                v => False{})
              +afterws = ifs(Bool, afterend,
                v => ifs(Bool, hasend,
                  w => md_unicode_space_code(endcode),
                  w => True{}),
                v => md_unicode_space_code(aftercode))
              +afterpu = ifs(Bool, afterend,
                v => ifs(Bool, hasend,
                  w => md_unicode_punct_code(endcode),
                  w => False{}),
                v => md_unicode_punct_code(aftercode))
              +left = Bool.and(Bool.not(afterws),
                Bool.or(Bool.not(afterpu), Bool.or(prevws, prevpu)))
              +right = Bool.and(Bool.not(prevws),
                Bool.or(Bool.not(prevpu), Bool.or(afterws, afterpu)))
              +open = ifs(Bool, Char.is_eq(h, '*'),
                v => left,
                v => Bool.and(left, Bool.or(Bool.not(right), prevpu)))
              +close = ifs(Bool, Char.is_eq(h, '*'),
                v => right,
                v => Bool.and(right, Bool.or(Bool.not(left), afterpu)))
              +hit = md_make_emph_delim(pos, endpos, h, run, run, open, close)
              md_scan_delims_go(f, after, endpos, True{}, Char.to_u32(h), hasend, endcode, hit <> acc),
            u => md_scan_delims_go(f, t, md_pos_add_text(pos, md_char_string(h)), True{}, Char.to_u32(h), hasend, endcode, acc))

def md_scan_delim_infos_ctx(+s: String, +pos: U32, +hasprev: Bool, +prevcode: U32,
    +hasend: Bool, +endcode: U32) -> List<&2, MdEmphDelim>:
  +fuel = Nat.add(String.length(s), 1n)
  List.reverse(&2, MdEmphDelim,
    md_scan_delims_go(fuel, s, pos, hasprev, prevcode, hasend, endcode, Nil{}))

def md_scan_delim_infos(+s: String, +pos: U32) -> List<&2, MdEmphDelim>:
  md_scan_delim_infos_ctx(s, pos, False{}, 0, False{}, 0)

type MdEmphTok is Data:
  MdTokNode{node: Ast.Inline}
  MdTokDelim{delim: MdEmphDelim}

def md_make_tok_node(+node: Ast.Inline) -> MdEmphTok:
  (MdTokNode{node} : MdEmphTok)

def md_make_tok_delim(+delim: MdEmphDelim) -> MdEmphTok:
  (MdTokDelim{delim} : MdEmphTok)

def md_cons_tok_node(+node: Ast.Inline, +tail: List<&2, MdEmphTok>) -> List<&2, MdEmphTok>:
  +tok = md_make_tok_node(node)
  tok <> tail

def md_cons_tok_delim(+delim: MdEmphDelim, +tail: List<&2, MdEmphTok>) -> List<&2, MdEmphTok>:
  +tok = md_make_tok_delim(delim)
  tok <> tail

def md_make_span(+start: U32, +end: U32) -> Ast.Span:
  (Ast.Span{start, end} : Ast.Span)

def md_span_start(x: Ast.Span) -> U32:
  match x:
    case Ast.Span{start, end}:
      start

def md_span_end(x: Ast.Span) -> U32:
  match x:
    case Ast.Span{start, end}:
      end

def md_delim_at(+xs: List<&2, MdEmphDelim>, +start: U32, +end: U32) -> Maybe<&2, MdEmphDelim>:
  match xs:
    case Nil{}:
      None{}
    case +h <> t:
      ifs(Maybe<&2, MdEmphDelim>,
        Bool.and(U32.is_eq(md_delim_start(h), start), U32.is_eq(md_delim_end(h), end)),
        u => Some{h},
        u => md_delim_at(t, start, end))

def md_emph_tokenize_text(+text: String, +span: Ast.Span,
    +infos: List<&2, MdEmphDelim>) -> MdEmphTok:
  maybe_case(MdEmphDelim, MdEmphTok,
    md_delim_at(infos, md_span_start(span), md_span_end(span)),
    +delim => md_make_tok_delim(delim),
    u => md_make_tok_node(Ast.IText{text, span}))

def md_emph_tokenize(+infos: List<&2, MdEmphDelim>, xs: List<&2, Ast.Inline>) -> List<&2, MdEmphTok>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Ast.IText{text, span}:
          md_emph_tokenize_text(text, span, infos) <> md_emph_tokenize(infos, t)
        case u:
          md_make_tok_node(u) <> md_emph_tokenize(infos, t)

def md_emph_tok_finish(tok: MdEmphTok) -> Ast.Inline:
  match tok:
    case MdTokNode{node}:
      node
    case MdTokDelim{+delim}:
      +text = md_repeat_char(md_delim_marker(delim), md_delim_count(delim))
      Ast.IText{text, md_make_span(md_delim_start(delim), md_delim_end(delim))}

def md_emph_finalize_tokens(xs: List<&2, MdEmphTok>) -> List<&2, Ast.Inline>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      md_emph_tok_finish(h) <> md_emph_finalize_tokens(t)

type MdEmphHit is Data:
  MdEmphHit{index: Nat, delim: MdEmphDelim}

def md_make_emph_hit(+index: Nat, +delim: MdEmphDelim) -> MdEmphHit:
  (MdEmphHit{index, delim} : MdEmphHit)

def md_emph_hit_index(x: MdEmphHit) -> Nat:
  match x:
    case MdEmphHit{index, delim}:
      index

def md_emph_hit_delim(x: MdEmphHit) -> MdEmphDelim:
  match x:
    case MdEmphHit{index, delim}:
      delim

def md_emph_close_ready(+d: MdEmphDelim) -> Bool:
  Bool.and(md_delim_can_close(d), Nat.is_gt(md_delim_count(d), 0n))

def md_find_emph_closer_go(xs: List<&2, MdEmphTok>, +idx: Nat) -> Maybe<&2, MdEmphHit>:
  match xs:
    case Nil{}:
      None{}
    case h <> t:
      match h:
        case MdTokNode{node}:
          md_find_emph_closer_go(t, 1n+idx)
        case MdTokDelim{+delim}:
          ifs(Maybe<&2, MdEmphHit>, md_emph_close_ready(delim),
            u => Some{md_make_emph_hit(idx, delim)},
            u => md_find_emph_closer_go(t, 1n+idx))

def md_find_emph_closer(+xs: List<&2, MdEmphTok>) -> Maybe<&2, MdEmphHit>:
  md_find_emph_closer_go(xs, 0n)

def md_emph_lengths_ok(+orun: Nat, +crun: Nat, +oboth: Bool, +cboth: Bool) -> Bool:
  +sum = Nat.add(orun, crun)
  +sum3 = Nat.is_eq(Nat.mod(sum, 3n), 0n)
  +om3 = Nat.is_eq(Nat.mod(orun, 3n), 0n)
  +cm3 = Nat.is_eq(Nat.mod(crun, 3n), 0n)
  +blocked = Bool.and(Bool.or(oboth, cboth),
    Bool.and(sum3, Bool.not(Bool.and(om3, cm3))))
  Bool.not(blocked)

def md_delim_open_compatible(+op: MdEmphDelim, +cl: MdEmphDelim) -> Bool:
  Bool.and(Char.is_eq(md_delim_marker(op), md_delim_marker(cl)),
    Bool.and(md_delim_can_open(op),
      Bool.and(Nat.is_gt(md_delim_count(op), 0n),
        md_emph_lengths_ok(md_delim_runlen(op), md_delim_runlen(cl),
          md_delim_both(op), md_delim_both(cl)))))

def md_find_emph_opener_go(xs: List<&2, MdEmphTok>, +idx: Nat,
    +best: Maybe<&2, MdEmphHit>, +closer: MdEmphDelim) -> Maybe<&2, MdEmphHit>:
  match xs:
    case Nil{}:
      best
    case h <> t:
      match h:
        case MdTokNode{node}:
          md_find_emph_opener_go(t, 1n+idx, best, closer)
        case MdTokDelim{+delim}:
          +hit = md_delim_open_compatible(delim, closer)
          +newbest = Bool.pick(Maybe<&2, MdEmphHit>, hit, Some{md_make_emph_hit(idx, delim)}, best)
          md_find_emph_opener_go(t, 1n+idx, newbest, closer)

def md_find_emph_opener(+xs: List<&2, MdEmphTok>, +closer: MdEmphDelim) -> Maybe<&2, MdEmphHit>:
  md_find_emph_opener_go(xs, 0n, None{}, closer)

def md_delim_open_remainder(+d: MdEmphDelim, +count: Nat) -> MdEmphDelim:
  match d:
    case MdEmphDelim{start, end, marker, oldcount, runlen, can_open, can_close, both}:
      MdEmphDelim{start, U32.add(start, U32.from_nat(count)), marker, count, runlen, can_open, can_close, both}

def md_delim_close_remainder(+d: MdEmphDelim, +count: Nat) -> MdEmphDelim:
  match d:
    case MdEmphDelim{start, end, marker, oldcount, runlen, can_open, can_close, both}:
      MdEmphDelim{U32.sub(end, U32.from_nat(count)), end, marker, count, runlen, can_open, can_close, both}

def md_delim_close_off(+d: MdEmphDelim) -> MdEmphDelim:
  match d:
    case MdEmphDelim{start, end, marker, count, runlen, can_open, can_close, both}:
      MdEmphDelim{start, end, marker, count, runlen, can_open, False{}, both}

def md_emph_cons_remainder(+d: MdEmphDelim, +xs: List<&2, MdEmphTok>) -> List<&2, MdEmphTok>:
  ifs(List<&2, MdEmphTok>, Nat.is_gt(md_delim_count(d), 0n),
    u => md_cons_tok_delim(d, xs),
    u => xs)

def md_make_iemph(+children: List<&2, Ast.Inline>, +span: Ast.Span) -> Ast.Inline:
  (Ast.IEmph{children, span} : Ast.Inline)

def md_make_istrong(+children: List<&2, Ast.Inline>, +span: Ast.Span) -> Ast.Inline:
  (Ast.IStrong{children, span} : Ast.Inline)

def md_emph_wrap_tokens(+tokens: List<&2, MdEmphTok>, +oi: Nat, +ci: Nat,
    +op: MdEmphDelim, +cl: MdEmphDelim) -> List<&2, MdEmphTok>:
  +use = Bool.pick(Nat,
    Bool.and(Nat.is_ge(md_delim_count(op), 2n), Nat.is_ge(md_delim_count(cl), 2n)),
    2n, 1n)
  +openleft = Nat.sub(md_delim_count(op), use)
  +closeleft = Nat.sub(md_delim_count(cl), use)
  +newop = md_delim_open_remainder(op, openleft)
  +newcl = md_delim_close_remainder(cl, closeleft)
  +middlelen = Nat.sub(ci, Nat.add(oi, 1n))
  +middle = List.take(&2, MdEmphTok, List.drop(&2, MdEmphTok, tokens, Nat.add(oi, 1n)), middlelen)
  +inner = md_emph_finalize_tokens(middle)
  +span = md_make_span(U32.sub(md_delim_end(op), U32.from_nat(use)), U32.add(md_delim_start(cl), U32.from_nat(use)))
  +node = Bool.pick(Ast.Inline, Nat.is_eq(use, 2n),
    md_make_istrong(inner, span),
    md_make_iemph(inner, span))
  +before = List.take(&2, MdEmphTok, tokens, oi)
  +after = List.drop(&2, MdEmphTok, tokens, Nat.add(ci, 1n))
  +tail = md_emph_cons_remainder(newcl, after)
  +center = md_cons_tok_node(node, tail)
  +front = md_emph_cons_remainder(newop, center)
  List.append(&2, MdEmphTok, before, front)

def md_emph_process(fuel: Nat, +tokens: List<&2, MdEmphTok>) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      md_emph_finalize_tokens(tokens)
    case 1n++f:
      maybe_case(MdEmphHit, List<&2, Ast.Inline>, md_find_emph_closer(tokens),
        +closerhit =>
          +ci = md_emph_hit_index(closerhit)
          +cl = md_emph_hit_delim(closerhit)
          +beforecloser = List.take(&2, MdEmphTok, tokens, ci)
          maybe_case(MdEmphHit, List<&2, Ast.Inline>, md_find_emph_opener(beforecloser, cl),
            +openerhit =>
              +oi = md_emph_hit_index(openerhit)
              +op = md_emph_hit_delim(openerhit)
              md_emph_process(f, md_emph_wrap_tokens(tokens, oi, ci, op, cl)),
            u =>
              +newcloser = md_delim_close_off(cl)
              md_emph_process(f,
                List.set(&2, MdEmphTok, tokens, ci, md_make_tok_delim(newcloser)))),
        u => md_emph_finalize_tokens(tokens))

def md_emph_resolve_input_ctx(+s: String, +pos: U32, +hasprev: Bool, +prevcode: U32,
    +hasend: Bool, +endcode: U32, xs: List<&2, Ast.Inline>) -> List<&2, Ast.Inline>:
  +infos = md_scan_delim_infos_ctx(s, pos, hasprev, prevcode, hasend, endcode)
  +tokens = md_emph_tokenize(infos, xs)
  +len = Text.utf8_length(s)
  md_emph_process(Nat.add(Nat.mul(8n, len), 8n), tokens)

def md_emph_resolve_input(+s: String, +pos: U32, xs: List<&2, Ast.Inline>) -> List<&2, Ast.Inline>:
  md_emph_resolve_input_ctx(s, pos, False{}, 0, False{}, 0, xs)

def md_emph_resolve_link_label_input(+s: String, +pos: U32, xs: List<&2, Ast.Inline>) -> List<&2, Ast.Inline>:
  md_emph_resolve_input_ctx(s, pos, True{}, 91, True{}, 93, xs)

# Inline scanner.  It is one recursive definition, so there is no mutual
# recursion; nested content and the continuation both recurse on fuel's
# predecessor.  Malformed delimiters consume at least one byte as literal text.
def md_parse_inlines(fuel: Nat, +refs: List<&2, RefDef>, +s: String, +pos: U32) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      md_text_node(s, pos)
    case 1n++f:
      match s:
        case SNil{}:
          Nil{}
        case SCon{'\n', t}:
          +endpos = md_pos_add(pos, 1n)
          Ast.ISoftBreak{Ast.Span{pos, endpos}} <> md_parse_inlines(f, refs, t, endpos)
        case SCon{'\\', SCon{'\n', t}}:
          +after = md_drop_leading_spaces(t)
          +skipped = Nat.sub(Text.utf8_length(t), Text.utf8_length(after))
          +breakend = md_pos_add(pos, 2n)
          +newpos = md_pos_add(breakend, skipped)
          Ast.IHardBreak{Ast.Span{pos, breakend}} <> md_parse_inlines(f, refs, after, newpos)
        case SCon{'\\', SCon{+h, +t}}:
          ifs(List<&2, Ast.Inline>, Text.ascii_punctuation(h),
            u =>
              +escaped = md_char_string(h)
              +endpos = md_pos_add(pos, 2n)
              Ast.IText{escaped, Ast.Span{pos, endpos}} <> md_parse_inlines(f, refs, t, endpos),
            u => Ast.IText{"\\", md_span_text(pos, "\\")} <>
              md_parse_inlines(f, refs, SCon{h, t}, md_pos_add_text(pos, "\\")))
        case SCon{'\\', t}:
          Ast.IText{"\\", md_span_text(pos, "\\")} <>
            md_parse_inlines(f, refs, t, md_pos_add_text(pos, "\\"))
        case SCon{'&', t}:
          maybe_case(EntityHit, List<&2, Ast.Inline>, md_scan_entity_after_amp(t),
            +hit =>
              +decoded = entity_hit_decoded(hit)
              +after = entity_hit_after(hit)
              +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(after))
              +endpos = md_pos_add(pos, used)
              Ast.IText{decoded, Ast.Span{pos, endpos}} <> md_parse_inlines(f, refs, after, endpos)
            u => Ast.IText{"&", md_span_text(pos, "&")} <>
              md_parse_inlines(f, refs, t, md_pos_add_text(pos, "&")))
        case SCon{'`', t}:
          +run = md_count_prefix(s, '`', 0n)
          +needle = md_repeat_char('`', run)
          +after_open = String.drop(s, run)
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_find_exact_delim(after_open, '`', run),
            +hit =>
              +content = str_split_before(hit)
              +rest = str_split_after(hit)
              +open_bytes = Text.utf8_length(needle)
              +content_start = md_pos_add(pos, open_bytes)
              +content_end = md_pos_add_text(content_start, content)
              +endpos = md_pos_add(content_end, open_bytes)
              ifs(List<&2, Ast.Inline>, String.is_empty(content),
                u => Ast.IText{needle, md_span_text(pos, needle)} <>
                  md_parse_inlines(f, refs, after_open, md_pos_add_text(pos, needle)),
                u => Ast.ICode{md_normalize_code_span(content), Ast.Span{pos, endpos}} <>
                  md_parse_inlines(f, refs, rest, endpos))
            u => Ast.IText{needle, md_span_text(pos, needle)} <>
              md_parse_inlines(f, refs, after_open, md_pos_add_text(pos, needle)))
        case SCon{'[', t}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_bracket(t),
            +closehit =>
              +label = str_split_before(closehit)
              +afterclose = str_split_after(closehit)
              +inlinechoice0 = md_scan_inline_link_choice(label, afterclose)
              +choice = maybe_case(LinkChoice, Maybe<&2, LinkChoice>, inlinechoice0,
                +inlinehit => Some{inlinehit},
                u => md_scan_ref_label_use(refs, label, afterclose))
              maybe_case(LinkChoice, List<&2, Ast.Inline>, choice,
                +goodchoice =>
                  +rest = link_choice_after(goodchoice)
                  +goodtarget = link_choice_target(goodchoice)
                  +label_start = md_pos_add(pos, 1n)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = md_pos_add(pos, used)
                  +labelinner0 = md_parse_inlines(f, refs, label, label_start)
                  +labelinner = md_emph_resolve_link_label_input(label, label_start, labelinner0)
                  Ast.ILink{labelinner, link_target_href(goodtarget),
                    link_target_title(goodtarget), Ast.Span{pos, endpos}} <>
                    md_parse_inlines(f, refs, rest, endpos),
                z => Ast.IText{"[", md_span_text(pos, "[")} <>
                  md_parse_inlines(f, refs, t, md_pos_add_text(pos, "[")))
            u => Ast.IText{"[", md_span_text(pos, "[")} <>
              md_parse_inlines(f, refs, t, md_pos_add_text(pos, "[")))
        case SCon{'!', SCon{'[', tt}}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_bracket(tt),
            +closehit =>
              +label = str_split_before(closehit)
              +afterclose = str_split_after(closehit)
              +inlinechoice0 = md_scan_inline_link_choice(label, afterclose)
              +choice = maybe_case(LinkChoice, Maybe<&2, LinkChoice>, inlinechoice0,
                +inlinehit => Some{inlinehit},
                u => md_scan_ref_label_use(refs, label, afterclose))
              maybe_case(LinkChoice, List<&2, Ast.Inline>, choice,
                +goodchoice =>
                  +rest = link_choice_after(goodchoice)
                  +goodtarget = link_choice_target(goodchoice)
                  +label_start = md_pos_add(pos, 2n)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = md_pos_add(pos, used)
                  +children = md_parse_inlines(f, refs, label, label_start)
                  Ast.IImage{link_target_href(goodtarget), md_alt_text(label),
                    link_target_title(goodtarget), Ast.Span{pos, endpos}} <>
                    md_parse_inlines(f, refs, rest, endpos),
                z => Ast.IText{"!", md_span_text(pos, "!")} <>
                  md_parse_inlines(f, refs, SCon{'[', tt}, md_pos_add_text(pos, "!")))
            u => Ast.IText{"!", md_span_text(pos, "!")} <>
              md_parse_inlines(f, refs, SCon{'[', tt}, md_pos_add_text(pos, "!")))
        case SCon{'!', t}:
          Ast.IText{"!", md_span_text(pos, "!")} <>
            md_parse_inlines(f, refs, t, md_pos_add_text(pos, "!"))
        case SCon{'<', t}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_raw_html(s),
            +rawhit =>
              +raw = str_split_before(rawhit)
              +rawrest = str_split_after(rawhit)
              +rawend = md_pos_add_text(pos, raw)
              Ast.IRawHtml{raw, Ast.Span{pos, rawend}} <> md_parse_inlines(f, refs, rawrest, rawend)
            u =>
              maybe_case(StrSplit, List<&2, Ast.Inline>, md_find_split(t, ">"),
                +hit =>
                  +label = str_split_before(hit)
                  +rest = str_split_after(hit)
                  +is_uri = md_valid_uri_autolink(label)
                  +is_email = Bool.not(is_uri) && md_valid_email_autolink(label)
                  +ok = Bool.and(is_uri || is_email, Bool.not(String.contains(label, "<")))
                  +used = Nat.add(Text.utf8_length(label), 2n)
                  +endpos = md_pos_add(pos, used)
                  ifs(List<&2, Ast.Inline>, ok,
                    v => Ast.IAutolink{md_autolink_href(label, is_email), label,
                      Ast.Span{pos, endpos}} <> md_parse_inlines(f, refs, rest, endpos),
                    v => Ast.IText{"<", md_span_text(pos, "<")} <>
                      md_parse_inlines(f, refs, t, md_pos_add_text(pos, "<")))
                u => Ast.IText{"<", md_span_text(pos, "<")} <>
                  md_parse_inlines(f, refs, t, md_pos_add_text(pos, "<"))))
        case SCon{h, t}:
          ifs(List<&2, Ast.Inline>, md_is_emphasis_char(h),
            u =>
              +run = md_count_prefix(s, h, 0n)
              +delimiter = md_repeat_char(h, run)
              +endpos = md_pos_add(pos, run)
              Ast.IText{delimiter, Ast.Span{pos, endpos}} <>
                md_parse_inlines(f, refs, String.drop(s, run), endpos)
            u =>
              +n = md_plain_index(s, 0n)
              +plain0 = String.take(s, n)
              +rest = String.drop(s, n)
              ifs(List<&2, Ast.Inline>, String.starts_with(rest, "\n"),
                v =>
                  +spacecount = md_count_trailing_spaces(plain0)
                  +plain = md_drop_trailing_spaces(plain0)
                  +hard = Nat.is_ge(spacecount, 2n)
                  +plainend = md_pos_add_text(pos, plain)
                  +nlpos = md_pos_add_text(pos, plain0)
                  +nlend = md_pos_add(nlpos, 1n)
                  +after_nl = String.drop(rest, 1n)
                  +after = ifs(String, hard,
                    w => md_drop_leading_spaces(after_nl),
                    w => after_nl)
                  +skipped = Nat.sub(Text.utf8_length(after_nl), Text.utf8_length(after))
                  +newpos = md_pos_add(nlend, skipped)
                  ifs(List<&2, Ast.Inline>, hard,
                    w =>
                      ifs(List<&2, Ast.Inline>, String.is_empty(plain),
                        x => Ast.IHardBreak{Ast.Span{pos, nlend}} <>
                          md_parse_inlines(f, refs, after, newpos),
                        x => Ast.IText{plain, Ast.Span{pos, plainend}} <>
                          Ast.IHardBreak{Ast.Span{plainend, nlend}} <>
                          md_parse_inlines(f, refs, after, newpos)),
                    w =>
                      ifs(List<&2, Ast.Inline>, String.is_empty(plain),
                        x => Ast.ISoftBreak{Ast.Span{nlpos, nlend}} <>
                          md_parse_inlines(f, refs, after, newpos),
                        x => Ast.IText{plain, Ast.Span{pos, plainend}} <>
                          Ast.ISoftBreak{Ast.Span{nlpos, nlend}} <>
                          md_parse_inlines(f, refs, after, newpos))),
                v =>
                  +endpos = md_pos_add_text(pos, plain0)
                  Ast.IText{plain0, Ast.Span{pos, endpos}} <> md_parse_inlines(f, refs, rest, endpos)))

def md_parse_inlines_top(+refs: List<&2, RefDef>, +s: String, +pos: U32) -> List<&2, Ast.Inline>:
  +len = Text.utf8_length(s)
  +fuel = Nat.add(Nat.mul(8n, len), 8n)
  +scanned = md_parse_inlines(fuel, refs, s, pos)
  md_emph_resolve_input(s, pos, scanned)

# Block parsing
# =============

type MdLine is Data:
  MdLine{text: String, start: U32, end: U32}

def md_line_text(x: MdLine) -> String:
  match x:
    case MdLine{text, start, end}:
      text

def md_line_start(x: MdLine) -> U32:
  match x:
    case MdLine{text, start, end}:
      start

def md_line_end(x: MdLine) -> U32:
  match x:
    case MdLine{text, start, end}:
      end

def md_line_span(x: MdLine) -> Ast.Span:
  match x:
    case MdLine{text, start, end}:
      Ast.Span{start, end}

# String.lines is character based and reports one artificial empty cell after
# a final line terminator.  Remove exactly that final cell before annotating
# lines; real trailing blank lines remain because they appear as earlier empty
# cells.  Besides being cleaner for ordinary blocks, this keeps an unclosed
# fenced block from gaining a phantom extra LF at EOF.
def md_drop_final_empty(+xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> Nil{}:
      ifs(List<&2, String>, String.is_empty(h),
        u => Nil{},
        u => [h])
    case h <> (x <> rest):
      h <> md_drop_final_empty(x <> rest)

# Annotate each line with an approximate UTF-8 byte interval in the
# normalized source.
def md_make_lines(+xs: List<&2, String>, +start: Nat) -> List<&2, MdLine>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      +len = Text.utf8_length(h)
      +spos = U32.from_nat(start)
      +epos = U32.from_nat(Nat.add(start, len))
      MdLine{h, spos, epos} <> md_make_lines(t, Nat.add(Nat.add(start, len), 1n))

type StringLinesGrab is Data:
  StringLinesGrab{lines: List<&2, String>, rest: List<&2, MdLine>, end: U32}

def string_lines_grab_lines(x: StringLinesGrab) -> List<&2, String>:
  match x:
    case StringLinesGrab{lines, rest, end}:
      lines

def string_lines_grab_rest(x: StringLinesGrab) -> List<&2, MdLine>:
  match x:
    case StringLinesGrab{lines, rest, end}:
      rest

def string_lines_grab_end(x: StringLinesGrab) -> U32:
  match x:
    case StringLinesGrab{lines, rest, end}:
      end

type LinesGrab is Data:
  LinesGrab{lines: List<&2, MdLine>, rest: List<&2, MdLine>, end: U32}

def lines_grab_lines(x: LinesGrab) -> List<&2, MdLine>:
  match x:
    case LinesGrab{lines, rest, end}:
      lines

def lines_grab_rest(x: LinesGrab) -> List<&2, MdLine>:
  match x:
    case LinesGrab{lines, rest, end}:
      rest

def lines_grab_end(x: LinesGrab) -> U32:
  match x:
    case LinesGrab{lines, rest, end}:
      end

type ParaGrab is Data:
  ParaGrab{lines: List<&2, MdLine>, rest: List<&2, MdLine>, end: U32, setext: U32}

def para_grab_lines(x: ParaGrab) -> List<&2, MdLine>:
  match x:
    case ParaGrab{lines, rest, end, setext}:
      lines

def para_grab_rest(x: ParaGrab) -> List<&2, MdLine>:
  match x:
    case ParaGrab{lines, rest, end, setext}:
      rest

def para_grab_end(x: ParaGrab) -> U32:
  match x:
    case ParaGrab{lines, rest, end, setext}:
      end

def para_grab_setext(x: ParaGrab) -> U32:
  match x:
    case ParaGrab{lines, rest, end, setext}:
      setext

type DigitScan is Data:
  DigitScan{count: Nat, value: U32}

def digit_scan_count(x: DigitScan) -> Nat:
  match x:
    case DigitScan{count, value}:
      count

def digit_scan_value(x: DigitScan) -> U32:
  match x:
    case DigitScan{count, value}:
      value

type SimpleListGrab is Data:
  SimpleListGrab{items: List<&2, Ast.ListItem>, rest: List<&2, MdLine>, end: U32}

def simple_list_grab_items(x: SimpleListGrab) -> List<&2, Ast.ListItem>:
  match x:
    case SimpleListGrab{items, rest, end}:
      items

def simple_list_grab_rest(x: SimpleListGrab) -> List<&2, MdLine>:
  match x:
    case SimpleListGrab{items, rest, end}:
      rest

def simple_list_grab_end(x: SimpleListGrab) -> U32:
  match x:
    case SimpleListGrab{items, rest, end}:
      end

# Up to three ASCII spaces are block-marker indentation in this milestone.
# Tabs are preserved as literal indentation except in blank-line detection.
def md_marker_indent(+s: String) -> Nat:
  md_leading_spaces(s, 0n)

def md_after_marker_indent(+s: String) -> String:
  String.drop(s, md_marker_indent(s))

def md_marker_indent_ok(+s: String) -> Bool:
  Nat.is_le(md_marker_indent(s), 3n)

# Fences.
def md_fence_count_for(+s: String, +marker: Char) -> Nat:
  +indent = md_marker_indent(s)
  ifs(Nat, Nat.is_le(indent, 3n),
    u => md_count_prefix(String.drop(s, indent), marker, 0n),
    u => 0n)

def md_is_fence_start(+s: String) -> Bool:
  +btick = md_fence_count_for(s, '`')
  +tilde = md_fence_count_for(s, '~')
  +len = Nat.max(btick, tilde)
  +indent = md_marker_indent(s)
  +info = md_trim(String.drop(s, Nat.add(indent, len)))
  +present = Nat.is_ge(btick, 3n) || Nat.is_ge(tilde, 3n)
  +backtick_info_ok = Bool.not(Bool.and(Nat.is_ge(btick, 3n), String.contains(info, "`")))
  Bool.and(present, backtick_info_ok)

def md_fence_marker(+s: String) -> Char:
  ifs(Char, Nat.is_ge(md_fence_count_for(s, '`'), 3n),
    u => '`',
    u => '~')

def md_fence_len(+s: String) -> Nat:
  Nat.max(md_fence_count_for(s, '`'), md_fence_count_for(s, '~'))

def md_fence_info(+s: String) -> String:
  +indent = md_marker_indent(s)
  +len = md_fence_len(s)
  +decoded = md_decode_ee(md_trim(String.drop(s, Nat.add(indent, len))))
  word_split_word(md_split_word(decoded))

def md_is_fence_close(+s: String, +marker: Char, +minlen: Nat) -> Bool:
  +indent = md_marker_indent(s)
  +count = md_fence_count_for(s, marker)
  +rest = String.drop(s, Nat.add(indent, count))
  Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(count, minlen), Text.blank_line(rest)))

# ATX headings.
def md_atx_count(+s: String) -> Nat:
  +indent = md_marker_indent(s)
  ifs(Nat, Nat.is_le(indent, 3n),
    u => md_count_prefix(String.drop(s, indent), '#', 0n),
    u => 0n)

def md_atx_next_ok(+code: U32) -> Bool:
  U32.is_eq(code, 0) || U32.is_eq(code, 32) || U32.is_eq(code, 9)

def md_is_atx(+s: String) -> Bool:
  +indent = md_marker_indent(s)
  +count = md_atx_count(s)
  +next = md_str_at(s, Nat.add(indent, count))
  Bool.and(Nat.is_ge(count, 1n),
    Bool.and(Nat.is_le(count, 6n), md_atx_next_ok(next)))

def md_atx_level(+s: String) -> U32:
  U32.from_nat(md_atx_count(s))

def md_strip_atx_closing(+s: String) -> String:
  +rev = String.reverse(s)
  +n = md_count_prefix(rev, '#', 0n)
  +after = String.drop(rev, n)
  +after_code = md_str_at(after, 0n)
  +valid = Bool.and(Nat.is_ge(n, 1n),
    Bool.or(String.is_empty(after), Bool.or(U32.is_eq(after_code, 32), U32.is_eq(after_code, 9))))
  ifs(String, valid,
    u => String.reverse(md_trim_start(after)),
    u => s)

def md_atx_text(+s: String) -> String:
  +indent = md_marker_indent(s)
  +count = md_atx_count(s)
  md_strip_atx_closing(md_trim(String.drop(s, Nat.add(indent, count))))

# Thematic breaks and Setext underlines.
def md_thematic_with(+s: String, +marker: Char) -> Bool:
  +indent = md_marker_indent(s)
  +rest = String.drop(s, indent)
  +compact = md_compact_horizontal_space(rest)
  Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(String.length(compact), 3n), md_all_char(compact, marker)))

def md_is_thematic(+s: String) -> Bool:
  md_thematic_with(s, '-') || md_thematic_with(s, '_') || md_thematic_with(s, '*')

def md_setext_with(+s: String, +marker: Char, level: U32) -> U32:
  +indent = md_marker_indent(s)
  +rest = md_trim_end(String.drop(s, indent))
  +ok = Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(String.length(rest), 1n), md_all_char(rest, marker)))
  ifs(U32, ok,
    u => level,
    u => 0)

def md_setext_level(+s: String) -> U32:
  +eq = md_setext_with(s, '=', 1)
  ifs(U32, U32.is_zero(eq),
    u => md_setext_with(s, '-', 2),
    u => eq)

# Block quotes.
def md_is_quote_start(+s: String) -> Bool:
  +indent = md_marker_indent(s)
  Bool.and(Nat.is_le(indent, 3n), String.starts_with(String.drop(s, indent), ">"))

def md_quote_strip_text(+s: String) -> String:
  +indent = md_marker_indent(s)
  +after = String.drop(s, Nat.add(indent, 1n))
  ifs(String, String.starts_with(after, " "),
    u => String.drop(after, 1n),
    u =>
      ifs(String, String.starts_with(after, "\t"),
        v => String.drop(after, 1n),
        v => after))

def md_quote_strip_line(+line: MdLine) -> MdLine:
  +text = md_line_text(line)
  +content = md_quote_strip_text(text)
  +removed = Nat.sub(Text.utf8_length(text), Text.utf8_length(content))
  MdLine{content, md_pos_add(md_line_start(line), removed), md_line_end(line)}

# A small local list-start recognizer used only for quote laziness.  The full
# list scanner below has the ordered-start value machinery; this predicate is
# intentionally just enough to keep a sibling list marker outside a quote.
def md_digit_count_only(s: String, +acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      ifs(Nat, Char.is_digit(h),
        u => md_digit_count_only(t, 1n+acc),
        u => acc)

def md_quote_space_ok(+code: U32) -> Bool:
  U32.is_eq(code, 0) || U32.is_eq(code, 32) || U32.is_eq(code, 9)

def md_quote_listish(+s: String) -> Bool:
  +indent = md_marker_indent(s)
  +mark = md_str_at(s, indent)
  +next = md_str_at(s, Nat.add(indent, 1n))
  +bullet = Bool.and(U32.is_eq(mark, 45) || U32.is_eq(mark, 43) || U32.is_eq(mark, 42),
    md_quote_space_ok(next))
  +digits = md_digit_count_only(String.drop(s, indent), 0n)
  +delim = md_str_at(s, Nat.add(indent, digits))
  +afterdelim = md_str_at(s, Nat.add(Nat.add(indent, digits), 1n))
  +ordered = Bool.and(Nat.is_ge(digits, 1n),
    Bool.and(Nat.is_le(digits, 9n),
      Bool.and(U32.is_eq(delim, 46) || U32.is_eq(delim, 41), md_quote_space_ok(afterdelim))))
  Bool.and(Nat.is_le(indent, 3n), bullet || ordered)

# Heuristic lazy-continuation gate for this milestone.  It recognizes the
# common case of an open plain paragraph inside the quote.  Full laziness is
# container-stack dependent and remains a later milestone.
def md_quote_lazy_ok(+s: String) -> Bool:
  Bool.and(Bool.not(Text.blank_line(s)),
    Bool.not(md_is_fence_start(s) || md_is_atx(s) || md_is_thematic(s) ||
      md_is_quote_start(s) || md_quote_listish(s)))

def md_scan_quote_finish(acc: List<&2, MdLine>, rest: List<&2, MdLine>, +end: U32) -> LinesGrab:
  LinesGrab{List.reverse(&2, MdLine, acc), rest, end}

def md_scan_quote_go(
  +xs: List<&2, MdLine>,
  +acc: List<&2, MdLine>,
  +end: U32,
  +lazy_ok: Bool
) -> LinesGrab:
  match xs:
    case Nil{}:
      md_scan_quote_finish(acc, Nil{}, end)
    case line <> rest:
      +text = md_line_text(line)
      ifs(LinesGrab, md_is_quote_start(text),
        u =>
          +stripped = md_quote_strip_line(line)
          +next_lazy = md_quote_lazy_ok(md_line_text(stripped))
          md_scan_quote_go(rest, stripped <> acc, md_line_end(line), next_lazy)
        u =>
          +lazy = Bool.and(lazy_ok, md_quote_lazy_ok(text))
          ifs(LinesGrab, lazy,
            v => md_scan_quote_go(rest, line <> acc, md_line_end(line), lazy),
            v => md_scan_quote_finish(acc, line <> rest, end)))

def md_scan_quote(+xs: List<&2, MdLine>) -> LinesGrab:
  md_scan_quote_go(xs, Nil{}, 0, False{})

# Fenced-code collection.  Content lines contribute one normalized LF each;
# an unclosed fence simply closes at end of input.
def md_drop_up_to_spaces(s: String, n: Nat) -> String:
  match s n:
    case SCon{' ', t} 1n+p:
      md_drop_up_to_spaces(t, p)
    case u _:
      u

def md_join_code_lines(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case h <> t:
      h ++ ("\n" ++ md_join_code_lines(t))

def md_drop_empty_front(+xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      ifs(List<&2, String>, String.is_empty(h),
        u => md_drop_empty_front(t),
        u => h <> t)

# Indented-code trailing blank lines belong to the block structurally but not
# to its literal payload.  Interior blank lines are preserved.
def md_trim_trailing_empty_lines(+xs: List<&2, String>) -> List<&2, String>:
  List.reverse(&2, String, md_drop_empty_front(List.reverse(&2, String, xs)))

def md_scan_fenced_finish(+acc: List<&2, String>, rest: List<&2, MdLine>, +end: U32) -> StringLinesGrab:
  StringLinesGrab{List.reverse(&2, String, acc), rest, end}

def md_scan_fenced_go(
  +xs: List<&2, MdLine>,
  +marker: Char,
  +minlen: Nat,
  +openindent: Nat,
  +acc: List<&2, String>,
  +end: U32
) -> StringLinesGrab:
  match xs:
    case Nil{}:
      md_scan_fenced_finish(acc, Nil{}, end)
    case line <> rest:
      +text = md_line_text(line)
      ifs(StringLinesGrab, md_is_fence_close(text, marker, minlen),
        u => md_scan_fenced_finish(acc, rest, md_line_end(line)),
        u => md_scan_fenced_go(rest, marker, minlen, openindent,
          md_drop_up_to_spaces(text, openindent) <> acc, md_line_end(line)))

def md_scan_fenced(+xs: List<&2, MdLine>, +marker: Char, +minlen: Nat, +openindent: Nat, +startend: U32) -> StringLinesGrab:
  md_scan_fenced_go(xs, marker, minlen, openindent, Nil{}, startend)

# Indented code.  This milestone consumes simple blank lines inside the block
# and strips four ASCII spaces where present.
def md_is_indented_code_line(+s: String) -> Bool:
  Bool.and(Nat.is_ge(md_marker_indent(s), 4n), Bool.not(Text.blank_line(s)))

def md_indented_content(+s: String) -> String:
  String.drop(s, 4n)

def md_scan_indented_go(
  +xs: List<&2, MdLine>,
  +acc: List<&2, String>,
  +end: U32
) -> StringLinesGrab:
  match xs:
    case Nil{}:
      md_scan_fenced_finish(acc, Nil{}, end)
    case line <> rest:
      +text = md_line_text(line)
      +takeit = md_is_indented_code_line(text) || Text.blank_line(text)
      ifs(StringLinesGrab, takeit,
        u => md_scan_indented_go(rest, md_indented_content(text) <> acc, md_line_end(line)),
        u => md_scan_fenced_finish(acc, line <> rest, end))

def md_scan_indented(+xs: List<&2, MdLine>) -> StringLinesGrab:
  md_scan_indented_go(xs, Nil{}, 0)

# HTML blocks.  Kind numbers follow the seven start conditions in the
# CommonMark spec.  Type 6/7 blocks end immediately before a blank line;
# types 1--5 end on the line containing their matching terminator.
def md_starts_ci(+s: String, +prefix: String) -> Bool:
  String.starts_with(String.to_lower(s), prefix)

def md_contains_ci(+s: String, +needle: String) -> Bool:
  String.contains(String.to_lower(s), needle)

def md_html_type1_with(+s: String, +prefix: String) -> Bool:
  +len = String.length(prefix)
  +next = md_str_at(s, len)
  Bool.and(md_starts_ci(s, prefix),
    Bool.or(U32.is_eq(next, 0), Bool.or(U32.is_eq(next, 32),
      Bool.or(U32.is_eq(next, 9), U32.is_eq(next, 62)))))

def md_html_type1_start(+s: String) -> Bool:
  md_html_type1_with(s, "<pre") || md_html_type1_with(s, "<script") ||
    md_html_type1_with(s, "<style") || md_html_type1_with(s, "<textarea")

def md_html_type1_end(+s: String) -> Bool:
  md_contains_ci(s, "</pre>") || md_contains_ci(s, "</script>") ||
    md_contains_ci(s, "</style>") || md_contains_ci(s, "</textarea>")

def md_html_block6_names() -> String:
  "|address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul|"

def md_html_type6_delimiter(+rest: String) -> Bool:
  String.is_empty(rest) || String.starts_with(rest, " ") ||
    String.starts_with(rest, "\t") || String.starts_with(rest, ">") ||
    String.starts_with(rest, "/>")

def md_html_type6_start(+s: String) -> Bool:
  +offset = ifs(Nat, String.starts_with(s, "</"), u => 2n, u => 1n)
  ifs(Bool, String.starts_with(s, "<"),
    u =>
      maybe_case(WordSplit, Bool, md_scan_html_tag_name(String.drop(s, offset)),
        +hit =>
          +name = String.to_lower(word_split_word(hit))
          +known = String.contains(md_html_block6_names(), "|" ++ name ++ "|")
          Bool.and(known, md_html_type6_delimiter(word_split_rest(hit))),
        v => False{}),
    u => False{})

def md_html_type7_excluded(+name: String) -> Bool:
  String.eq(name, "pre") || String.eq(name, "script") ||
    String.eq(name, "style") || String.eq(name, "textarea")

def md_html_type7_start(+s0: String) -> Bool:
  +s = md_trim_end(s0)
  ifs(Bool, String.starts_with(s, "<"),
    u =>
      maybe_case(StrSplit, Bool, md_scan_html_openclose(s),
        +hit =>
          +whole = String.eq(str_split_before(hit), s)
          +offset = ifs(Nat, String.starts_with(s, "</"), v => 2n, v => 1n)
          +namepart = md_scan_html_tag_name(String.drop(s, offset))
          maybe_case(WordSplit, Bool, namepart,
            +namehit =>
              +name = String.to_lower(word_split_word(namehit))
              Bool.and(whole, Bool.not(md_html_type7_excluded(name))),
            v => False{}),
        v => False{}),
    u => False{})

# Return 0 for no HTML block start, otherwise the CommonMark type number.
def md_html_block_kind(+line: String) -> Nat:
  +s = String.drop(line, Nat.min(md_marker_indent(line), 3n))
  ifs(Nat, md_html_type1_start(s),
    u => 1n,
    u =>
      ifs(Nat, String.starts_with(s, "<!--"),
        v => 2n,
        v =>
          ifs(Nat, String.starts_with(s, "<?"),
            w => 3n,
            w =>
              ifs(Nat, md_html_declaration_start(s),
                x => 4n,
                x =>
                  ifs(Nat, String.starts_with(s, "<![CDATA["),
                    y => 5n,
                    y =>
                      ifs(Nat, md_html_type6_start(s),
                        z => 6n,
                        z => Bool.pick(Nat, md_html_type7_start(s), 7n, 0n)))))))

def md_html_closed_end(+s: String, +kind: Nat) -> Bool:
  ifs(Bool, Nat.is_eq(kind, 1n),
    u => md_html_type1_end(s),
    u =>
      ifs(Bool, Nat.is_eq(kind, 2n),
        v => String.contains(s, "-->"),
        v =>
          ifs(Bool, Nat.is_eq(kind, 3n),
            w => String.contains(s, "?>"),
            w =>
              ifs(Bool, Nat.is_eq(kind, 4n),
                x => String.contains(s, ">"),
                x => String.contains(s, "]]>")))))

def md_scan_html_closed_go(
  +xs: List<&2, MdLine>,
  +kind: Nat,
  +acc: List<&2, String>,
  +end: U32
) -> StringLinesGrab:
  match xs:
    case Nil{}:
      md_scan_fenced_finish(acc, Nil{}, end)
    case line <> rest:
      +text = md_line_text(line)
      +newacc : List<&2, String> = text <> acc
      +newend = md_line_end(line)
      ifs(StringLinesGrab, md_html_closed_end(text, kind),
        u => md_scan_fenced_finish(newacc, rest, newend),
        u => md_scan_html_closed_go(rest, kind, newacc, newend))

# 0 = continue, 1 = end of input, 2 = next line is blank.
def md_html_open_stop(+xs: List<&2, MdLine>) -> Nat:
  match xs:
    case Nil{}:
      1n
    case line <> rest:
      Bool.pick(Nat, Text.blank_line(md_line_text(line)), 2n, 0n)

def md_scan_html_open_go(
  +xs: List<&2, MdLine>,
  +acc: List<&2, String>,
  +end: U32
) -> StringLinesGrab:
  match xs:
    case Nil{}:
      md_scan_fenced_finish(acc, Nil{}, end)
    case line <> +rest:
      +text = md_line_text(line)
      +newacc : List<&2, String> = text <> acc
      +newend = md_line_end(line)
      +stopcode = md_html_open_stop(rest)
      +stop = Nat.is_ne(stopcode, 0n)
      +outrest = ifs(List<&2, MdLine>, Nat.is_eq(stopcode, 1n),
        u => Nil{},
        u => rest)
      ifs(StringLinesGrab, stop,
        u => md_scan_fenced_finish(newacc, outrest, newend),
        u => md_scan_html_open_go(rest, newacc, newend))

def md_scan_html_block(+xs: List<&2, MdLine>, +kind: Nat) -> StringLinesGrab:
  ifs(StringLinesGrab, Nat.is_le(kind, 5n),
    u => md_scan_html_closed_go(xs, kind, Nil{}, 0),
    u => md_scan_html_open_go(xs, Nil{}, 0))

# Simple list markers.
def md_scan_digits(+s: String, +count: Nat, +value: U32) -> DigitScan:
  match s:
    case SNil{}:
      DigitScan{count, value}
    case SCon{h, t}:
      ifs(DigitScan, Char.is_digit(h),
        u => md_scan_digits(t, 1n+count,
          U32.add(U32.mul(value, 10), U32.sub(Char.to_u32(h), 48))),
        u => DigitScan{count, value})

def md_ordered_scan(+s: String) -> DigitScan:
  +indent = md_marker_indent(s)
  md_scan_digits(String.drop(s, indent), 0n, 0)

def md_list_space_ok(+code: U32) -> Bool:
  U32.is_eq(code, 0) || U32.is_eq(code, 32) || U32.is_eq(code, 9)

def md_is_ordered_item(+s: String) -> Bool:
  +indent = md_marker_indent(s)
  +scan = md_ordered_scan(s)
  +count = digit_scan_count(scan)
  +delim = md_str_at(s, Nat.add(indent, count))
  +next = md_str_at(s, Nat.add(Nat.add(indent, count), 1n))
  Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(count, 1n),
      Bool.and(Nat.is_le(count, 9n),
        Bool.and(U32.is_eq(delim, 46) || U32.is_eq(delim, 41), md_list_space_ok(next)))))

def md_is_unordered_item(+s: String) -> Bool:
  +indent = md_marker_indent(s)
  +mark = md_str_at(s, indent)
  +next = md_str_at(s, Nat.add(indent, 1n))
  +bullet = U32.is_eq(mark, 45) || U32.is_eq(mark, 43) || U32.is_eq(mark, 42)
  Bool.and(Nat.is_le(indent, 3n), Bool.and(bullet, md_list_space_ok(next)))

def md_is_list_item(+s: String) -> Bool:
  md_is_unordered_item(s) || md_is_ordered_item(s)

def md_ordered_start(+s: String) -> U32:
  digit_scan_value(md_ordered_scan(s))

def md_list_marker_width(+s: String, ordered: Bool) -> Nat:
  match ordered:
    case True{}:
      Nat.add(Nat.add(md_marker_indent(s), digit_scan_count(md_ordered_scan(s))), 1n)
    case False{}:
      Nat.add(md_marker_indent(s), 1n)

def md_list_strip_line(+line: MdLine, +ordered: Bool) -> MdLine:
  +text = md_line_text(line)
  +width = md_list_marker_width(text, ordered)
  +content = md_trim_start(String.drop(text, width))
  +removed = Nat.sub(Text.utf8_length(text), Text.utf8_length(content))
  MdLine{content, md_pos_add(md_line_start(line), removed), md_line_end(line)}

# Indentation required of a simple continuation line: marker width plus the
# one-to-four spaces following it when present.  Tabs remain a milestone
# approximation.
def md_list_item_indent(+s: String, +ordered: Bool) -> Nat:
  +raw = md_list_marker_width(s, ordered)
  +spaces = md_count_prefix(String.drop(s, raw), ' ', 0n)
  ifs(Nat, Nat.is_eq(spaces, 0n),
    u => raw,
    u => Nat.add(raw, Nat.min(spaces, 4n)))

# Collect nonblank continuation lines indented by at least the item's content
# indentation.  They are joined into the item's single paragraph in this
# milestone; nested blocks inside list items are not yet modeled.
def md_scan_list_cont_go(
  +xs: List<&2, MdLine>,
  +indent: Nat,
  +acc: List<&2, String>,
  +end: U32
) -> StringLinesGrab:
  match xs:
    case Nil{}:
      md_scan_fenced_finish(acc, Nil{}, end)
    case line <> rest:
      +text = md_line_text(line)
      +takeit = Bool.and(Bool.not(Text.blank_line(text)), Nat.is_ge(md_marker_indent(text), indent))
      ifs(StringLinesGrab, takeit,
        u => md_scan_list_cont_go(rest, indent,
          md_drop_up_to_spaces(text, indent) <> acc, md_line_end(line)),
        u => md_scan_fenced_finish(acc, line <> rest, end))

def md_scan_list_cont(+xs: List<&2, MdLine>, +indent: Nat, +startend: U32) -> StringLinesGrab:
  md_scan_list_cont_go(xs, indent, Nil{}, startend)

# Marker identity used to keep adjacent-but-different simple lists apart:
# bullet byte for unordered lists, `.`/`)` byte for ordered lists.
def md_list_marker_code(+s: String, ordered: Bool) -> U32:
  match ordered:
    case True{}:
      md_str_at(s, Nat.add(md_marker_indent(s), digit_scan_count(md_ordered_scan(s))))
    case False{}:
      md_str_at(s, md_marker_indent(s))

def md_scan_list_finish(+acc: List<&2, Ast.ListItem>, rest: List<&2, MdLine>, +end: U32) -> SimpleListGrab:
  SimpleListGrab{List.reverse(&2, Ast.ListItem, acc), rest, end}

def md_scan_list_go(
  fuel: Nat,
  +refs: List<&2, RefDef>,
  +xs: List<&2, MdLine>,
  +ordered: Bool,
  +markcode: U32,
  +acc: List<&2, Ast.ListItem>,
  +end: U32
) -> SimpleListGrab:
  match fuel:
    case 0n:
      md_scan_list_finish(acc, xs, end)
    case 1n++f:
      match xs:
        case Nil{}:
          md_scan_list_finish(acc, Nil{}, end)
        case line <> rest:
          +text = md_line_text(line)
          +this_ordered = md_is_ordered_item(text)
          +this_unordered = md_is_unordered_item(text)
          +typevalid = ifs(Bool, ordered,
            u => this_ordered,
            u => this_unordered)
          +thismark = md_list_marker_code(text, this_ordered)
          +valid = Bool.and(typevalid, U32.is_eq(thismark, markcode))
          ifs(SimpleListGrab, valid,
            u =>
              +stripped = md_list_strip_line(line, ordered)
              +firstcontent = md_line_text(stripped)
              +content_start = md_line_start(stripped)
              +contentindent = md_list_item_indent(text, ordered)
              +cont = md_scan_list_cont(rest, contentindent, md_line_end(line))
              +content = String.join(firstcontent <> string_lines_grab_lines(cont), "\n")
              +span : Ast.Span = Ast.Span{md_line_start(line), string_lines_grab_end(cont)}
              +inlines = md_parse_inlines_top(refs, content, content_start)
              para : Ast.Block = Ast.BParagraph{inlines, [], span}
              item : Ast.ListItem = Ast.ListItem{[para], span}
              md_scan_list_go(f, refs, string_lines_grab_rest(cont), ordered, markcode,
                item <> acc, string_lines_grab_end(cont))
            u => md_scan_list_finish(acc, line <> rest, end))

def md_scan_list(+refs: List<&2, RefDef>, +xs: List<&2, MdLine>, +ordered: Bool) -> SimpleListGrab:
  match xs:
    case Nil{}:
      SimpleListGrab{Nil{}, Nil{}, 0}
    case line <> rest:
      +len = List.length(&2, MdLine, xs)
      +fuel = Nat.add(Nat.mul(4n, len), 4n)
      md_scan_list_go(fuel, refs, xs, ordered, md_list_marker_code(md_line_text(line), ordered), Nil{}, 0)

# Paragraph collection.  A Setext underline is recognized before generic
# interruption because `---` is also a valid thematic-break marker.
def md_html_interrupts_paragraph(+s: String) -> Bool:
  +kind = md_html_block_kind(s)
  Bool.and(Nat.is_ne(kind, 0n), Nat.is_ne(kind, 7n))

# Lists interrupt paragraphs only in the cases allowed by CommonMark:
# ordered lists must start at 1, and a bullet item may not be empty.  The
# thematic-break interpretation is considered separately by the caller.
def md_list_interrupts_paragraph(+s: String) -> Bool:
  +ordered = md_is_ordered_item(s)
  +unordered = md_is_unordered_item(s)
  ifs(Bool, ordered,
    u =>
      +width = md_list_marker_width(s, True{})
      Bool.and(U32.is_eq(md_ordered_start(s), 1), Bool.not(Text.blank_line(String.drop(s, width)))),
    u =>
      ifs(Bool, unordered,
        v =>
          +width = md_list_marker_width(s, False{})
          Bool.not(Text.blank_line(String.drop(s, width))),
        v => False{}))

def md_is_paragraph_interrupt(+s: String) -> Bool:
  md_is_fence_start(s) || md_is_atx(s) || md_is_thematic(s) ||
    md_is_quote_start(s) || md_list_interrupts_paragraph(s) || md_html_interrupts_paragraph(s)

def md_scan_paragraph_finish(
  +acc: List<&2, MdLine>,
  rest: List<&2, MdLine>,
  +end: U32,
  +setext: U32
) -> ParaGrab:
  ParaGrab{List.reverse(&2, MdLine, acc), rest, end, setext}

def md_scan_paragraph_go(
  +xs: List<&2, MdLine>,
  +acc: List<&2, MdLine>,
  +end: U32
) -> ParaGrab:
  match xs:
    case Nil{}:
      md_scan_paragraph_finish(acc, Nil{}, end, 0)
    case line <> rest:
      +text = md_line_text(line)
      +setext = md_setext_level(text)
      ifs(ParaGrab, Bool.not(U32.is_zero(setext)),
        u => md_scan_paragraph_finish(acc, rest, md_line_end(line), setext),
        u =>
          +stop = Text.blank_line(text) || md_is_paragraph_interrupt(text)
          ifs(ParaGrab, stop,
            v => md_scan_paragraph_finish(acc, line <> rest, end, 0),
            v => md_scan_paragraph_go(rest, line <> acc, md_line_end(line))))

def md_scan_paragraph(+xs: List<&2, MdLine>, +first: MdLine) -> ParaGrab:
  md_scan_paragraph_go(xs, [first], md_line_end(first))

def md_drop_upto3(+s: String) -> String:
  +n = Nat.min(md_marker_indent(s), 3n)
  String.drop(s, n)

def md_paragraph_strings(xs: List<&2, MdLine>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case line <> rest:
      md_trim_start(md_line_text(line)) <> md_paragraph_strings(rest)

def md_paragraph_text(+xs: List<&2, MdLine>) -> String:
  md_trim_end(String.join(md_paragraph_strings(xs), "\n"))

# If the conservative fuel estimate is ever exhausted, remaining lines still
# degrade to literal paragraph text rather than disappearing or looping.
def md_fallback_lines(+lines: List<&2, MdLine>) -> List<&2, Ast.Block>:
  match lines:
    case Nil{}:
      Nil{}
    case line <> rest:
      +text = md_line_text(line)
      ifs(List<&2, Ast.Block>, Text.blank_line(text),
        u => md_fallback_lines(rest),
        u =>
          +span = md_line_span(line)
          leaf : Ast.Inline = Ast.IText{text, span}
          Ast.BParagraph{[leaf], [], span} <> md_fallback_lines(rest))

# Block constructors in return position, so Bend does not need to infer the
# empty attribute/list literals inside local bindings.
def md_make_paragraph_block(+refs: List<&2, RefDef>, +text: String, +start: U32, +end: U32) -> Ast.Block:
  Ast.BParagraph{md_parse_inlines_top(refs, text, start), [], Ast.Span{start, end}}

def md_make_heading_block(+refs: List<&2, RefDef>, +level: U32, +text: String, +start: U32, +end: U32) -> Ast.Block:
  Ast.BHeading{level, md_parse_inlines_top(refs, text, start), [], Ast.Span{start, end}}

def md_make_code_block(+text: String, info: Maybe<&2, String>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BCodeBlock{text, info, [], Ast.Span{start, end}}

def md_make_thematic_block(+start: U32, +end: U32) -> Ast.Block:
  Ast.BThematicBreak{Ast.Span{start, end}}

def md_make_quote_block(inner: List<&2, Ast.Block>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BBlockQuote{inner, [], None{}, Ast.Span{start, end}}

def md_make_list_block(+ordered: Bool, +startnum: U32, items: List<&2, Ast.ListItem>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BList{ordered, startnum, True{}, items, Ast.Span{start, end}}

def md_maybe_info(+info: String) -> Maybe<&2, String>:
  ifs(Maybe<&2, String>, String.is_empty(info),
    u => None{},
    u => Some{info})

# The fueled block parser.  Every iteration consumes at least one physical
# line (blank lines included).  Container contents are parsed by a recursive
# call on the extracted inner lines, and the outer continuation is a sibling
# recursive call on the unconsumed remainder; both descend on fuel.
def md_parse_blocks(fuel: Nat, +refs: List<&2, RefDef>, +lines: List<&2, MdLine>) -> List<&2, Ast.Block>:
  match fuel:
    case 0n:
      md_fallback_lines(lines)
    case 1n++f:
      match lines:
        case Nil{}:
          Nil{}
        case line <> rest:
          +text = md_line_text(line)
          +start = md_line_start(line)
          +end = md_line_end(line)
          +htmlkind = md_html_block_kind(text)
          ifs(List<&2, Ast.Block>, Text.blank_line(text),
            u => md_parse_blocks(f, refs, rest),
            u =>
              ifs(List<&2, Ast.Block>, Nat.is_ne(htmlkind, 0n),
                u =>
                  +grab = md_scan_html_block(line <> rest, htmlkind)
                  +content = md_join_code_lines(string_lines_grab_lines(grab))
                  +blockend = string_lines_grab_end(grab)
                  Ast.BHtmlBlock{content, Ast.Span{start, blockend}} <>
                    md_parse_blocks(f, refs, string_lines_grab_rest(grab))
                u =>
                  ifs(List<&2, Ast.Block>, md_is_fence_start(text),
                u =>
                  +marker = md_fence_marker(text)
                  +flen = md_fence_len(text)
                  +openindent = md_marker_indent(text)
                  +grab = md_scan_fenced(rest, marker, flen, openindent, end)
                  +content = md_join_code_lines(string_lines_grab_lines(grab))
                  +blockend = string_lines_grab_end(grab)
                  +info = md_maybe_info(md_fence_info(text))
                  md_make_code_block(content, info, start, blockend) <>
                    md_parse_blocks(f, refs, string_lines_grab_rest(grab))
                u =>
                  ifs(List<&2, Ast.Block>, md_is_atx(text),
                    u =>
                      +content = md_atx_text(text)
                      +level = md_atx_level(text)
                      md_make_heading_block(refs, level, content, start, end) <>
                        md_parse_blocks(f, refs, rest)
                    u =>
                      ifs(List<&2, Ast.Block>, md_is_thematic(text),
                        u => md_make_thematic_block(start, end) <> md_parse_blocks(f, refs, rest),
                        u =>
                          ifs(List<&2, Ast.Block>, md_is_quote_start(text),
                            u =>
                              +grab = md_scan_quote(line <> rest)
                              +inner = md_parse_blocks(f, refs, lines_grab_lines(grab))
                              +outer = md_parse_blocks(f, refs, lines_grab_rest(grab))
                              +blockend = lines_grab_end(grab)
                              md_make_quote_block(inner, start, blockend) <> outer
                            u =>
                              ifs(List<&2, Ast.Block>, md_is_list_item(text),
                                u =>
                                  +ordered = md_is_ordered_item(text)
                                  +grab = md_scan_list(refs, line <> rest, ordered)
                                  +startnum = ifs(U32, ordered,
                                    v => md_ordered_start(text),
                                    v => 1)
                                  +blockend = simple_list_grab_end(grab)
                                  md_make_list_block(ordered, startnum,
                                    simple_list_grab_items(grab), start, blockend) <>
                                    md_parse_blocks(f, refs, simple_list_grab_rest(grab))
                                u =>
                                  ifs(List<&2, Ast.Block>, md_is_indented_code_line(text),
                                    u =>
                                      +grab = md_scan_indented(line <> rest)
                                      +content = md_join_code_lines(md_trim_trailing_empty_lines(string_lines_grab_lines(grab)))
                                      +blockend = string_lines_grab_end(grab)
                                      md_make_code_block(content, None{}, start, blockend) <>
                                        md_parse_blocks(f, refs, string_lines_grab_rest(grab))
                                    u =>
                                      +grab = md_scan_paragraph(rest, line)
                                      +content = md_paragraph_text(para_grab_lines(grab))
                                      +blockend = para_grab_end(grab)
                                      +setext = para_grab_setext(grab)
                                      +leaf = ifs(Ast.Block, U32.is_zero(setext),
                                        v => md_make_paragraph_block(refs, content, start, blockend),
                                        v => md_make_heading_block(refs, setext, content, start, blockend))
                                      leaf <> md_parse_blocks(f, refs, para_grab_rest(grab))))))))))

# Reference-definition stripping/collection.  This is a document-level
# lexical prepass over top-level lines.  It deliberately knows about the two
# block states that most affect definitions: fenced code (definitions inside
# are literal) and paragraph continuation (definitions cannot interrupt a
# paragraph).  Container-nested definitions are handled by the block parser's
# normal fallback as literal text in this milestone.
type RefStrip is Data:
  RefStrip{text: String, refs: List<&2, RefDef>}

def ref_strip_text(x: RefStrip) -> String:
  match x:
    case RefStrip{text, refs}:
      text

def ref_strip_refs(x: RefStrip) -> List<&2, RefDef>:
  match x:
    case RefStrip{text, refs}:
      refs

type StripState is Data:
  StripState{inpara: Bool, fencemode: Nat, fencelen: Nat}

def strip_state_inpara(x: StripState) -> Bool:
  match x:
    case StripState{inpara, fencemode, fencelen}:
      inpara

def strip_state_fencemode(x: StripState) -> Nat:
  match x:
    case StripState{inpara, fencemode, fencelen}:
      fencemode

def strip_state_fencelen(x: StripState) -> Nat:
  match x:
    case StripState{inpara, fencemode, fencelen}:
      fencelen

# The returned word is the complete physical line including its line ending
# when one is present; the rest is the following input.
def md_scan_raw_line_go(s: String, +acc: String) -> WordSplit:
  match s:
    case SNil{}:
      WordSplit{String.reverse(acc), SNil{}}
    case SCon{'\n', t}:
      WordSplit{String.reverse(SCon{'\n', acc}), t}
    case SCon{+h, +t}:
      md_scan_raw_line_go(t, SCon{h, acc})

def md_scan_raw_line(+s: String) -> WordSplit:
  md_scan_raw_line_go(s, SNil{})

def md_drop_line_ending(+s: String) -> String:
  +len = String.length(s)
  ifs(String, String.ends_with(s, "\n"),
    u => String.take(s, Nat.sub(len, 1n)),
    u => s)

def md_strip_finish(+chunks: List<&2, String>, +refs: List<&2, RefDef>) -> RefStrip:
  RefStrip{String.concat(List.reverse(&2, String, chunks)), refs}

def md_add_ref_once(+refs: List<&2, RefDef>, +definition: RefDef) -> List<&2, RefDef>:
  ifs(List<&2, RefDef>, md_refs_have_label(refs, ref_def_label(definition)),
    u => refs,
    u => definition <> refs)

# Fencemode: 0 outside, 1 backtick fence, 2 tilde fence.
def md_strip_next_state(+line: String, +state: StripState) -> StripState:
  +mode = strip_state_fencemode(state)
  +flen = strip_state_fencelen(state)
  ifs(StripState, Nat.is_ne(mode, 0n),
    u =>
      +marker = ifs(Char, Nat.is_eq(mode, 1n), v => '`', v => '~')
      +closes = md_is_fence_close(line, marker, flen)
      ifs(StripState, closes,
        v => StripState{False{}, 0n, 0n},
        v => StripState{False{}, mode, flen}),
    u =>
      +fence = md_is_fence_start(line)
      +newmode = ifs(Nat, fence,
        v => Bool.pick(Nat, Char.is_eq(md_fence_marker(line), '`'), 1n, 2n),
        v => 0n)
      +newlen = ifs(Nat, fence, v => md_fence_len(line), v => 0n)
      +blank = Text.blank_line(line)
      +htmlkind = md_html_block_kind(line)
      +blockstart = fence || md_is_atx(line) || md_is_thematic(line) ||
        md_is_quote_start(line) || md_is_list_item(line) || Nat.is_ne(htmlkind, 0n)
      +inpara = Bool.and(Bool.not(blank), Bool.not(blockstart))
      StripState{inpara, newmode, newlen})

def md_strip_refs_go(
  fuel: Nat,
  +s: String,
  +chunks: List<&2, String>,
  +refs: List<&2, RefDef>,
  +state: StripState
) -> RefStrip:
  match fuel:
    case 0n:
      RefStrip{s ++ String.concat(List.reverse(&2, String, chunks)), refs}
    case 1n++f:
      ifs(RefStrip, String.is_empty(s),
        u => md_strip_finish(chunks, refs),
        u =>
          +rawline = md_scan_raw_line(s)
          +linefull = word_split_word(rawline)
          +afterline = word_split_rest(rawline)
          +line = md_drop_line_ending(linefull)
          +inpara = strip_state_inpara(state)
          +fencemode = strip_state_fencemode(state)
          +indent = md_marker_indent(line)
          +candstart = Nat.is_le(indent, 3n) && String.starts_with(String.drop(line, indent), "[")
          +cand = Bool.and(candstart, Bool.and(Bool.not(inpara), Nat.is_eq(fencemode, 0n)))
          +defsrc = String.drop(s, indent)
          +defhit = ifs(Maybe<&2, RefHit>, cand,
            v => md_scan_reference_definition(defsrc),
            v => None{})
          maybe_case(RefHit, RefStrip, defhit,
            +hit =>
              +defrest = ref_hit_rest(hit)
              +nextinput = ifs(String, String.starts_with(defrest, "\n"),
                v => String.drop(defrest, 1n),
                v => defrest)
              +newrefs = md_add_ref_once(refs, ref_hit_def(hit))
              md_strip_refs_go(f, nextinput, chunks, newrefs, StripState{False{}, fencemode, strip_state_fencelen(state)}),
            v =>
              +newstate = md_strip_next_state(line, state)
              md_strip_refs_go(f, afterline, linefull <> chunks, refs, newstate)))

def md_strip_reference_definitions(+source: String) -> RefStrip:
  +len = Text.utf8_length(source)
  md_strip_refs_go(Nat.add(len, 4n), source, Nil{}, Nil{}, StripState{False{}, 0n, 0n})

# Build the line table and parse the normalized input.  Fuel is proportional
# to input bytes; blank-only lines still consume one fuel and there is slack
# for container descent.
def md_document_from_normalized(+source: String) -> Ast.Document:
  +stripped = md_strip_reference_definitions(source)
  +refs = ref_strip_refs(stripped)
  +cleansource = ref_strip_text(stripped)
  +rawlines = String.lines(cleansource)
  +lines = md_make_lines(md_drop_final_empty(rawlines), 0n)
  +len = Text.utf8_length(source)
  +fuel = Nat.add(Nat.mul(8n, len), 16n)
  Ast.Document{md_parse_blocks(fuel, refs, lines)}

def parse_markdown(+source: String) -> Ast.Document:
  md_document_from_normalized(Text.normalize_newlines(source))

# Small integration helpers used by the repository-level laws.  The gate is
# deliberately explicit about the Boolean ceiling decision so the proof file
# can rewrite that decision without depending on parser internals.
def empty_document() -> Ast.Document:
  Ast.Document{[]}

def markdown_gate(+input: String, too_big: Bool) -> Maybe<&2, Ast.Document>:
  match too_big:
    case True{}:
      None{}
    case False{}:
      Some{parse_markdown(input)}

# Byte ceiling over the original UTF-8 input.  In particular max_input_bytes
# is zero only for the empty source, whose UTF-8 length is also zero.
def parse_markdown_bounded(+source: String, +max_input_bytes: Nat) -> Maybe<&2, Ast.Document>:
  markdown_gate(source, Nat.is_lt(max_input_bytes, Text.utf8_length(source)))
