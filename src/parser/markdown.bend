import Base
import ../ast.bend as Ast
import ../text.bend as Text
import ../unicode.bend as Unicode
import ../html_entities.bend as HtmlEntities

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
  LinkTarget{href: String, logical_href: String, raw_href: String, title: Maybe<&2, String>}

def link_target_href(x: LinkTarget) -> String:
  match x:
    case LinkTarget{href, logical_href, raw_href, title}:
      href

def link_target_logical_href(x: LinkTarget) -> String:
  match x:
    case LinkTarget{href, logical_href, raw_href, title}:
      logical_href

def link_target_raw_href(x: LinkTarget) -> String:
  match x:
    case LinkTarget{href, logical_href, raw_href, title}:
      raw_href

def link_target_title(x: LinkTarget) -> Maybe<&2, String>:
  match x:
    case LinkTarget{href, logical_href, raw_href, title}:
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

def md_list_length_go(a, -A: Kind(a), xs: List<a, A>, +acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      md_list_length_go(a, A, t, 1n+acc)

def md_list_length(a, -A: Kind(a), xs: List<a, A>) -> Nat:
  md_list_length_go(a, A, xs, 0n)

def md_list_rev_onto(a, -A: Kind(a), xs: List<a, A>, ys: List<a, A>) -> List<a, A>:
  match xs:
    case Nil{}:
      ys
    case h <> t:
      md_list_rev_onto(a, A, t, h <> ys)

def md_list_append(a, -A: Kind(a), xs: List<a, A>, ys: List<a, A>) -> List<a, A>:
  md_list_rev_onto(a, A, List.reverse(a, A, xs), ys)

def md_list_take_go(a, -A: Kind(a), xs: List<a, A>, n: Nat, acc: List<a, A>) -> List<a, A>:
  match xs n:
    case Nil{} _:
      List.reverse(a, A, acc)
    case _ 0n:
      List.reverse(a, A, acc)
    case h <> t 1n++p:
      md_list_take_go(a, A, t, p, h <> acc)

def md_list_take(a, -A: Kind(a), xs: List<a, A>, n: Nat) -> List<a, A>:
  md_list_take_go(a, A, xs, n, Nil{})

def md_list_drop(a, -A: Kind(a), xs: List<a, A>, n: Nat) -> List<a, A>:
  match xs n:
    case u 0n:
      u
    case Nil{} _:
      Nil{}
    case h <> t 1n++p:
      md_list_drop(a, A, t, p)

def md_list_set_go(a, -A: Kind(a), xs: List<a, A>, n: Nat, new: A, acc: List<a, A>) -> List<a, A>:
  match xs n:
    case Nil{} _:
      List.reverse(a, A, acc)
    case h <> t 0n:
      md_list_append(a, A, List.reverse(a, A, acc), new <> t)
    case h <> t 1n++p:
      md_list_set_go(a, A, t, p, new, h <> acc)

def md_list_set(a, -A: Kind(a), xs: List<a, A>, n: Nat, new: A) -> List<a, A>:
  md_list_set_go(a, A, xs, n, new, Nil{})

def md_string_concat_go(xs: List<&2, String>, +acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      md_string_concat_go(t, h ++ acc)

def md_string_concat(+xs: List<&2, String>) -> String:
  md_string_concat_go(List.reverse(&2, String, xs), SNil{})

def md_join_strings_rev_go(xs: List<&2, String>, +sep: String, +acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      md_join_strings_rev_go(t, sep, h ++ sep ++ acc)

def md_join_strings_rev(xs: List<&2, String>, +sep: String) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case h <> t:
      md_join_strings_rev_go(t, sep, h)

def md_join_strings(+xs: List<&2, String>, +sep: String) -> String:
  md_join_strings_rev(List.reverse(&2, String, xs), sep)

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

def md_repeat_char_go(+c: Char, n: Nat, +acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n++p:
      md_repeat_char_go(c, p, SCon{c, acc})

def md_repeat_char(+c: Char, n: Nat) -> String:
  md_repeat_char_go(c, n, SNil{})

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

def md_hspace_prefix(s: String, +acc: Nat) -> Nat:
  match s:
    case SCon{' ', t}:
      md_hspace_prefix(t, 1n+acc)
    case SCon{'\t', t}:
      md_hspace_prefix(t, 1n+acc)
    case u:
      acc

def md_hspace_suffix_count(+s: String) -> Nat:
  md_hspace_prefix(String.reverse(s), 0n)

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

# HTML5 named entities are generated from the authoritative table referenced
# by the CommonMark specification.  Unknown names remain literal, as required
# for nonentities.
def md_named_entity_value(+name: String) -> Maybe<&2, String>:
  HtmlEntities.html5_named_entity_value(name)

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
def md_decode_ee_go(fuel: Nat, +s: String, +acc: String) -> String:
  match fuel:
    case 0n:
      s
    case 1n++f:
      match s:
        case SNil{}:
          String.reverse(acc)
        case SCon{'\\', SCon{h, t}}:
          ifs(String, Text.ascii_punctuation(h),
            u => md_decode_ee_go(f, t, SCon{h, acc}),
            u => md_decode_ee_go(f, SCon{h, t}, SCon{'\\', acc}))
        case SCon{'&', t}:
          maybe_case(EntityHit, String, md_scan_entity_after_amp(t),
            +hit => md_decode_ee_go(f, entity_hit_after(hit),
              String.reverse(entity_hit_decoded(hit)) ++ acc),
            u => md_decode_ee_go(f, t, SCon{'&', acc}))
        case SCon{h, t}:
          md_decode_ee_go(f, t, SCon{h, acc})

def md_decode_ee(+s: String) -> String:
  md_decode_ee_go(Nat.add(String.length(s), 1n), s, SNil{})

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

def md_uri_encode_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{+h, +t}:
      ifs(String, md_uri_safe_char(h),
        u => md_uri_encode_go(t, SCon{h, acc}),
        u => md_uri_encode_go(t,
          String.reverse(md_percent_codepoint(Char.to_u32(h))) ++ acc))

def md_uri_encode(+s: String) -> String:
  md_uri_encode_go(s, SNil{})

def md_normalize_uri(+s: String) -> String:
  md_uri_encode(md_decode_ee(s))

def md_compact_horizontal_space_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{' ', t}:
      md_compact_horizontal_space_go(t, acc)
    case SCon{'\t', t}:
      md_compact_horizontal_space_go(t, acc)
    case SCon{+h, +t}:
      md_compact_horizontal_space_go(t, SCon{h, acc})

def md_compact_horizontal_space(s: String) -> String:
  md_compact_horizontal_space_go(s, SNil{})

def md_string_to_lower_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{+h, +t}:
      md_string_to_lower_go(t, SCon{Char.to_lower(h), acc})

def md_string_to_lower(+s: String) -> String:
  md_string_to_lower_go(s, SNil{})

def md_all_char(s: String, +c: Char) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+h, +t}:
      ifs(Bool, Char.is_eq(h, c),
        u => md_all_char(t, c),
        u => False{})

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

def md_take_go(s: String, n: Nat, +acc: String) -> String:
  match s n:
    case SNil{} _:
      String.reverse(acc)
    case _ 0n:
      String.reverse(acc)
    case SCon{+h, +t} 1n++p:
      md_take_go(t, p, SCon{h, acc})

# Character-count prefix extraction without input-length non-tail recursion.
def md_take(+s: String, +n: Nat) -> String:
  md_take_go(s, n, SNil{})

def md_split_at_index(+s: String, +idx: Nat, +width: Nat) -> StrSplit:
  StrSplit{md_take(s, idx), String.drop(s, Nat.add(idx, width))}

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

def md_span_mk(+start: U32, +end: U32) -> Ast.Span:
  Ast.Span{start, end}

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

def md_code_newlines_to_spaces_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{'\n', t}:
      md_code_newlines_to_spaces_go(t, SCon{' ', acc})
    case SCon{+h, +t}:
      md_code_newlines_to_spaces_go(t, SCon{h, acc})

def md_code_newlines_to_spaces(+s: String) -> String:
  md_code_newlines_to_spaces_go(s, SNil{})

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
    u => md_take(String.drop(s, 1n), Nat.sub(len, 2n)),
    u => s)

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
      ifs(Bool, md_title_newline_blank(t),
        u => True{},
        u => md_title_has_blank_line(t))
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

def md_finish_link_target_spelling(+rawdest: String, +spelling: String, +rest0: String) -> Maybe<&2, LinkTarget>:
  +separated = String.is_empty(rest0) || md_starts_inline_space(rest0)
  +logical = md_decode_ee(rawdest)
  +href = md_uri_encode(logical)
  ifs(Maybe<&2, LinkTarget>, Bool.not(separated),
    u => None{},
    u =>
      +rest = md_trim_inline(rest0)
      ifs(Maybe<&2, LinkTarget>, String.is_empty(rest),
        v => Some{LinkTarget{href, logical, spelling, None{}}},
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_title(rest),
            +hit =>
              +after = md_trim_inline(word_split_rest(hit))
              ifs(Maybe<&2, LinkTarget>, String.is_empty(after),
                w => Some{LinkTarget{href, logical, spelling,
                  Some{md_decode_ee(word_split_word(hit))}}},
                w => None{}),
            w => None{})))

def md_finish_link_target(+rawdest: String, +rest0: String) -> Maybe<&2, LinkTarget>:
  md_finish_link_target_spelling(rawdest, rawdest, rest0)

def md_parse_link_target(+inside: String) -> Maybe<&2, LinkTarget>:
  +trimmed = md_trim_inline(inside)
  ifs(Maybe<&2, LinkTarget>, String.is_empty(trimmed),
    u => Some{LinkTarget{"", "", "", None{}}},
    u =>
      ifs(Maybe<&2, LinkTarget>, String.starts_with(trimmed, "<"),
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_angle_dest(String.drop(trimmed, 1n)),
            +hit =>
              +angledest = word_split_word(hit)
              md_finish_link_target_spelling(angledest, "<" ++ angledest ++ ">", word_split_rest(hit)),
            w => None{}),
        v =>
          maybe_case(WordSplit, Maybe<&2, LinkTarget>, md_scan_plain_dest(trimmed),
            +hit => md_finish_link_target(word_split_word(hit), word_split_rest(hit)),
            w => None{})))


# Link reference definitions and reference-link labels.  Labels are matched
# as literal source strings: case folding and whitespace normalization happen
# before comparison, but backslash escapes and entities are not decoded.
type RefDef is Data:
  RefDef{label: String, href: String, logical_href: String, raw_href: String,
    title: Maybe<&2, String>, destination_span: Ast.Span, definition_span: Ast.Span}

def ref_def_label(x: RefDef) -> String:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      label

def ref_def_href(x: RefDef) -> String:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      href

def ref_def_logical_href(x: RefDef) -> String:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      logical_href

def ref_def_raw_href(x: RefDef) -> String:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      raw_href

def ref_def_title(x: RefDef) -> Maybe<&2, String>:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      title

def ref_def_destination_span(x: RefDef) -> Ast.Span:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      destination_span

def ref_def_definition_span(x: RefDef) -> Ast.Span:
  match x:
    case RefDef{label, href, logical_href, raw_href, title, destination_span, definition_span}:
      definition_span

type RefHit is Data:
  RefHit{definition: RefDef, rest: String, consumed: Nat}

def ref_hit_def(x: RefHit) -> RefDef:
  match x:
    case RefHit{definition, rest, consumed}:
      definition

def ref_hit_rest(x: RefHit) -> String:
  match x:
    case RefHit{definition, rest, consumed}:
      rest

def ref_hit_consumed(x: RefHit) -> Nat:
  match x:
    case RefHit{definition, rest, consumed}:
      consumed

type RefTargetHit is Data:
  RefTargetHit{href: String, logical_href: String, raw_href: String,
    title: Maybe<&2, String>, rest: String, consumed: Nat,
    dest_start: Nat, dest_end: Nat}

