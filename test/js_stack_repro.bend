import Base
import ../src/parser/markdown.bend as Markdown
import ../src/ast.bend as Ast

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
