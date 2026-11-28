import Base
import ../ast.bend as Ast
import ../text.bend as Text

# Clean-room Textile parser, first milestone.
#
# The parser is total: every construct either recognizes a complete documented
# shape or emits the offending bytes as ordinary text.  The deeply recursive
# inline/block passes carry Nat fuel because Bend termination checking cannot
# otherwise see that a recursively parsed fragment is smaller than its parent.

# Bend cannot match on a computed local value.  These eliminators isolate the
# match in a helper; each continuation closure is used at most once.
def tx_if(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def tx_maybe_case(-A: Data, -B: Type, m: Maybe<&2, A>, some: A -> B, none: Unit -> B) -> B:
  match m:
    case Some{x}:
      some(x)
    case None{}:
      none(Unit{})

# Small Data records used where primitive pairs would be affine.
type TxStrSplit is Data:
  TxStrSplit{before: String, after: String}

def tx_str_before(x: TxStrSplit) -> String:
  match x:
    case TxStrSplit{before, after}:
      before

def tx_str_after(x: TxStrSplit) -> String:
  match x:
    case TxStrSplit{before, after}:
      after

type TxLinkLabel is Data:
  TxLinkLabel{display: String, title: Maybe<&2, String>}

def tx_link_label_display(x: TxLinkLabel) -> String:
  match x:
    case TxLinkLabel{display, title}:
      display

def tx_link_label_title(x: TxLinkLabel) -> Maybe<&2, String>:
  match x:
    case TxLinkLabel{display, title}:
      title

type TxImageParts is Data:
  TxImageParts{src: String, alt: String, title: Maybe<&2, String>}

def tx_image_parts_src(x: TxImageParts) -> String:
  match x:
    case TxImageParts{src, alt, title}:
      src

def tx_image_parts_alt(x: TxImageParts) -> String:
  match x:
    case TxImageParts{src, alt, title}:
      alt

def tx_image_parts_title(x: TxImageParts) -> Maybe<&2, String>:
  match x:
    case TxImageParts{src, alt, title}:
      title

type TxLineSplit is Data:
  TxLineSplit{taken: List<&2, String>, rest: List<&2, String>}

def tx_line_split_taken(x: TxLineSplit) -> List<&2, String>:
  match x:
    case TxLineSplit{taken, rest}:
      taken

def tx_line_split_rest(x: TxLineSplit) -> List<&2, String>:
  match x:
    case TxLineSplit{taken, rest}:
      rest

type TxItemsSplit is Data:
  TxItemsSplit{items: List<&2, TxRawItem>, rest: List<&2, String>}

def tx_items_split_items(x: TxItemsSplit) -> List<&2, TxRawItem>:
  match x:
    case TxItemsSplit{items, rest}:
      items

def tx_items_split_rest(x: TxItemsSplit) -> List<&2, String>:
  match x:
    case TxItemsSplit{items, rest}:
      rest

type TxEscapeSplit is Data:
  TxEscapeSplit{taken: List<&2, String>, rest: List<&2, String>, closed: Bool}

def tx_escape_taken(x: TxEscapeSplit) -> List<&2, String>:
  match x:
    case TxEscapeSplit{taken, rest, closed}:
      taken

def tx_escape_rest(x: TxEscapeSplit) -> List<&2, String>:
  match x:
    case TxEscapeSplit{taken, rest, closed}:
      rest

def tx_escape_closed(x: TxEscapeSplit) -> Bool:
  match x:
    case TxEscapeSplit{taken, rest, closed}:
      closed

# A block signature, normalized to a small numeric kind:
# 1 = paragraph, 2 = heading, 3 = block quote.
type TxBlockSig is Data:
  TxBlockSig{kind: Nat, level: U32, attrs: List<&2, Ast.Attr>, text: String}

def tx_sig_kind(x: TxBlockSig) -> Nat:
  match x:
    case TxBlockSig{kind, level, attrs, text}:
      kind

def tx_sig_level(x: TxBlockSig) -> U32:
  match x:
    case TxBlockSig{kind, level, attrs, text}:
      level

def tx_sig_attrs(x: TxBlockSig) -> List<&2, Ast.Attr>:
  match x:
    case TxBlockSig{kind, level, attrs, text}:
      attrs

def tx_sig_text(x: TxBlockSig) -> String:
  match x:
    case TxBlockSig{kind, level, attrs, text}:
      text

type TxRawItem is Data:
  TxRawItem{depth: Nat, ordered: Bool, text: String, line: String}

def tx_raw_depth(+x: TxRawItem) -> Nat:
  TxRawItem{depth, ordered, text, line} = x
  depth

def tx_raw_ordered(+x: TxRawItem) -> Bool:
  TxRawItem{depth, ordered, text, line} = x
  ordered

def tx_raw_text(+x: TxRawItem) -> String:
  TxRawItem{depth, ordered, text, line} = x
  text

def tx_raw_line(+x: TxRawItem) -> String:
  TxRawItem{depth, ordered, text, line} = x
  line

type TxListLevel is Data:
  TxListLevel{items: List<&2, Ast.ListItem>, rest: List<&2, TxRawItem>}

def tx_level_items(x: TxListLevel) -> List<&2, Ast.ListItem>:
  match x:
    case TxListLevel{items, rest}:
      items

def tx_level_rest(x: TxListLevel) -> List<&2, TxRawItem>:
  match x:
    case TxListLevel{items, rest}:
      rest

type TxLineKind is Data:
  TxLineKind{blank: Bool, sig: Maybe<&2, TxBlockSig>, item: Maybe<&2, TxRawItem>,
    table: Bool, escape: Bool}

def tx_linekind_blank(x: TxLineKind) -> Bool:
  match x:
    case TxLineKind{blank, sig, item, table, escape}:
      blank

def tx_linekind_sig(x: TxLineKind) -> Maybe<&2, TxBlockSig>:
  match x:
    case TxLineKind{blank, sig, item, table, escape}:
      sig

def tx_linekind_item(x: TxLineKind) -> Maybe<&2, TxRawItem>:
  match x:
    case TxLineKind{blank, sig, item, table, escape}:
      item

def tx_linekind_table(x: TxLineKind) -> Bool:
  match x:
    case TxLineKind{blank, sig, item, table, escape}:
      table

def tx_linekind_escape(x: TxLineKind) -> Bool:
  match x:
    case TxLineKind{blank, sig, item, table, escape}:
      escape

# String and position utilities.
def tx_pos_add(+p: U32, n: Nat) -> U32:
  U32.add(p, U32.from_nat(n))

def tx_pos_add_text(+p: U32, +s: String) -> U32:
  tx_pos_add(p, Text.utf8_length(s))

def tx_span_text(+start: U32, +text: String) -> Ast.Span:
  Ast.Span{start, tx_pos_add_text(start, text)}

def tx_char_string(+c: Char) -> String:
  SCon{c, SNil{}}

def tx_repeat_char(+c: Char, n: Nat) -> String:
  String.repeat(tx_char_string(c), n)

def tx_count_prefix(s: String, +c: Char, +acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      tx_if(Nat, Char.is_eq(h, c),
        u => tx_count_prefix(t, c, 1n+acc),
        u => acc)

def tx_find_sub_index(+s: String, +needle: String, +idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      tx_if(Maybe<&2, Nat>, String.is_empty(needle),
        u => Some{idx},
        u => None{})
    case SCon{h, +t}:
      tx_if(Maybe<&2, Nat>, String.starts_with(s, needle),
        u => Some{idx},
        u => tx_find_sub_index(t, needle, 1n+idx))

def tx_split_at_index(+s: String, +idx: Nat, +width: Nat) -> TxStrSplit:
  TxStrSplit{String.take(s, idx), String.drop(s, Nat.add(idx, width))}

def tx_split_at_maybe(+s: String, +needle: String, m: Maybe<&2, Nat>) -> Maybe<&2, TxStrSplit>:
  match m:
    case Some{idx}:
      Some{tx_split_at_index(s, idx, String.length(needle))}
    case None{}:
      None{}

# Split at the first occurrence of needle.  `before` excludes it and `after`
# starts immediately after it.
def tx_find_split(+s: String, +needle: String) -> Maybe<&2, TxStrSplit>:
  tx_split_at_maybe(s, needle, tx_find_sub_index(s, needle, 0n))

def tx_reverse_strings(xs: List<&2, String>) -> List<&2, String>:
  List.reverse(&2, String, xs)

def tx_space_char(+c: Char) -> Bool:
  Char.is_eq(c, ' ') || Char.is_eq(c, '\t') || Char.is_eq(c, '\n') || Char.is_eq(c, '\r')

# ASCII punctuation is exact.  For non-ASCII text we treat the common Unicode
# punctuation blocks as boundaries and other non-ASCII code points as letters;
# this keeps é/cjk intraword cases literal while curly quotes and CJK
# punctuation still act as punctuation boundaries.
def tx_unicode_punctuation(+c: Char) -> Bool:
  +x = Char.to_u32(c)
  (x >= 8192 : U32) && (x <= 8303 : U32) ||
    (x >= 12288 : U32) && (x <= 12351 : U32)

def tx_boundary_char(+c: Char) -> Bool:
  tx_space_char(c) || Text.ascii_punctuation(c) || tx_unicode_punctuation(c)

def tx_boundary_at(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      tx_boundary_char(h)

def tx_nonspace_at(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{h, t}:
      Bool.not(tx_space_char(h))

def tx_boundary_after_text(s: String, acc: Bool) -> Bool:
  match s:
    case SNil{}:
      acc
    case SCon{h, t}:
      tx_boundary_after_text(t, tx_boundary_char(h))

def tx_is_phrase_char(+c: Char) -> Bool:
  Char.is_eq(c, '_') || Char.is_eq(c, '*') || Char.is_eq(c, '-') ||
    Char.is_eq(c, '+') || Char.is_eq(c, '^') || Char.is_eq(c, '~') ||
    Char.is_eq(c, '%')

def tx_is_special_inline(+c: Char) -> Bool:
  Char.is_eq(c, '@') || Char.is_eq(c, '"') || Char.is_eq(c, '!') ||
    Char.is_eq(c, '=') || Char.is_eq(c, '\n') || tx_is_phrase_char(c)

def tx_plain_index(s: String, +idx: Nat) -> Nat:
  match s:
    case SNil{}:
      idx
    case SCon{h, t}:
      tx_if(Nat, tx_is_special_inline(h),
        u => idx,
        u => tx_plain_index(t, 1n+idx))

def tx_text_node(+text: String, +pos: U32) -> List<&2, Ast.Inline>:
  tx_if(List<&2, Ast.Inline>, String.is_empty(text),
    u => Nil{},
    u => Ast.IText{text, tx_span_text(pos, text)} <> Nil{})

# Scan for a delimiter run that is exactly `width` long, has non-whitespace
# immediately before it, and has a boundary (or end) immediately after it.
# A valid inner opening run increments `depth`, so nested uses of the same
# phrase delimiter are retained for the recursive inline parser instead of
# accidentally closing the outer phrase.  Longer runs are opaque literal text;
# consuming the whole run prevents a suffix of an over-long run from being
# reinterpreted as a valid delimiter.
def tx_scan_close(fuel: Nat, +s: String, +delim: String, +width: Nat,
    +acc: String, +depth: Nat, +prev_space: Bool, +prev_boundary: Bool) -> Maybe<&2, TxStrSplit>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{+h, +t}:
          tx_if(Maybe<&2, TxStrSplit>, String.starts_with(s, delim),
            u =>
              +run = tx_count_prefix(s, h, 0n)
              +exact = Nat.is_eq(run, width)
              +after_run = String.drop(s, run)
              +close_valid = exact && Bool.not(prev_space) && tx_boundary_at(after_run)
              +open_valid = exact && prev_boundary && tx_nonspace_at(after_run)
              +runtext = String.take(s, run)
              +acc2 = String.reverse(runtext) ++ acc
              tx_if(Maybe<&2, TxStrSplit>, close_valid,
                v => tx_if(Maybe<&2, TxStrSplit>, Nat.is_eq(depth, 0n),
                  w => Some{TxStrSplit{String.reverse(acc), after_run}},
                  w => tx_scan_close(f, after_run, delim, width, acc2, Nat.sub(depth, 1n), False{}, True{})),
                v => tx_if(Maybe<&2, TxStrSplit>, open_valid,
                  w => tx_scan_close(f, after_run, delim, width, acc2, 1n+depth, False{}, True{}),
                  w => tx_scan_close(f, after_run, delim, width, acc2, depth, False{}, True{}))),
            u => tx_scan_close(f, t, delim, width, SCon{h, acc}, depth,
              tx_space_char(h), tx_boundary_char(h)))

def tx_scan_close_top(+s: String, +delim: String, +width: Nat) -> Maybe<&2, TxStrSplit>:
  tx_scan_close(Nat.add(String.length(s), 1n), s, delim, width, SNil{}, 0n, False{}, True{})

# URL scanning: read to whitespace or a closing bracket, then trim trailing
# sentence punctuation back into the input stream.
def tx_url_scan(s: String, acc: String) -> TxStrSplit:
  match s:
    case SNil{}:
      TxStrSplit{String.reverse(acc), SNil{}}
    case SCon{' ', t}:
      TxStrSplit{String.reverse(acc), SCon{' ', t}}
    case SCon{'\t', t}:
      TxStrSplit{String.reverse(acc), SCon{'\t', t}}
    case SCon{'\n', t}:
      TxStrSplit{String.reverse(acc), SCon{'\n', t}}
    case SCon{')', t}:
      TxStrSplit{String.reverse(acc), SCon{')', t}}
    case SCon{']', t}:
      TxStrSplit{String.reverse(acc), SCon{']', t}}
    case SCon{'}', t}:
      TxStrSplit{String.reverse(acc), SCon{'}', t}}
    case SCon{h, t}:
      tx_url_scan(t, SCon{h, acc})

def tx_url_clean_len(s: String, +n: Nat, +last: Nat) -> Nat:
  match s:
    case SNil{}:
      last
    case SCon{'.', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{',', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{';', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{':', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{'!', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{'?', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{'"', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{'\'', t}:
      tx_url_clean_len(t, 1n+n, last)
    case SCon{h, t}:
      tx_url_clean_len(t, 1n+n, 1n+n)

def tx_read_url_finish(+raw: String, +after: String, +clean: Nat) -> Maybe<&2, TxStrSplit>:
  +url = String.take(raw, clean)
  +leftover = String.drop(raw, clean)
  tx_if(Maybe<&2, TxStrSplit>, Nat.is_gt(clean, 0n),
    u => Some{TxStrSplit{url, leftover ++ after}},
    u => None{})

def tx_read_url(+s: String) -> Maybe<&2, TxStrSplit>:
  +parts = tx_url_scan(s, SNil{})
  +raw = tx_str_before(parts)
  +after = tx_str_after(parts)
  tx_read_url_finish(raw, after, tx_url_clean_len(raw, 0n, 0n))

# Split a link label's documented trailing title form: "text (title)".
def tx_split_link_label_rev(+label: String, +rev: String) -> TxLinkLabel:
  +after_close = String.drop(rev, 1n)
  tx_maybe_case(TxStrSplit, TxLinkLabel, tx_find_split(after_close, "("),
    +hit =>
      +title = String.reverse(tx_str_before(hit))
      +after_open = tx_str_after(hit)
      tx_if(TxLinkLabel, String.starts_with(after_open, " "),
        u =>
          +display = String.reverse(String.drop(after_open, 1n))
          tx_if(TxLinkLabel, String.is_empty(display),
            v => TxLinkLabel{label, None{}},
            v => TxLinkLabel{display, Some{title}}),
        u => TxLinkLabel{label, None{}}),
    u => TxLinkLabel{label, None{}})

def tx_split_link_label(+label: String) -> TxLinkLabel:
  +rev = String.reverse(label)
  tx_if(TxLinkLabel, String.starts_with(rev, ")"),
    u => tx_split_link_label_rev(label, rev),
    u => TxLinkLabel{label, None{}})

def tx_drop_trailing_char(+s: String, +c: Char) -> Maybe<&2, String>:
  +rev = String.reverse(s)
  tx_maybe_case(Char, Maybe<&2, String>, String.get(rev, 0n),
    +h =>
      tx_if(Maybe<&2, String>, Char.is_eq(h, c),
        u => Some{String.reverse(String.drop(rev, 1n))},
        u => None{}),
    u => None{})

# Image internals: both url(alt) and url (alt) are recognized.  The alt is
# also the title, matching the documented Textile behavior.
def tx_image_parts_finish(+inner: String, +src0: String, +altplus: String) -> TxImageParts:
  +src = String.trim_end(src0)
  tx_maybe_case(String, TxImageParts, tx_drop_trailing_char(altplus, ')'),
    +alt =>
      tx_if(TxImageParts, String.is_empty(src) || String.is_empty(alt),
        u => TxImageParts{inner, "", None{}},
        u => TxImageParts{src, alt, Some{alt}}),
    u => TxImageParts{inner, "", None{}})

def tx_image_parts(+inner: String) -> TxImageParts:
  tx_maybe_case(TxStrSplit, TxImageParts, tx_find_split(inner, "("),
    +hit => tx_image_parts_finish(inner, tx_str_before(hit), tx_str_after(hit)),
    u => TxImageParts{inner, "", None{}})

def tx_read_image_link(+rest: String) -> Maybe<&2, TxStrSplit>:
  tx_if(Maybe<&2, TxStrSplit>, String.starts_with(rest, ":"),
    u => tx_read_url(String.drop(rest, 1n)),
    u => None{})

# Phrase operator kinds: 1 strong, 2 bold, 3 emphasis, 4 italic, 5 deleted,
# 6 inserted, 7 superscript, 8 subscript, 9 span.
def tx_phrase_kind(+c: Char, +run: Nat) -> Nat:
  match c:
    case '*':
      match run:
        case 1n:
          1n
        case 2n:
          2n
        case _:
          0n
    case '_':
      match run:
        case 1n:
          3n
        case 2n:
          4n
        case _:
          0n
    case '-':
      match run:
        case 1n:
          5n
        case _:
          0n
    case '+':
      match run:
        case 1n:
          6n
        case _:
          0n
    case '^':
      match run:
        case 1n:
          7n
        case _:
          0n
    case '~':
      match run:
        case 1n:
          8n
        case _:
          0n
    case '%':
      match run:
        case 1n:
          9n
        case _:
          0n
    case _:
      0n

def tx_phrase_node(+kind: Nat, children: List<&2, Ast.Inline>, span: Ast.Span) -> Ast.Inline:
  match kind:
    case 1n:
      Ast.IStrong{children, span}
    case 2n:
      Ast.IBold{children, span}
    case 3n:
      Ast.IEmph{children, span}
    case 4n:
      Ast.IItalic{children, span}
    case 5n:
      Ast.IDeleted{children, span}
    case 6n:
      Ast.IInserted{children, span}
    case 7n:
      Ast.ISuperscript{children, span}
    case 8n:
      Ast.ISubscript{children, span}
    case _:
      Ast.ISpan{children, Nil{}, span}

# Inline scanner.  Nested content and the continuation both recurse on the
# predecessor of the same fuel.  Malformed constructs always consume input as
# literal text, so no input can make the scanner fail or loop.
def tx_parse_inlines(fuel: Nat, +s: String, +pos: U32, +boundary: Bool) -> List<&2, Ast.Inline>:
  match fuel:
    case 0n:
      tx_text_node(s, pos)
    case 1n++f:
      match s:
        case SNil{}:
          Nil{}
        case SCon{'\n', +t}:
          +endpos = tx_pos_add(pos, 1n)
          Ast.IHardBreak{Ast.Span{pos, endpos}} <> tx_parse_inlines(f, t, endpos, True{})
        case SCon{'@', +t}:
          +delimiter = {"@" : String}
          +after_open = t
          +open_ok = boundary && tx_nonspace_at(after_open)
          tx_if(List<&2, Ast.Inline>, open_ok,
            u =>
              tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_scan_close_top(after_open, delimiter, 1n),
                +hit =>
                  +content = tx_str_before(hit)
                  +rest = tx_str_after(hit)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = tx_pos_add(pos, used)
                  tx_if(List<&2, Ast.Inline>, String.is_empty(content),
                    v => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                      tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{}),
                    v => Ast.ICode{content, Ast.Span{pos, endpos}} <>
                      tx_parse_inlines(f, rest, endpos, True{})),
                u => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                  tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{})),
            u => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
              tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{}))
        case SCon{'"', +t}:
          tx_if(List<&2, Ast.Inline>, boundary,
            u =>
              tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_find_split(t, "\""),
                +hit =>
                  +label = tx_str_before(hit)
                  +after_quote = tx_str_after(hit)
                  tx_if(List<&2, Ast.Inline>, String.starts_with(after_quote, ":"),
                    v =>
                      +after_colon = String.drop(after_quote, 1n)
                      tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_read_url(after_colon),
                        +urlhit =>
                          +href = tx_str_before(urlhit)
                          +rest = tx_str_after(urlhit)
                          +labelparts = tx_split_link_label(label)
                          +display = tx_link_label_display(labelparts)
                          +title = tx_link_label_title(labelparts)
                          tx_if(List<&2, Ast.Inline>, String.is_empty(display),
                            w => Ast.IText{"\"", tx_span_text(pos, "\"")} <>
                              tx_parse_inlines(f, t, tx_pos_add_text(pos, "\""), True{}),
                            w =>
                              +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                              +endpos = tx_pos_add(pos, used)
                              +labelpos = tx_pos_add(pos, 1n)
                              Ast.ILink{Ast.IText{display, tx_span_text(labelpos, display)} <> Nil{},
                                href, title, Ast.Span{pos, endpos}, None{}} <>
                                tx_parse_inlines(f, rest, endpos, False{})),
                        v => Ast.IText{"\"", tx_span_text(pos, "\"")} <>
                          tx_parse_inlines(f, t, tx_pos_add_text(pos, "\""), True{})),
                    v => Ast.IText{"\"", tx_span_text(pos, "\"")} <>
                      tx_parse_inlines(f, t, tx_pos_add_text(pos, "\""), True{})),
                u => Ast.IText{"\"", tx_span_text(pos, "\"")} <>
                  tx_parse_inlines(f, t, tx_pos_add_text(pos, "\""), True{})),
            u => Ast.IText{"\"", tx_span_text(pos, "\"")} <>
              tx_parse_inlines(f, t, tx_pos_add_text(pos, "\""), True{}))
        case SCon{'!', +t}:
          tx_if(List<&2, Ast.Inline>, boundary && tx_nonspace_at(t),
            u =>
              tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_scan_close_top(t, "!", 1n),
                +hit =>
                  +inner = tx_str_before(hit)
                  +after_close = tx_str_after(hit)
                  +parts = tx_image_parts(inner)
                  +src = tx_image_parts_src(parts)
                  +alt = tx_image_parts_alt(parts)
                  +title = tx_image_parts_title(parts)
                  tx_if(List<&2, Ast.Inline>, String.is_empty(inner) || String.is_empty(src),
                    v => Ast.IText{"!", tx_span_text(pos, "!")} <>
                      tx_parse_inlines(f, t, tx_pos_add_text(pos, "!"), True{}),
                    v =>
                      tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_read_image_link(after_close),
                        +urlhit =>
                          +href = tx_str_before(urlhit)
                          +rest = tx_str_after(urlhit)
                          +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                          +endpos = tx_pos_add(pos, used)
                          +image_used = Nat.sub(Text.utf8_length(s), Text.utf8_length(after_close))
                          +image_endpos = tx_pos_add(pos, image_used)
                          Ast.ILink{Ast.IImage{src, alt, title, Ast.Span{pos, image_endpos}, None{}} <> Nil{},
                            href, None{}, Ast.Span{pos, endpos}, None{}} <>
                            tx_parse_inlines(f, rest, endpos, False{}),
                        v =>
                          +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(after_close))
                          +endpos = tx_pos_add(pos, used)
                          Ast.IImage{src, alt, title, Ast.Span{pos, endpos}, None{}} <>
                            tx_parse_inlines(f, after_close, endpos, True{}))),
                u => Ast.IText{"!", tx_span_text(pos, "!")} <>
                  tx_parse_inlines(f, t, tx_pos_add_text(pos, "!"), True{})),
            u => Ast.IText{"!", tx_span_text(pos, "!")} <>
              tx_parse_inlines(f, t, tx_pos_add_text(pos, "!"), True{}))
        case SCon{'=', SCon{'=', +tt}}:
          +delimiter = {"==" : String}
          +after_open = String.drop(s, 2n)
          +open_ok = boundary && tx_nonspace_at(after_open)
          tx_if(List<&2, Ast.Inline>, open_ok,
            u =>
              tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_scan_close_top(after_open, delimiter, 2n),
                +hit =>
                  +content = tx_str_before(hit)
                  +rest = tx_str_after(hit)
                  +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                  +endpos = tx_pos_add(pos, used)
                  tx_if(List<&2, Ast.Inline>, String.is_empty(content),
                    v => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                      tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{}),
                    v => Ast.IText{content, tx_span_text(tx_pos_add(pos, 2n), content)} <>
                      tx_parse_inlines(f, rest, endpos, True{})),
                u => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                  tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{})),
            u => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
              tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{}))
        case SCon{+h, +t}:
          tx_if(List<&2, Ast.Inline>, tx_is_phrase_char(h),
            u =>
              +run = tx_count_prefix(s, h, 0n)
              +kind = tx_phrase_kind(h, run)
              +delimiter = tx_repeat_char(h, run)
              +after_open = String.drop(s, run)
              +open_ok = Nat.is_gt(kind, 0n) && boundary && tx_nonspace_at(after_open)
              tx_if(List<&2, Ast.Inline>, open_ok,
                v =>
                  tx_maybe_case(TxStrSplit, List<&2, Ast.Inline>, tx_scan_close_top(after_open, delimiter, run),
                    +hit =>
                      +content = tx_str_before(hit)
                      +rest = tx_str_after(hit)
                      +used = Nat.sub(Text.utf8_length(s), Text.utf8_length(rest))
                      +endpos = tx_pos_add(pos, used)
                      tx_if(List<&2, Ast.Inline>, String.is_empty(content),
                        w => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                          tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{}),
                        w =>
                          +content_start = tx_pos_add(pos, run)
                          +inner = tx_parse_inlines(f, content, content_start, True{})
                          tx_phrase_node(kind, inner, Ast.Span{pos, endpos}) <>
                            tx_parse_inlines(f, rest, endpos, True{})),
                    u2 => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                      tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{})),
                v => Ast.IText{delimiter, tx_span_text(pos, delimiter)} <>
                  tx_parse_inlines(f, after_open, tx_pos_add_text(pos, delimiter), True{})),
            u =>
              +n = tx_plain_index(s, 0n)
              tx_if(List<&2, Ast.Inline>, Nat.is_eq(n, 0n),
                v =>
                  +one = tx_char_string(h)
                  Ast.IText{one, tx_span_text(pos, one)} <>
                    tx_parse_inlines(f, t, tx_pos_add_text(pos, one), tx_boundary_char(h)),
                v =>
                  +plain = String.take(s, n)
                  +rest = String.drop(s, n)
                  +endpos = tx_pos_add_text(pos, plain)
                  Ast.IText{plain, Ast.Span{pos, endpos}} <>
                    tx_parse_inlines(f, rest, endpos, tx_boundary_after_text(plain, boundary))))

