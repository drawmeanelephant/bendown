import Base
import ./ast.bend as Ast

type DocumentLinkKind is Data:
  DocumentLinkInline{}
  DocumentLinkAutolink{}
  DocumentLinkImage{}

type DocumentLink is Data:
  DocumentLink{target: String, span: Ast.Span, kind: DocumentLinkKind}

def document_link_target(x: DocumentLink) -> String:
  match x:
    case DocumentLink{target, span, kind}:
      target

def document_link_span(x: DocumentLink) -> Ast.Span:
  match x:
    case DocumentLink{target, span, kind}:
      span

def document_link_kind(x: DocumentLink) -> DocumentLinkKind:
  match x:
    case DocumentLink{target, span, kind}:
      kind

type DocumentLinkWork is Data:
  DlwInline{one: Ast.Inline}
  DlwInlines{xs: List<&2, Ast.Inline>}
  DlwBlock{one: Ast.Block}
  DlwBlocks{xs: List<&2, Ast.Block>}
  DlwItems{xs: List<&2, Ast.ListItem>}
  DlwRows{xs: List<&2, Ast.TableRow>}
  DlwCells{xs: List<&2, Ast.TableCell>}

def document_link_cat(xs: List<&2, DocumentLink>, ys: List<&2, DocumentLink>) -> List<&2, DocumentLink>:
  List.append(&2, DocumentLink, xs, ys)

def document_links_work(+fuel: Nat, work: DocumentLinkWork) -> List<&2, DocumentLink>:
  match fuel:
    case 0n:
      Nil{}
    case 1n++f:
      match work:
        case DlwInlines{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case h <> t:
              document_link_cat(document_links_work(f, DlwInline{h}), document_links_work(f, DlwInlines{t}))
        case DlwInline{one}:
          match one:
            case Ast.ILink{children, href, title, span}:
              DocumentLink{href, span, DocumentLinkInline{}} <> document_links_work(f, DlwInlines{children})
            case Ast.IImage{src, alt, title, span}:
              DocumentLink{src, span, DocumentLinkImage{}} <> Nil{}
            case Ast.IAutolink{href, label, span}:
              DocumentLink{href, span, DocumentLinkAutolink{}} <> Nil{}
            case Ast.IEmph{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.IStrong{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.IBold{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.IItalic{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.IDeleted{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.IInserted{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.ISuperscript{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.ISubscript{children, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.ISpan{children, attrs, span}:
              document_links_work(f, DlwInlines{children})
            case u:
              Nil{}
        case DlwBlocks{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case h <> t:
              document_link_cat(document_links_work(f, DlwBlock{h}), document_links_work(f, DlwBlocks{t}))
        case DlwBlock{one}:
          match one:
            case Ast.BParagraph{children, attrs, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.BHeading{level, children, attrs, span}:
              document_links_work(f, DlwInlines{children})
            case Ast.BBlockQuote{blocks, attrs, cite, span}:
              document_links_work(f, DlwBlocks{blocks})
            case Ast.BList{ordered, start, tight, items, span}:
              document_links_work(f, DlwItems{items})
            case Ast.BTable{alignments, rows, span}:
              document_links_work(f, DlwRows{rows})
            case u:
              Nil{}
        case DlwItems{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.ListItem{blocks, ispan} <> t:
              document_link_cat(document_links_work(f, DlwBlocks{blocks}), document_links_work(f, DlwItems{t}))
        case DlwRows{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.TableRow{cells, attrs, span} <> t:
              document_link_cat(document_links_work(f, DlwCells{cells}), document_links_work(f, DlwRows{t}))
        case DlwCells{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span} <> t:
              document_link_cat(document_links_work(f, DlwInlines{children}), document_links_work(f, DlwCells{t}))

def document_links_fuel() -> Nat:
  4294967295n

def document_links(doc: Ast.Document) -> List<&2, DocumentLink>:
  match doc:
    case Ast.Document{blocks}:
      document_links_work(document_links_fuel(), DlwBlocks{blocks})

def document_link_target_list(xs: List<&2, DocumentLink>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      document_link_target(h) <> document_link_target_list(t)

def document_link_targets(doc: Ast.Document) -> List<&2, String>:
  document_link_target_list(document_links(doc))
