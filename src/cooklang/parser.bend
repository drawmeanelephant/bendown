import Base
import ../ast.bend as Ast
import ../text.bend as Text
import ./model.bend as Model

# Clean-room Cooklang parser, first milestone.
#
# The parser is deliberately total: malformed constructs are literal text and
# every scanner either consumes its input structurally or counts down fuel.
# Spans inside steps are approximate in this milestone; frontmatter and block
# boundaries are exact byte positions in the original input.

# Bend cannot match on a freshly computed value.  These eliminators isolate
# that match in a parameter, as in the project's other parsers.
def ck_if(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def ck_maybe(-A: Data, -B: Type, m: Maybe<&2, A>, some: A -> B, none: Unit -> B) -> B:
  match m:
    case Some{x}:
      some(x)
    case None{}:
      none(Unit{})

def ck_pos_add(+p: U32, n: Nat) -> U32:
  U32.add(p, U32.from_nat(n))

# ---------------------------------------------------------------------------
# Physical lines and frontmatter
# ---------------------------------------------------------------------------

type LineSplit is Data:
  LineSplit{line: String, lined: String, rest: String, line_bytes: U32, all_bytes: U32}

type SrcLine is Data:
  SrcLine{text: String, start: U32, end: U32}

type FMScan is Data:
  FMScan{found: Bool, raw: String, body: String, span_end: U32}

def make_line_split(+line: String, +lined: String, rest: String) -> LineSplit:
  LineSplit{line, lined, rest,
    U32.from_nat(Text.utf8_length(line)), U32.from_nat(Text.utf8_length(lined))}

def finish_line_split(+line_acc: String, +lined_acc: String, rest: String) -> LineSplit:
  make_line_split(String.reverse(line_acc), String.reverse(lined_acc), rest)

# Split one physical line.  LF, CRLF, and a lone CR are all line terminators;
# `line` excludes the terminator while `lined` preserves it exactly.
def split_line_go(s: String, line_acc: String, lined_acc: String) -> LineSplit:
  match s:
    case SNil{}:
      finish_line_split(line_acc, lined_acc, SNil{})
    case SCon{'\r', SCon{'\n', tt}}:
      finish_line_split(line_acc, SCon{'\n', SCon{'\r', lined_acc}}, tt)
    case SCon{'\r', t}:
      finish_line_split(line_acc, SCon{'\r', lined_acc}, t)
    case SCon{'\n', t}:
      finish_line_split(line_acc, SCon{'\n', lined_acc}, t)
    case SCon{+h, t}:
      split_line_go(t, SCon{h, line_acc}, SCon{h, lined_acc})

def split_line(s: String) -> LineSplit:
  split_line_go(s, SNil{}, SNil{})

def ls_line(+x: LineSplit) -> String:
  match x:
    case LineSplit{line, lined, rest, line_bytes, all_bytes}:
      line

def ls_lined(+x: LineSplit) -> String:
  match x:
    case LineSplit{line, lined, rest, line_bytes, all_bytes}:
      lined

def ls_rest(+x: LineSplit) -> String:
  match x:
    case LineSplit{line, lined, rest, line_bytes, all_bytes}:
      rest

def ls_line_bytes(+x: LineSplit) -> U32:
  match x:
    case LineSplit{line, lined, rest, line_bytes, all_bytes}:
      line_bytes

def ls_all_bytes(+x: LineSplit) -> U32:
  match x:
    case LineSplit{line, lined, rest, line_bytes, all_bytes}:
      all_bytes

def src_line_text(+x: SrcLine) -> String:
  match x:
    case SrcLine{text, start, end}:
      text

def src_line_start(+x: SrcLine) -> U32:
  match x:
    case SrcLine{text, start, end}:
      start

def src_line_end(+x: SrcLine) -> U32:
  match x:
    case SrcLine{text, start, end}:
      end

def split_lines_go(fuel: Nat, s: String, +pos: U32, acc: List<&2, SrcLine>) -> List<&2, SrcLine>:
  match fuel:
    case 0n:
      List.reverse(&2, SrcLine, acc)
    case 1n+p:
      match s:
        case SNil{}:
          List.reverse(&2, SrcLine, acc)
        case SCon{h, t}:
          +hit = split_line(SCon{h, t})
          +line_bytes = ls_line_bytes(hit)
          +all_bytes = ls_all_bytes(hit)
          +endpos = U32.add(pos, line_bytes)
          +nextpos = U32.add(pos, all_bytes)
          split_lines_go(p, ls_rest(hit), nextpos,
            SrcLine{ls_line(hit), pos, endpos} <> acc)

def split_lines(+s: String, +pos: U32) -> List<&2, SrcLine>:
  split_lines_go(Nat.add(String.length(s), 1n), s, pos, Nil{})

def drop_space_tab_cr(s: String) -> String:
  match s:
    case SCon{' ', t}:
      drop_space_tab_cr(t)
    case SCon{'\t', t}:
      drop_space_tab_cr(t)
    case SCon{'\r', t}:
      drop_space_tab_cr(t)
    case x:
      x

def trim_space_tab_cr(s: String) -> String:
  String.reverse(drop_space_tab_cr(String.reverse(drop_space_tab_cr(s))))

def is_fence_line(+s: String) -> Bool:
  String.eq(trim_space_tab_cr(s), "---")

def fm_scan_go(fuel: Nat, s: String, +pos: U32, +raws: List<&2, String>) -> FMScan:
  match fuel:
    case 0n:
      FMScan{False{}, SNil{}, s, pos}
    case 1n+p:
      match s:
        case SNil{}:
          FMScan{False{}, SNil{}, s, pos}
        case SCon{h, t}:
          +hit = split_line(SCon{h, t})
          +nextpos = U32.add(pos, ls_all_bytes(hit))
          ck_if(FMScan, is_fence_line(ls_line(hit)),
            u => FMScan{True{}, String.concat(List.reverse(&2, String, raws)),
              ls_rest(hit), nextpos},
            u => fm_scan_go(p, ls_rest(hit), nextpos, ls_lined(hit) <> raws))

def fm_scan(+s: String, +pos: U32) -> FMScan:
  fm_scan_go(Nat.add(String.length(s), 1n), s, pos, Nil{})

def frontmatter_from_first(+source: String, first: LineSplit) -> FMScan:
  match first:
    case LineSplit{+line, lined, +rest, line_bytes, +all_bytes}:
      ck_if(FMScan, is_fence_line(line),
        u => fm_scan(rest, all_bytes),
        u => FMScan{False{}, SNil{}, source, 0})

# ---------------------------------------------------------------------------
# Comment cleaning inside steps
# ---------------------------------------------------------------------------

# U+D800 is not a Unicode scalar value, so it cannot occur in decoded input
# text.  It is a purely internal lexical barrier marker and is never emitted.
def barrier_char() -> Char:
  Chr{55296}

def is_barrier(+c: Char) -> Bool:
  Char.is_eq(c, barrier_char())

def strip_barriers(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, +t}:
      ck_if(String, is_barrier(h),
        u => strip_barriers(t),
        u => SCon{h, strip_barriers(t)})

def append_literal_rev(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{+h, +t}:
      ck_if(String, is_barrier(h),
        u => append_literal_rev(t, acc),
        u => append_literal_rev(t, SCon{h, acc}))

# ---------------------------------------------------------------------------
# Ingredient/cookware/timer token scanning
# ---------------------------------------------------------------------------

type TokenKind is Data:
  TKIngredient{}
  TKCookware{}
  TKTimer{}

type NameScan is Data:
  NameScan{name: String, len: Nat}

type PrepScan is Data:
  PrepScan{prep: String, len: Nat}

type FieldSplit is Data:
  FieldSplit{quantity: String, units: String}

type TokenResult is Data:
  TokenResult{name: String, quantity: Maybe<&2, String>, units: Maybe<&2, String>,
    preparation: Maybe<&2, String>, consumed: Nat}

def prep_scan_prep(+x: PrepScan) -> String:
  match x:
    case PrepScan{prep, len}:
      prep

def prep_scan_len(+x: PrepScan) -> Nat:
  match x:
    case PrepScan{prep, len}:
      len

def token_result_consumed(+x: TokenResult) -> Nat:
  match x:
    case TokenResult{name, quantity, units, preparation, consumed}:
      consumed

def ck_range(+x: U32, +lo: U32, +hi: U32) -> Bool:
  (x >= lo : U32) && (x <= hi : U32)

# A pragmatic Unicode P-category approximation.  It covers ASCII punctuation
# and the punctuation blocks exercised by the canonical corpus, plus the wide
# compatibility blocks.  Symbols deliberately are not boundaries.
def unicode_punctuation(+c: Char) -> Bool:
  +x = Char.to_u32(c)
  ck_range(x, 33, 47) || ck_range(x, 58, 64) || ck_range(x, 91, 96) ||
    ck_range(x, 123, 126) || ck_range(x, 8192, 8303) ||
    ck_range(x, 11776, 11903) || ck_range(x, 12288, 12351) ||
    ck_range(x, 65040, 65055) || ck_range(x, 65072, 65099) ||
    ck_range(x, 65104, 65131) || ck_range(x, 65281, 65295) ||
    ck_range(x, 65306, 65312) || ck_range(x, 65339, 65344) ||
    ck_range(x, 65371, 65381)

def unicode_space(+c: Char) -> Bool:
  +x = Char.to_u32(c)
  Char.is_space(c) || U32.is_eq(x, 160) || U32.is_eq(x, 5760) ||
    ck_range(x, 8192, 8202) || U32.is_eq(x, 8232) ||
    U32.is_eq(x, 8233) || U32.is_eq(x, 8239) ||
    U32.is_eq(x, 8287) || U32.is_eq(x, 12288)

def token_marker(+c: Char) -> Bool:
  Char.is_eq(c, '@') || Char.is_eq(c, '#') || Char.is_eq(c, '~')

def token_boundary(+c: Char) -> Bool:
  unicode_space(c) || unicode_punctuation(c) || token_marker(c) || is_barrier(c)

def word_char(+c: Char) -> Bool:
  Bool.not(token_boundary(c))

def multiword_exception(+c: Char) -> Bool:
  Char.is_eq(c, '-') || Char.is_eq(c, '.') || Char.is_eq(c, '/')

def multiword_forbidden(+c: Char) -> Bool:
  token_marker(c) || is_barrier(c) ||
    Bool.and(unicode_punctuation(c), Bool.not(multiword_exception(c)))

def has_block_close(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'-', SCon{']', t}}:
      True{}
    case SCon{h, t}:
      has_block_close(t)

type PrepMarker is Data:
  PMIngredient{}
  PMOther{}
  PMNone{}

def prep_marker_result(+h: Char, +seen: Bool, +first_valid: Bool) -> PrepMarker:
  ck_if(PrepMarker, Bool.and(seen, first_valid),
    u => ck_if(PrepMarker, Char.is_eq(h, '@'),
      v => PMIngredient{},
      v => PMOther{}),
    u => PMNone{})

# Scan a reversed candidate token name.  This mirrors the serializer's small
# reverse scanner, but returns the marker kind so shorthand preparations stay
# ingredient-only even during comment cleaning.
def prep_rev_marker_go(s: String, +seen: Bool, +first_valid: Bool) -> PrepMarker:
  match s:
    case SNil{}:
      PMNone{}
    case SCon{+h, +t}:
      ck_if(PrepMarker, token_marker(h),
        u => prep_marker_result(h, seen, first_valid),
        u =>
          ck_if(PrepMarker, unicode_space(h),
            v => ck_if(PrepMarker, seen,
              w => prep_rev_marker_go(t, True{}, False{}),
              w => PMNone{}),
            v =>
              ck_if(PrepMarker, Bool.and(unicode_punctuation(h),
                  Bool.not(multiword_exception(h))),
                w => PMNone{},
                w => prep_rev_marker_go(t, True{},
                  Bool.or(word_char(h), Char.is_eq(h, '.'))))))

def prep_rev_open_brace(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{'{', t}:
      Some{t}
    case SCon{'}', t}:
      None{}
    case SCon{'\n', t}:
      None{}
    case SCon{h, t}:
      prep_rev_open_brace(t)

def prep_marker_is_ingredient(m: PrepMarker) -> Bool:
  match m:
    case PMIngredient{}:
      True{}
    case PMOther{}:
      False{}
    case PMNone{}:
      False{}

def prep_candidate_before(+before_open: String) -> Bool:
  prep_marker_is_ingredient(prep_rev_marker_go(before_open, False{}, False{}))

def prep_candidate_tail(m: Maybe<&2, String>) -> Bool:
  ck_maybe(String, Bool, m,
    +before_open => prep_candidate_before(before_open),
    u => False{})

def prep_close_ahead(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{')', t}:
      True{}
    case SCon{'(', t}:
      False{}
    case SCon{'\n', t}:
      False{}
    case SCon{h, t}:
      prep_close_ahead(t)

# A shorthand preparation opens only immediately after the closing brace of a
# braced ingredient.  The reversed output lets the cleaner recognize that
# shape without changing ordinary parentheses into comment-opaque regions.
def after_close_brace(+s: String) -> Bool:
  match s:
    case SCon{'}', +rest}:
      prep_candidate_tail(prep_rev_open_brace(rest))
    case x:
      False{}

def prep_open_candidate(+out: String, +tail: String) -> Bool:
  Bool.and(after_close_brace(out), prep_close_ahead(tail))

type CleanMode is Data:
  CleanNormal{}
  CleanBlock{}
  CleanLineComment{}
  CleanDashLiteral{}

# Remove line and block comments in step text.  Newlines are retained so the
# later step joiner can apply Cooklang's one-space rule.  Comments inside a
# braced quantity are opaque; comments outside one are trivia, with a barrier
# left behind so deleting one cannot glue a multiword token together.
def clean_step_go(s: String, +mode: CleanMode, +depth: Nat, +out: String) -> String:
  match s:
    case SNil{}:
      String.reverse(out)
    case SCon{'\n', t}:
      match mode:
        case CleanNormal{}:
          clean_step_go(t, CleanNormal{}, 0n, SCon{'\n', out})
        case CleanLineComment{}:
          clean_step_go(t, CleanNormal{}, 0n, SCon{'\n', out})
        case CleanBlock{}:
          clean_step_go(t, CleanBlock{}, 0n,
            SCon{'\n', SCon{barrier_char(), out}})
        case CleanDashLiteral{}:
          clean_step_go(t, CleanNormal{}, 0n, SCon{'\n', out})
    case SCon{'[', SCon{'-', +tt}}:
      match mode:
        case CleanNormal{}:
          match depth:
            case 0n:
              ck_if(String, has_block_close(tt),
                u => clean_step_go(tt, CleanBlock{}, 0n, SCon{barrier_char(), out}),
                u => clean_step_go(SCon{'-', tt}, CleanNormal{}, 0n, SCon{'[', out}))
            case 1n+p:
              clean_step_go(SCon{'-', tt}, CleanNormal{}, depth, SCon{'[', out})
        case CleanLineComment{}:
          clean_step_go(tt, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(tt, mode, depth, out)
        case CleanDashLiteral{}:
          match depth:
            case 0n:
              ck_if(String, has_block_close(tt),
                u => clean_step_go(tt, CleanBlock{}, 0n, SCon{barrier_char(), out}),
                u => clean_step_go(SCon{'-', tt}, CleanNormal{}, 0n, SCon{'[', out}))
            case 1n+p:
              clean_step_go(SCon{'-', tt}, CleanNormal{}, depth, SCon{'[', out})
    case SCon{'-', SCon{'-', SCon{'-', ttt}}}:
      match mode:
        case CleanNormal{}:
          match depth:
            case 0n:
              clean_step_go(ttt, CleanDashLiteral{}, depth,
                SCon{'-', SCon{'-', SCon{'-', out}}})
            case 1n+p:
              clean_step_go(ttt, CleanNormal{}, depth,
                SCon{'-', SCon{'-', SCon{'-', out}}})
        case CleanDashLiteral{}:
          clean_step_go(ttt, mode, depth,
            SCon{'-', SCon{'-', SCon{'-', out}}})
        case CleanLineComment{}:
          clean_step_go(ttt, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(ttt, mode, depth, out)
    case SCon{'-', SCon{']', tt}}:
      match mode:
        case CleanBlock{}:
          clean_step_go(tt, CleanNormal{}, depth, SCon{barrier_char(), out})
        case CleanNormal{}:
          clean_step_go(SCon{']', tt}, mode, depth, SCon{'-', out})
        case CleanLineComment{}:
          clean_step_go(tt, mode, depth, out)
        case CleanDashLiteral{}:
          clean_step_go(SCon{']', tt}, CleanNormal{}, depth, SCon{'-', out})
    case SCon{'-', SCon{'-', tt}}:
      match mode:
        case CleanNormal{}:
          match depth:
            case 0n:
              clean_step_go(tt, CleanLineComment{}, depth, SCon{barrier_char(), out})
            case 1n+p:
              clean_step_go(SCon{'-', tt}, mode, depth, SCon{'-', out})
        case CleanLineComment{}:
          clean_step_go(tt, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(tt, mode, depth, out)
        case CleanDashLiteral{}:
          clean_step_go(tt, mode, depth, SCon{'-', SCon{'-', out}})
    case SCon{'{', t}:
      match mode:
        case CleanNormal{}:
          clean_step_go(t, CleanNormal{}, Nat.add(depth, 1n), SCon{'{', out})
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
        case CleanDashLiteral{}:
          clean_step_go(t, CleanNormal{}, Nat.add(depth, 1n), SCon{'{', out})
    case SCon{'}', t}:
      match mode:
        case CleanNormal{}:
          match depth:
            case 0n:
              clean_step_go(t, CleanNormal{}, 0n, SCon{'}', out})
            case 1n+p:
              clean_step_go(t, CleanNormal{}, p, SCon{'}', out})
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
        case CleanDashLiteral{}:
          match depth:
            case 0n:
              clean_step_go(t, CleanNormal{}, 0n, SCon{'}', out})
            case 1n+p:
              clean_step_go(t, CleanNormal{}, p, SCon{'}', out})
    case SCon{'(', +t}:
      match mode:
        case CleanNormal{}:
          ck_if(String, Bool.and(Nat.is_eq(depth, 0n), prep_open_candidate(out, t)),
            u => clean_step_go(t, CleanNormal{}, Nat.add(depth, 1n), SCon{'(', out}),
            u => clean_step_go(t, CleanNormal{}, depth, SCon{'(', out}))
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
        case CleanDashLiteral{}:
          ck_if(String, Bool.and(Nat.is_eq(depth, 0n), prep_open_candidate(out, t)),
            u => clean_step_go(t, CleanNormal{}, Nat.add(depth, 1n), SCon{'(', out}),
            u => clean_step_go(t, CleanNormal{}, depth, SCon{'(', out}))
    case SCon{')', t}:
      match mode:
        case CleanNormal{}:
          match depth:
            case 0n:
              clean_step_go(t, CleanNormal{}, 0n, SCon{')', out})
            case 1n+p:
              clean_step_go(t, CleanNormal{}, p, SCon{')', out})
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
        case CleanDashLiteral{}:
          match depth:
            case 0n:
              clean_step_go(t, CleanNormal{}, 0n, SCon{')', out})
            case 1n+p:
              clean_step_go(t, CleanNormal{}, p, SCon{')', out})
    case SCon{'-', t}:
      match mode:
        case CleanDashLiteral{}:
          clean_step_go(t, mode, depth, SCon{'-', out})
        case CleanNormal{}:
          clean_step_go(t, CleanNormal{}, depth, SCon{'-', out})
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
    case SCon{h, t}:
      match mode:
        case CleanNormal{}:
          clean_step_go(t, CleanNormal{}, depth, SCon{h, out})
        case CleanLineComment{}:
          clean_step_go(t, mode, depth, out)
        case CleanBlock{}:
          clean_step_go(t, mode, depth, out)
        case CleanDashLiteral{}:
          clean_step_go(t, CleanNormal{}, depth, SCon{h, out})

def clean_step_text(+s: String) -> String:
  clean_step_go(s, CleanNormal{}, 0n, SNil{})


def scan_multiword_go(s: String, +acc: String, +len: Nat, last_word: Bool) -> Maybe<&2, NameScan>:
  match s:
    case SNil{}:
      None{}
    case SCon{'{', t}:
      ck_if(Maybe<&2, NameScan>, Bool.and(Nat.is_gt(len, 0n), last_word),
        u => Some{NameScan{String.reverse(acc), len}},
        u => None{})
    case SCon{+h, +t}:
      ck_if(Maybe<&2, NameScan>, multiword_forbidden(h),
        u => None{},
        u => scan_multiword_go(t, SCon{h, acc}, 1n+len,
          Bool.not(unicode_space(h))))

def scan_multiword(s: String) -> Maybe<&2, NameScan>:
  scan_multiword_go(s, SNil{}, 0n, False{})

def scan_unbraced_go(s: String, +acc: String, +len: Nat) -> NameScan:
  match s:
    case SNil{}:
      NameScan{String.reverse(acc), len}
    case SCon{+h, +t}:
      ck_if(NameScan, token_boundary(h),
        u => NameScan{String.reverse(acc), len},
        u => scan_unbraced_go(t, SCon{h, acc}, 1n+len))

def scan_unbraced(s: String) -> NameScan:
  scan_unbraced_go(s, SNil{}, 0n)

def find_brace_close(s: String, idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{'}', t}:
      Some{idx}
    case SCon{'{', t}:
      None{}
    case SCon{h, t}:
      find_brace_close(t, 1n+idx)

def find_percent(s: String, idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{'%', t}:
      Some{idx}
    case SCon{h, t}:
      find_percent(t, 1n+idx)

def find_prep_close(s: String, idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{')', t}:
      Some{idx}
    case SCon{'(', t}:
      None{}
    case SCon{h, t}:
      find_prep_close(t, 1n+idx)

def prep_from_close(+inside: String, +idx: Nat) -> PrepScan:
  PrepScan{String.trim(String.take(inside, idx)), Nat.add(idx, 2n)}

def scan_prep_finish(+after_open: String, m: Maybe<&2, Nat>) -> Maybe<&2, PrepScan>:
  match m:
    case Some{+idx}:
      Some{prep_from_close(after_open, idx)}
    case None{}:
      None{}

def scan_prep(s: String) -> Maybe<&2, PrepScan>:
  match s:
    case SCon{'(', +t}:
      scan_prep_finish(t, find_prep_close(t, 0n))
    case x:
      None{}

def quantity_fields(+content: String, m: Maybe<&2, Nat>) -> FieldSplit:
  match m:
    case Some{+idx}:
      FieldSplit{String.trim(String.take(content, idx)),
        String.trim(String.drop(content, 1n+idx))}
    case None{}:
      FieldSplit{String.trim(content), SNil{}}

def fields_for_kind(kind: TokenKind, +content: String) -> FieldSplit:
  match kind:
    case TKIngredient{}:
      quantity_fields(content, find_percent(content, 0n))
    case TKTimer{}:
      quantity_fields(content, find_percent(content, 0n))
    case TKCookware{}:
      FieldSplit{String.trim(content), SNil{}}

def token_finish_fields(+kind: TokenKind, +name: String, +fields: FieldSplit,
    +prep: Maybe<&2, String>, +consumed: Nat) -> TokenResult:
  match fields:
    case FieldSplit{+quantity, +units}:
      TokenResult{name, Some{quantity}, Some{units}, prep, consumed}

def token_with_prep(+kind: TokenKind, +name: String, +fields: FieldSplit,
    +base_consumed: Nat, +after_close: String) -> TokenResult:
  match kind:
    case TKIngredient{}:
      ck_maybe(PrepScan, TokenResult, scan_prep(after_close),
        +phit =>
          token_finish_fields(kind, name, fields, Some{prep_scan_prep(phit)},
            Nat.add(base_consumed, prep_scan_len(phit))),
        u => token_finish_fields(kind, name, fields, None{}, base_consumed))
    case TKCookware{}:
      token_finish_fields(kind, name, fields, None{}, base_consumed)
    case TKTimer{}:
      token_finish_fields(kind, name, fields, None{}, base_consumed)

def token_braced_finish(+kind: TokenKind, +name: String, +name_len: Nat,
    +after_open: String, +idx: Nat) -> Maybe<&2, TokenResult>:
  +content = String.take(after_open, idx)
  +after_close = String.drop(after_open, 1n+idx)
  +base = Nat.add(1n, Nat.add(name_len, Nat.add(idx, 2n)))
  Some{token_with_prep(kind, name, fields_for_kind(kind, content), base, after_close)}

def token_braced_close(+kind: TokenKind, +name: String, +name_len: Nat,
    +after_open: String, m: Maybe<&2, Nat>) -> Maybe<&2, TokenResult>:
  match m:
    case Some{idx}:
      token_braced_finish(kind, name, name_len, after_open, idx)
    case None{}:
      None{}

def parse_brace_at(+kind: TokenKind, +name: String, +name_len: Nat, +after: String) -> Maybe<&2, TokenResult>:
  +after_open = String.drop(after, 1n+name_len)
  token_braced_close(kind, name, name_len, after_open, find_brace_close(after_open, 0n))

def parse_named_braced(+kind: TokenKind, +after: String, hit: NameScan) -> Maybe<&2, TokenResult>:
  match hit:
    case NameScan{+name, +len}:
      parse_brace_at(kind, name, len, after)

def parse_unbraced_finish(+kind: TokenKind, hit: NameScan) -> Maybe<&2, TokenResult>:
  match hit:
    case NameScan{+name, +len}:
      ck_if(Maybe<&2, TokenResult>, Nat.is_gt(len, 0n),
        u => Some{TokenResult{name, None{}, None{}, None{}, Nat.add(1n, len)}},
        u => None{})

def parse_named_unbraced(+kind: TokenKind, +after: String) -> Maybe<&2, TokenResult>:
  parse_unbraced_finish(kind, scan_unbraced(after))

def valid_token_start(+after: String) -> Bool:
  match after:
    case SNil{}:
      False{}
    case SCon{+h, t}:
      word_char(h) || Char.is_eq(h, '.')

def parse_named_token(+kind: TokenKind, +after: String) -> Maybe<&2, TokenResult>:
  ck_if(Maybe<&2, TokenResult>, valid_token_start(after),
    u => ck_maybe(NameScan, Maybe<&2, TokenResult>, scan_multiword(after),
      +hit => parse_named_braced(kind, after, hit),
      u => parse_named_unbraced(kind, after)),
    u => None{})

def parse_anonymous_timer(+after: String) -> Maybe<&2, TokenResult>:
  parse_brace_at(TKTimer{}, SNil{}, 0n, after)

def try_token(+kind: TokenKind, +after: String) -> Maybe<&2, TokenResult>:
  match kind:
    case TKTimer{}:
      match after:
        case SCon{'{', t}:
          parse_anonymous_timer(after)
        case x:
          parse_named_token(kind, after)
    case TKIngredient{}:
      parse_named_token(kind, after)
    case TKCookware{}:
      parse_named_token(kind, after)

def empty_span() -> Ast.Span:
  Ast.Span{0, 0}

def recipe_reference(+name: String) -> Bool:
  String.starts_with(name, "./")

def token_part(kind: TokenKind, hit: TokenResult) -> Model.CookPart:
  match kind hit:
    case TKIngredient{} TokenResult{+name, +quantity, +units, +preparation, consumed}:
      Model.CookIngredient{Model.Ingredient{name, quantity, units, preparation,
        recipe_reference(name), empty_span()}, empty_span()}
    case TKCookware{} TokenResult{+name, +quantity, units, preparation, consumed}:
      Model.CookCookware{Model.Cookware{name, quantity, empty_span()}, empty_span()}
    case TKTimer{} TokenResult{+name, +quantity, +units, preparation, consumed}:
      Model.CookTimer{Model.Timer{name, quantity, units, empty_span()}, empty_span()}

# ---------------------------------------------------------------------------
# Step line joining and part scanning
# ---------------------------------------------------------------------------

def push_text_rev(text_rev: String, +parts: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  +text = String.reverse(text_rev)
  ck_if(List<&2, Model.CookPart>, String.is_empty(text),
    u => parts,
    u => Model.CookText{text, empty_span()} <> parts)

def scan_line_go(fuel: Nat, s: String, +text_rev: String,
    +parts: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match fuel:
    case 0n:
      List.reverse(&2, Model.CookPart, push_text_rev(append_literal_rev(s, text_rev), parts))
    case 1n++f:
      match s:
        case SNil{}:
          List.reverse(&2, Model.CookPart, push_text_rev(text_rev, parts))
        case SCon{'@', +t}:
          ck_maybe(TokenResult, List<&2, Model.CookPart>, try_token(TKIngredient{}, t),
            +hit =>
              scan_line_go(f, String.drop(SCon{'@', t}, token_result_consumed(hit)),
                SNil{}, token_part(TKIngredient{}, hit) <> push_text_rev(text_rev, parts)),
            u => scan_line_go(f, t, SCon{'@', text_rev}, parts))
        case SCon{'#', +t}:
          ck_maybe(TokenResult, List<&2, Model.CookPart>, try_token(TKCookware{}, t),
            +hit =>
              scan_line_go(f, String.drop(SCon{'#', t}, token_result_consumed(hit)),
                SNil{}, token_part(TKCookware{}, hit) <> push_text_rev(text_rev, parts)),
            u => scan_line_go(f, t, SCon{'#', text_rev}, parts))
        case SCon{'~', SCon{'~', tt}}:
          scan_line_go(f, tt, SCon{'~', SCon{'~', text_rev}}, parts)
        case SCon{'~', +t}:
          ck_maybe(TokenResult, List<&2, Model.CookPart>, try_token(TKTimer{}, t),
            +hit =>
              scan_line_go(f, String.drop(SCon{'~', t}, token_result_consumed(hit)),
                SNil{}, token_part(TKTimer{}, hit) <> push_text_rev(text_rev, parts)),
            u => scan_line_go(f, t, SCon{'~', text_rev}, parts))
        case SCon{+h, +t}:
          ck_if(List<&2, Model.CookPart>, is_barrier(h),
            u => scan_line_go(f, t, text_rev, parts),
            u => scan_line_go(f, t, SCon{h, text_rev}, parts))

def scan_line_parts(+s: String) -> List<&2, Model.CookPart>:
  scan_line_go(Nat.add(String.length(s), 2n), s, SNil{}, Nil{})

def drop_rev_break_padding(s: String) -> String:
  match s:
    case SCon{' ', t}:
      drop_rev_break_padding(t)
    case SCon{'\t', t}:
      drop_rev_break_padding(t)
    case SCon{+h, +t}:
      SCon{h, t}
    case SNil{}:
      SNil{}

type ForcedLine is Data:
  ForcedLine{content: String, forced: Bool}

def forced_from_rev(+line: String, rev: String) -> ForcedLine:
  match rev:
    case SCon{'\\', t}:
      ForcedLine{String.reverse(t), True{}}
    case x:
      ForcedLine{line, False{}}

def analyze_forced(+line: String) -> ForcedLine:
  forced_from_rev(line, drop_rev_break_padding(String.reverse(line)))

def only_barriers(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+h, t}:
      Bool.and(is_barrier(h), only_barriers(t))

type SepState is Data:
  SepNone{}
  SepSpace{}
  SepBreak{}

def prepend_sep(sep: SepState, parts: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match sep:
    case SepNone{}:
      parts
    case SepSpace{}:
      Model.CookText{" ", empty_span()} <> parts
    case SepBreak{}:
      Model.CookLineBreak{empty_span()} <> parts

def append_ordered_parts(xs: List<&2, Model.CookPart>, acc: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      append_ordered_parts(t, h <> acc)

def fl_content(+x: ForcedLine) -> String:
  match x:
    case ForcedLine{content, forced}:
      content

def fl_forced(+x: ForcedLine) -> Bool:
  match x:
    case ForcedLine{content, forced}:
      forced

# Merge adjacent text parts created by line joining.  The accumulator is in
# reverse order, so a text part at its head is the immediately preceding part.
def push_merge_part(part: Model.CookPart, acc: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match part:
    case Model.CookText{+text, +span}:
      match acc:
        case Model.CookText{+ptext, pspan} <> rest:
          Model.CookText{ptext ++ text, span} <> rest
        case other:
          Model.CookText{text, span} <> other
    case otherpart:
      otherpart <> acc

def merge_text_parts_go(parts: List<&2, Model.CookPart>, acc: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match parts:
    case Nil{}:
      List.reverse(&2, Model.CookPart, acc)
    case h <> t:
      merge_text_parts_go(t, push_merge_part(h, acc))

def merge_text_parts(parts: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  merge_text_parts_go(parts, Nil{})

def finish_parts_at_end(sep: SepState, acc: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match sep:
    case SepBreak{}:
      Model.CookLineBreak{empty_span()} <> acc
    case SepNone{}:
      acc
    case SepSpace{}:
      acc

def parse_clean_lines_go(lines: List<&2, String>, +sep: SepState,
    +acc: List<&2, Model.CookPart>) -> List<&2, Model.CookPart>:
  match lines:
    case Nil{}:
      merge_text_parts(List.reverse(&2, Model.CookPart, finish_parts_at_end(sep, acc)))
    case line <> +rest:
      +hit = analyze_forced(line)
      +content = fl_content(hit)
      ck_if(List<&2, Model.CookPart>, only_barriers(content),
        u =>
          ck_if(List<&2, Model.CookPart>, fl_forced(hit),
            v => parse_clean_lines_go(rest, SepBreak{}, acc),
            v => parse_clean_lines_go(rest, sep, acc)),
        u =>
          +with_sep = prepend_sep(sep, acc)
          +line_parts = scan_line_parts(content)
          parse_clean_lines_go(rest,
            ck_if(SepState, fl_forced(hit), v => SepBreak{}, v => SepSpace{}),
            append_ordered_parts(line_parts, with_sep)))

def parse_clean_lines(lines: List<&2, String>) -> List<&2, Model.CookPart>:
  parse_clean_lines_go(lines, SepNone{}, Nil{})

# ---------------------------------------------------------------------------
# Block parsing: steps, notes, and sections
# ---------------------------------------------------------------------------

def line_texts(xs: List<&2, SrcLine>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      src_line_text(h) <> line_texts(t)

def parse_step_lines(+xs: List<&2, SrcLine>) -> List<&2, Model.CookPart>:
  +raw = String.join(line_texts(xs), "\n")
  +cleaned = clean_step_text(raw)
  parse_clean_lines(String.split(cleaned, '\n'))

def blank_raw_line(+s: String) -> Bool:
  Text.blank_line(s)

def starts_char(s: String, +c: Char) -> Bool:
  match s:
    case SCon{h, t}:
      Char.is_eq(h, c)
    case SNil{}:
      False{}

def strip_leading_equals(s: String) -> String:
  match s:
    case SCon{'=', t}:
      strip_leading_equals(t)
    case x:
      x

def strip_trailing_equals(s: String) -> String:
  String.reverse(strip_leading_equals(String.reverse(s)))

def section_name(+s: String) -> String:
  String.trim(strip_trailing_equals(String.trim(strip_leading_equals(s))))

def strip_note_marker(+s: String) -> String:
  match s:
    case SCon{'>', SCon{' ', t}}:
      t
    case SCon{'>', t}:
      t
    case x:
      x

def note_text_go(xs: List<&2, SrcLine>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case line <> rest:
      match rest:
        case Nil{}:
          strip_note_marker(src_line_text(line))
        case rline <> rrest:
          strip_note_marker(src_line_text(line)) ++ " " ++ note_text_go(rest)

def note_block(+xs: List<&2, SrcLine>, +start: U32, +end: U32) -> Model.CookBlock:
  Model.CookNote{note_text_go(xs), Ast.Span{start, end}}

def step_block(+xs: List<&2, SrcLine>, +start: U32, +end: U32) -> Maybe<&2, Model.CookBlock>:
  +ordered = List.reverse(&2, SrcLine, xs)
  +parts = parse_step_lines(ordered)
  ck_if(Maybe<&2, Model.CookBlock>, List.is_empty(&2, Model.CookPart, parts),
    u => None{},
    u => Some{Model.CookStep{parts, Ast.Span{start, end}}})

def push_step_if_any(+out: List<&2, Model.CookBlock>, +xs: List<&2, SrcLine>,
    +start: U32, +end: U32) -> List<&2, Model.CookBlock>:
  ck_maybe(Model.CookBlock, List<&2, Model.CookBlock>, step_block(xs, start, end),
    +block => block <> out,
    u => out)

def section_block_for(+line: SrcLine) -> Model.CookBlock:
  +text = src_line_text(line)
  Model.CookSection{section_name(text), Nil{},
    Ast.Span{src_line_start(line), src_line_end(line)}}


# A lightweight lexical scan used only while grouping physical lines.  It
# answers whether a step prefix ends inside a block comment.  Blank lines and
# section-looking lines inside a complete multiline comment therefore do not
# become block boundaries.  If no closing `-]` exists later, the same prefix
# is literal Cooklang text and normal blank-line rules apply.
type BlockScanMode is Data:
  BSNormal{}
  BSBlock{}
  BSLineComment{}

def block_scan_end(mode: BlockScanMode) -> Bool:
  match mode:
    case BSBlock{}:
      True{}
    case BSNormal{}:
      False{}
    case BSLineComment{}:
      False{}

def block_scan_go(s: String, mode: BlockScanMode, depth: Nat) -> Bool:
  match s:
    case SNil{}:
      block_scan_end(mode)
    case SCon{'\n', t}:
      match mode:
        case BSNormal{}:
          block_scan_go(t, BSNormal{}, 0n)
        case BSLineComment{}:
          block_scan_go(t, BSNormal{}, 0n)
        case BSBlock{}:
          block_scan_go(t, BSBlock{}, 0n)
    case SCon{'[', SCon{'-', tt}}:
      match mode:
        case BSNormal{}:
          match depth:
            case 0n:
              block_scan_go(tt, BSBlock{}, depth)
            case 1n+p:
              block_scan_go(tt, mode, depth)
        case BSLineComment{}:
          block_scan_go(tt, mode, depth)
        case BSBlock{}:
          block_scan_go(tt, mode, depth)
    case SCon{'-', SCon{']', tt}}:
      match mode:
        case BSBlock{}:
          block_scan_go(tt, BSNormal{}, depth)
        case BSNormal{}:
          block_scan_go(tt, mode, depth)
        case BSLineComment{}:
          block_scan_go(tt, mode, depth)
    case SCon{'-', SCon{'-', tt}}:
      match mode:
        case BSNormal{}:
          match depth:
            case 0n:
              block_scan_go(tt, BSLineComment{}, depth)
            case 1n+p:
              block_scan_go(tt, mode, depth)
        case BSLineComment{}:
          block_scan_go(tt, mode, depth)
        case BSBlock{}:
          block_scan_go(tt, mode, depth)
    case SCon{'{', t}:
      match mode:
        case BSNormal{}:
          block_scan_go(t, mode, Nat.add(depth, 1n))
        case BSLineComment{}:
          block_scan_go(t, mode, depth)
        case BSBlock{}:
          block_scan_go(t, mode, depth)
    case SCon{'}', t}:
      match mode:
        case BSNormal{}:
          match depth:
            case 0n:
              block_scan_go(t, mode, 0n)
            case 1n+p:
              block_scan_go(t, mode, p)
        case BSLineComment{}:
          block_scan_go(t, mode, depth)
        case BSBlock{}:
          block_scan_go(t, mode, depth)
    case SCon{h, t}:
      block_scan_go(t, mode, depth)

def block_scan_inside(+s: String) -> Bool:
  block_scan_go(s, BSNormal{}, 0n)

def step_prefix_inside_block(+step_lines_rev: List<&2, SrcLine>) -> Bool:
  +ordered = List.reverse(&2, SrcLine, step_lines_rev)
  block_scan_inside(String.join(line_texts(ordered), "\n"))

def rest_has_block_close(+rest: List<&2, SrcLine>) -> Bool:
  String.contains(String.join(line_texts(rest), "\n"), "-]")

type ParseMode is Data:
  ParseBoundary{}
  ParseStepMode{}
  ParseNoteMode{}

type ParseState is Data:
  ParseState{mode: ParseMode, step_lines: List<&2, SrcLine>, note_lines: List<&2, SrcLine>,
    start: U32, end: U32, out: List<&2, Model.CookBlock>}

def ps_mode(+x: ParseState) -> ParseMode:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      mode

def ps_step_lines(+x: ParseState) -> List<&2, SrcLine>:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      step_lines

def ps_note_lines(+x: ParseState) -> List<&2, SrcLine>:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      note_lines

def ps_start(+x: ParseState) -> U32:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      start

def ps_end(+x: ParseState) -> U32:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      end

def ps_out(+x: ParseState) -> List<&2, Model.CookBlock>:
  match x:
    case ParseState{mode, step_lines, note_lines, start, end, out}:
      out

# Finish the currently open block at EOF.
def finish_parse_state(mode: ParseMode, step_lines: List<&2, SrcLine>,
    note_lines: List<&2, SrcLine>, +start: U32, +end: U32,
    out: List<&2, Model.CookBlock>) -> List<&2, Model.CookBlock>:
  match mode:
    case ParseBoundary{}:
      List.reverse(&2, Model.CookBlock, out)
    case ParseStepMode{}:
      List.reverse(&2, Model.CookBlock, push_step_if_any(out, step_lines, start, end))
    case ParseNoteMode{}:
      List.reverse(&2, Model.CookBlock,
        note_block(List.reverse(&2, SrcLine, note_lines), start, end) <> out)

def boundary_state(+line: SrcLine, out: List<&2, Model.CookBlock>,
    blank: Bool, section: Bool, note: Bool) -> ParseState:
  match blank section note:
    case True{} _ _:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0, out}
    case False{} True{} _:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0,
        section_block_for(line) <> out}
    case False{} False{} True{}:
      ParseState{ParseNoteMode{}, Nil{}, line <> Nil{},
        src_line_start(line), src_line_end(line), out}
    case False{} False{} False{}:
      ParseState{ParseStepMode{}, line <> Nil{}, Nil{},
        src_line_start(line), src_line_end(line), out}

def step_state(+line: SrcLine, step_lines: List<&2, SrcLine>,
    out: List<&2, Model.CookBlock>, +start: U32, +cur_end: U32,
    blank: Bool, section: Bool) -> ParseState:
  match blank section:
    case True{} _:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0,
        push_step_if_any(out, step_lines, start, cur_end)}
    case False{} True{}:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0,
        section_block_for(line) <>
          push_step_if_any(out, step_lines, start, cur_end)}
    case False{} False{}:
      ParseState{ParseStepMode{}, line <> step_lines, Nil{},
        start, src_line_end(line), out}

def note_state(+line: SrcLine, note_lines: List<&2, SrcLine>,
    out: List<&2, Model.CookBlock>, +start: U32, +cur_end: U32,
    blank: Bool, section: Bool) -> ParseState:
  match blank section:
    case True{} _:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0,
        note_block(List.reverse(&2, SrcLine, note_lines), start, cur_end) <> out}
    case False{} True{}:
      ParseState{ParseBoundary{}, Nil{}, Nil{}, 0, 0,
        section_block_for(line) <>
          (note_block(List.reverse(&2, SrcLine, note_lines), start, cur_end) <> out)}
    case False{} False{}:
      ParseState{ParseNoteMode{}, Nil{}, line <> note_lines,
        start, src_line_end(line), out}

def parse_lines_go(lines: List<&2, SrcLine>, mode: ParseMode,
    +step_lines: List<&2, SrcLine>, note_lines: List<&2, SrcLine>,
    +start: U32, +end: U32, out: List<&2, Model.CookBlock>) -> List<&2, Model.CookBlock>:
  match lines:
    case Nil{}:
      finish_parse_state(mode, step_lines, note_lines, start, end, out)
    case +line <> +rest:
      match mode:
        case ParseBoundary{}:
          +st = boundary_state(line, out,
            blank_raw_line(src_line_text(line)), starts_char(src_line_text(line), '='),
            starts_char(src_line_text(line), '>'))
          parse_lines_go(rest, ps_mode(st), ps_step_lines(st), ps_note_lines(st),
            ps_start(st), ps_end(st), ps_out(st))
        case ParseStepMode{}:
          +protected = Bool.and(step_prefix_inside_block(step_lines), rest_has_block_close(rest))
          +blank = Bool.and(blank_raw_line(src_line_text(line)), Bool.not(protected))
          +section = Bool.and(starts_char(src_line_text(line), '='), Bool.not(protected))
          +st = step_state(line, step_lines, out, start, end, blank, section)
          parse_lines_go(rest, ps_mode(st), ps_step_lines(st), ps_note_lines(st),
            ps_start(st), ps_end(st), ps_out(st))
        case ParseNoteMode{}:
          +st = note_state(line, note_lines, out, start, end,
            blank_raw_line(src_line_text(line)), starts_char(src_line_text(line), '='))
          parse_lines_go(rest, ps_mode(st), ps_step_lines(st), ps_note_lines(st),
            ps_start(st), ps_end(st), ps_out(st))

# Nest blocks after a section header inside that section.  Sections are flat
# in Cooklang; a new header closes the previous one.
def close_section(has: Bool, +name: String, +span: Ast.Span,
    blocks_rev: List<&2, Model.CookBlock>, out: List<&2, Model.CookBlock>) -> List<&2, Model.CookBlock>:
  match has:
    case False{}:
      out
    case True{}:
      Model.CookSection{name, List.reverse(&2, Model.CookBlock, blocks_rev), span} <> out

def group_sections_go(xs: List<&2, Model.CookBlock>, has: Bool,
    +name: String, +span: Ast.Span, blocks_rev: List<&2, Model.CookBlock>,
    out: List<&2, Model.CookBlock>) -> List<&2, Model.CookBlock>:
  match xs:
    case Nil{}:
      List.reverse(&2, Model.CookBlock,
        close_section(has, name, span, blocks_rev, out))
    case h <> t:
      match h:
        case Model.CookSection{+newname, newblocks, +newspan}:
          group_sections_go(t, True{}, newname, newspan, Nil{},
            close_section(has, name, span, blocks_rev, out))
        case other:
          match has:
            case False{}:
              group_sections_go(t, has, name, span, blocks_rev, other <> out)
            case True{}:
              group_sections_go(t, has, name, span, other <> blocks_rev, out)

def group_sections(xs: List<&2, Model.CookBlock>) -> List<&2, Model.CookBlock>:
  group_sections_go(xs, False{}, SNil{}, Ast.Span{0, 0}, Nil{}, Nil{})

def parse_body_blocks(+body: String, +base: U32) -> List<&2, Model.CookBlock>:
  group_sections(parse_lines_go(split_lines(body, base), ParseBoundary{},
    Nil{}, Nil{}, 0, 0, Nil{}))

def parse_body_recipe(+body: String, +base: U32, fm: Maybe<&2, Model.Frontmatter>) -> Model.Recipe:
  Model.Recipe{fm, parse_body_blocks(body, base)}

def finish_recipe(scan: FMScan, +source: String) -> Model.Recipe:
  match scan:
    case FMScan{+found, +raw, +body, +span_end}:
      ck_if(Model.Recipe, found,
        u => parse_body_recipe(body, span_end,
          Some{Model.Frontmatter{raw, Ast.Span{0, span_end}}}),
        u => parse_body_recipe(source, 0, None{}))

# Public entry points.
def parse_cooklang(+source: String) -> Model.Recipe:
  finish_recipe(frontmatter_from_first(source, split_line(source)), source)

def parse_cooklang_bounded(+source: String, +max_input_bytes: Nat) -> Maybe<&2, Model.Recipe>:
  ck_if(Maybe<&2, Model.Recipe>, Nat.is_le(Text.utf8_length(source), max_input_bytes),
    u => Some{parse_cooklang(source)},
    u => None{})