def tx_parse_inlines_top(+s: String, +pos: U32) -> List<&2, Ast.Inline>:
  +len = Text.utf8_length(s)
  +fuel = Nat.add(Nat.mul(8n, len), 8n)
  tx_parse_inlines(fuel, s, pos, True{})

# Block attributes and signatures.
type TxMods is Data:
  TxMods{style: Maybe<&2, String>, class_name: Maybe<&2, String>,
    id: Maybe<&2, String>, lang: Maybe<&2, String>, align: Maybe<&2, String>,
    pad_left: Nat, pad_right: Nat}

def tx_mods_empty() -> TxMods:
  TxMods{None{}, None{}, None{}, None{}, None{}, 0n, 0n}

def tx_nonempty_string(+s: String) -> Maybe<&2, String>:
  tx_if(Maybe<&2, String>, String.is_empty(s),
    u => None{},
    u => Some{s})

def tx_mods_set_style(m: TxMods, +v: String) -> TxMods:
  TxMods{style, class_name, id, lang, align, pad_left, pad_right} = m
  TxMods{Some{v}, class_name, id, lang, align, pad_left, pad_right}

def tx_mods_set_lang(m: TxMods, +v: String) -> TxMods:
  TxMods{style, class_name, id, lang, align, pad_left, pad_right} = m
  TxMods{style, class_name, id, tx_nonempty_string(v), align, pad_left, pad_right}

