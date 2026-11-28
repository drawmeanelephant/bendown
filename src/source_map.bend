import Base
import ./ast.bend as Ast
import ./text.bend as Text


def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# A line-indexed map from parser spans to original-input UTF-8 byte offsets.
# Markdown parsing normalizes CRLF/CR line endings to LF and blanks reference
# definitions without changing their byte length.  Consequently parser spans
# are exact byte offsets in that normalized form.  Within each physical line
# normalization is byte-preserving; only line endings can shift later offsets,
# so line-start pairs are sufficient for exact inverse mapping.
type SourceLineOffset is Data:
  SourceLineOffset{normalized_start: U32, original_start: U32}

def source_line_offset_mk(+normalized_start: U32, +original_start: U32) -> SourceLineOffset:
  SourceLineOffset{normalized_start, original_start}

def source_line_offset_normalized_start(x: SourceLineOffset) -> U32:
  match x:
    case SourceLineOffset{normalized_start, original_start}:
      normalized_start

def source_line_offset_original_start(x: SourceLineOffset) -> U32:
  match x:
    case SourceLineOffset{normalized_start, original_start}:
      original_start

type SourceMap is Data:
  SourceMap{lines: List<&2, SourceLineOffset>}

def source_map_lines(x: SourceMap) -> List<&2, SourceLineOffset>:
  match x:
    case SourceMap{lines}:
      lines

def source_map_scan_go(s: String, +acc: List<&2, SourceLineOffset>,
    +opos: U32, +npos: U32) -> List<&2, SourceLineOffset>:
  match s:
    case SNil{}:
      List.reverse(&2, SourceLineOffset, acc)
    case SCon{'\r', SCon{'\n', t}}:
      +nexto = U32.add(opos, 2)
      +nextn = U32.add(npos, 1)
      +line = source_line_offset_mk(nextn, nexto)
      source_map_scan_go(t, line <> acc, nexto, nextn)
    case SCon{'\r', t}:
      +nexto = U32.add(opos, 1)
      +nextn = U32.add(npos, 1)
      +line = source_line_offset_mk(nextn, nexto)
      source_map_scan_go(t, line <> acc, nexto, nextn)
    case SCon{+h, +t}:
      +width = Text.utf8_width(h)
      +step = U32.from_nat(width)
      source_map_scan_go(t, acc, U32.add(opos, step), U32.add(npos, step))

def source_map_from_original(+original: String) -> SourceMap:
  +first = source_line_offset_mk(0, 0)
  SourceMap{source_map_scan_go(original, first <> Nil{}, 0, 0)}

def source_map_find_line_go(xs: List<&2, SourceLineOffset>, +offset: U32,
    +best: SourceLineOffset) -> SourceLineOffset:
  match xs:
    case Nil{}:
      best
    case +h <> t:
      ifs(SourceLineOffset, U32.is_le(source_line_offset_normalized_start(h), offset),
        u => source_map_find_line_go(t, offset, h),
        u => best)

def source_map_original_offset(+map: SourceMap, +offset: U32) -> U32:
  +zero = source_line_offset_mk(0, 0)
  +line = source_map_find_line_go(source_map_lines(map), offset, zero)
  +inside = U32.sub(offset, source_line_offset_normalized_start(line))
  U32.add(source_line_offset_original_start(line), inside)

def source_map_original_span(+map: SourceMap, span: Ast.Span) -> Ast.Span:
  match span:
    case Ast.Span{start, end}:
      Ast.Span{source_map_original_offset(map, start),
        source_map_original_offset(map, end)}
