import Base
import ./ast.bend as Ast

type DocumentLinkKind is Data:
  DocumentLinkInline{}
  DocumentLinkAutolink{}
  DocumentLinkImage{}

# A link-like node projected from a document.  `target` is the engine-normalized
# rendering target retained for compatibility.  `span` is the whole inline node
# at the use site in the producing parser's coordinate space.  `destination`
# carries lexical provenance when the parser can provide it: raw/logical forms
# before publication-policy normalization, the destination-specific span, and
# reference-definition provenance.  Synthetic ASTs and formats without that
# provenance may use None.
type DocumentLink is Data:
  DocumentLink{target: String, span: Ast.Span, kind: DocumentLinkKind,
    destination: Maybe<&2, Ast.LinkDestination>}

def document_link_target(x: DocumentLink) -> String:
  match x:
    case DocumentLink{target, span, kind, destination}:
      target

def document_link_span(x: DocumentLink) -> Ast.Span:
  match x:
    case DocumentLink{target, span, kind, destination}:
      span

def document_link_kind(x: DocumentLink) -> DocumentLinkKind:
  match x:
    case DocumentLink{target, span, kind, destination}:
      kind


def document_link_destination(x: DocumentLink) -> Maybe<&2, Ast.LinkDestination>:
  match x:
    case DocumentLink{target, span, kind, destination}:
      destination

def document_link_raw_target(x: DocumentLink) -> Maybe<&2, String>:
  match x:
    case DocumentLink{target, span, kind, destination}:
      match destination:
        case Some{+d}:
          Some{Ast.link_destination_raw(d)}
        case None{}:
          None{}

def document_link_logical_target(x: DocumentLink) -> Maybe<&2, String>:
  match x:
    case DocumentLink{target, span, kind, destination}:
      match destination:
        case Some{+d}:
          Some{Ast.link_destination_logical(d)}
        case None{}:
          None{}

def document_link_destination_span(x: DocumentLink) -> Maybe<&2, Ast.Span>:
  match x:
    case DocumentLink{target, span, kind, destination}:
      match destination:
        case Some{+d}:
          Some{Ast.link_destination_span(d)}
        case None{}:
          None{}

def document_link_definition_span(x: DocumentLink) -> Maybe<&2, Ast.Span>:
  match x:
    case DocumentLink{target, span, kind, destination}:
      match destination:
        case Some{+d}:
          Ast.link_destination_definition_span(d)
        case None{}:
          None{}

type DocumentLinkWork is Data:
  DlwInline{one: Ast.Inline}
  DlwInlines{xs: List<&2, Ast.Inline>}
  DlwBlock{one: Ast.Block}
  DlwBlocks{xs: List<&2, Ast.Block>}
  DlwItems{xs: List<&2, Ast.ListItem>}
  DlwRows{xs: List<&2, Ast.TableRow>}
  DlwCells{xs: List<&2, Ast.TableCell>}

def document_links_loop(+fuel: Nat, worklist: List<&2, DocumentLinkWork>, acc: List<&2, DocumentLink>) -> List<&2, DocumentLink>:
  match fuel:
    case 0n:
      List.reverse(&2, DocumentLink, acc)
    case 1n++f:
      match worklist:
        case Nil{}:
          List.reverse(&2, DocumentLink, acc)
        case work <> rest:
          match work:
            case DlwInlines{xs}:
              match xs:
                case Nil{}:
                  document_links_loop(f, rest, acc)
                case h <> t:
                  document_links_loop(f, DlwInline{h} <> DlwInlines{t} <> rest, acc)
            case DlwInline{one}:
              match one:
                case Ast.ILink{children, href, title, span, destination}:
                  document_links_loop(f, DlwInlines{children} <> rest,
                    DocumentLink{href, span, DocumentLinkInline{}, destination} <> acc)
                case Ast.IImage{src, alt, title, span, destination}:
                  document_links_loop(f, rest,
                    DocumentLink{src, span, DocumentLinkImage{}, destination} <> acc)
                case Ast.IAutolink{href, label, span, destination}:
                  document_links_loop(f, rest,
                    DocumentLink{href, span, DocumentLinkAutolink{}, destination} <> acc)
                case Ast.IEmph{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.IStrong{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.IBold{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.IItalic{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.IDeleted{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.IInserted{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.ISuperscript{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.ISubscript{children, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.ISpan{children, attrs, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case u:
                  document_links_loop(f, rest, acc)
            case DlwBlocks{xs}:
              match xs:
                case Nil{}:
                  document_links_loop(f, rest, acc)
                case h <> t:
                  document_links_loop(f, DlwBlock{h} <> DlwBlocks{t} <> rest, acc)
            case DlwBlock{one}:
              match one:
                case Ast.BParagraph{children, attrs, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.BHeading{level, children, attrs, span}:
                  document_links_loop(f, DlwInlines{children} <> rest, acc)
                case Ast.BBlockQuote{blocks, attrs, cite, span}:
                  document_links_loop(f, DlwBlocks{blocks} <> rest, acc)
                case Ast.BList{ordered, start, tight, items, span}:
                  document_links_loop(f, DlwItems{items} <> rest, acc)
                case Ast.BTable{alignments, rows, span}:
                  document_links_loop(f, DlwRows{rows} <> rest, acc)
                case u:
                  document_links_loop(f, rest, acc)
            case DlwItems{xs}:
              match xs:
                case Nil{}:
                  document_links_loop(f, rest, acc)
                case Ast.ListItem{blocks, ispan} <> t:
                  document_links_loop(f, DlwBlocks{blocks} <> DlwItems{t} <> rest, acc)
            case DlwRows{xs}:
              match xs:
                case Nil{}:
                  document_links_loop(f, rest, acc)
                case Ast.TableRow{cells, attrs, span} <> t:
                  document_links_loop(f, DlwCells{cells} <> DlwRows{t} <> rest, acc)
            case DlwCells{xs}:
              match xs:
                case Nil{}:
                  document_links_loop(f, rest, acc)
                case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span} <> t:
                  document_links_loop(f, DlwInlines{children} <> DlwCells{t} <> rest, acc)

def document_links_fuel() -> Nat:
  4294967295n

def document_links(doc: Ast.Document) -> List<&2, DocumentLink>:
  match doc:
    case Ast.Document{blocks}:
      document_links_loop(document_links_fuel(), DlwBlocks{blocks} <> Nil{}, Nil{})

def document_link_target_list_go(xs: List<&2, DocumentLink>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case h <> t:
      document_link_target_list_go(t, document_link_target(h) <> acc)

def document_link_target_list(xs: List<&2, DocumentLink>) -> List<&2, String>:
  document_link_target_list_go(xs, Nil{})

def document_link_targets(doc: Ast.Document) -> List<&2, String>:
  document_link_target_list(document_links(doc))
