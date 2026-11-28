import Base
import ./ast.bend as Ast
import ./document_links.bend as DocumentLinks
import ./text.bend as Text


def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# A line-indexed map from Markdown parser spans to original-input UTF-8 byte
# offsets.  Markdown parsing normalizes CRLF/CR line endings to LF and blanks
# reference definitions during the block phase without changing source bytes.
# Consequently parser spans are byte offsets in that newline-normalized form.  Within each
# physical line newline normalization is byte-preserving; only line endings can
# shift later offsets, so line-start pairs are sufficient for exact inverse
# newline mapping.  Build the map from the same original input passed to the
# parser.  This cannot repair positions that were approximate before mapping
# (for example container block spans that describe stripped content rather
# than the complete marker-inclusive source extent).
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


def source_map_original_maybe_span(+map: SourceMap,
  m: Maybe<&2, Ast.Span>) -> Maybe<&2, Ast.Span>:
  match m:
    case Some{+span}:
      Some{source_map_original_span(map, span)}
    case None{}:
      None{}

# Map every part of Markdown link destination provenance from parser coordinates
# to original-input UTF-8 byte offsets.  For reference links this includes both
# the destination inside the definition and the whole definition span; the use
# site is carried separately by DocumentLink.span.
def source_map_original_link_destination(+map: SourceMap,
  x: Ast.LinkDestination) -> Ast.LinkDestination:
  match x:
    case Ast.LinkDestination{raw, logical, span, definition_span}:
      Ast.LinkDestination{raw, logical, source_map_original_span(map, span),
        source_map_original_maybe_span(map, definition_span)}

def source_map_original_link_destination_maybe(+map: SourceMap,
  m: Maybe<&2, Ast.LinkDestination>) -> Maybe<&2, Ast.LinkDestination>:
  match m:
    case Some{+x}:
      Some{source_map_original_link_destination(map, x)}
    case None{}:
      None{}

# Map a document link's whole-node span and destination provenance in one step.
# `target`, `kind`, and the lexical/logical destination strings are unchanged.
def source_map_original_document_link(+map: SourceMap,
  x: DocumentLinks.DocumentLink) -> DocumentLinks.DocumentLink:
  match x:
    case DocumentLinks.DocumentLink{target, span, kind, destination}:
      DocumentLinks.DocumentLink{target, source_map_original_span(map, span), kind,
        source_map_original_link_destination_maybe(map, destination)}

def source_map_original_document_links_go(+map: SourceMap,
  xs: List<&2, DocumentLinks.DocumentLink>,
  +acc: List<&2, DocumentLinks.DocumentLink>) -> List<&2, DocumentLinks.DocumentLink>:
  match xs:
    case Nil{}:
      List.reverse(&2, DocumentLinks.DocumentLink, acc)
    case h <> t:
      source_map_original_document_links_go(map, t,
        source_map_original_document_link(map, h) <> acc)

def source_map_original_document_links(+map: SourceMap,
  xs: List<&2, DocumentLinks.DocumentLink>) -> List<&2, DocumentLinks.DocumentLink>:
  source_map_original_document_links_go(map, xs, Nil{})