def ref_target_hit_href(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      href

def ref_target_hit_logical_href(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      logical_href

def ref_target_hit_raw_href(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      raw_href

def ref_target_hit_title(x: RefTargetHit) -> Maybe<&2, String>:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      title

def ref_target_hit_rest(x: RefTargetHit) -> String:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      rest

def ref_target_hit_consumed(x: RefTargetHit) -> Nat:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      consumed

def ref_target_hit_dest_start(x: RefTargetHit) -> Nat:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      dest_start

def ref_target_hit_dest_end(x: RefTargetHit) -> Nat:
  match x:
    case RefTargetHit{href, logical_href, raw_href, title, rest, consumed, dest_start, dest_end}:
      dest_end

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
      ifs(Bool, md_inline_space_char(h),
        u => md_label_has_nonspace(t),
        u => True{})

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

type RefWs is Data:
  RefWs{rest: String, consumed: Nat}

def ref_ws_rest(x: RefWs) -> String:
  match x:
    case RefWs{rest, consumed}:
      rest

def ref_ws_consumed(x: RefWs) -> Nat:
  match x:
    case RefWs{rest, consumed}:
      consumed

# Spaces/tabs plus at most one line ending, followed again by spaces/tabs.
def md_skip_ref_ws_count(+s: String) -> RefWs:
  +first = md_scan_hspace(s)
  +firstlen = Text.utf8_length(word_split_word(first))
  +after = word_split_rest(first)
  ifs(RefWs, String.starts_with(after, "\n"),
    u =>
      +second = md_scan_hspace(String.drop(after, 1n))
      +secondlen = Text.utf8_length(word_split_word(second))
      RefWs{word_split_rest(second), Nat.add(Nat.add(firstlen, 1n), secondlen)},
    u => RefWs{after, firstlen})

def md_skip_ref_ws(+s: String) -> String:
  ref_ws_rest(md_skip_ref_ws_count(s))

def md_ref_line_end(+s: String) -> Bool:
  String.is_empty(s) || String.starts_with(s, "\n")

def md_ref_title_opener(+s: String) -> Bool:
  String.starts_with(s, "\"") || String.starts_with(s, "'") || String.starts_with(s, "(")

type RefTitleHit is Data:
  RefTitleHit{title: String, rest: String, consumed: Nat}

def ref_title_hit_title(x: RefTitleHit) -> String:
  match x:
    case RefTitleHit{title, rest, consumed}:
      title

def ref_title_hit_rest(x: RefTitleHit) -> String:
  match x:
    case RefTitleHit{title, rest, consumed}:
      rest

def ref_title_hit_consumed(x: RefTitleHit) -> Nat:
  match x:
    case RefTitleHit{title, rest, consumed}:
      consumed

# Try a title at the current position.  On success the returned rest begins
# at the line ending (or EOF) after optional trailing horizontal spaces, and
# consumed counts both title delimiters plus that trailing horizontal space.
def md_try_ref_title_count(+s: String) -> Maybe<&2, RefTitleHit>:
  ifs(Maybe<&2, RefTitleHit>, md_ref_title_opener(s),
    u =>
      maybe_case(WordSplit, Maybe<&2, RefTitleHit>, md_scan_title(s),
        +hit =>
          +tail = md_scan_hspace(word_split_rest(hit))
          +after = word_split_rest(tail)
          +titlelen = Text.utf8_length(word_split_word(hit))
          +taillen = Text.utf8_length(word_split_word(tail))
          +consumed = Nat.add(Nat.add(1n, titlelen), Nat.add(1n, taillen))
          ifs(Maybe<&2, RefTitleHit>, md_ref_line_end(after),
            v => Some{RefTitleHit{md_decode_ee(word_split_word(hit)), after, consumed}},
            v => None{}),
        v => None{}),
    u => None{})

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

def md_ref_target_hit_make(+href: String, +logical: String, +raw: String,
  title: Maybe<&2, String>, +rest: String, +consumed: Nat,
  +dest_start: Nat, +dest_end: Nat) -> Maybe<&2, RefTargetHit>:
  Some{RefTargetHit{href, logical, raw, title, rest, consumed, dest_start, dest_end}}

def md_finish_ref_dest_pos(+rawdest: String, +spelling: String, +rest: String, +baseconsumed: Nat,
  +dest_start: Nat, +dest_end: Nat) -> Maybe<&2, RefTargetHit>:
  +firstcode = md_str_at(rest, 0n)
  +sep = String.is_empty(rest) || Bool.or(U32.is_eq(firstcode, 32),
    Bool.or(U32.is_eq(firstcode, 9), U32.is_eq(firstcode, 10)))
  +logical = md_decode_ee(rawdest)
  +href = md_uri_encode(logical)
  ifs(Maybe<&2, RefTargetHit>, Bool.not(sep),
    u => None{},
    u =>
      +hs = md_scan_hspace(rest)
      +hslen = Text.utf8_length(word_split_word(hs))
      +hadspace = Bool.not(String.is_empty(word_split_word(hs)))
      +afterh = word_split_rest(hs)
      +baseh = Nat.add(baseconsumed, hslen)
      ifs(Maybe<&2, RefTargetHit>, String.is_empty(afterh),
        v => md_ref_target_hit_make(href, logical, spelling, None{}, afterh, baseh, dest_start, dest_end),
        v =>
          ifs(Maybe<&2, RefTargetHit>, String.starts_with(afterh, "\n"),
            w =>
              +indentscan = md_scan_hspace(String.drop(afterh, 1n))
              +indentlen = Text.utf8_length(word_split_word(indentscan))
              +nextstart = word_split_rest(indentscan)
              maybe_case(RefTitleHit, Maybe<&2, RefTargetHit>, md_try_ref_title_count(nextstart),
                +titlehit =>
                  +titleconsumed = Nat.add(Nat.add(Nat.add(baseh, 1n), indentlen), ref_title_hit_consumed(titlehit))
                  md_ref_target_hit_make(href, logical, spelling, Some{ref_title_hit_title(titlehit)},
                    ref_title_hit_rest(titlehit), titleconsumed, dest_start, dest_end),
                x => md_ref_target_hit_make(href, logical, spelling, None{}, afterh, baseh, dest_start, dest_end)),
            w =>
              ifs(Maybe<&2, RefTargetHit>, Bool.and(hadspace, md_ref_title_opener(afterh)),
                x =>
                  maybe_case(RefTitleHit, Maybe<&2, RefTargetHit>, md_try_ref_title_count(afterh),
                    +titlehit =>
                      +titleconsumed = Nat.add(baseh, ref_title_hit_consumed(titlehit))
                      md_ref_target_hit_make(href, logical, spelling, Some{ref_title_hit_title(titlehit)},
                        ref_title_hit_rest(titlehit), titleconsumed, dest_start, dest_end),
                    y => None{}),
                x => None{}))))

def md_scan_ref_target(+aftercolon: String) -> Maybe<&2, RefTargetHit>:
  +ws = md_skip_ref_ws_count(aftercolon)
  +start = ref_ws_rest(ws)
  +lead = ref_ws_consumed(ws)
  ifs(Maybe<&2, RefTargetHit>, String.starts_with(start, "<"),
    u =>
      maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_scan_angle_dest(String.drop(start, 1n)),
        +hit =>
          +rawdest = word_split_word(hit)
          +rawlen = Text.utf8_length(rawdest)
          +contentstart = Nat.add(lead, 1n)
          +contentend = Nat.add(contentstart, rawlen)
          +base = Nat.add(contentend, 1n)
          +destend = Nat.add(contentend, 1n)
          md_finish_ref_dest_pos(rawdest, "<" ++ rawdest ++ ">", word_split_rest(hit), base, lead, destend),
        v => None{}),
    u =>
      maybe_case(WordSplit, Maybe<&2, RefTargetHit>, md_scan_plain_dest(start),
        +hit =>
          +rawlen = Text.utf8_length(word_split_word(hit))
          +deststart = lead
          +destend = Nat.add(deststart, rawlen)
          md_finish_ref_dest_pos(word_split_word(hit), word_split_word(hit), word_split_rest(hit), destend, deststart, destend),
        v => None{}))

def md_scan_reference_definition_at(+s: String, +basepos: U32) -> Maybe<&2, RefHit>:
  maybe_case(StrSplit, Maybe<&2, RefHit>, md_scan_link_label(s),
    +labelhit =>
      +afterlabel = str_split_after(labelhit)
      ifs(Maybe<&2, RefHit>, String.starts_with(afterlabel, ":"),
        u =>
          maybe_case(RefTargetHit, Maybe<&2, RefHit>,
            md_scan_ref_target(String.drop(afterlabel, 1n)),
            +targethit =>
              +labellen = Text.utf8_length(str_split_before(labelhit))
              +prefix = Nat.add(labellen, 3n)
              +defconsumed = Nat.add(prefix, ref_target_hit_consumed(targethit))
              +deststartrel = Nat.add(prefix, ref_target_hit_dest_start(targethit))
              +destendrel = Nat.add(prefix, ref_target_hit_dest_end(targethit))
              +destspan = md_span_mk(md_pos_add(basepos, deststartrel), md_pos_add(basepos, destendrel))
              +defspan = md_span_mk(basepos, md_pos_add(basepos, defconsumed))
              +definition : RefDef = RefDef{md_normalize_ref_label(str_split_before(labelhit)),
                ref_target_hit_href(targethit), ref_target_hit_logical_href(targethit),
                ref_target_hit_raw_href(targethit), ref_target_hit_title(targethit), destspan, defspan}
              Some{RefHit{definition, ref_target_hit_rest(targethit), defconsumed}},
            v => None{}),
        u => None{}),
    v => None{})

def md_scan_reference_definition(+s: String) -> Maybe<&2, RefHit>:
  md_scan_reference_definition_at(s, 0)

def md_refs_have_label(+refs: List<&2, RefDef>, +label: String) -> Bool:
  match refs:
    case Nil{}:
      False{}
    case h <> t:
      ifs(Bool, String.eq(ref_def_label(h), label),
        u => True{},
        u => md_refs_have_label(t, label))

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
    case SCon{+h, +t}:
      ifs(Bool, md_uri_scheme_char(h),
        u => md_uri_scheme_tail(t),
        u => False{})

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

def md_autolink_logical_href(+label: String, email: Bool) -> String:
  match email:
    case True{}:
      "mailto:" ++ label
    case False{}:
      label

def md_autolink_href(+label: String, email: Bool) -> String:
  md_uri_encode(md_autolink_logical_href(label, email))

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


# Scan balanced link text brackets.  Escaped brackets are literal input;
# unescaped nested pairs are retained in the label for the recursive inline
# parser.  Brackets inside code spans, autolinks, and raw HTML are not link
# brackets because those constructs bind more tightly than link text.
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
        case SCon{'`', +t}:
          +run = md_count_prefix(s, '`', 0n)
          +needle = md_repeat_char('`', run)
          +after_open = String.drop(s, run)
          maybe_case(StrSplit, Maybe<&2, StrSplit>, md_find_exact_delim(after_open, '`', run),
            +codehit =>
              +codebody = str_split_before(codehit)
              +coderest = str_split_after(codehit)
              +chunk = needle ++ codebody ++ needle
              md_scan_bracket_go(f, coderest, String.reverse(chunk) ++ acc, depth),
            u => md_scan_bracket_go(f, t, SCon{'`', acc}, depth))
        case SCon{'<', +t}:
          maybe_case(StrSplit, Maybe<&2, StrSplit>, md_scan_raw_html(s),
            +rawhit =>
              +raw = str_split_before(rawhit)
              +rawrest = str_split_after(rawhit)
              md_scan_bracket_go(f, rawrest, String.reverse(raw) ++ acc, depth),
            u =>
              maybe_case(StrSplit, Maybe<&2, StrSplit>, md_find_split(t, ">"),
                +anglehit =>
                  +anglelabel = str_split_before(anglehit)
                  +anglerest = str_split_after(anglehit)
                  +is_uri = md_valid_uri_autolink(anglelabel)
                  +is_email = Bool.not(is_uri) && md_valid_email_autolink(anglelabel)
                  +ok = Bool.and(is_uri || is_email, Bool.not(String.contains(anglelabel, "<")))
                  ifs(Maybe<&2, StrSplit>, ok,
                    v =>
                      +chunk = "<" ++ anglelabel ++ ">"
                      md_scan_bracket_go(f, anglerest, String.reverse(chunk) ++ acc, depth),
                    v => md_scan_bracket_go(f, t, SCon{'<', acc}, depth)),
                v => md_scan_bracket_go(f, t, SCon{'<', acc}, depth)))
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

def md_inline_space_code(+code: U32) -> Bool:
  U32.is_eq(code, 32) || U32.is_eq(code, 9) || U32.is_eq(code, 10) || U32.is_eq(code, 13)

def md_unicode_space_code(+code: U32) -> Bool:
  md_inline_space_code(code) || U32.is_eq(code, 12) || U32.is_eq(code, 160) ||
    U32.is_eq(code, 5760) || Bool.and(U32.is_ge(code, 8192), U32.is_le(code, 8202)) ||
    U32.is_eq(code, 8239) || U32.is_eq(code, 8287) || U32.is_eq(code, 12288)

# A unified validated link/image target plus the unconsumed input after it.
type LinkChoice is Data:
  LinkChoice{target: LinkTarget, after: String, destination_span: Ast.Span,
    reference_definition_span: Maybe<&2, Ast.Span>}

def link_choice_target(x: LinkChoice) -> LinkTarget:
  match x:
    case LinkChoice{target, after, destination_span, reference_definition_span}:
      target

def link_choice_after(x: LinkChoice) -> String:
  match x:
    case LinkChoice{target, after, destination_span, reference_definition_span}:
      after

def link_choice_destination_span(x: LinkChoice) -> Ast.Span:
  match x:
    case LinkChoice{target, after, destination_span, reference_definition_span}:
      destination_span

def link_choice_reference_definition_span(x: LinkChoice) -> Maybe<&2, Ast.Span>:
  match x:
    case LinkChoice{target, after, destination_span, reference_definition_span}:
      reference_definition_span

def md_link_choice(+target: LinkTarget, +after: String, +destination_span: Ast.Span,
  reference_definition_span: Maybe<&2, Ast.Span>) -> Maybe<&2, LinkChoice>:
  Some{LinkChoice{target, after, destination_span, reference_definition_span}}

def md_link_destination(+raw: String, +logical: String, +span: Ast.Span,
  definition_span: Maybe<&2, Ast.Span>) -> Maybe<&2, Ast.LinkDestination>:
  Some{Ast.LinkDestination{raw, logical, span, definition_span}}

def md_ref_target_from_def(+hit: RefDef) -> LinkTarget:
  LinkTarget{ref_def_href(hit), ref_def_logical_href(hit), ref_def_raw_href(hit), ref_def_title(hit)}

def md_lookup_ref_choice(+refs: List<&2, RefDef>, +rawlabel: String, +after: String) -> Maybe<&2, LinkChoice>:
  +label = md_normalize_ref_label(rawlabel)
  maybe_case(RefDef, Maybe<&2, LinkChoice>, md_lookup_ref(refs, label),
    +hit => md_link_choice(md_ref_target_from_def(hit), after,
      ref_def_destination_span(hit), Some{ref_def_definition_span(hit)}),
    u => None{})

# Reference forms, in precedence order after inline links: full, collapsed,
# shortcut.  A syntactically valid following label blocks shortcut parsing
# even when that label itself is undefined.
def md_scan_ref_label_use(+refs: List<&2, RefDef>, +textlabel: String, +afterclose: String) -> Maybe<&2, LinkChoice>:
  ifs(Maybe<&2, LinkChoice>, String.starts_with(afterclose, "[]"),
    u => md_lookup_ref_choice(refs, textlabel, String.drop(afterclose, 2n)),
    u =>
      ifs(Maybe<&2, LinkChoice>, String.starts_with(afterclose, "["),
        v =>
          maybe_case(StrSplit, Maybe<&2, LinkChoice>, md_scan_link_label(afterclose),
            +labelhit => md_lookup_ref_choice(refs, str_split_before(labelhit), str_split_after(labelhit)),
            w => md_lookup_ref_choice(refs, textlabel, afterclose)),
        v => md_lookup_ref_choice(refs, textlabel, afterclose)))

def md_inline_space_prefix(s: String, +acc: Nat) -> Nat:
  match s:
    case SCon{' ', t}:
      md_inline_space_prefix(t, 1n+acc)
    case SCon{'\t', t}:
      md_inline_space_prefix(t, 1n+acc)
    case SCon{'\n', t}:
      md_inline_space_prefix(t, 1n+acc)
    case SCon{'\r', t}:
      md_inline_space_prefix(t, 1n+acc)
    case u:
      acc

def md_inline_dest_span_finish(+start: U32, +raw: String) -> Ast.Span:
  md_span_mk(start, md_pos_add_text(start, raw))

def md_inline_destination_span(+inside: String, +insidepos: U32) -> Ast.Span:
  +lead = md_inline_space_prefix(inside, 0n)
  +trimmed = String.drop(inside, lead)
  +destbase = md_pos_add(insidepos, lead)
  ifs(Ast.Span, String.is_empty(trimmed),
    u => md_span_mk(destbase, destbase),
    u =>
      ifs(Ast.Span, String.starts_with(trimmed, "<"),
        v =>
          maybe_case(WordSplit, Ast.Span, md_scan_angle_dest(String.drop(trimmed, 1n)),
            +hit =>
              +rawlen = Text.utf8_length(word_split_word(hit))
              md_span_mk(destbase, md_pos_add(destbase, Nat.add(rawlen, 2n))),
            w => md_span_mk(destbase, destbase)),
        v =>
          maybe_case(WordSplit, Ast.Span, md_scan_plain_dest(trimmed),
            +hit => md_inline_dest_span_finish(destbase, word_split_word(hit)),
            w => md_span_mk(destbase, destbase))))

def md_scan_inline_link_choice(+textlabel: String, +afterclose: String, +bracket_open_pos: U32) -> Maybe<&2, LinkChoice>:
  maybe_case(LinkParts, Maybe<&2, LinkChoice>, md_scan_link_parts_inner(afterclose, textlabel),
    +parts =>
      maybe_case(LinkTarget, Maybe<&2, LinkChoice>, md_parse_link_target(link_parts_inside(parts)),
        +target =>
          +labelbytes = Text.utf8_length(textlabel)
          +insidepos = md_pos_add(bracket_open_pos, Nat.add(labelbytes, 3n))
          +destspan = md_inline_destination_span(link_parts_inside(parts), insidepos)
          md_link_choice(target, link_parts_after(parts), destspan, None{}),
        u => None{}),
    u => None{})


# Approximate plain textual content used for image alt attributes.  Entities
# and escapes are decoded and the ASCII markup delimiters most common in image
# descriptions are removed.  This intentionally avoids a second AST-walking
# recursive machine in the inline parser.
def md_strip_alt_markup_go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{'*', t}:
      md_strip_alt_markup_go(t, acc)
    case SCon{'_', t}:
      md_strip_alt_markup_go(t, acc)
    case SCon{'`', t}:
      md_strip_alt_markup_go(t, acc)
    case SCon{+h, +t}:
      md_strip_alt_markup_go(t, SCon{h, acc})

def md_strip_alt_markup(+s: String) -> String:
  md_strip_alt_markup_go(s, SNil{})

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

def md_emph_tokenize_go(+infos: List<&2, MdEmphDelim>, xs: List<&2, Ast.Inline>, +acc: List<&2, MdEmphTok>) -> List<&2, MdEmphTok>:
  match xs:
    case Nil{}:
      List.reverse(&2, MdEmphTok, acc)
    case h <> t:
      match h:
        case Ast.IText{text, span}:
          md_emph_tokenize_go(infos, t, md_emph_tokenize_text(text, span, infos) <> acc)
        case u:
          md_emph_tokenize_go(infos, t, md_make_tok_node(u) <> acc)

def md_emph_tokenize(+infos: List<&2, MdEmphDelim>, +xs: List<&2, Ast.Inline>) -> List<&2, MdEmphTok>:
  md_emph_tokenize_go(infos, xs, Nil{})

def md_emph_tok_finish(tok: MdEmphTok) -> Ast.Inline:
  match tok:
    case MdTokNode{node}:
      node
    case MdTokDelim{+delim}:
      +text = md_repeat_char(md_delim_marker(delim), md_delim_count(delim))
      Ast.IText{text, md_make_span(md_delim_start(delim), md_delim_end(delim))}

def md_emph_finalize_tokens_go(xs: List<&2, MdEmphTok>, +acc: List<&2, Ast.Inline>) -> List<&2, Ast.Inline>:
  match xs:
    case Nil{}:
      List.reverse(&2, Ast.Inline, acc)
    case h <> t:
      md_emph_finalize_tokens_go(t, md_emph_tok_finish(h) <> acc)

def md_emph_finalize_tokens(+xs: List<&2, MdEmphTok>) -> List<&2, Ast.Inline>:
  md_emph_finalize_tokens_go(xs, Nil{})

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
  +middle = md_list_take(&2, MdEmphTok, md_list_drop(&2, MdEmphTok, tokens, Nat.add(oi, 1n)), middlelen)
  +inner = md_emph_finalize_tokens(middle)
  +span = md_make_span(U32.sub(md_delim_end(op), U32.from_nat(use)), U32.add(md_delim_start(cl), U32.from_nat(use)))
  +node = Bool.pick(Ast.Inline, Nat.is_eq(use, 2n),
    md_make_istrong(inner, span),
    md_make_iemph(inner, span))
  +before = md_list_take(&2, MdEmphTok, tokens, oi)
  +after = md_list_drop(&2, MdEmphTok, tokens, Nat.add(ci, 1n))
  +tail = md_emph_cons_remainder(newcl, after)
  +center = md_cons_tok_node(node, tail)
  +front = md_emph_cons_remainder(newop, center)
  md_list_append(&2, MdEmphTok, before, front)

def md_emph_process(fuel: Nat, +tokens: List<&2, MdEmphTok>) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      md_emph_finalize_tokens(tokens)
    case 1n++f:
      maybe_case(MdEmphHit, List<&2, Ast.Inline>, md_find_emph_closer(tokens),
        +closerhit =>
          +ci = md_emph_hit_index(closerhit)
          +cl = md_emph_hit_delim(closerhit)
          +beforecloser = md_list_take(&2, MdEmphTok, tokens, ci)
          maybe_case(MdEmphHit, List<&2, Ast.Inline>, md_find_emph_opener(beforecloser, cl),
            +openerhit =>
              +oi = md_emph_hit_index(openerhit)
              +op = md_emph_hit_delim(openerhit)
              md_emph_process(f, md_emph_wrap_tokens(tokens, oi, ci, op, cl)),
            u =>
              +newcloser = md_delim_close_off(cl)
              md_emph_process(f,
                md_list_set(&2, MdEmphTok, tokens, ci, md_make_tok_delim(newcloser)))),
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

def md_inline_tree_has_link_go(fuel: Nat, xs: List<&2, Ast.Inline>) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n++f:
      match xs:
        case Nil{}:
          False{}
        case h <> t:
          match h:
            case Ast.ILink{children, href, title, span, destination}:
              True{}
            case Ast.IEmph{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.IStrong{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.IBold{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.IItalic{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.IDeleted{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.IInserted{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.ISuperscript{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.ISubscript{children, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case Ast.ISpan{children, attrs, span}:
              md_inline_tree_has_link_go(f, md_list_append(&2, Ast.Inline, children, t))
            case u:
              md_inline_tree_has_link_go(f, t)

def md_inline_tree_fuel(+source: String) -> Nat:
  Nat.add(Nat.mul(16n, Text.utf8_length(source)), 16n)

def md_inline_tree_has_link(+source: String, +xs: List<&2, Ast.Inline>) -> Bool:
  md_inline_tree_has_link_go(md_inline_tree_fuel(source), xs)

def md_alt_inlines_finish(+chunks: List<&2, String>) -> String:
  md_string_concat(List.reverse(&2, String, chunks))

def md_alt_inlines_go(fuel: Nat, xs: List<&2, Ast.Inline>, +chunks: List<&2, String>) -> String:
  match fuel:
    case 0n:
      md_alt_inlines_finish(chunks)
    case 1n++f:
      match xs:
        case Nil{}:
          md_alt_inlines_finish(chunks)
        case h <> t:
          match h:
            case Ast.IText{text, span}:
              md_alt_inlines_go(f, t, text <> chunks)
            case Ast.ICode{text, span}:
              md_alt_inlines_go(f, t, text <> chunks)
            case Ast.IEmph{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IStrong{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IBold{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IItalic{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IDeleted{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IInserted{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.ISuperscript{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.ISubscript{children, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.ISpan{children, attrs, span}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.ILink{children, href, title, span, destination}:
              md_alt_inlines_go(f, md_list_append(&2, Ast.Inline, children, t), chunks)
            case Ast.IImage{src, alt, title, span, destination}:
              md_alt_inlines_go(f, t, alt <> chunks)
            case Ast.IAutolink{href, label, span, destination}:
              md_alt_inlines_go(f, t, label <> chunks)
            case Ast.IRawHtml{text, span}:
              md_alt_inlines_go(f, t, chunks)
            case Ast.ISoftBreak{span}:
              md_alt_inlines_go(f, t, "\n" <> chunks)
            case Ast.IHardBreak{span}:
              md_alt_inlines_go(f, t, "\n" <> chunks)
            case Ast.IFootnoteRef{number, span}:
              md_alt_inlines_go(f, t, chunks)

def md_alt_inlines(+source: String, +xs: List<&2, Ast.Inline>) -> String:
  md_alt_inlines_go(md_inline_tree_fuel(source), xs, Nil{})

# Piecewise positions for inline input assembled from multiple source lines.
# `assumed_start` is the contiguous coordinate seen by the inline scanner;
# `original_start` is the corresponding byte offset in the normalized source.
type MdInlineSegment is Data:
  MdInlineSegment{assumed_start: U32, original_start: U32}

def md_inline_segment_mk(+assumed_start: U32, +original_start: U32) -> MdInlineSegment:
  MdInlineSegment{assumed_start, original_start}

def md_inline_segment_assumed_start(x: MdInlineSegment) -> U32:
  match x:
    case MdInlineSegment{assumed_start, original_start}:
      assumed_start

def md_inline_segment_original_start(x: MdInlineSegment) -> U32:
  match x:
    case MdInlineSegment{assumed_start, original_start}:
      original_start

def md_inline_segment_find_go(xs: List<&2, MdInlineSegment>, +offset: U32,
    +best: MdInlineSegment) -> MdInlineSegment:
  match xs:
    case Nil{}:
      best
    case +h <> t:
      ifs(MdInlineSegment, U32.is_le(md_inline_segment_assumed_start(h), offset),
        u => md_inline_segment_find_go(t, offset, h),
        u => best)

def md_inline_segment_find_end_go(xs: List<&2, MdInlineSegment>, +offset: U32,
    +best: MdInlineSegment) -> MdInlineSegment:
  match xs:
    case Nil{}:
      best
    case +h <> t:
      ifs(MdInlineSegment, U32.is_lt(md_inline_segment_assumed_start(h), offset),
        u => md_inline_segment_find_end_go(t, offset, h),
        u => best)

def md_inline_segment_offset_in(+found: MdInlineSegment, +offset: U32) -> U32:
  +inside = U32.sub(offset, md_inline_segment_assumed_start(found))
  U32.add(md_inline_segment_original_start(found), inside)

def md_inline_segment_offset_list(xs: List<&2, MdInlineSegment>, +offset: U32) -> U32:
  match xs:
    case Nil{}:
      offset
    case +h <> t:
      md_inline_segment_offset_in(md_inline_segment_find_go(t, offset, h), offset)

def md_inline_segment_end_offset_list(xs: List<&2, MdInlineSegment>, +offset: U32) -> U32:
  match xs:
    case Nil{}:
      offset
    case +h <> t:
      md_inline_segment_offset_in(md_inline_segment_find_end_go(t, offset, h), offset)

def md_inline_segment_offset(+xs: List<&2, MdInlineSegment>, +offset: U32) -> U32:
  md_inline_segment_offset_list(xs, offset)

def md_inline_segment_end_offset(+xs: List<&2, MdInlineSegment>, +offset: U32) -> U32:
  md_inline_segment_end_offset_list(xs, offset)

# Half-open spans need boundary-aware endpoint mapping: a start at a segment
# boundary belongs to the following byte, while an end at that boundary belongs
# to the preceding byte.  This preserves newline widths across elided container
# or indentation prefixes.  Empty spans use start semantics for both endpoints.
def md_inline_segment_span(+xs: List<&2, MdInlineSegment>, span: Ast.Span) -> Ast.Span:
  match span:
    case Ast.Span{+start, +end}:
      +mappedstart = md_inline_segment_offset(xs, start)
      +mappedend = ifs(U32, U32.is_eq(start, end),
        u => mappedstart,
        u => md_inline_segment_end_offset(xs, end))
      Ast.Span{mappedstart, mappedend}

# Inline destinations at use sites participate in the same piecewise coordinate
# space as their enclosing inline node.  Reference-definition destinations are
# collected before block parsing in normalized-document coordinates, so they
# must not be adjusted by the use site's line-segment map.
def md_map_link_destination_finish(+xs: List<&2, MdInlineSegment>, +raw: String,
  +logical: String, +span: Ast.Span, definition_span: Maybe<&2, Ast.Span>) -> Ast.LinkDestination:
  match definition_span:
    case Some{defspan}:
      Ast.LinkDestination{raw, logical, span, Some{defspan}}
    case None{}:
      Ast.LinkDestination{raw, logical, md_inline_segment_span(xs, span), None{}}

def md_map_link_destination(+xs: List<&2, MdInlineSegment>, x: Ast.LinkDestination) -> Ast.LinkDestination:
  match x:
    case Ast.LinkDestination{raw, logical, span, definition_span}:
      md_map_link_destination_finish(xs, raw, logical, span, definition_span)

def md_map_link_destination_maybe(+xs: List<&2, MdInlineSegment>,
  m: Maybe<&2, Ast.LinkDestination>) -> Maybe<&2, Ast.LinkDestination>:
  match m:
    case Some{+x}:
      Some{md_map_link_destination(xs, x)}
    case None{}:
      None{}

type MdMapInlineWork is Data:
  MdMapInlineNode{node: Ast.Inline}
  MdMapInlineNodes{xs: List<&2, Ast.Inline>}
  MdMapInlineNodesAcc{xs: List<&2, Ast.Inline>, acc: List<&2, Ast.Inline>}

def md_map_inline_work(fuel: Nat, +segs: List<&2, MdInlineSegment>,
  work: MdMapInlineWork) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      match work:
        case MdMapInlineNode{node}:
          node <> Nil{}
        case MdMapInlineNodes{xs}:
          xs
        case MdMapInlineNodesAcc{xs, acc}:
          List.append(&2, Ast.Inline, List.reverse(&2, Ast.Inline, acc), xs)
    case 1n++f:
      match work:
        case MdMapInlineNodes{xs}:
          md_map_inline_work(f, segs, MdMapInlineNodesAcc{xs, Nil{}})
        case MdMapInlineNodesAcc{xs, acc}:
          match xs:
            case Nil{}:
              List.reverse(&2, Ast.Inline, acc)
            case h <> t:
              +mapped = md_map_inline_work(f, segs, MdMapInlineNode{h})
              md_map_inline_work(f, segs,
                MdMapInlineNodesAcc{t, List.append(&2, Ast.Inline, mapped, acc)})
        case MdMapInlineNode{node}:
          match node:
            case Ast.IText{text, span}:
              Ast.IText{text, md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ICode{text, span}:
              Ast.ICode{text, md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IEmph{children, span}:
              Ast.IEmph{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IStrong{children, span}:
              Ast.IStrong{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IBold{children, span}:
              Ast.IBold{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IItalic{children, span}:
              Ast.IItalic{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IDeleted{children, span}:
              Ast.IDeleted{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IInserted{children, span}:
              Ast.IInserted{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ISuperscript{children, span}:
              Ast.ISuperscript{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ISubscript{children, span}:
              Ast.ISubscript{md_map_inline_work(f, segs, MdMapInlineNodes{children}),
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ISpan{children, attrs, span}:
              Ast.ISpan{md_map_inline_work(f, segs, MdMapInlineNodes{children}), attrs,
                md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ILink{children, href, title, span, destination}:
              Ast.ILink{md_map_inline_work(f, segs, MdMapInlineNodes{children}), href, title,
                md_inline_segment_span(segs, span), md_map_link_destination_maybe(segs, destination)} <> Nil{}
            case Ast.IImage{src, alt, title, span, destination}:
              Ast.IImage{src, alt, title, md_inline_segment_span(segs, span),
                md_map_link_destination_maybe(segs, destination)} <> Nil{}
            case Ast.IAutolink{href, label, span, destination}:
              Ast.IAutolink{href, label, md_inline_segment_span(segs, span),
                md_map_link_destination_maybe(segs, destination)} <> Nil{}
            case Ast.IRawHtml{text, span}:
              Ast.IRawHtml{text, md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.ISoftBreak{span}:
              Ast.ISoftBreak{md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IHardBreak{span}:
              Ast.IHardBreak{md_inline_segment_span(segs, span)} <> Nil{}
            case Ast.IFootnoteRef{number, span}:
              Ast.IFootnoteRef{number, md_inline_segment_span(segs, span)} <> Nil{}

def md_map_inline_nodes(+segs: List<&2, MdInlineSegment>,
  xs: List<&2, Ast.Inline>, +len: Nat) -> List<&2, Ast.Inline>:
  md_map_inline_work(Nat.add(Nat.mul(8n, len), 8n), segs, MdMapInlineNodes{xs})

# Inline scanner.  It is one recursive definition, so there is no mutual
# recursion; nested content and the continuation both recurse on fuel's
# predecessor.  Malformed delimiters consume at least one byte as literal text.
def md_parse_inlines(fuel: Nat, +refs: List<&2, RefDef>, +s: String, +pos: U32, +acc: List<&2, Ast.Inline>) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      md_list_rev_onto(&2, Ast.Inline, acc, md_text_node(s, pos))
    case 1n++f:
      match s:
        case SNil{}:
          List.reverse(&2, Ast.Inline, acc)
        case SCon{'\n', t}:
          +endpos = md_pos_add(pos, 1n)
          md_parse_inlines(f, refs, t, endpos,
            Ast.ISoftBreak{Ast.Span{pos, endpos}} <> acc)
        case SCon{'\\', SCon{'\n', t}}:
          +after = md_drop_leading_spaces(t)
          +skipped = Nat.sub(Text.utf8_length(t), Text.utf8_length(after))
          +breakend = md_pos_add(pos, 2n)
          +newpos = md_pos_add(breakend, skipped)
          md_parse_inlines(f, refs, after, newpos,
            Ast.IHardBreak{Ast.Span{pos, breakend}} <> acc)
        case SCon{'\\', SCon{+h, +t}}:
          ifs(List<&2, Ast.Inline>, Text.ascii_punctuation(h),
            u =>
              +escaped = md_char_string(h)
              +endpos = md_pos_add(pos, 2n)
              md_parse_inlines(f, refs, t, endpos,
                Ast.IText{escaped, Ast.Span{pos, endpos}} <> acc),
            u => md_parse_inlines(f, refs, SCon{h, t}, md_pos_add_text(pos, "\\"),
              Ast.IText{"\\", md_span_text(pos, "\\")} <> acc))
        case SCon{'\\', t}:
          md_parse_inlines(f, refs, t, md_pos_add_text(pos, "\\"),
            Ast.IText{"\\", md_span_text(pos, "\\")} <> acc)
        case SCon{'&', t}:
          maybe_case(EntityHit, List<&2, Ast.Inline>, md_scan_entity_after_amp(t),
            +hit =>
              +decoded = entity_hit_decoded(hit)
              +after = entity_hit_after(hit)
              +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(after))
              +endpos = md_pos_add(pos, used)
              md_parse_inlines(f, refs, after, endpos,
                Ast.IText{decoded, Ast.Span{pos, endpos}} <> acc)
            u => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "&"),
              Ast.IText{"&", md_span_text(pos, "&")} <> acc))
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
                u => md_parse_inlines(f, refs, after_open, md_pos_add_text(pos, needle),
                  Ast.IText{needle, md_span_text(pos, needle)} <> acc),
                u => md_parse_inlines(f, refs, rest, endpos,
                  Ast.ICode{md_normalize_code_span(content), Ast.Span{pos, endpos}} <> acc))
            u => md_parse_inlines(f, refs, after_open, md_pos_add_text(pos, needle),
              Ast.IText{needle, md_span_text(pos, needle)} <> acc))
        case SCon{'[', t}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_bracket(t),
            +closehit =>
              +label = str_split_before(closehit)
              +afterclose = str_split_after(closehit)
              +inlinechoice0 = md_scan_inline_link_choice(label, afterclose, pos)
              +choice = maybe_case(LinkChoice, Maybe<&2, LinkChoice>, inlinechoice0,
                +inlinehit => Some{inlinehit},
                u => md_scan_ref_label_use(refs, label, afterclose))
              maybe_case(LinkChoice, List<&2, Ast.Inline>, choice,
                +goodchoice =>
                  +rest = link_choice_after(goodchoice)
                  +goodtarget = link_choice_target(goodchoice)
                  +destmeta = md_link_destination(link_target_raw_href(goodtarget),
                    link_target_logical_href(goodtarget), link_choice_destination_span(goodchoice),
                    link_choice_reference_definition_span(goodchoice))
                  +label_start = md_pos_add(pos, 1n)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = md_pos_add(pos, used)
                  +labelinner0 = md_parse_inlines(f, refs, label, label_start, Nil{})
                  +labelinner = md_emph_resolve_link_label_input(label, label_start, labelinner0)
                  +nestedlink = md_inline_tree_has_link(label, labelinner)
                  ifs(List<&2, Ast.Inline>, nestedlink,
                    q => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "["),
                      Ast.IText{"[", md_span_text(pos, "[")} <> acc),
                    q => md_parse_inlines(f, refs, rest, endpos,
                      Ast.ILink{labelinner, link_target_href(goodtarget),
                        link_target_title(goodtarget), Ast.Span{pos, endpos}, destmeta} <> acc)),
                z => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "["),
                  Ast.IText{"[", md_span_text(pos, "[")} <> acc))
            u => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "["),
              Ast.IText{"[", md_span_text(pos, "[")} <> acc))
        case SCon{'!', SCon{'[', tt}}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_bracket(tt),
            +closehit =>
              +label = str_split_before(closehit)
              +afterclose = str_split_after(closehit)
              +inlinechoice0 = md_scan_inline_link_choice(label, afterclose, md_pos_add(pos, 1n))
              +choice = maybe_case(LinkChoice, Maybe<&2, LinkChoice>, inlinechoice0,
                +inlinehit => Some{inlinehit},
                u => md_scan_ref_label_use(refs, label, afterclose))
              maybe_case(LinkChoice, List<&2, Ast.Inline>, choice,
                +goodchoice =>
                  +rest = link_choice_after(goodchoice)
                  +goodtarget = link_choice_target(goodchoice)
                  +destmeta = md_link_destination(link_target_raw_href(goodtarget),
                    link_target_logical_href(goodtarget), link_choice_destination_span(goodchoice),
                    link_choice_reference_definition_span(goodchoice))
                  +label_start = md_pos_add(pos, 2n)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = md_pos_add(pos, used)
                  +children0 = md_parse_inlines(f, refs, label, label_start, Nil{})
                  +children = md_emph_resolve_link_label_input(label, label_start, children0)
                  +alttext = md_alt_inlines(label, children)
                  md_parse_inlines(f, refs, rest, endpos,
                    Ast.IImage{link_target_href(goodtarget), alttext,
                      link_target_title(goodtarget), Ast.Span{pos, endpos}, destmeta} <> acc),
                z => md_parse_inlines(f, refs, SCon{'[', tt}, md_pos_add_text(pos, "!"),
                  Ast.IText{"!", md_span_text(pos, "!")} <> acc))
            u => md_parse_inlines(f, refs, SCon{'[', tt}, md_pos_add_text(pos, "!"),
              Ast.IText{"!", md_span_text(pos, "!")} <> acc))
        case SCon{'!', t}:
          md_parse_inlines(f, refs, t, md_pos_add_text(pos, "!"),
            Ast.IText{"!", md_span_text(pos, "!")} <> acc)
        case SCon{'<', t}:
          maybe_case(StrSplit, List<&2, Ast.Inline>, md_scan_raw_html(s),
            +rawhit =>
              +raw = str_split_before(rawhit)
              +rawrest = str_split_after(rawhit)
              +rawend = md_pos_add_text(pos, raw)
              md_parse_inlines(f, refs, rawrest, rawend,
                Ast.IRawHtml{raw, Ast.Span{pos, rawend}} <> acc)
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
                  +labelstart = md_pos_add(pos, 1n)
                  +autospan = md_inline_dest_span_finish(labelstart, label)
                  +destmeta = md_link_destination(label, md_autolink_logical_href(label, is_email), autospan, None{})
                  ifs(List<&2, Ast.Inline>, ok,
                    v => md_parse_inlines(f, refs, rest, endpos,
                      Ast.IAutolink{md_autolink_href(label, is_email), label,
                        Ast.Span{pos, endpos}, destmeta} <> acc),
                    v => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "<"),
                      Ast.IText{"<", md_span_text(pos, "<")} <> acc))
                u => md_parse_inlines(f, refs, t, md_pos_add_text(pos, "<"),
                  Ast.IText{"<", md_span_text(pos, "<")} <> acc)))
        case SCon{h, t}:
          ifs(List<&2, Ast.Inline>, md_is_emphasis_char(h),
            u =>
              +run = md_count_prefix(s, h, 0n)
              +delimiter = md_repeat_char(h, run)
              +endpos = md_pos_add(pos, run)
              md_parse_inlines(f, refs, String.drop(s, run), endpos,
                Ast.IText{delimiter, Ast.Span{pos, endpos}} <> acc)
            u =>
              +n = md_plain_index(s, 0n)
              +plain0 = md_take(s, n)
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
                        x => md_parse_inlines(f, refs, after, newpos,
                          Ast.IHardBreak{Ast.Span{pos, nlend}} <> acc),
                        x => md_parse_inlines(f, refs, after, newpos,
                          Ast.IHardBreak{Ast.Span{plainend, nlend}} <>
                            Ast.IText{plain, Ast.Span{pos, plainend}} <> acc)),
                    w =>
                      ifs(List<&2, Ast.Inline>, String.is_empty(plain),
                        x => md_parse_inlines(f, refs, after, newpos,
                          Ast.ISoftBreak{Ast.Span{nlpos, nlend}} <> acc),
                        x => md_parse_inlines(f, refs, after, newpos,
                          Ast.ISoftBreak{Ast.Span{nlpos, nlend}} <>
                            Ast.IText{plain, Ast.Span{pos, plainend}} <> acc))),
                v =>
                  +endpos = md_pos_add_text(pos, plain0)
                  md_parse_inlines(f, refs, rest, endpos,
                    Ast.IText{plain0, Ast.Span{pos, endpos}} <> acc)))

def md_parse_inlines_top(+refs: List<&2, RefDef>, +s: String, +pos: U32,
  +segs: List<&2, MdInlineSegment>) -> List<&2, Ast.Inline>:
  +len = Text.utf8_length(s)
  +fuel = Nat.add(Nat.mul(8n, len), 8n)
  +scanned = md_parse_inlines(fuel, refs, s, pos, Nil{})
  +resolved = md_emph_resolve_input(s, pos, scanned)
  md_map_inline_nodes(segs, resolved, len)

# Block parsing
# =============

type MdLine is Data:
  MdLine{text: String, start: U32, end: U32, col: Nat, lazy: Bool}

def md_line_mk(+text: String, +start: U32, +end: U32, +col: Nat, +lazy: Bool) -> MdLine:
  MdLine{text, start, end, col, lazy}

def md_line_text(x: MdLine) -> String:
  match x:
    case MdLine{text, start, end, col, lazy}:
      text

def md_line_start(x: MdLine) -> U32:
  match x:
    case MdLine{text, start, end, col, lazy}:
      start

def md_line_end(x: MdLine) -> U32:
  match x:
    case MdLine{text, start, end, col, lazy}:
      end

def md_line_col(x: MdLine) -> Nat:
  match x:
    case MdLine{text, start, end, col, lazy}:
      col

def md_line_lazy(x: MdLine) -> Bool:
  match x:
    case MdLine{text, start, end, col, lazy}:
      lazy

def md_line_as_lazy(+line: MdLine) -> MdLine:
  MdLine{md_line_text(line), md_line_start(line), md_line_end(line), md_line_col(line), True{}}

def md_line_span(x: MdLine) -> Ast.Span:
  match x:
    case MdLine{text, start, end, col, lazy}:
      Ast.Span{start, end}

type MdInlineSource is Data:
  MdInlineSource{text: String, start: U32, segments: List<&2, MdInlineSegment>}

def md_inline_source_text(x: MdInlineSource) -> String:
  match x:
    case MdInlineSource{text, start, segments}:
      text

def md_inline_source_start(x: MdInlineSource) -> U32:
  match x:
    case MdInlineSource{text, start, segments}:
      start

def md_inline_source_segments(x: MdInlineSource) -> List<&2, MdInlineSegment>:
  match x:
    case MdInlineSource{text, start, segments}:
      segments

def md_inline_source_single(+text: String, +start: U32) -> MdInlineSource:
  +segment = md_inline_segment_mk(start, start)
  MdInlineSource{text, start, segment <> Nil{}}

def md_lines_is_empty(xs: List<&2, MdLine>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      False{}

# Reconstruct the relationship between the flattened paragraph text seen by
# the inline scanner and normalized-source byte positions.  Container and
# indentation prefixes are not part of the paragraph text, but their widths are
# retained here as segment discontinuities.  Newline separators are explicit
# segments so endpoints inside soft/hard breaks keep the right position.
def md_paragraph_segments_go(xs: List<&2, MdLine>, +assumed: U32,
    +acc: List<&2, MdInlineSegment>) -> List<&2, MdInlineSegment>:
  match xs:
    case Nil{}:
      List.reverse(&2, MdInlineSegment, acc)
    case +line <> +rest:
      +text = md_line_text(line)
      +lead = md_hspace_prefix(text, 0n)
      +trimmed = md_trim_start(text)
      +fullen = Text.utf8_length(trimmed)
      +last = md_lines_is_empty(rest)
      +trail = ifs(Nat, last,
        u => md_hspace_suffix_count(trimmed),
        u => 0n)
      +len = Nat.sub(fullen, trail)
      +physicallen = U32.to_nat(U32.sub(md_line_end(line), md_line_start(line)))
      +textbytes = Text.utf8_length(text)
      +virtuallead = Nat.min(lead, Nat.sub(textbytes, physicallen))
      +physicallead = Nat.sub(lead, virtuallead)
      +original = md_pos_add(md_line_start(line), physicallead)
      +contentseg = md_inline_segment_mk(assumed, original)
      ifs(List<&2, MdInlineSegment>, last,
        u => List.reverse(&2, MdInlineSegment, contentseg <> acc),
        u =>
          +newlineassumed = md_pos_add(assumed, len)
          +newlineseg = md_inline_segment_mk(newlineassumed, md_line_end(line))
          +nextassumed = md_pos_add(newlineassumed, 1n)
          md_paragraph_segments_go(rest, nextassumed, newlineseg <> contentseg <> acc))

def md_paragraph_segments(+xs: List<&2, MdLine>, +start: U32) -> List<&2, MdInlineSegment>:
  md_paragraph_segments_go(xs, start, Nil{})

type MdIndentScan is Data:
  MdIndentScan{cols: Nat, chars: Nat}

def md_indent_scan_cols(x: MdIndentScan) -> Nat:
  match x:
    case MdIndentScan{cols, chars}:
      cols

def md_indent_scan_chars(x: MdIndentScan) -> Nat:
  match x:
    case MdIndentScan{cols, chars}:
      chars

def md_tab_width(+col: Nat) -> Nat:
  Nat.sub(4n, Nat.mod(col, 4n))

def md_scan_indent_go(s: String, +startcol: Nat, +cols: Nat, +chars: Nat) -> MdIndentScan:
  match s:
    case SNil{}:
      MdIndentScan{cols, chars}
    case SCon{' ', t}:
      md_scan_indent_go(t, startcol, 1n+cols, 1n+chars)
    case SCon{'\t', t}:
      +width = md_tab_width(Nat.add(startcol, cols))
      md_scan_indent_go(t, startcol, Nat.add(cols, width), 1n+chars)
    case u:
      MdIndentScan{cols, chars}

def md_scan_indent_from(+s: String, +startcol: Nat) -> MdIndentScan:
  md_scan_indent_go(s, startcol, 0n, 0n)

def md_scan_indent(+s: String) -> MdIndentScan:
  md_scan_indent_from(s, 0n)

type MdColumnStrip is Data:
  MdColumnStrip{text: String, cols: Nat, chars: Nat}

def md_column_strip_text(x: MdColumnStrip) -> String:
  match x:
    case MdColumnStrip{text, cols, chars}:
      text

def md_column_strip_cols(x: MdColumnStrip) -> Nat:
  match x:
    case MdColumnStrip{text, cols, chars}:
      cols

def md_column_strip_chars(x: MdColumnStrip) -> Nat:
  match x:
    case MdColumnStrip{text, cols, chars}:
      chars

def md_strip_columns_go(+s: String, n: Nat, +col: Nat, +cols: Nat, +chars: Nat) -> MdColumnStrip:
  match s n:
    case SCon{' ', t} 1n++p:
      md_strip_columns_go(t, p, Nat.add(col, 1n), 1n+cols, 1n+chars)
    case SCon{'\t', t} 1n++p:
      +width = md_tab_width(col)
      +remaining = Nat.add(1n, p)
      ifs(MdColumnStrip, Nat.is_le(width, remaining),
        u => md_strip_columns_go(t, Nat.sub(remaining, width), Nat.add(col, width), Nat.add(cols, width), 1n+chars),
        u => MdColumnStrip{md_repeat_char(' ', Nat.sub(width, remaining)) ++ t, Nat.add(cols, remaining), 1n+chars})
    case u _:
      MdColumnStrip{u, cols, chars}

def md_strip_columns_from(+s: String, +n: Nat, +startcol: Nat) -> MdColumnStrip:
  md_strip_columns_go(s, n, startcol, 0n, 0n)

# String.lines is character based and reports one artificial empty cell after
# a final line terminator.  Remove exactly that final cell before annotating
# lines; real trailing blank lines remain because they appear as earlier empty
# cells.  Besides being cleaner for ordinary blocks, this keeps an unclosed
# fenced block from gaining a phantom extra LF at EOF.
def md_lines_go(s: String, +cur: String, +lines: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      List.reverse(&2, String, String.reverse(cur) <> lines)
    case SCon{'\n', t}:
      md_lines_go(t, SNil{}, String.reverse(cur) <> lines)
    case SCon{+h, +t}:
      md_lines_go(t, SCon{h, cur}, lines)

# Same cell semantics as String.lines, including the artificial empty cell
# after a final newline, but iterative in the generated backends.
def md_lines(+s: String) -> List<&2, String>:
  md_lines_go(s, SNil{}, Nil{})

def md_drop_final_empty_rev(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      ifs(List<&2, String>, String.is_empty(h),
        u => List.reverse(&2, String, t),
        u => List.reverse(&2, String, h <> t))

def md_drop_final_empty(+xs: List<&2, String>) -> List<&2, String>:
  md_drop_final_empty_rev(List.reverse(&2, String, xs))

# Annotate each physical line with its UTF-8 byte interval in the
# newline-normalized, reference-blanked source.  These base intervals are
# exact.  Container and indentation elision is reconstructed through the
# inline segment map, including leading virtual spaces left by partial tab
# expansion.  Block spans around containers may still describe stripped
# content rather than marker-inclusive source extents.
def md_make_lines_go(xs: List<&2, String>, +start: Nat, +acc: List<&2, MdLine>) -> List<&2, MdLine>:
  match xs:
    case Nil{}:
      List.reverse(&2, MdLine, acc)
    case +h <> t:
      +len = Text.utf8_length(h)
      +spos = U32.from_nat(start)
      +epos = U32.from_nat(Nat.add(start, len))
      +line = md_line_mk(h, spos, epos, 0n, False{})
      md_make_lines_go(t, Nat.add(Nat.add(start, len), 1n), line <> acc)

def md_make_lines(+xs: List<&2, String>, +start: Nat) -> List<&2, MdLine>:
  md_make_lines_go(xs, start, Nil{})

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

# Up to three columns of indentation are block-marker indentation.
def md_marker_indent_at(+s: String, +startcol: Nat) -> Nat:
  md_indent_scan_cols(md_scan_indent_from(s, startcol))

def md_marker_indent(+s: String) -> Nat:
  md_marker_indent_at(s, 0n)

def md_marker_indent_chars_at(+s: String, +startcol: Nat) -> Nat:
  md_indent_scan_chars(md_scan_indent_from(s, startcol))

def md_after_marker_indent_at(+s: String, +startcol: Nat) -> String:
  String.drop(s, md_marker_indent_chars_at(s, startcol))

def md_after_marker_indent(+s: String) -> String:
  md_after_marker_indent_at(s, 0n)

def md_marker_indent_ok_at(+s: String, +startcol: Nat) -> Bool:
  Nat.is_le(md_marker_indent_at(s, startcol), 3n)

def md_marker_indent_ok(+s: String) -> Bool:
  md_marker_indent_ok_at(s, 0n)

# Fences.
def md_fence_count_for_at(+s: String, +marker: Char, +startcol: Nat) -> Nat:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +after = String.drop(s, md_indent_scan_chars(scan))
  ifs(Nat, Nat.is_le(indent, 3n),
    u => md_count_prefix(after, marker, 0n),
    u => 0n)

def md_fence_count_for(+s: String, +marker: Char) -> Nat:
  md_fence_count_for_at(s, marker, 0n)

def md_is_fence_start_at(+s: String, +startcol: Nat) -> Bool:
  +btick = md_fence_count_for_at(s, '`', startcol)
  +tilde = md_fence_count_for_at(s, '~', startcol)
  +len = Nat.max(btick, tilde)
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  +info = md_trim(String.drop(afterindent, len))
  +present = Nat.is_ge(btick, 3n) || Nat.is_ge(tilde, 3n)
  +backtick_info_ok = Bool.not(Bool.and(Nat.is_ge(btick, 3n), String.contains(info, "`")))
  Bool.and(present, backtick_info_ok)

def md_is_fence_start(+s: String) -> Bool:
  md_is_fence_start_at(s, 0n)

def md_fence_marker_at(+s: String, +startcol: Nat) -> Char:
  ifs(Char, Nat.is_ge(md_fence_count_for_at(s, '`', startcol), 3n),
    u => '`',
    u => '~')

def md_fence_marker(+s: String) -> Char:
  md_fence_marker_at(s, 0n)

def md_fence_len_at(+s: String, +startcol: Nat) -> Nat:
  Nat.max(md_fence_count_for_at(s, '`', startcol), md_fence_count_for_at(s, '~', startcol))

def md_fence_len(+s: String) -> Nat:
  md_fence_len_at(s, 0n)

def md_fence_info_at(+s: String, +startcol: Nat) -> String:
  +scan = md_scan_indent_from(s, startcol)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  +len = md_fence_len_at(s, startcol)
  +decoded = md_decode_ee(md_trim(String.drop(afterindent, len)))
  word_split_word(md_split_word(decoded))

def md_fence_info(+s: String) -> String:
  md_fence_info_at(s, 0n)

def md_is_fence_close_at(+s: String, +marker: Char, +minlen: Nat, +startcol: Nat) -> Bool:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  +count = md_fence_count_for_at(s, marker, startcol)
  +rest = String.drop(afterindent, count)
  Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(count, minlen), Text.blank_line(rest)))

def md_is_fence_close(+s: String, +marker: Char, +minlen: Nat) -> Bool:
  md_is_fence_close_at(s, marker, minlen, 0n)

# ATX headings.
def md_atx_count_at(+s: String, +startcol: Nat) -> Nat:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  ifs(Nat, Nat.is_le(indent, 3n),
    u => md_count_prefix(afterindent, '#', 0n),
    u => 0n)

def md_atx_count(+s: String) -> Nat:
  md_atx_count_at(s, 0n)

def md_atx_next_ok(+code: U32) -> Bool:
  U32.is_eq(code, 0) || U32.is_eq(code, 32) || U32.is_eq(code, 9)

def md_is_atx_at(+s: String, +startcol: Nat) -> Bool:
  +scan = md_scan_indent_from(s, startcol)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  +count = md_atx_count_at(s, startcol)
  +next = md_str_at(afterindent, count)
  Bool.and(Nat.is_ge(count, 1n),
    Bool.and(Nat.is_le(count, 6n), md_atx_next_ok(next)))

def md_is_atx(+s: String) -> Bool:
  md_is_atx_at(s, 0n)

def md_atx_level_at(+s: String, +startcol: Nat) -> U32:
  U32.from_nat(md_atx_count_at(s, startcol))

def md_atx_level(+s: String) -> U32:
  md_atx_level_at(s, 0n)

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

def md_atx_text_at(+s: String, +startcol: Nat) -> String:
  +scan = md_scan_indent_from(s, startcol)
  +afterindent = String.drop(s, md_indent_scan_chars(scan))
  +count = md_atx_count_at(s, startcol)
  md_strip_atx_closing(md_trim(String.drop(afterindent, count)))

def md_atx_text(+s: String) -> String:
  md_atx_text_at(s, 0n)

def md_atx_content_start_at(+s: String, +startcol: Nat, +linestart: U32, +lineend: U32) -> U32:
  +scan = md_scan_indent_from(s, startcol)
  +indentchars = md_indent_scan_chars(scan)
  +afterindent = String.drop(s, indentchars)
  +count = md_atx_count_at(s, startcol)
  +aftermarker = String.drop(afterindent, count)
  +lead = md_hspace_prefix(aftermarker, 0n)
  +physicallen = U32.to_nat(U32.sub(lineend, linestart))
  +virtualindent = Nat.min(indentchars, Nat.sub(Text.utf8_length(s), physicallen))
  +physicalindent = Nat.sub(indentchars, virtualindent)
  md_pos_add(linestart, Nat.add(Nat.add(physicalindent, count), lead))

# Thematic breaks and Setext underlines.
def md_thematic_with_at(+s: String, +marker: Char, +startcol: Nat) -> Bool:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +rest = String.drop(s, md_indent_scan_chars(scan))
  +compact = md_compact_horizontal_space(rest)
  Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(String.length(compact), 3n), md_all_char(compact, marker)))

def md_thematic_with(+s: String, +marker: Char) -> Bool:
  md_thematic_with_at(s, marker, 0n)

def md_is_thematic_at(+s: String, +startcol: Nat) -> Bool:
  md_thematic_with_at(s, '-', startcol) || md_thematic_with_at(s, '_', startcol) || md_thematic_with_at(s, '*', startcol)

def md_is_thematic(+s: String) -> Bool:
  md_is_thematic_at(s, 0n)

def md_setext_with_at(+s: String, +marker: Char, level: U32, +startcol: Nat) -> U32:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +rest = md_trim_end(String.drop(s, md_indent_scan_chars(scan)))
  +ok = Bool.and(Nat.is_le(indent, 3n),
    Bool.and(Nat.is_ge(String.length(rest), 1n), md_all_char(rest, marker)))
  ifs(U32, ok,
    u => level,
    u => 0)

def md_setext_with(+s: String, +marker: Char, level: U32) -> U32:
  md_setext_with_at(s, marker, level, 0n)

def md_setext_level_at(+s: String, +startcol: Nat) -> U32:
  +eq = md_setext_with_at(s, '=', 1, startcol)
  ifs(U32, U32.is_zero(eq),
    u => md_setext_with_at(s, '-', 2, startcol),
    u => eq)

def md_setext_level(+s: String) -> U32:
  md_setext_level_at(s, 0n)

# Block quotes.
def md_is_quote_start_at(+s: String, +startcol: Nat) -> Bool:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +after = String.drop(s, md_indent_scan_chars(scan))
  Bool.and(Nat.is_le(indent, 3n), String.starts_with(after, ">"))

def md_is_quote_start(+s: String) -> Bool:
  md_is_quote_start_at(s, 0n)

def md_quote_pad_strip(+after: String, +startcol: Nat, haspad: Bool) -> MdColumnStrip:
  match haspad:
    case True{}:
      md_strip_columns_from(after, 1n, startcol)
    case False{}:
      MdColumnStrip{after, 0n, 0n}

def md_quote_strip_text_at(+s: String, +startcol: Nat) -> MdColumnStrip:
  +scan = md_scan_indent_from(s, startcol)
  +indentcols = md_indent_scan_cols(scan)
  +indentchars = md_indent_scan_chars(scan)
  +afterindent = String.drop(s, indentchars)
  +aftergt = String.drop(afterindent, 1n)
  +basecol = Nat.add(startcol, Nat.add(indentcols, 1n))
  +padcode = md_str_at(aftergt, 0n)
  +haspad = U32.is_eq(padcode, 32) || U32.is_eq(padcode, 9)
  +padstrip = md_quote_pad_strip(aftergt, basecol, haspad)
  MdColumnStrip{md_column_strip_text(padstrip),
    Nat.add(Nat.add(indentcols, 1n), md_column_strip_cols(padstrip)),
    Nat.add(Nat.add(indentchars, 1n), md_column_strip_chars(padstrip))}

def md_quote_strip_text(+s: String) -> String:
  md_column_strip_text(md_quote_strip_text_at(s, 0n))

def md_quote_strip_line(+line: MdLine) -> MdLine:
  +text = md_line_text(line)
  +oldcol = md_line_col(line)
  +strip = md_quote_strip_text_at(text, oldcol)
  MdLine{md_column_strip_text(strip),
    md_pos_add(md_line_start(line), md_column_strip_chars(strip)),
    md_line_end(line),
    Nat.add(oldcol, md_column_strip_cols(strip)),
    md_line_lazy(line)}

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

def md_quote_listish_at(+s: String, +startcol: Nat) -> Bool:
  +scan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(scan)
  +after = String.drop(s, md_indent_scan_chars(scan))
  +mark = md_str_at(after, 0n)
  +next = md_str_at(after, 1n)
  +bullet = Bool.and(U32.is_eq(mark, 45) || U32.is_eq(mark, 43) || U32.is_eq(mark, 42),
    md_quote_space_ok(next))
  +digits = md_digit_count_only(after, 0n)
  +delim = md_str_at(after, digits)
  +afterdelim = md_str_at(after, Nat.add(digits, 1n))
  +ordered = Bool.and(Nat.is_ge(digits, 1n),
    Bool.and(Nat.is_le(digits, 9n),
      Bool.and(U32.is_eq(delim, 46) || U32.is_eq(delim, 41), md_quote_space_ok(afterdelim))))
  Bool.and(Nat.is_le(indent, 3n), bullet || ordered)

def md_quote_listish(+s: String) -> Bool:
  md_quote_listish_at(s, 0n)

def md_drop_up_to_columns(+s: String, +n: Nat, +startcol: Nat) -> String:
  md_column_strip_text(md_strip_columns_from(s, n, startcol))

def md_join_code_lines_go(xs: List<&2, String>, +acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      md_join_code_lines_go(t, h ++ "\n" ++ acc)

def md_join_code_lines(+xs: List<&2, String>) -> String:
  md_join_code_lines_go(List.reverse(&2, String, xs), SNil{})

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
      +linecol = md_line_col(line)
      ifs(StringLinesGrab, md_is_fence_close_at(text, marker, minlen, linecol),
        u => md_scan_fenced_finish(acc, rest, md_line_end(line)),
        u => md_scan_fenced_go(rest, marker, minlen, openindent,
          md_drop_up_to_columns(text, openindent, linecol) <> acc, md_line_end(line)))

def md_scan_fenced(+xs: List<&2, MdLine>, +marker: Char, +minlen: Nat, +openindent: Nat, +startend: U32) -> StringLinesGrab:
  md_scan_fenced_go(xs, marker, minlen, openindent, Nil{}, startend)

def md_is_indented_code_line_at(+s: String, +startcol: Nat) -> Bool:
  Bool.and(Nat.is_ge(md_marker_indent_at(s, startcol), 4n), Bool.not(Text.blank_line(s)))

def md_is_indented_code_line(+s: String) -> Bool:
  md_is_indented_code_line_at(s, 0n)

def md_indented_content_at(+s: String, +startcol: Nat) -> String:
  md_drop_up_to_columns(s, 4n, startcol)

def md_indented_content(+s: String) -> String:
  md_indented_content_at(s, 0n)

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
      +linecol = md_line_col(line)
      +takeit = md_is_indented_code_line_at(text, linecol) || Text.blank_line(text)
      ifs(StringLinesGrab, takeit,
        u => md_scan_indented_go(rest, md_indented_content_at(text, linecol) <> acc, md_line_end(line)),
        u => md_scan_fenced_finish(acc, line <> rest, end))

def md_scan_indented(+xs: List<&2, MdLine>) -> StringLinesGrab:
  md_scan_indented_go(xs, Nil{}, 0)

# HTML blocks.  Kind numbers follow the seven start conditions in the
# CommonMark spec.  Type 6/7 blocks end immediately before a blank line;
# types 1--5 end on the line containing their matching terminator.
def md_starts_ci_go(s: String, p: String) -> Bool:
  match s:
    case SNil{}:
      String.is_empty(p)
    case SCon{+h, +t}:
      match p:
        case SNil{}:
          True{}
        case SCon{+ph, +pt}:
          ifs(Bool, Char.is_eq(Char.to_lower(h), ph),
            u => md_starts_ci_go(t, pt),
            u => False{})

def md_starts_ci(+s: String, +prefix: String) -> Bool:
  md_starts_ci_go(s, prefix)

def md_contains_ci_go(s: String, +needle: String) -> Bool:
  match s:
    case SNil{}:
      String.is_empty(needle)
    case SCon{+h, +t}:
      ifs(Bool, md_starts_ci(SCon{h, t}, needle),
        u => True{},
        u => md_contains_ci_go(t, needle))

def md_contains_ci(+s: String, +needle: String) -> Bool:
  md_contains_ci_go(s, needle)

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
          +name = md_string_to_lower(word_split_word(hit))
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
              +name = md_string_to_lower(word_split_word(namehit))
              Bool.and(whole, Bool.not(md_html_type7_excluded(name))),
            v => False{}),
        v => False{}),
    u => False{})

# Return 0 for no HTML block start, otherwise the CommonMark type number.
def md_html_block_kind_at(+line: String, +startcol: Nat) -> Nat:
  +scan = md_scan_indent_from(line, startcol)
  +indent = md_indent_scan_cols(scan)
  +s = ifs(String, Nat.is_le(indent, 3n),
    u => String.drop(line, md_indent_scan_chars(scan)),
    u => line)
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

def md_html_block_kind(+line: String) -> Nat:
  md_html_block_kind_at(line, 0n)

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

def md_ordered_scan_at(+s: String, +startcol: Nat) -> DigitScan:
  md_scan_digits(md_after_marker_indent_at(s, startcol), 0n, 0)

def md_ordered_scan(+s: String) -> DigitScan:
  md_ordered_scan_at(s, 0n)

def md_list_space_ok(+code: U32) -> Bool:
  U32.is_eq(code, 0) || U32.is_eq(code, 32) || U32.is_eq(code, 9)

type MdListMarkerInfo is Data:
  MdListMarkerInfo{valid: Bool, ordered: Bool, start: U32, markcode: U32,
    contentindent: Nat, blankfirst: Bool, content: String, contentcol: Nat, contentchars: Nat}

def mlmi_valid(x: MdListMarkerInfo) -> Bool:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      valid

def mlmi_ordered(x: MdListMarkerInfo) -> Bool:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      ordered

def mlmi_start(x: MdListMarkerInfo) -> U32:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      start

def mlmi_markcode(x: MdListMarkerInfo) -> U32:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      markcode

def mlmi_contentindent(x: MdListMarkerInfo) -> Nat:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      contentindent

def mlmi_blankfirst(x: MdListMarkerInfo) -> Bool:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      blankfirst

def mlmi_content(x: MdListMarkerInfo) -> String:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      content

def mlmi_contentcol(x: MdListMarkerInfo) -> Nat:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      contentcol

def mlmi_contentchars(x: MdListMarkerInfo) -> Nat:
  match x:
    case MdListMarkerInfo{valid, ordered, start, markcode, contentindent, blankfirst, content, contentcol, contentchars}:
      contentchars

def md_scan_list_marker_info_at(+s: String, +startcol: Nat) -> MdListMarkerInfo:
  +indentscan = md_scan_indent_from(s, startcol)
  +indent = md_indent_scan_cols(indentscan)
  +indentchars = md_indent_scan_chars(indentscan)
  +afterindent = String.drop(s, indentchars)
  +scan = md_scan_digits(afterindent, 0n, 0)
  +digits = digit_scan_count(scan)
  +mark = md_str_at(afterindent, 0n)
  +nextbullet = md_str_at(afterindent, 1n)
  +bulletchar = U32.is_eq(mark, 45) || U32.is_eq(mark, 43) || U32.is_eq(mark, 42)
  +unordered = Bool.and(Nat.is_le(indent, 3n), Bool.and(bulletchar, md_list_space_ok(nextbullet)))
  +delim = md_str_at(afterindent, digits)
  +nextordered = md_str_at(afterindent, Nat.add(digits, 1n))
  +orderedshape = Bool.and(Nat.is_ge(digits, 1n),
    Bool.and(Nat.is_le(digits, 9n),
      Bool.and(U32.is_eq(delim, 46) || U32.is_eq(delim, 41), md_list_space_ok(nextordered))))
  +ordered = Bool.and(Nat.is_le(indent, 3n), orderedshape)
  +valid = unordered || ordered
  +markwidth = ifs(Nat, ordered,
    u => Nat.add(digits, 1n),
    u => 1n)
  +markerend = Nat.add(indent, markwidth)
  +markerendcol = Nat.add(startcol, markerend)
  +after = String.drop(afterindent, markwidth)
  +padscan = md_scan_indent_from(after, markerendcol)
  +padcols = md_indent_scan_cols(padscan)
  +blankfirst = Text.blank_line(after)
  +wide = Nat.is_gt(padcols, 4n)
  +normalpad = Bool.pick(Nat, wide, 1n, padcols)
  +padding = Bool.pick(Nat, blankfirst, 1n, normalpad)
  +dropn = Bool.pick(Nat, blankfirst, padcols, normalpad)
  +padstrip = md_strip_columns_from(after, dropn, markerendcol)
  +content = md_column_strip_text(padstrip)
  +contentcol = Nat.add(markerendcol, md_column_strip_cols(padstrip))
  +contentchars = Nat.add(Nat.add(indentchars, markwidth), md_column_strip_chars(padstrip))
  +markcode = ifs(U32, ordered,
    u => delim,
    u => mark)
  +start = ifs(U32, ordered,
    u => digit_scan_value(scan),
    u => 1)
  MdListMarkerInfo{valid, ordered, start, markcode,
    Nat.add(markerend, padding), blankfirst, content, contentcol, contentchars}

def md_scan_list_marker_info(+s: String) -> MdListMarkerInfo:
  md_scan_list_marker_info_at(s, 0n)

def md_is_ordered_item_at(+s: String, +startcol: Nat) -> Bool:
  +info = md_scan_list_marker_info_at(s, startcol)
  Bool.and(mlmi_valid(info), mlmi_ordered(info))

def md_is_ordered_item(+s: String) -> Bool:
  md_is_ordered_item_at(s, 0n)

def md_is_unordered_item_at(+s: String, +startcol: Nat) -> Bool:
  +info = md_scan_list_marker_info_at(s, startcol)
  Bool.and(mlmi_valid(info), Bool.not(mlmi_ordered(info)))

def md_is_unordered_item(+s: String) -> Bool:
  md_is_unordered_item_at(s, 0n)

def md_is_list_item_at(+s: String, +startcol: Nat) -> Bool:
  mlmi_valid(md_scan_list_marker_info_at(s, startcol))

def md_is_list_item(+s: String) -> Bool:
  md_is_list_item_at(s, 0n)

def md_ordered_start_at(+s: String, +startcol: Nat) -> U32:
  mlmi_start(md_scan_list_marker_info_at(s, startcol))

def md_ordered_start(+s: String) -> U32:
  md_ordered_start_at(s, 0n)

# Paragraph-interruption predicates are needed by both the structural list
# scanner (for conservative lazy continuation) and paragraph collection.
def md_html_interrupts_paragraph_at(+s: String, +startcol: Nat) -> Bool:
  +kind = md_html_block_kind_at(s, startcol)
  Bool.and(Nat.is_ne(kind, 0n), Nat.is_ne(kind, 7n))

def md_html_interrupts_paragraph(+s: String) -> Bool:
  md_html_interrupts_paragraph_at(s, 0n)

# Lists interrupt paragraphs only in the cases allowed by CommonMark:
# ordered lists must start at 1, and a bullet item may not be empty.  The
# thematic-break interpretation is considered separately by the caller.
def md_list_interrupts_paragraph_at(+s: String, +startcol: Nat) -> Bool:
  +info = md_scan_list_marker_info_at(s, startcol)
  +orderedcase = Bool.and(mlmi_ordered(info), U32.is_eq(mlmi_start(info), 1))
  Bool.and(mlmi_valid(info),
    Bool.and(orderedcase || Bool.not(mlmi_ordered(info)), Bool.not(mlmi_blankfirst(info))))

def md_list_interrupts_paragraph(+s: String) -> Bool:
  md_list_interrupts_paragraph_at(s, 0n)

def md_is_paragraph_interrupt_at(+s: String, +startcol: Nat) -> Bool:
  md_is_fence_start_at(s, startcol) || md_is_atx_at(s, startcol) || md_is_thematic_at(s, startcol) ||
    md_is_quote_start_at(s, startcol) || md_list_interrupts_paragraph_at(s, startcol) || md_html_interrupts_paragraph_at(s, startcol)

def md_is_paragraph_interrupt(+s: String) -> Bool:
  md_is_paragraph_interrupt_at(s, 0n)

# Structural list-region scanner
# ------------------------------
#
# The scanner below is deliberately pure with respect to block parsing: it
# recognizes list markers, calculates the content indentation required by
# CommonMark rules 1--4, extracts the physical lines belonging to each item,
# removes that item indentation from continuation lines, and records whether
# sibling items were separated by blank lines.  It never constructs blocks;
# the fueled block dispatcher later parses each extracted item region
# recursively.

def md_ordered_type_matches(candidate: Bool, wanted: Bool) -> Bool:
  match wanted:
    case True{}:
      candidate
    case False{}:
      Bool.not(candidate)

# A sibling item must have the same bullet character or the same ordered
# delimiter.  A line that is itself a thematic break is never a list item.
def md_same_list_marker_at(+s: String, wanted_ordered: Bool, +markcode: U32, +startcol: Nat) -> Bool:
  +info = md_scan_list_marker_info_at(s, startcol)
  +typeok = md_ordered_type_matches(mlmi_ordered(info), wanted_ordered)
  Bool.and(mlmi_valid(info),
    Bool.and(typeok,
      Bool.and(U32.is_eq(mlmi_markcode(info), markcode), Bool.not(md_is_thematic_at(s, startcol)))))

def md_same_list_marker(+s: String, wanted_ordered: Bool, +markcode: U32) -> Bool:
  md_same_list_marker_at(s, wanted_ordered, markcode, 0n)

# While a list container is open, any well-formed list marker at a shallower
# indentation is a container boundary before lazy paragraph continuation is
# considered.  Whether it continues the current list or starts a following
# list is decided only after the current item has ended.
def md_any_list_marker_at(+s: String, +startcol: Nat) -> Bool:
  +info = md_scan_list_marker_info_at(s, startcol)
  Bool.and(mlmi_valid(info), Bool.not(md_is_thematic_at(s, startcol)))

def md_any_list_marker(+s: String) -> Bool:
  md_any_list_marker_at(s, 0n)

type MdRawItem is Data:
  MdRawItem{lines: List<&2, MdLine>, start: U32, end: U32}

def md_raw_item_lines(x: MdRawItem) -> List<&2, MdLine>:
  match x:
    case MdRawItem{lines, start, end}:
      lines

def md_raw_item_start(x: MdRawItem) -> U32:
  match x:
    case MdRawItem{lines, start, end}:
      start

def md_raw_item_end(x: MdRawItem) -> U32:
  match x:
    case MdRawItem{lines, start, end}:
      end

type MdRawListGrab is Data:
  MdRawListGrab{items: List<&2, MdRawItem>, rest: List<&2, MdLine>, end: U32, loose: Bool}

def md_raw_list_grab_items(x: MdRawListGrab) -> List<&2, MdRawItem>:
  match x:
    case MdRawListGrab{items, rest, end, loose}:
      items

def md_raw_list_grab_rest(x: MdRawListGrab) -> List<&2, MdLine>:
  match x:
    case MdRawListGrab{items, rest, end, loose}:
      rest

def md_raw_list_grab_end(x: MdRawListGrab) -> U32:
  match x:
    case MdRawListGrab{items, rest, end, loose}:
      end

def md_raw_list_grab_loose(x: MdRawListGrab) -> Bool:
  match x:
    case MdRawListGrab{items, rest, end, loose}:
      loose

# `xs` is in original order and `acc` is reversed.  The result is still
# reversed, with every element of `xs` preceding the old accumulated lines.
def md_rev_onto(+xs: List<&2, MdLine>, +acc: List<&2, MdLine>) -> List<&2, MdLine>:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      md_rev_onto(t, h <> acc)

def md_restore_pending(+pendingrev: List<&2, MdLine>, +tail: List<&2, MdLine>) -> List<&2, MdLine>:
  md_list_append(&2, MdLine, List.reverse(&2, MdLine, pendingrev), tail)

def md_item_scan_finish(
  +accrev: List<&2, MdLine>,
  +pendingrev: List<&2, MdLine>,
  +tail: List<&2, MdLine>,
  +end: U32
) -> LinesGrab:
  LinesGrab{List.reverse(&2, MdLine, accrev), md_restore_pending(pendingrev, tail), end}

def md_item_scan_eof(+accrev: List<&2, MdLine>, +end: U32) -> LinesGrab:
  LinesGrab{List.reverse(&2, MdLine, accrev), Nil{}, end}

def md_strip_list_cont_line(+line: MdLine, +indent: Nat) -> MdLine:
  +text = md_line_text(line)
  +oldcol = md_line_col(line)
  +strip = md_strip_columns_from(text, indent, oldcol)
  MdLine{md_column_strip_text(strip),
    md_pos_add(md_line_start(line), md_column_strip_chars(strip)),
    md_line_end(line),
    Nat.add(oldcol, md_column_strip_cols(strip)),
    md_line_lazy(line)}

# Conservative provenance test for the simple open-paragraph case in rule 5
# (laziness).  It deliberately never reopens a paragraph after another block.
# Lines that may become reference definitions still count as paragraph lines
# here because CommonMark determines container structure before extracting
# reference definitions from accumulated paragraphs.
def md_initial_plain_paragraph_at(+s: String, +startcol: Nat) -> Bool:
  +htmlkind = md_html_block_kind_at(s, startcol)
  +blockstart = md_is_fence_start_at(s, startcol) || md_is_atx_at(s, startcol) || md_is_thematic_at(s, startcol) ||
    md_is_quote_start_at(s, startcol) || md_is_list_item_at(s, startcol) || Nat.is_ne(htmlkind, 0n)
  Bool.and(Bool.not(Text.blank_line(s)),
    Bool.and(Bool.not(md_is_indented_code_line_at(s, startcol)), Bool.not(blockstart)))

def md_initial_plain_paragraph(+s: String) -> Bool:
  md_initial_plain_paragraph_at(s, 0n)


# Determine whether this line opens a plain paragraph at the deepest end of
# a chain of quote/list containers.  Container scanners use that provenance
# as their lazy-continuation state: a following line may omit markers only
# while such a paragraph is open.  This remains deliberately initial-block
# only; blank lines and intervening non-paragraph blocks close the state in
# the scanners themselves.
def md_container_plain_paragraph_go(fuel: Nat, +s: String, +startcol: Nat) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n++f:
      ifs(Bool, md_initial_plain_paragraph_at(s, startcol),
        u => True{},
        u =>
          ifs(Bool, md_is_quote_start_at(s, startcol),
            v =>
              +strip = md_quote_strip_text_at(s, startcol)
              +innercol = Nat.add(startcol, md_column_strip_cols(strip))
              md_container_plain_paragraph_go(f, md_column_strip_text(strip), innercol),
            v =>
              +info = md_scan_list_marker_info_at(s, startcol)
              ifs(Bool, mlmi_valid(info),
                w => md_container_plain_paragraph_go(f, mlmi_content(info), mlmi_contentcol(info)),
                w => False{})))

def md_container_plain_paragraph_at(+s: String, +startcol: Nat) -> Bool:
  md_container_plain_paragraph_go(Nat.add(String.length(s), 1n), s, startcol)

def md_container_plain_paragraph(+s: String) -> Bool:
  md_container_plain_paragraph_at(s, 0n)

def md_quote_lazy_candidate_ok_at(+s: String, +startcol: Nat) -> Bool:
  Bool.and(Bool.not(Text.blank_line(s)),
    Bool.not(md_is_fence_start_at(s, startcol) || md_is_atx_at(s, startcol) || md_is_thematic_at(s, startcol) ||
      md_is_quote_start_at(s, startcol) || md_quote_listish_at(s, startcol)))

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
      +linecol = md_line_col(line)
      ifs(LinesGrab, md_is_quote_start_at(text, linecol),
        u =>
          +stripped = md_quote_strip_line(line)
          +next_lazy = md_container_plain_paragraph_at(md_line_text(stripped), md_line_col(stripped))
          md_scan_quote_go(rest, stripped <> acc, md_line_end(line), next_lazy)
        u =>
          +lazy = Bool.and(lazy_ok, md_quote_lazy_candidate_ok_at(text, linecol))
          ifs(LinesGrab, lazy,
            v => md_scan_quote_go(rest, md_line_as_lazy(line) <> acc, md_line_end(line), lazy),
            v => md_scan_quote_finish(acc, line <> rest, end)))

def md_scan_quote(+xs: List<&2, MdLine>) -> LinesGrab:
  md_scan_quote_go(xs, Nil{}, 0, False{})



def md_lazy_continuation_ok_at(+s: String, +startcol: Nat) -> Bool:
  Bool.and(U32.is_zero(md_setext_level_at(s, startcol)), Bool.not(md_is_paragraph_interrupt_at(s, startcol)))

def md_lazy_continuation_ok(+s: String) -> Bool:
  md_lazy_continuation_ok_at(s, 0n)

def md_lazy_closes_paragraph_at(+s: String, +startcol: Nat) -> Bool:
  Bool.or(Bool.not(U32.is_zero(md_setext_level_at(s, startcol))), md_is_paragraph_interrupt_at(s, startcol))

def md_lazy_closes_paragraph(+s: String) -> Bool:
  md_lazy_closes_paragraph_at(s, 0n)

# Collect continuation lines for one item.  Blank lines are held in
# `pendingrev` until the next nonblank line proves that the item continues.
# If it does not, those blanks are restored to the returned remainder so the
# list-level scanner can decide whether they separate sibling items.  A
# blank-first item may begin with at most one blank line, so an additional
# pending blank before its first nonblank continuation blocks continuation.
def md_scan_list_item_go(
  +xs: List<&2, MdLine>,
  +contentindent: Nat,
  +wanted_ordered: Bool,
  +markcode: U32,
  +accrev: List<&2, MdLine>,
  +pendingrev: List<&2, MdLine>,
  +end: U32,
  +emptywait: Bool,
  +pendingblank: Bool,
  +paraopen: Bool
) -> LinesGrab:
  match xs:
    case Nil{}:
      md_item_scan_eof(accrev, end)
    case +line <> rest:
      +text = md_line_text(line)
      ifs(LinesGrab, Text.blank_line(text),
        u => md_scan_list_item_go(rest, contentindent, wanted_ordered, markcode,
          accrev, line <> pendingrev, end, emptywait, True{}, paraopen),
        u =>
          +linecol = md_line_col(line)
          +indented = Nat.is_ge(md_marker_indent_at(text, linecol), contentindent)
          +initialblocked = Bool.and(emptywait, pendingblank)
          +takecont = Bool.and(indented, Bool.not(initialblocked))
          ifs(LinesGrab, takecont,
            v =>
              +stripped = md_strip_list_cont_line(line, contentindent)
              +pendingorig = List.reverse(&2, MdLine, pendingrev)
              +accwithblanks = md_rev_onto(pendingorig, accrev)
              +closespara = md_lazy_closes_paragraph_at(md_line_text(stripped), md_line_col(stripped))
              +newparaopen = Bool.and(paraopen,
                Bool.and(Bool.not(pendingblank), Bool.not(closespara)))
              md_scan_list_item_go(rest, contentindent, wanted_ordered, markcode,
                stripped <> accwithblanks, Nil{}, md_line_end(line), False{}, False{}, newparaopen),
            v =>
              +containerboundary = md_any_list_marker_at(text, linecol)
              +lazybase = Bool.and(paraopen, Bool.not(pendingblank))
              +lazy = Bool.and(Bool.not(containerboundary),
                Bool.and(lazybase, md_lazy_continuation_ok_at(text, linecol)))
              ifs(LinesGrab, lazy,
                w =>
                  +pendingorig2 = List.reverse(&2, MdLine, pendingrev)
                  +accwithblanks2 = md_rev_onto(pendingorig2, accrev)
                  md_scan_list_item_go(rest, contentindent, wanted_ordered, markcode,
                    md_line_as_lazy(line) <> accwithblanks2, Nil{}, md_line_end(line), False{}, False{}, paraopen),
                w => md_item_scan_finish(accrev, pendingrev, line <> rest, end))))

# Extract the body of one item.  The first line is rewritten to the content
# after its marker/padding; continuation lines are rewritten by removing the
# item content indentation.  Positions remain approximate UTF-8 byte offsets.
def md_scan_raw_item(+line: MdLine, +rest: List<&2, MdLine>, +wanted_ordered: Bool, +markcode: U32) -> LinesGrab:
  +text = md_line_text(line)
  +info = md_scan_list_marker_info_at(text, md_line_col(line))
  +content = mlmi_content(info)
  +first : MdLine = MdLine{content, md_pos_add(md_line_start(line), mlmi_contentchars(info)), md_line_end(line), mlmi_contentcol(info), False{}}
  +paraopen = md_container_plain_paragraph_at(content, mlmi_contentcol(info))
  md_scan_list_item_go(rest, mlmi_contentindent(info), wanted_ordered, markcode,
    first <> Nil{}, Nil{}, md_line_end(line), mlmi_blankfirst(info), False{}, paraopen)

def md_raw_list_finish(
  +accrev: List<&2, MdRawItem>,
  +rest: List<&2, MdLine>,
  +end: U32,
  loose: Bool
) -> MdRawListGrab:
  MdRawListGrab{List.reverse(&2, MdRawItem, accrev), rest, end, loose}

# Group sibling items.  Blank lines at a boundary are consumed only after an
# item has ended; when the next nonblank line is a same-type marker they are
# recorded as item separation and make the list loose.  A different marker or
# non-marker line is left for the outer block parser.
def md_scan_raw_list_go(
  fuel: Nat,
  +xs: List<&2, MdLine>,
  +wanted_ordered: Bool,
  +markcode: U32,
  +accrev: List<&2, MdRawItem>,
  +loose: Bool,
  +end: U32,
  +pendingrev: List<&2, MdLine>,
  +blanks: Nat
) -> MdRawListGrab:
  match fuel:
    case 0n:
      md_raw_list_finish(accrev, md_restore_pending(pendingrev, xs), end, loose)
    case 1n++f:
      match xs:
        case Nil{}:
          md_raw_list_finish(accrev, md_restore_pending(pendingrev, Nil{}), end, loose)
        case line <> rest:
          +text = md_line_text(line)
          ifs(MdRawListGrab, Text.blank_line(text),
            u => md_scan_raw_list_go(f, rest, wanted_ordered, markcode, accrev, loose, end,
              line <> pendingrev, 1n+blanks),
            u =>
              ifs(MdRawListGrab, md_same_list_marker_at(text, wanted_ordered, markcode, md_line_col(line)),
                v =>
                  +itemscan = md_scan_raw_item(line, rest, wanted_ordered, markcode)
                  +itemlines = lines_grab_lines(itemscan)
                  +itemend = lines_grab_end(itemscan)
                  item : MdRawItem = MdRawItem{itemlines, md_line_start(line), itemend}
                  +seploose = Nat.is_gt(blanks, 0n)
                  md_scan_raw_list_go(f, lines_grab_rest(itemscan), wanted_ordered, markcode,
                    item <> accrev, loose || seploose, itemend, Nil{}, 0n),
                v => md_raw_list_finish(accrev, md_restore_pending(pendingrev, line <> rest), end, loose)))

def md_scan_raw_list(+xs: List<&2, MdLine>, ordered: Bool) -> MdRawListGrab:
  match xs:
    case Nil{}:
      MdRawListGrab{Nil{}, Nil{}, 0, False{}}
    case line <> rest:
      +len = md_list_length(&2, MdLine, xs)
      +fuel = Nat.add(Nat.mul(4n, len), 4n)
      +markcode = mlmi_markcode(md_scan_list_marker_info_at(md_line_text(line), md_line_col(line)))
      md_scan_raw_list_go(fuel, xs, ordered, markcode, Nil{}, False{}, 0, Nil{}, 0n)

# Paragraph collection.  A Setext underline is recognized before generic
# interruption because `---` is also a valid thematic-break marker.
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
      +linecol = md_line_col(line)
      +lazyline = md_line_lazy(line)
      +setext = Bool.pick(U32, lazyline, 0, md_setext_level_at(text, linecol))
      ifs(ParaGrab, Bool.not(U32.is_zero(setext)),
        u => md_scan_paragraph_finish(acc, rest, md_line_end(line), setext),
        u =>
          +structural = Bool.and(Bool.not(lazyline), md_is_paragraph_interrupt_at(text, linecol))
          +stop = Text.blank_line(text) || structural
          ifs(ParaGrab, stop,
            v => md_scan_paragraph_finish(acc, line <> rest, end, 0),
            v => md_scan_paragraph_go(rest, line <> acc, md_line_end(line))))

def md_scan_paragraph(+xs: List<&2, MdLine>, +first: MdLine) -> ParaGrab:
  md_scan_paragraph_go(xs, [first], md_line_end(first))

def md_drop_upto3(+s: String) -> String:
  +n = Nat.min(md_marker_indent(s), 3n)
  String.drop(s, n)

def md_paragraph_strings_go(xs: List<&2, MdLine>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case line <> rest:
      md_paragraph_strings_go(rest, md_trim_start(md_line_text(line)) <> acc)

def md_paragraph_strings(+xs: List<&2, MdLine>) -> List<&2, String>:
  md_paragraph_strings_go(xs, Nil{})

def md_paragraph_text(+xs: List<&2, MdLine>) -> String:
  md_trim_end(md_join_strings(md_paragraph_strings(xs), "\n"))

def md_paragraph_inline_source(+xs: List<&2, MdLine>) -> MdInlineSource:
  match xs:
    case Nil{}:
      MdInlineSource{"", 0, Nil{}}
    case +first <> rest:
      +firsttext = md_line_text(first)
      +firstlead = md_hspace_prefix(firsttext, 0n)
      +firstphysicallen = U32.to_nat(U32.sub(md_line_end(first), md_line_start(first)))
      +firstvirtuallead = Nat.min(firstlead, Nat.sub(Text.utf8_length(firsttext), firstphysicallen))
      +firstphysicallead = Nat.sub(firstlead, firstvirtuallead)
      +start = md_pos_add(md_line_start(first), firstphysicallead)
      MdInlineSource{md_paragraph_text(xs), start, md_paragraph_segments(xs, start)}


# If the conservative fuel estimate is ever exhausted, remaining lines still
# degrade to literal paragraph text rather than disappearing or looping.
def md_fallback_lines_go(lines: List<&2, MdLine>, +acc: List<&2, Ast.Block>) -> List<&2, Ast.Block>:
  match lines:
    case Nil{}:
      List.reverse(&2, Ast.Block, acc)
    case +line <> +rest:
      +text = md_line_text(line)
      ifs(List<&2, Ast.Block>, Text.blank_line(text),
        u => md_fallback_lines_go(rest, acc),
        u =>
          +span = md_line_span(line)
          leaf : Ast.Inline = Ast.IText{text, span}
          md_fallback_lines_go(rest, Ast.BParagraph{[leaf], [], span} <> acc))

def md_fallback_lines(+lines: List<&2, MdLine>) -> List<&2, Ast.Block>:
  md_fallback_lines_go(lines, Nil{})

# Block constructors in return position, so Bend does not need to infer the
# empty attribute/list literals inside local bindings.
def md_make_paragraph_block(+refs: List<&2, RefDef>, +source: MdInlineSource, +start: U32, +end: U32) -> Ast.Block:
  Ast.BParagraph{md_parse_inlines_top(refs, md_inline_source_text(source),
    md_inline_source_start(source), md_inline_source_segments(source)), [], Ast.Span{start, end}}

def md_make_heading_block(+refs: List<&2, RefDef>, +level: U32, +source: MdInlineSource, +start: U32, +end: U32) -> Ast.Block:
  Ast.BHeading{level, md_parse_inlines_top(refs, md_inline_source_text(source),
    md_inline_source_start(source), md_inline_source_segments(source)), [], Ast.Span{start, end}}

def md_make_code_block(+text: String, info: Maybe<&2, String>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BCodeBlock{text, info, [], Ast.Span{start, end}}

def md_make_thematic_block(+start: U32, +end: U32) -> Ast.Block:
  Ast.BThematicBreak{Ast.Span{start, end}}

def md_make_quote_block(inner: List<&2, Ast.Block>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BBlockQuote{inner, [], None{}, Ast.Span{start, end}}

def md_make_list_block(+ordered: Bool, +startnum: U32, tight: Bool, items: List<&2, Ast.ListItem>, +start: U32, +end: U32) -> Ast.Block:
  Ast.BList{ordered, startnum, tight, items, Ast.Span{start, end}}

def md_make_html_block(+text: String, +start: U32, +end: U32) -> Ast.Block:
  Ast.BHtmlBlock{text, Ast.Span{start, end}}

def md_maybe_info(+info: String) -> Maybe<&2, String>:
  ifs(Maybe<&2, String>, String.is_empty(info),
    u => None{},
    u => Some{info})

# One recursion-owning block dispatcher.  `MdWorkLines` parses a sequence of
# lines, while `MdWorkItems` parses the already extracted line regions of list
# items.  Keeping both modes in this one definition gives list parsing direct
# self-recursion without prohibited mutual recursion: scan helpers never call
# back into block construction.
type MdParseWork is Data:
  MdWorkLines{lines: List<&2, MdLine>, seenblock: Bool, blankafter: Bool, loose: Bool}
  MdWorkItems{items: List<&2, MdRawItem>, loose: Bool}

type MdParseOut is Data:
  MdParseOut{blocks: List<&2, Ast.Block>, items: List<&2, Ast.ListItem>, loose: Bool}

def md_parse_out_blocks(x: MdParseOut) -> List<&2, Ast.Block>:
  match x:
    case MdParseOut{blocks, items, loose}:
      blocks

def md_parse_out_items(x: MdParseOut) -> List<&2, Ast.ListItem>:
  match x:
    case MdParseOut{blocks, items, loose}:
      items

def md_parse_out_loose(x: MdParseOut) -> Bool:
  match x:
    case MdParseOut{blocks, items, loose}:
      loose

def md_parse_out_prepend_block(block: Ast.Block, +out: MdParseOut) -> MdParseOut:
  MdParseOut{block <> md_parse_out_blocks(out), md_parse_out_items(out), md_parse_out_loose(out)}

def md_parse_out_prepend_item(item: Ast.ListItem, +out: MdParseOut) -> MdParseOut:
  MdParseOut{md_parse_out_blocks(out), item <> md_parse_out_items(out), md_parse_out_loose(out)}

def md_lines_work(+lines: List<&2, MdLine>) -> MdParseWork:
  MdWorkLines{lines, False{}, False{}, False{}}

# State for the sequence continuation after emitting one direct child block.
# A pending blank line makes the region loose only when it separates two
# direct child blocks; leading and trailing blanks do not.
def md_lines_after_block(
  +lines: List<&2, MdLine>,
  +seenblock: Bool,
  +blankafter: Bool,
  +loose: Bool
) -> MdParseWork:
  +separated = Bool.and(seenblock, blankafter)
  MdWorkLines{lines, True{}, False{}, loose || separated}

# The fueled block parser.  Every iteration consumes at least one physical
# line (blank lines included).  Container contents are parsed by a recursive
# call on the extracted inner lines, and the outer continuation is a sibling
# recursive call on the unconsumed remainder; both descend on fuel.
def md_parse_work(
  fuel: Nat,
  +refs: List<&2, RefDef>,
  work: MdParseWork,
  +accblocks: List<&2, Ast.Block>,
  +accitems: List<&2, Ast.ListItem>
) -> MdParseOut:
  match fuel:
    case 0n:
      match work:
        case MdWorkLines{lines, seenblock, blankafter, loose}:
          MdParseOut{md_list_rev_onto(&2, Ast.Block, accblocks, md_fallback_lines(lines)),
            List.reverse(&2, Ast.ListItem, accitems), loose}
        case MdWorkItems{items, loose}:
          MdParseOut{List.reverse(&2, Ast.Block, accblocks),
            List.reverse(&2, Ast.ListItem, accitems), loose}
    case 1n++f:
      match work:
        case MdWorkItems{items, +loose}:
          match items:
            case Nil{}:
              MdParseOut{List.reverse(&2, Ast.Block, accblocks),
                List.reverse(&2, Ast.ListItem, accitems), loose}
            case +item <> restitems:
              +bodyout = md_parse_work(f, refs, md_lines_work(md_raw_item_lines(item)), Nil{}, Nil{})
              +bodyloose = md_parse_out_loose(bodyout)
              +bodyblocks = md_parse_out_blocks(bodyout)
              +span = md_make_span(md_raw_item_start(item), md_raw_item_end(item))
              itemout : Ast.ListItem = Ast.ListItem{bodyblocks, span}
              md_parse_work(f, refs, MdWorkItems{restitems, loose || bodyloose},
                accblocks, itemout <> accitems)
        case MdWorkLines{lines, +seenblock, +blankafter, +loose}:
          match lines:
            case Nil{}:
              MdParseOut{List.reverse(&2, Ast.Block, accblocks),
                List.reverse(&2, Ast.ListItem, accitems), loose}
            case +line <> +rest:
              +text = md_line_text(line)
              +start = md_line_start(line)
              +end = md_line_end(line)
              +linecol = md_line_col(line)
              +htmlkind = md_html_block_kind_at(text, linecol)
              ifs(MdParseOut, Text.blank_line(text),
                u => md_parse_work(f, refs, MdWorkLines{rest, seenblock, True{}, loose},
                  accblocks, accitems),
                u =>
                  ifs(MdParseOut, Nat.is_ne(htmlkind, 0n),
                    u =>
                      +grab = md_scan_html_block(line <> rest, htmlkind)
                      +content = md_join_code_lines(string_lines_grab_lines(grab))
                      +blockend = string_lines_grab_end(grab)
                      md_parse_work(f, refs,
                        md_lines_after_block(string_lines_grab_rest(grab), seenblock, blankafter, loose),
                        md_make_html_block(content, start, blockend) <> accblocks, accitems)
                    u =>
                      ifs(MdParseOut, md_is_fence_start_at(text, linecol),
                        u =>
                          +marker = md_fence_marker_at(text, linecol)
                          +flen = md_fence_len_at(text, linecol)
                          +openindent = md_marker_indent_at(text, linecol)
                          +grab = md_scan_fenced(rest, marker, flen, openindent, end)
                          +content = md_join_code_lines(string_lines_grab_lines(grab))
                          +blockend = string_lines_grab_end(grab)
                          +info = md_maybe_info(md_fence_info_at(text, linecol))
                          md_parse_work(f, refs,
                            md_lines_after_block(string_lines_grab_rest(grab), seenblock, blankafter, loose),
                            md_make_code_block(content, info, start, blockend) <> accblocks, accitems)
                        u =>
                          ifs(MdParseOut, md_is_atx_at(text, linecol),
                            u =>
                              +content = md_atx_text_at(text, linecol)
                              +contentstart = md_atx_content_start_at(text, linecol, start, end)
                              +inlinesrc = md_inline_source_single(content, contentstart)
                              +level = md_atx_level_at(text, linecol)
                              md_parse_work(f, refs,
                                md_lines_after_block(rest, seenblock, blankafter, loose),
                                md_make_heading_block(refs, level, inlinesrc, start, end) <> accblocks, accitems)
                            u =>
                              ifs(MdParseOut, md_is_thematic_at(text, linecol),
                                u =>
                                  md_parse_work(f, refs,
                                    md_lines_after_block(rest, seenblock, blankafter, loose),
                                    md_make_thematic_block(start, end) <> accblocks, accitems)
                                u =>
                                  ifs(MdParseOut, md_is_quote_start_at(text, linecol),
                                    u =>
                                      +grab = md_scan_quote(line <> rest)
                                      +innerout = md_parse_work(f, refs, md_lines_work(lines_grab_lines(grab)), Nil{}, Nil{})
                                      +inner = md_parse_out_blocks(innerout)
                                      +blockend = lines_grab_end(grab)
                                      md_parse_work(f, refs,
                                        md_lines_after_block(lines_grab_rest(grab), seenblock, blankafter, loose),
                                        md_make_quote_block(inner, start, blockend) <> accblocks, accitems)
                                    u =>
                                      ifs(MdParseOut, md_is_list_item_at(text, linecol),
                                        u =>
                                          +minfo = md_scan_list_marker_info_at(text, linecol)
                                          +ordered = mlmi_ordered(minfo)
                                          +grab = md_scan_raw_list(line <> rest, ordered)
                                          +startnum = mlmi_start(minfo)
                                          +rawitems = md_raw_list_grab_items(grab)
                                          +rawloose = md_raw_list_grab_loose(grab)
                                          +itemsout = md_parse_work(f, refs, MdWorkItems{rawitems, rawloose}, Nil{}, Nil{})
                                          +listitems = md_parse_out_items(itemsout)
                                          +listloose = md_parse_out_loose(itemsout)
                                          +blockend = md_raw_list_grab_end(grab)
                                          +listblock = md_make_list_block(ordered, startnum,
                                            Bool.not(listloose), listitems, start, blockend)
                                          md_parse_work(f, refs,
                                            md_lines_after_block(md_raw_list_grab_rest(grab), seenblock, blankafter, loose),
                                            listblock <> accblocks, accitems)
                                        u =>
                                          ifs(MdParseOut, md_is_indented_code_line_at(text, linecol),
                                            u =>
                                              +grab = md_scan_indented(line <> rest)
                                              +content = md_join_code_lines(md_trim_trailing_empty_lines(string_lines_grab_lines(grab)))
                                              +blockend = string_lines_grab_end(grab)
                                              md_parse_work(f, refs,
                                                md_lines_after_block(string_lines_grab_rest(grab), seenblock, blankafter, loose),
                                                md_make_code_block(content, None{}, start, blockend) <> accblocks, accitems)
                                            u =>
                                              +grab = md_scan_paragraph(rest, line)
                                              +inlinesrc = md_paragraph_inline_source(para_grab_lines(grab))
                                              +blockend = para_grab_end(grab)
                                              +setext = para_grab_setext(grab)
                                              +leaf = ifs(Ast.Block, U32.is_zero(setext),
                                                v => md_make_paragraph_block(refs, inlinesrc, start, blockend),
                                                v => md_make_heading_block(refs, setext, inlinesrc, start, blockend))
                                              md_parse_work(f, refs,
                                                md_lines_after_block(para_grab_rest(grab), seenblock, blankafter, loose),
                                                leaf <> accblocks, accitems)))))))))

def md_parse_blocks(fuel: Nat, +refs: List<&2, RefDef>, +lines: List<&2, MdLine>) -> List<&2, Ast.Block>:
  md_parse_out_blocks(md_parse_work(fuel, refs, md_lines_work(lines), Nil{}, Nil{}))

# Reference-definition stripping/collection.  Collection traverses the same
# block-container structure as the parser, then rewrites definition content
# to same-width whitespace before the normal parse.  This preserves byte
# positions while ensuring that definitions in code and HTML blocks remain
# literal and that definitions cannot interrupt an accumulated paragraph.
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


# Blank spans are half-open byte intervals in the newline-normalized source.
# They cover only content bytes, never the physical line ending; container
# markers outside the span are therefore preserved exactly.
type RefBlank is Data:
  RefBlank{start: U32, end: U32}

def ref_blank_start(x: RefBlank) -> U32:
  match x:
    case RefBlank{start, end}:
      start

def ref_blank_end(x: RefBlank) -> U32:
  match x:
    case RefBlank{start, end}:
      end

# Reference collection accumulates blank spans in reverse document order.
# They are reversed once before being applied to the source.
type RefScan is Data:
  RefScan{refs: List<&2, RefDef>, blanks: List<&2, RefBlank>}

def ref_scan_refs(x: RefScan) -> List<&2, RefDef>:
  match x:
    case RefScan{refs, blanks}:
      refs

def ref_scan_blanks(x: RefScan) -> List<&2, RefBlank>:
  match x:
    case RefScan{refs, blanks}:
      blanks

def md_add_ref_once(+refs: List<&2, RefDef>, +definition: RefDef) -> List<&2, RefDef>:
  ifs(List<&2, RefDef>, md_refs_have_label(refs, ref_def_label(definition)),
    u => refs,
    u => definition <> refs)


# Move the blank spans of one definition (stored in document order) onto the
# reverse-document-order accumulator.
def md_ref_scan_add_blanks(xs: List<&2, RefBlank>, +acc: List<&2, RefBlank>) -> List<&2, RefBlank>:
  match xs:
    case Nil{}:
      acc
    case +h <> +t:
      md_ref_scan_add_blanks(t, h <> acc)

# A flattened view of adjacent container-stripped lines.  The byte positions
# in that flattened text are piecewise, because container markers and other
# elided prefixes occupy source bytes but no flattened bytes.
type RefVirtual is Data:
  RefVirtual{text: String, segments: List<&2, MdInlineSegment>}

def ref_virtual_text(x: RefVirtual) -> String:
  match x:
    case RefVirtual{text, segments}:
      text

def ref_virtual_segments(x: RefVirtual) -> List<&2, MdInlineSegment>:
  match x:
    case RefVirtual{text, segments}:
      segments

def md_ref_line_exact(+line: MdLine) -> Bool:
  +physical = U32.to_nat(U32.sub(md_line_end(line), md_line_start(line)))
  Nat.is_eq(Text.utf8_length(md_line_text(line)), physical)

# Partial-tab container stripping can insert virtual spaces that have no
# independent source byte.  Reference collection is conservative for those
# lines: it declines the candidate rather than inventing inaccurate spans.
def md_ref_lines_exact(xs: List<&2, MdLine>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +line <> +rest:
      ifs(Bool, md_ref_line_exact(line),
        u => md_ref_lines_exact(rest),
        u => False{})

# Build the flattened reference-candidate text and its segment map.  `dropn`
# is physical indentation on the first line only.  Each retained line has one
# virtual LF separator whose endpoint is the physical LF byte at that line's
# end.  The final line ends at EOF in the flattened view, which the reference
# scanner treats equivalently to a line ending.
def md_ref_virtual_go(
  xs: List<&2, MdLine>,
  +dropn: Nat,
  +vpos: Nat,
  +chunksrev: List<&2, String>,
  +segsrev: List<&2, MdInlineSegment>
) -> RefVirtual:
  match xs:
    case Nil{}:
      RefVirtual{md_string_concat(List.reverse(&2, String, chunksrev)),
        List.reverse(&2, MdInlineSegment, segsrev)}
    case +line <> +rest:
      +text = String.drop(md_line_text(line), dropn)
      +len = Text.utf8_length(text)
      +original = md_pos_add(md_line_start(line), dropn)
      +contentseg = md_inline_segment_mk(U32.from_nat(vpos), original)
      +newlinepos = Nat.add(vpos, len)
      +last = md_lines_is_empty(rest)
      ifs(RefVirtual, last,
        u => RefVirtual{md_string_concat(List.reverse(&2, String, text <> chunksrev)),
          List.reverse(&2, MdInlineSegment, contentseg <> segsrev)},
        u =>
          +newlineseg = md_inline_segment_mk(U32.from_nat(newlinepos), md_line_end(line))
          +linechunk = text ++ "\n"
          md_ref_virtual_go(rest, 0n, Nat.add(newlinepos, 1n),
            linechunk <> chunksrev, newlineseg <> contentseg <> segsrev))

def md_ref_virtual(+xs: List<&2, MdLine>, +dropn: Nat) -> RefVirtual:
  md_ref_virtual_go(xs, dropn, 0n, Nil{}, Nil{})

# Blanking result for one definition.  `rest` is the first unconsumed input
# line; blanks are in document order.
type RefBlankCount is Data:
  RefBlankCount{blanks: List<&2, RefBlank>, rest: List<&2, MdLine>}

def ref_blank_count_blanks(x: RefBlankCount) -> List<&2, RefBlank>:
  match x:
    case RefBlankCount{blanks, rest}:
      blanks

def ref_blank_count_rest(x: RefBlankCount) -> List<&2, MdLine>:
  match x:
    case RefBlankCount{blanks, rest}:
      rest

# Valid definitions consume complete physical content lines: trailing spaces
# are part of the definition scan, while any other trailing byte would make
# the candidate invalid.  Consequently every consumed line can be blanked as
# a whole after container prefixes.  Newline bytes are outside every span.
def md_blank_ref_lines_go(
  xs: List<&2, MdLine>,
  +dropn: Nat,
  +left: Nat,
  +acc: List<&2, RefBlank>
) -> RefBlankCount:
  match xs:
    case Nil{}:
      RefBlankCount{List.reverse(&2, RefBlank, acc), Nil{}}
    case +line <> +rest:
      ifs(RefBlankCount, Nat.is_eq(left, 0n),
        u => RefBlankCount{List.reverse(&2, RefBlank, acc), line <> rest},
        u =>
          +textlen = Text.utf8_length(md_line_text(line))
          +len = Nat.sub(textlen, dropn)
          +blank : RefBlank = RefBlank{md_line_start(line), md_line_end(line)}
          ifs(RefBlankCount, Nat.is_le(left, len),
            v => RefBlankCount{List.reverse(&2, RefBlank, blank <> acc), rest},
            v => md_blank_ref_lines_go(rest, 0n, Nat.sub(left, Nat.add(len, 1n)), blank <> acc)))

def md_blank_ref_lines(+xs: List<&2, MdLine>, +dropn: Nat, +consumed: Nat) -> RefBlankCount:
  md_blank_ref_lines_go(xs, dropn, consumed, Nil{})

# A successful scan over one or more container-stripped lines.
type RefLinesHit is Data:
  RefLinesHit{definition: RefDef, blanks: List<&2, RefBlank>, rest: List<&2, MdLine>}

def ref_lines_hit_definition(x: RefLinesHit) -> RefDef:
  match x:
    case RefLinesHit{definition, blanks, rest}:
      definition

def ref_lines_hit_blanks(x: RefLinesHit) -> List<&2, RefBlank>:
  match x:
    case RefLinesHit{definition, blanks, rest}:
      blanks

def ref_lines_hit_rest(x: RefLinesHit) -> List<&2, MdLine>:
  match x:
    case RefLinesHit{definition, blanks, rest}:
      rest

# Move reference destination/definition spans from flattened coordinates to
# normalized-source coordinates.  The semantic strings are unchanged.
def md_ref_def_respan(+definition: RefDef, +segs: List<&2, MdInlineSegment>) -> RefDef:
  RefDef{ref_def_label(definition), ref_def_href(definition),
    ref_def_logical_href(definition), ref_def_raw_href(definition),
    ref_def_title(definition),
    md_inline_segment_span(segs, ref_def_destination_span(definition)),
    md_inline_segment_span(segs, ref_def_definition_span(definition))}

# Scan a reference definition at the start of a sequence of lines belonging
# to one accumulated paragraph.  The sequence has already been confined by
# the block scanner, so a multiline title cannot cross a blank line or a
# block interrupt.  Up to three columns of initial indentation are allowed;
# those bytes are blanked with the definition but are not part of its span.
def md_scan_ref_in_lines(+xs: List<&2, MdLine>) -> Maybe<&2, RefLinesHit>:
  match xs:
    case Nil{}:
      None{}
    case +line <> +rest:
      +text = md_line_text(line)
      +indentscan = md_scan_indent_from(text, md_line_col(line))
      +indentcols = md_indent_scan_cols(indentscan)
      +indentchars = md_indent_scan_chars(indentscan)
      +afterindent = String.drop(text, indentchars)
      +candidate = Bool.and(Nat.is_le(indentcols, 3n), String.starts_with(afterindent, "["))
      ifs(Maybe<&2, RefLinesHit>, candidate,
        u =>
          +virtual = md_ref_virtual(xs, indentchars)
          maybe_case(RefHit, Maybe<&2, RefLinesHit>,
            md_scan_reference_definition_at(ref_virtual_text(virtual), 0),
            +hit =>
              +segs = ref_virtual_segments(virtual)
              +mapped = md_ref_def_respan(ref_hit_def(hit), segs)
              +blanked = md_blank_ref_lines(xs, indentchars, ref_hit_consumed(hit))
              +hitrest = ref_blank_count_rest(blanked)
              +alllen = md_list_length(&2, MdLine, xs)
              +restlen = md_list_length(&2, MdLine, hitrest)
              +consumedlines = Nat.sub(alllen, restlen)
              +consumedexact = md_ref_lines_exact(md_list_take(&2, MdLine, xs, consumedlines))
              ifs(Maybe<&2, RefLinesHit>, consumedexact,
                v => Some{RefLinesHit{mapped, ref_blank_count_blanks(blanked), hitrest}},
                v => None{}),
            v => None{}),
        u => None{})

# Leading-reference scan for one accumulated paragraph.  Scanning stops at
# the first line that is not a complete definition; that line and everything
# after it is ordinary paragraph content, so later apparent definitions in
# the same paragraph cannot interrupt it.
type ParaRefScan is Data:
  ParaRefScan{refs: List<&2, RefDef>, blanks: List<&2, RefBlank>,
    remaining: List<&2, MdLine>, scanned: Nat}

def para_ref_scan_refs(x: ParaRefScan) -> List<&2, RefDef>:
  match x:
    case ParaRefScan{refs, blanks, remaining, scanned}:
      refs

def para_ref_scan_blanks(x: ParaRefScan) -> List<&2, RefBlank>:
  match x:
    case ParaRefScan{refs, blanks, remaining, scanned}:
      blanks

def para_ref_scan_remaining(x: ParaRefScan) -> List<&2, MdLine>:
  match x:
    case ParaRefScan{refs, blanks, remaining, scanned}:
      remaining

def para_ref_scan_scanned(x: ParaRefScan) -> Nat:
  match x:
    case ParaRefScan{refs, blanks, remaining, scanned}:
      scanned

def md_para_refs_go(
  fuel: Nat,
  +xs: List<&2, MdLine>,
  +refs: List<&2, RefDef>,
  +blanks: List<&2, RefBlank>,
  +scanned: Nat
) -> ParaRefScan:
  match fuel:
    case 0n:
      ParaRefScan{refs, blanks, xs, scanned}
    case 1n++f:
      match xs:
        case Nil{}:
          ParaRefScan{refs, blanks, Nil{}, scanned}
        case line <> rest:
          maybe_case(RefLinesHit, ParaRefScan, md_scan_ref_in_lines(xs),
            +hit =>
              +newblanks = md_ref_scan_add_blanks(ref_lines_hit_blanks(hit), blanks)
              +newrefs = md_add_ref_once(refs, ref_lines_hit_definition(hit))
              md_para_refs_go(f, ref_lines_hit_rest(hit), newrefs, newblanks, 1n+scanned),
            v => ParaRefScan{refs, blanks, xs, scanned})

def md_scan_paragraph_refs(
  +xs: List<&2, MdLine>,
  +refs: List<&2, RefDef>,
  +blanks: List<&2, RefBlank>
) -> ParaRefScan:
  +len = md_list_length(&2, MdLine, xs)
  md_para_refs_go(Nat.add(len, 2n), xs, refs, blanks, 0n)

# Collection traversal mirrors the block parser's own container extraction.
# Unlike the parser dispatcher, it emits no AST and descends only to find
# accumulated paragraphs whose leading text can contain definitions.
type RefCollectWork is Data:
  RefWorkLines{lines: List<&2, MdLine>}
  RefWorkItems{items: List<&2, MdRawItem>}

# After a false setext candidate, reparse the underline as ordinary paragraph
# content and return the first line after the enlarged paragraph.  A setext
# line is false when every preceding line was consumed as a reference
# definition: removing those lines leaves no paragraph content for it to
# underline.
def md_false_setext_rest(+afterpre: List<&2, MdLine>, +fallback: List<&2, MdLine>) -> List<&2, MdLine>:
  match afterpre:
    case Nil{}:
      fallback
    case +underline <> +afterunderline:
      +contgrab = md_scan_paragraph(afterunderline, underline)
      para_grab_rest(contgrab)

def md_collect_refs_work(
  fuel: Nat,
  +refs: List<&2, RefDef>,
  +blanks: List<&2, RefBlank>,
  work: RefCollectWork
) -> RefScan:
  match fuel:
    case 0n:
      RefScan{refs, blanks}
    case 1n++f:
      match work:
        case RefWorkItems{items}:
          match items:
            case Nil{}:
              RefScan{refs, blanks}
            case +item <> restitems:
              +inner = md_collect_refs_work(f, refs, blanks,
                RefWorkLines{md_raw_item_lines(item)})
              md_collect_refs_work(f, ref_scan_refs(inner), ref_scan_blanks(inner),
                RefWorkItems{restitems})
        case RefWorkLines{lines}:
          match lines:
            case Nil{}:
              RefScan{refs, blanks}
            case +line <> +rest:
              +text = md_line_text(line)
              +linecol = md_line_col(line)
              +htmlkind = md_html_block_kind_at(text, linecol)
              ifs(RefScan, Text.blank_line(text),
                u => md_collect_refs_work(f, refs, blanks, RefWorkLines{rest}),
                u =>
                  ifs(RefScan, Nat.is_ne(htmlkind, 0n),
                    u =>
                      +grab = md_scan_html_block(line <> rest, htmlkind)
                      md_collect_refs_work(f, refs, blanks,
                        RefWorkLines{string_lines_grab_rest(grab)}),
                    u =>
                      ifs(RefScan, md_is_fence_start_at(text, linecol),
                        u =>
                          +marker = md_fence_marker_at(text, linecol)
                          +flen = md_fence_len_at(text, linecol)
                          +openindent = md_marker_indent_at(text, linecol)
                          +grab = md_scan_fenced(rest, marker, flen, openindent, md_line_end(line))
                          md_collect_refs_work(f, refs, blanks,
                            RefWorkLines{string_lines_grab_rest(grab)}),
                        u =>
                          ifs(RefScan, md_is_atx_at(text, linecol),
                            u => md_collect_refs_work(f, refs, blanks, RefWorkLines{rest}),
                            u =>
                              ifs(RefScan, md_is_thematic_at(text, linecol),
                                u => md_collect_refs_work(f, refs, blanks, RefWorkLines{rest}),
                                u =>
                                  ifs(RefScan, md_is_quote_start_at(text, linecol),
                                    u =>
                                      +grab = md_scan_quote(line <> rest)
                                      +inner = md_collect_refs_work(f, refs, blanks,
                                        RefWorkLines{lines_grab_lines(grab)})
                                      md_collect_refs_work(f, ref_scan_refs(inner), ref_scan_blanks(inner),
                                        RefWorkLines{lines_grab_rest(grab)}),
                                    u =>
                                      ifs(RefScan, md_is_list_item_at(text, linecol),
                                        u =>
                                          +minfo = md_scan_list_marker_info_at(text, linecol)
                                          +ordered = mlmi_ordered(minfo)
                                          +grab = md_scan_raw_list(line <> rest, ordered)
                                          +inner = md_collect_refs_work(f, refs, blanks,
                                            RefWorkItems{md_raw_list_grab_items(grab)})
                                          md_collect_refs_work(f, ref_scan_refs(inner), ref_scan_blanks(inner),
                                            RefWorkLines{md_raw_list_grab_rest(grab)}),
                                        u =>
                                          ifs(RefScan, md_is_indented_code_line_at(text, linecol),
                                            u =>
                                              +grab = md_scan_indented(line <> rest)
                                              md_collect_refs_work(f, refs, blanks,
                                                RefWorkLines{string_lines_grab_rest(grab)}),
                                            u =>
                                              +grab = md_scan_paragraph(rest, line)
                                              +parascan = md_scan_paragraph_refs(para_grab_lines(grab), refs, blanks)
                                              +newrefs = para_ref_scan_refs(parascan)
                                              +newblanks = para_ref_scan_blanks(parascan)
                                              +remaining = para_ref_scan_remaining(parascan)
                                              +scanned = para_ref_scan_scanned(parascan)
                                              +setext = para_grab_setext(grab)
                                              +allrefs = Bool.and(Nat.is_le(1n, scanned), md_lines_is_empty(remaining))
                                              +falsesetext = Bool.and(Bool.not(U32.is_zero(setext)), allrefs)
                                              +inputlines : List<&2, MdLine> = line <> rest
                                              +prelen = md_list_length(&2, MdLine, para_grab_lines(grab))
                                              +afterpre = md_list_drop(&2, MdLine, inputlines, prelen)
                                              +continuerest = ifs(List<&2, MdLine>, falsesetext,
                                                v => md_false_setext_rest(afterpre, para_grab_rest(grab)),
                                                v => para_grab_rest(grab))
                                              md_collect_refs_work(f, newrefs, newblanks,
                                                RefWorkLines{continuerest})))))))))

# Blank-span application cursor: expired spans are discarded at the
# front, then the first remaining span is the only one that can contain the
# current byte because spans are produced in ascending order.
type BlankCursor is Data:
  BlankCursor{inside: Bool, blanks: List<&2, RefBlank>}

def blank_cursor_inside(x: BlankCursor) -> Bool:
  match x:
    case BlankCursor{inside, blanks}:
      inside

def blank_cursor_blanks(x: BlankCursor) -> List<&2, RefBlank>:
  match x:
    case BlankCursor{inside, blanks}:
      blanks

def md_blank_cursor(xs: List<&2, RefBlank>, +pos: U32) -> BlankCursor:
  match xs:
    case Nil{}:
      BlankCursor{False{}, Nil{}}
    case +h <> +t:
      ifs(BlankCursor, U32.is_le(ref_blank_end(h), pos),
        u => md_blank_cursor(t, pos),
        u =>
          +inside = Bool.and(U32.is_le(ref_blank_start(h), pos), U32.is_lt(pos, ref_blank_end(h)))
          BlankCursor{inside, h <> t})

# Rewrite only bytes covered by reference-definition content spans.  Each
# UTF-8 byte becomes one ASCII space, except line endings, so the output has
# exactly the input's byte length and physical line structure.
def md_apply_blank_spans_go(
  fuel: Nat,
  +s: String,
  +pos: U32,
  +blanks: List<&2, RefBlank>,
  +acc: String
) -> String:
  match fuel:
    case 0n:
      String.reverse(acc) ++ s
    case 1n++f:
      match s:
        case SNil{}:
          String.reverse(acc)
        case SCon{+h, +t}:
          +width = Text.utf8_width(h)
          +cursor = md_blank_cursor(blanks, pos)
          +blankit = Bool.and(blank_cursor_inside(cursor), Bool.not(Char.is_eq(h, '\n')))
          +piece = ifs(String, blankit,
            u => md_repeat_char(' ', width),
            u => md_char_string(h))
          md_apply_blank_spans_go(f, t, md_pos_add(pos, width),
            blank_cursor_blanks(cursor), piece ++ acc)

def md_apply_blank_spans(+source: String, +spans: List<&2, RefBlank>) -> String:
  +len = Text.utf8_length(source)
  md_apply_blank_spans_go(Nat.add(len, 4n), source, 0, spans, SNil{})

# Collect definitions by traversing the same block structure that the parser
# will later consume.  This is intentionally structural rather than a line
# prefix heuristic: definitions inside fences, indented code, and HTML blocks
# are literal at every container depth, while definitions cannot interrupt an
# already open paragraph.
def md_collect_reference_spans(+source: String) -> RefScan:
  +rawlines = md_lines(source)
  +lines = md_make_lines(md_drop_final_empty(rawlines), 0n)
  +len = Text.utf8_length(source)
  +fuel = Nat.add(Nat.mul(8n, len), 16n)
  md_collect_refs_work(fuel, Nil{}, Nil{}, RefWorkLines{lines})

def md_strip_reference_definitions(+source: String) -> RefStrip:
  +scan = md_collect_reference_spans(source)
  +forwardblanks = List.reverse(&2, RefBlank, ref_scan_blanks(scan))
  +text = md_apply_blank_spans(source, forwardblanks)
  RefStrip{text, ref_scan_refs(scan)}

# Build the line table and parse the normalized input.  Fuel is proportional
# to input bytes; blank-only lines still consume one fuel and there is slack
# for container descent.
def md_document_from_normalized(+source: String) -> Ast.Document:
  +stripped = md_strip_reference_definitions(source)
  +refs = ref_strip_refs(stripped)
  +cleansource = ref_strip_text(stripped)
  +rawlines = md_lines(cleansource)
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
