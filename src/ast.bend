import Base

type Span is Data:
  Span{start: U32, end: U32}

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
  ILink{children: List<&2, Inline>, href: String, title: Maybe<&2, String>, span: Span}
  IImage{src: String, alt: String, title: Maybe<&2, String>, span: Span}
  IAutolink{href: String, label: String, span: Span}
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
