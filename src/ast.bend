import Base

type Span is Data:
  Span{start: U32, end: U32}

# Markdown destination provenance.  `raw` is the exact destination spelling
# inside any angle-bracket delimiters; `logical` is that spelling after
# Markdown backslash/entity decoding but before URI percent-encoding.  `span`
# addresses the raw spelling in the parser coordinate space.  For a link whose
# destination came from a reference definition, `definition_span` is the whole
# definition and `span` is the destination inside that definition; otherwise
# `definition_span` is absent and `span` is at the use site.
type LinkDestination is Data:
  LinkDestination{raw: String, logical: String, span: Span,
    definition_span: Maybe<&2, Span>}

def link_destination_raw(x: LinkDestination) -> String:
  match x:
    case LinkDestination{raw, logical, span, definition_span}:
      raw

def link_destination_logical(x: LinkDestination) -> String:
  match x:
    case LinkDestination{raw, logical, span, definition_span}:
      logical

def link_destination_span(x: LinkDestination) -> Span:
  match x:
    case LinkDestination{raw, logical, span, definition_span}:
      span

def link_destination_definition_span(x: LinkDestination) -> Maybe<&2, Span>:
  match x:
    case LinkDestination{raw, logical, span, definition_span}:
      definition_span

type Attr is Data:
  Attr{key: String, value: String}

type Alignment is Data:
  AlignNone{}
  AlignLeft{}
  AlignCenter{}
  AlignRight{}

type Inline is Data:
  IText{text: String, span: Span}
  ICode{text: String, span: Span}
  IEmph{children: List<&2, Inline>, span: Span}
  IStrong{children: List<&2, Inline>, span: Span}
  IBold{children: List<&2, Inline>, span: Span}
  IItalic{children: List<&2, Inline>, span: Span}
  IDeleted{children: List<&2, Inline>, span: Span}
  IInserted{children: List<&2, Inline>, span: Span}
  ISuperscript{children: List<&2, Inline>, span: Span}
  ISubscript{children: List<&2, Inline>, span: Span}
  ISpan{children: List<&2, Inline>, attrs: List<&2, Attr>, span: Span}
  ILink{children: List<&2, Inline>, href: String, title: Maybe<&2, String>, span: Span,
    destination: Maybe<&2, LinkDestination>}
  IImage{src: String, alt: String, title: Maybe<&2, String>, span: Span,
    destination: Maybe<&2, LinkDestination>}
  IAutolink{href: String, label: String, span: Span, destination: Maybe<&2, LinkDestination>}
  IRawHtml{text: String, span: Span}
  ISoftBreak{span: Span}
  IHardBreak{span: Span}
  IFootnoteRef{number: U32, span: Span}

type Block is Data:
  BParagraph{children: List<&2, Inline>, attrs: List<&2, Attr>, span: Span}
  BHeading{level: U32, children: List<&2, Inline>, attrs: List<&2, Attr>, span: Span}
  BThematicBreak{span: Span}
  BCodeBlock{text: String, info: Maybe<&2, String>, attrs: List<&2, Attr>, span: Span}
  BHtmlBlock{text: String, span: Span}
  BBlockQuote{blocks: List<&2, Block>, attrs: List<&2, Attr>, cite: Maybe<&2, String>, span: Span}
  BList{ordered: Bool, start: U32, tight: Bool, items: List<&2, ListItem>, span: Span}
  BTable{alignments: List<&2, Alignment>, rows: List<&2, TableRow>, span: Span}
  BRawPassthrough{text: String, span: Span}

type ListItem is Data:
  ListItem{blocks: List<&2, Block>, span: Span}

type TableRow is Data:
  TableRow{cells: List<&2, TableCell>, attrs: List<&2, Attr>, span: Span}

type TableCell is Data:
  TableCell{header: Bool, align: Alignment, colspan: U32, rowspan: U32,
    children: List<&2, Inline>, attrs: List<&2, Attr>, span: Span}

type Document is Data:
  Document{blocks: List<&2, Block>}

def span_empty() -> Span:
  Span{0, 0}

def document_empty() -> Document:
  Document{[]}
