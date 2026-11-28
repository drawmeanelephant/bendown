import Base
import ../src/parser/markdown.bend as Markdown
import ../src/ast.bend as Ast

def parse_ok_doc(doc: Ast.Document) -> Bool:
  match doc:
    case Ast.Document{blocks}:
      True{}

def parse_ok(+source: String) -> Bool:
  parse_ok_doc(Markdown.parse_markdown(source))
