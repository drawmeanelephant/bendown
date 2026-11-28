import Base
import ../src/parser/markdown.bend as Markdown
import ../src/ast.bend as Ast
import ../src/document_links.bend as DocumentLinks

def count_blocks_go(xs: List<&2, Ast.Block>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      count_blocks_go(t, 1n+acc)

def count_blocks(+xs: List<&2, Ast.Block>) -> Nat:
  count_blocks_go(xs, 0n)

def parse_ok_doc(doc: Ast.Document) -> Bool:
  match doc:
    case Ast.Document{blocks}:
      Nat.is_gt(count_blocks(blocks), 0n)

def parse_ok(+source: String) -> Bool:
  parse_ok_doc(Markdown.parse_markdown(source))

def count_document_links_go(xs: List<&2, DocumentLinks.DocumentLink>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      count_document_links_go(t, 1n+acc)

def count_document_links(+source: String) -> Nat:
  count_document_links_go(DocumentLinks.document_links(Markdown.parse_markdown(source)), 0n)

type DocumentLinksStackProbe is Data:
  DocumentLinksStackProbe{links: Nat, targets: Nat}

def count_strings_go(xs: List<&2, String>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case h <> t:
      count_strings_go(t, 1n+acc)

def document_links_stack_probe(+source: String) -> DocumentLinksStackProbe:
  +doc = Markdown.parse_markdown(source)
  DocumentLinksStackProbe{
    count_document_links_go(DocumentLinks.document_links(doc), 0n),
    count_strings_go(DocumentLinks.document_link_targets(doc), 0n)}