def tx_mods_set_align(m: TxMods, +v: String) -> TxMods:
  TxMods{style, class_name, id, lang, align, pad_left, pad_right} = m
  TxMods{style, class_name, id, lang, Some{v}, pad_left, pad_right}

def tx_mods_pad_left(m: TxMods) -> TxMods:
  TxMods{style, class_name, id, lang, align, pad_left, pad_right} = m
  TxMods{style, class_name, id, lang, align, 1n+pad_left, pad_right}

def tx_mods_pad_right(m: TxMods) -> TxMods:
  TxMods{style, class_name, id, lang, align, pad_left, pad_right} = m
  TxMods{style, class_name, id, lang, align, pad_left, 1n+pad_right}

def tx_mods_set_class(m: TxMods, +v: String) -> TxMods:
  TxMods{+style, +class_name, +id, +lang, +align, +pad_left, +pad_right} = m
  tx_maybe_case(TxStrSplit, TxMods, tx_find_split(v, "#"),
    +hit =>
      TxMods{style, tx_nonempty_string(tx_str_before(hit)),
        tx_nonempty_string(tx_str_after(hit)), lang, align, pad_left, pad_right},
    u => TxMods{style, tx_nonempty_string(v), id, lang, align, pad_left, pad_right})

# Textile style attributes are serialized with one inserted space after each
# non-final semicolon.  Existing whitespace is retained, so a semicolon already
# followed by a space intentionally produces two spaces, matching the oracle's
# byte-level normalization rule.
def tx_style_semicolon_space(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{';', +t}:
      tx_if(String, String.is_empty(t),
        u => SCon{';', SNil{}},
        u => SCon{';', SCon{' ', tx_style_semicolon_space(t)}})
    case SCon{h, t}:
      SCon{h, tx_style_semicolon_space(t)}

def tx_style_normalize(+s: String) -> String:
  +spaced = tx_style_semicolon_space(s)
  tx_if(String, String.ends_with(spaced, ";"),
    u => spaced,
    u => spaced ++ ";")

def tx_style_append(+acc: String, +part: String) -> String:
  tx_if(String, String.is_empty(acc),
    u => part ++ ";",
    u => acc ++ " " ++ part ++ ";")

def tx_mods_style_base(m: Maybe<&2, String>) -> String:
  tx_maybe_case(String, String, m,
    +x => tx_style_normalize(x),
    u => "")

def tx_mods_style_value(m: TxMods) -> Maybe<&2, String>:
  TxMods{+style, class_name, id, lang, +align, +pad_left, +pad_right} = m
  +base = tx_mods_style_base(style)
  +with_left = tx_if(String, Nat.is_gt(pad_left, 0n),
    u => tx_style_append(base, "padding-left:" ++ Nat.show(pad_left) ++ "em"),
    u => base)
  +with_right = tx_if(String, Nat.is_gt(pad_right, 0n),
    u => tx_style_append(with_left, "padding-right:" ++ Nat.show(pad_right) ++ "em"),
    u => with_left)
  +with_align = tx_maybe_case(String, String, align,
    +a => tx_style_append(with_right, "text-align:" ++ a),
    u => with_right)
  tx_if(Maybe<&2, String>, String.is_empty(with_align),
    u => None{},
    u => Some{with_align})

def tx_maybe_attr_append(+key: String, m: Maybe<&2, String>, +attrs: List<&2, Ast.Attr>) -> List<&2, Ast.Attr>:
  tx_maybe_case(String, List<&2, Ast.Attr>, m,
    +v => List.append(&2, Ast.Attr, attrs, Ast.Attr{key, v} <> Nil{}),
    u => attrs)

def tx_attrs_from_mods(m: TxMods) -> List<&2, Ast.Attr>:
  TxMods{+style, +class_name, +id, +lang, align, pad_left, pad_right} = m
  +style_value = tx_mods_style_value(TxMods{style, class_name, id, lang, align, pad_left, pad_right})
  +a0 = {Nil{} : List<&2, Ast.Attr>}
  +a1 = tx_maybe_attr_append("style", style_value, a0)
  +a2 = tx_maybe_attr_append("class", class_name, a1)
  +a3 = tx_maybe_attr_append("id", id, a2)
  tx_maybe_attr_append("lang", lang, a3)

type TxSigTail is Data:
  TxSigTail{attrs: List<&2, Ast.Attr>, text: String}

def tx_sig_tail_attrs(x: TxSigTail) -> List<&2, Ast.Attr>:
  match x:
    case TxSigTail{attrs, text}:
      attrs

def tx_sig_tail_text(x: TxSigTail) -> String:
  match x:
    case TxSigTail{attrs, text}:
      text

def tx_mods_terminator(+s: String) -> Maybe<&2, String>:
  tx_if(Maybe<&2, String>, String.starts_with(s, ". "),
    u => Some{String.drop(s, 2n)},
    u => tx_if(Maybe<&2, String>, String.starts_with(s, ".\t"),
      v => Some{String.drop(s, 2n)},
      v => None{}))

def tx_paren_is_padding(s: String) -> Bool:
  match s:
    case SCon{'.', t}:
      True{}
    case SCon{'(', t}:
      True{}
    case SCon{')', t}:
      True{}
    case _:
      False{}

# Parse modifiers between a block marker and its period.  A malformed token
# rejects the whole signature, causing the line to degrade to a paragraph.
def tx_parse_mods(fuel: Nat, +s: String, +mods: TxMods) -> Maybe<&2, TxSigTail>:
  match fuel:
    case 0n:
      None{}
    case 1n++f:
      match s:
        case SNil{}:
          None{}
        case SCon{'.', SCon{' ', +text}}:
          Some{TxSigTail{tx_attrs_from_mods(mods), text}}
        case SCon{'.', SCon{'\t', +text}}:
          Some{TxSigTail{tx_attrs_from_mods(mods), text}}
        case SCon{'{', +t}:
          tx_maybe_case(TxStrSplit, Maybe<&2, TxSigTail>, tx_find_split(t, "}"),
            +hit => tx_parse_mods(f, tx_str_after(hit), tx_mods_set_style(mods, tx_str_before(hit))),
            v => None{})
        case SCon{'(', +t}:
          tx_if(Maybe<&2, TxSigTail>, tx_paren_is_padding(t),
            v => tx_parse_mods(f, t, tx_mods_pad_left(mods)),
            v =>
              tx_maybe_case(TxStrSplit, Maybe<&2, TxSigTail>, tx_find_split(t, ")"),
                +hit => tx_parse_mods(f, tx_str_after(hit), tx_mods_set_class(mods, tx_str_before(hit))),
                w => None{}))
        case SCon{')', +t}:
          tx_parse_mods(f, t, tx_mods_pad_right(mods))
        case SCon{'[', +t}:
          tx_maybe_case(TxStrSplit, Maybe<&2, TxSigTail>, tx_find_split(t, "]"),
            +hit => tx_parse_mods(f, tx_str_after(hit), tx_mods_set_lang(mods, tx_str_before(hit))),
            v => None{})
        case SCon{'<', +t}:
          tx_if(Maybe<&2, TxSigTail>, String.starts_with(s, "<>"),
            v => tx_parse_mods(f, String.drop(s, 2n), tx_mods_set_align(mods, "justify")),
            v => tx_parse_mods(f, t, tx_mods_set_align(mods, "left")))
        case SCon{'>', +t}:
          tx_parse_mods(f, t, tx_mods_set_align(mods, "right"))
        case SCon{'=', +t}:
          tx_parse_mods(f, t, tx_mods_set_align(mods, "center"))
        case SCon{h, t}:
          None{}

def tx_parse_mods_top(+s: String) -> Maybe<&2, TxSigTail>:
  tx_parse_mods(Nat.add(String.length(s), 1n), s, tx_mods_empty())

def tx_sig_finish(+kind: Nat, +level: U32, m: Maybe<&2, TxSigTail>) -> Maybe<&2, TxBlockSig>:
  tx_maybe_case(TxSigTail, Maybe<&2, TxBlockSig>, m,
    +tail =>
      +attrs = tx_sig_tail_attrs(tail)
      +text = tx_sig_tail_text(tail)
      tx_if(Maybe<&2, TxBlockSig>, Text.blank_line(text),
        u => None{},
        u => Some{TxBlockSig{kind, level, attrs, text}}),
    u => None{})

def tx_sig_paragraph(+tail: String) -> Maybe<&2, TxBlockSig>:
  tx_sig_finish(1n, 0, tx_parse_mods_top(tail))

def tx_sig_heading(+level: U32, +tail: String) -> Maybe<&2, TxBlockSig>:
  tx_sig_finish(2n, level, tx_parse_mods_top(tail))

def tx_sig_quote(+tail: String) -> Maybe<&2, TxBlockSig>:
  tx_sig_finish(3n, 0, tx_parse_mods_top(tail))

def tx_parse_sig_h(s: String) -> Maybe<&2, TxBlockSig>:
  match s:
    case SCon{'1', t}:
      tx_sig_heading(1, t)
    case SCon{'2', t}:
      tx_sig_heading(2, t)
    case SCon{'3', t}:
      tx_sig_heading(3, t)
    case SCon{'4', t}:
      tx_sig_heading(4, t)
    case SCon{'5', t}:
      tx_sig_heading(5, t)
    case SCon{'6', t}:
      tx_sig_heading(6, t)
    case _:
      None{}

def tx_parse_signature(+line: String) -> Maybe<&2, TxBlockSig>:
  match line:
    case SCon{'h', t}:
      tx_parse_sig_h(t)
    case SCon{'p', t}:
      tx_sig_paragraph(t)
    case SCon{'b', SCon{'q', t}}:
      tx_sig_quote(t)
    case _:
      None{}

# List markers: a homogeneous run of * or # followed by one space or tab.
def tx_drop_one_space(s: String) -> Maybe<&2, String>:
  match s:
    case SCon{' ', t}:
      Some{t}
    case SCon{'\t', t}:
      Some{t}
    case _:
      None{}

def tx_list_marker_for(+line: String, +c: Char, ordered: Bool) -> Maybe<&2, TxRawItem>:
  +run = tx_count_prefix(line, c, 0n)
  +after = String.drop(line, run)
  tx_maybe_case(String, Maybe<&2, TxRawItem>, tx_drop_one_space(after),
    +text =>
      tx_if(Maybe<&2, TxRawItem>, Text.blank_line(text),
        u => None{},
        u => Some{TxRawItem{run, ordered, text, line}}),
    u => None{})

def tx_parse_list_marker(+line: String) -> Maybe<&2, TxRawItem>:
  match line:
    case SCon{'*', t}:
      tx_list_marker_for(line, '*', False{})
    case SCon{'#', t}:
      tx_list_marker_for(line, '#', True{})
    case _:
      None{}

def tx_is_table_row(+line: String) -> Bool:
  String.starts_with(line, "|") && String.ends_with(line, "|") &&
    Nat.is_ge(String.length(line), 2n)

def tx_sig_present(m: Maybe<&2, TxBlockSig>) -> Bool:
  tx_maybe_case(TxBlockSig, Bool, m,
    x => True{},
    u => False{})

def tx_item_present(m: Maybe<&2, TxRawItem>) -> Bool:
  tx_maybe_case(TxRawItem, Bool, m,
    x => True{},
    u => False{})

def tx_line_kind(+line: String) -> TxLineKind:
  tx_if(TxLineKind, Text.blank_line(line),
    u => TxLineKind{True{}, None{}, None{}, False{}, False{}},
    u =>
      tx_maybe_case(TxBlockSig, TxLineKind, tx_parse_signature(line),
        +sig => TxLineKind{False{}, Some{sig}, None{}, False{}, False{}},
        v =>
          tx_maybe_case(TxRawItem, TxLineKind, tx_parse_list_marker(line),
            +item => TxLineKind{False{}, None{}, Some{item}, False{}, False{}},
            w => TxLineKind{False{}, None{}, None{}, tx_is_table_row(line),
              String.eq(line, "==")})))

def tx_kind_is_plain(k: TxLineKind) -> Bool:
  TxLineKind{+blank, +sig, +item, +table, +escape} = k
  Bool.not(blank || tx_sig_present(sig) || tx_item_present(item) || table || escape)

# Collect continuation lines that classify as plain.  The returned `taken`
# list is in source order and `rest` still contains the first non-plain line.
def tx_collect_plain(fuel: Nat, +lines: List<&2, String>, +acc: List<&2, String>) -> TxLineSplit:
  match fuel:
    case 0n:
      TxLineSplit{tx_reverse_strings(acc), lines}
    case 1n++f:
      match lines:
        case Nil{}:
          TxLineSplit{tx_reverse_strings(acc), Nil{}}
        case +h <> +t:
          tx_if(TxLineSplit, tx_kind_is_plain(tx_line_kind(h)),
            u => tx_collect_plain(f, t, h <> acc),
            u => TxLineSplit{tx_reverse_strings(acc), h <> t})

def tx_collect_escape(fuel: Nat, +lines: List<&2, String>, +acc: List<&2, String>) -> TxEscapeSplit:
  match fuel:
    case 0n:
      TxEscapeSplit{tx_reverse_strings(acc), lines, False{}}
    case 1n++f:
      match lines:
        case Nil{}:
          TxEscapeSplit{tx_reverse_strings(acc), Nil{}, False{}}
        case +h <> +t:
          tx_if(TxEscapeSplit, String.eq(h, "=="),
            u => TxEscapeSplit{tx_reverse_strings(acc), t, True{}},
            u => tx_collect_escape(f, t, h <> acc))

def tx_collect_table(fuel: Nat, +lines: List<&2, String>, +acc: List<&2, String>) -> TxLineSplit:
  match fuel:
    case 0n:
      TxLineSplit{tx_reverse_strings(acc), lines}
    case 1n++f:
      match lines:
        case Nil{}:
          TxLineSplit{tx_reverse_strings(acc), Nil{}}
        case +h <> +t:
          tx_if(TxLineSplit, tx_is_table_row(h),
            u => tx_collect_table(f, t, h <> acc),
            u => TxLineSplit{tx_reverse_strings(acc), h <> t})

def tx_reverse_items(xs: List<&2, TxRawItem>) -> List<&2, TxRawItem>:
  List.reverse(&2, TxRawItem, xs)

def tx_collect_list(fuel: Nat, +lines: List<&2, String>, +acc: List<&2, TxRawItem>) -> TxItemsSplit:
  match fuel:
    case 0n:
      TxItemsSplit{tx_reverse_items(acc), lines}
    case 1n++f:
      match lines:
        case Nil{}:
          TxItemsSplit{tx_reverse_items(acc), Nil{}}
        case +h <> +t:
          tx_maybe_case(TxRawItem, TxItemsSplit, tx_parse_list_marker(h),
            +item => tx_collect_list(f, t, item <> acc),
            u => TxItemsSplit{tx_reverse_items(acc), h <> t})

# Tables: simple pipe rows, with the documented `_. ` header-cell marker.
def tx_table_cell_strings(+line: String) -> List<&2, String>:
  +parts = String.split(line, '|')
  +no_first = List.drop(&2, String, parts, 1n)
  +rev = List.reverse(&2, String, no_first)
  +no_last_rev = List.drop(&2, String, rev, 1n)
  List.reverse(&2, String, no_last_rev)

type TxCellParts is Data:
  TxCellParts{header: Bool, content: String}

def tx_cell_parts_header(x: TxCellParts) -> Bool:
  match x:
    case TxCellParts{header, content}:
      header

def tx_cell_parts_content(x: TxCellParts) -> String:
  match x:
    case TxCellParts{header, content}:
      content

def tx_cell_parts(+cell: String) -> TxCellParts:
  tx_if(TxCellParts, String.starts_with(cell, "_. "),
    u => TxCellParts{True{}, String.drop(cell, 3n)},
    u => TxCellParts{False{}, cell})

def tx_parse_table_cells(xs: List<&2, String>, +acc: List<&2, Ast.TableCell>) -> List<&2, Ast.TableCell>:
  match xs:
    case Nil{}:
      List.reverse(&2, Ast.TableCell, acc)
    case +h <> +t:
      +parts = tx_cell_parts(h)
      +header = tx_cell_parts_header(parts)
      +content = tx_cell_parts_content(parts)
      tx_parse_table_cells(t, Ast.TableCell{header, Ast.AlignNone{}, 1, 1,
        tx_parse_inlines_top(content, 0), Nil{}, Ast.span_empty()} <> acc)

def tx_parse_table_row(+line: String) -> Ast.TableRow:
  Ast.TableRow{tx_parse_table_cells(tx_table_cell_strings(line), Nil{}), Nil{}, Ast.span_empty()}

def tx_parse_table_rows(xs: List<&2, String>, +acc: List<&2, Ast.TableRow>) -> List<&2, Ast.TableRow>:
  match xs:
    case Nil{}:
      List.reverse(&2, Ast.TableRow, acc)
    case +h <> +t:
      tx_parse_table_rows(t, tx_parse_table_row(h) <> acc)

def tx_alignment_none_list(n: Nat) -> List<&2, Ast.Alignment>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Ast.AlignNone{} <> tx_alignment_none_list(p)

def tx_first_row_width(lines: List<&2, String>) -> Nat:
  match lines:
    case Nil{}:
      0n
    case h <> t:
      List.length(&2, String, tx_table_cell_strings(h))

def tx_make_table(+lines: List<&2, String>, +pos: U32, width: Nat) -> Ast.Block:
  Ast.BTable{tx_alignment_none_list(tx_first_row_width(lines)),
    tx_parse_table_rows(lines, Nil{}), Ast.Span{pos, tx_pos_add(pos, width)}}

# List tree conversion.  Depth jumps nest directly under the preceding item;
# a marker switch at the same depth closes the current list and the caller
# emits a sibling list.  This covers the documented uniform nesting forms.
def tx_item_text_block(+item: TxRawItem) -> Ast.Block:
  Ast.BParagraph{tx_parse_inlines_top(tx_raw_text(item), 0), Nil{}, Ast.span_empty()}

def tx_bool_eq(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case _ _:
      False{}

def tx_same_list_item(+depth: Nat, +ordered: Bool, +item: TxRawItem) -> Bool:
  Nat.is_eq(tx_raw_depth(item), depth) && tx_bool_eq(tx_raw_ordered(item), ordered)

type TxListChild is Data:
  TxListChild{depth: Nat, ordered: Bool}

def tx_child_depth(x: TxListChild) -> Nat:
  match x:
    case TxListChild{depth, ordered}:
      depth

def tx_child_ordered(x: TxListChild) -> Bool:
  match x:
    case TxListChild{depth, ordered}:
      ordered

def tx_list_child(+depth: Nat, xs: List<&2, TxRawItem>) -> Maybe<&2, TxListChild>:
  match xs:
    case Nil{}:
      None{}
    case +h <> t:
      tx_if(Maybe<&2, TxListChild>, Nat.is_gt(tx_raw_depth(h), depth),
        u => Some{TxListChild{tx_raw_depth(h), tx_raw_ordered(h)}},
        u => None{})

def tx_list_level_done(+xs: List<&2, TxRawItem>, +acc: List<&2, Ast.ListItem>) -> TxListLevel:
  TxListLevel{List.reverse(&2, Ast.ListItem, acc), xs}

def tx_nested_list_block(+child: TxListChild, items: List<&2, Ast.ListItem>) -> Ast.Block:
  TxListChild{+depth, +ordered} = child
  Ast.BList{ordered, 1, True{}, items, Ast.span_empty()}

def tx_parse_list_level(fuel: Nat, +depth: Nat, +ordered: Bool,
    +xs: List<&2, TxRawItem>, +acc: List<&2, Ast.ListItem>) -> TxListLevel:
  match fuel:
    case 0n:
      tx_list_level_done(xs, acc)
    case 1n++f:
      match xs:
        case Nil{}:
          tx_list_level_done(Nil{}, acc)
        case +item <> +rest:
          tx_if(TxListLevel, tx_same_list_item(depth, ordered, item),
            u =>
              tx_maybe_case(TxListChild, TxListLevel, tx_list_child(depth, rest),
                +child =>
                  +childres = tx_parse_list_level(f, tx_child_depth(child), tx_child_ordered(child), rest, Nil{})
                  +child_items = tx_level_items(childres)
                  +child_rest = tx_level_rest(childres)
                  +nested = tx_nested_list_block(child, child_items)
                  +blocks = {tx_item_text_block(item) <> nested <> Nil{} : List<&2, Ast.Block>}
                  tx_parse_list_level(f, depth, ordered, child_rest,
                    Ast.ListItem{blocks, Ast.span_empty()} <> acc),
                u =>
                  tx_parse_list_level(f, depth, ordered, rest,
                    Ast.ListItem{tx_item_text_block(item) <> Nil{}, Ast.span_empty()} <> acc)),
            u => tx_list_level_done(xs, acc))

def tx_build_lists(fuel: Nat, +xs: List<&2, TxRawItem>, +acc: List<&2, Ast.Block>) -> List<&2, Ast.Block>:
  match fuel:
    case 0n:
      List.reverse(&2, Ast.Block, acc)
    case 1n++f:
      match xs:
        case Nil{}:
          List.reverse(&2, Ast.Block, acc)
        case +item <> +rest:
          +level = tx_parse_list_level(f, tx_raw_depth(item), tx_raw_ordered(item), xs, Nil{})
          +items = tx_level_items(level)
          +level_rest = tx_level_rest(level)
          tx_build_lists(f, level_rest,
            Ast.BList{tx_raw_ordered(item), 1, True{}, items, Ast.span_empty()} <> acc)

# Block constructors.
def tx_lines_width(lines: List<&2, String>) -> Nat:
  match lines:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(Text.utf8_length(h), Nat.add(1n, tx_lines_width(t)))

def tx_items_width(items: List<&2, TxRawItem>) -> Nat:
  match items:
    case Nil{}:
      0n
    case h <> t:
      Nat.add(Text.utf8_length(tx_raw_line(h)), Nat.add(1n, tx_items_width(t)))

# String.lines represents a trailing newline as a final empty pseudo-line.
# parse_textile removes that pseudo-line and threads `ends_newline` instead.
# Widths otherwise count one normalized LF after every logical line; subtract
# it only for a block that consumes the final line of input without that LF.
def tx_width_at_end(+base: Nat, reaches_end: Bool, +ends_newline: Bool) -> Nat:
  tx_if(Nat, reaches_end && Bool.not(ends_newline),
    u => Nat.sub(base, 1n),
    u => base)

def tx_drop_final_empty_rev(+lines: List<&2, String>, rev: List<&2, String>) -> List<&2, String>:
  match rev:
    case SNil{} <> +trev:
      List.reverse(&2, String, trev)
    case xs:
      lines

def tx_drop_final_empty_line(+lines: List<&2, String>) -> List<&2, String>:
  tx_drop_final_empty_rev(lines, List.reverse(&2, String, lines))

def tx_make_paragraph(+lines: List<&2, String>, +attrs: List<&2, Ast.Attr>,
    +pos: U32, +width: Nat) -> Ast.Block:
  +text = String.join(lines, "\n")
  Ast.BParagraph{tx_parse_inlines_top(text, pos), attrs,
    Ast.Span{pos, tx_pos_add(pos, width)}}

def tx_block_from_sig(+sig: TxBlockSig, +lines: List<&2, String>,
    +pos: U32, +content_pos: U32, +width: Nat) -> Ast.Block:
  +kind = tx_sig_kind(sig)
  +level = tx_sig_level(sig)
  +attrs = tx_sig_attrs(sig)
  +text = String.join(lines, "\n")
  +span = {Ast.Span{pos, tx_pos_add(pos, width)} : Ast.Span}
  tx_if(Ast.Block, Nat.is_eq(kind, 1n),
    u => Ast.BParagraph{tx_parse_inlines_top(text, content_pos), attrs, span},
    u => tx_if(Ast.Block, Nat.is_eq(kind, 2n),
      v => Ast.BHeading{level, tx_parse_inlines_top(text, content_pos), attrs, span},
      v =>
        +innerspan = tx_span_text(content_pos, text)
        +inner = {Ast.BParagraph{tx_parse_inlines_top(text, content_pos), Nil{}, innerspan} : Ast.Block}
        Ast.BBlockQuote{inner <> Nil{}, attrs, None{}, span}))

def tx_escape_block(+taken: List<&2, String>, closed: Bool, +pos: U32, +width: Nat) -> Ast.Block:
  +text = String.join(taken, "\n")
  +span = {Ast.Span{pos, tx_pos_add(pos, width)} : Ast.Span}
  tx_if(Ast.Block, closed,
    u => Ast.BRawPassthrough{text, span},
    u =>
      +lines = {"==" <> taken : List<&2, String>}
      +plain = String.join(lines, "\n")
      Ast.BParagraph{tx_parse_inlines_top(plain, pos), Nil{}, span})

def tx_pos_add_line(+pos: U32, +line: String) -> U32:
  tx_pos_add(pos, Nat.add(Text.utf8_length(line), 1n))

def tx_escape_width(+taken: List<&2, String>, closed: Bool) -> Nat:
  +base = Nat.add(3n, tx_lines_width(taken))
  tx_if(Nat, closed,
    u => Nat.add(base, 3n),
    u => base)

# The block loop.  A line that is not a complete signature, list marker,
# table row, or escape fence is paragraph text.  Paragraphs and single-period
# quotes continue only over lines that independently classify as plain.
def tx_parse_blocks(fuel: Nat, +lines: List<&2, String>, +pos: U32, +ends_newline: Bool) -> List<&2, Ast.Block>:
  match fuel:
    case 0n:
      Nil{}
    case 1n++f:
      match lines:
        case Nil{}:
          Nil{}
        case +h <> +t:
          +kind = tx_line_kind(h)
          +blank = tx_linekind_blank(kind)
          +sig = tx_linekind_sig(kind)
          +item = tx_linekind_item(kind)
          +table = tx_linekind_table(kind)
          +escape = tx_linekind_escape(kind)
          tx_if(List<&2, Ast.Block>, blank,
            u => tx_parse_blocks(f, t, tx_pos_add_line(pos, h), ends_newline),
            u =>
              tx_maybe_case(TxBlockSig, List<&2, Ast.Block>, sig,
                +sigval =>
                  +isheading = Nat.is_eq(tx_sig_kind(sigval), 2n)
                  +split = tx_if(TxLineSplit, isheading,
                    v => TxLineSplit{Nil{}, t},
                    v => tx_collect_plain(f, t, Nil{}))
                  +taken = tx_line_split_taken(split)
                  +rest = tx_line_split_rest(split)
                  +rawlines = {h <> taken : List<&2, String>}
                  +rawwidth = tx_lines_width(rawlines)
                  +width = tx_width_at_end(rawwidth, List.is_empty(&2, String, rest), ends_newline)
                  +contentlines = {tx_sig_text(sigval) <> taken : List<&2, String>}
                  +sigprefix = Nat.sub(Text.utf8_length(h), Text.utf8_length(tx_sig_text(sigval)))
                  +contentpos = tx_pos_add(pos, sigprefix)
                  +block = tx_block_from_sig(sigval, contentlines, pos, contentpos, width)
                  block <> tx_parse_blocks(f, rest, tx_pos_add(pos, width), ends_newline),
                u =>
                  tx_maybe_case(TxRawItem, List<&2, Ast.Block>, item,
                    +firstitem =>
                      +itemsplit = tx_collect_list(f, t, firstitem <> Nil{})
                      +items = tx_items_split_items(itemsplit)
                      +rest = tx_items_split_rest(itemsplit)
                      +rawwidth = tx_items_width(items)
                      +width = tx_width_at_end(rawwidth, List.is_empty(&2, String, rest), ends_newline)
                      +listblocks = tx_build_lists(f, items, Nil{})
                      List.append(&2, Ast.Block, listblocks,
                        tx_parse_blocks(f, rest, tx_pos_add(pos, width), ends_newline)),
                    u =>
                      tx_if(List<&2, Ast.Block>, table,
                        v =>
                          +split = tx_collect_table(f, t, Nil{})
                          +taken = tx_line_split_taken(split)
                          +rest = tx_line_split_rest(split)
                          +rowlines = {h <> taken : List<&2, String>}
                          +rawwidth = tx_lines_width(rowlines)
                          +width = tx_width_at_end(rawwidth, List.is_empty(&2, String, rest), ends_newline)
                          tx_make_table(rowlines, pos, width) <>
                            tx_parse_blocks(f, rest, tx_pos_add(pos, width), ends_newline),
                        v =>
                          tx_if(List<&2, Ast.Block>, escape,
                            w =>
                              +esc = tx_collect_escape(f, t, Nil{})
                              +taken = tx_escape_taken(esc)
                              +rest = tx_escape_rest(esc)
                              +closed = tx_escape_closed(esc)
                              +rawwidth = tx_escape_width(taken, closed)
                              +width = tx_width_at_end(rawwidth, List.is_empty(&2, String, rest), ends_newline)
                              tx_escape_block(taken, closed, pos, width) <>
                                tx_parse_blocks(f, rest, tx_pos_add(pos, width), ends_newline),
                            w =>
                              +split = tx_collect_plain(f, t, Nil{})
                              +taken = tx_line_split_taken(split)
                              +rest = tx_line_split_rest(split)
                              +rawlines = {h <> taken : List<&2, String>}
                              +rawwidth = tx_lines_width(rawlines)
                              +width = tx_width_at_end(rawwidth, List.is_empty(&2, String, rest), ends_newline)
                              tx_make_paragraph(rawlines, Nil{}, pos, width) <>
                                tx_parse_blocks(f, rest, tx_pos_add(pos, width), ends_newline))))))

# Public entry points.
def parse_textile(+source: String) -> Ast.Document:
  +normalized = Text.normalize_newlines(source)
  +ends_newline = String.ends_with(normalized, "\n")
  +lines0 = String.lines(normalized)
  +lines = tx_if(List<&2, String>, ends_newline,
    u => tx_drop_final_empty_line(lines0),
    u => lines0)
  +count = List.length(&2, String, lines)
  +fuel = Nat.add(Nat.mul(4n, count), 4n)
  Ast.Document{tx_parse_blocks(fuel, lines, 0, ends_newline)}

def parse_textile_bounded_gate(+source: String, too_large: Bool) -> Maybe<&2, Ast.Document>:
  match too_large:
    case True{}:
      None{}
    case False{}:
      Some{parse_textile(source)}

def parse_textile_bounded(+source: String, +max_input_bytes: Nat) -> Maybe<&2, Ast.Document>:
  parse_textile_bounded_gate(source, Nat.is_gt(Text.utf8_length(source), max_input_bytes))
