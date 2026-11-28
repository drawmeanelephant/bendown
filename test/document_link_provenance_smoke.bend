import Base
import ../src/ast.bend as Ast
import ../src/document_links.bend as DocumentLinks
import ../src/parser/markdown.bend as Markdown

def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\\', t}:
      "\\\\" ++ esc(t)
    case SCon{'\n', t}:
      "\\n" ++ esc(t)
    case SCon{'"', t}:
      "\\\"" ++ esc(t)
    case SCon{h, t}:
      SCon{h, esc(t)}

def q(s: String) -> String:
  "\"" ++ esc(s) ++ "\""

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      U32.show(start) ++ "-" ++ U32.show(end)

def show_maybe_string(m: Maybe<&2, String>) -> String:
  match m:
    case Some{x}:
      "Some(" ++ q(x) ++ ")"
    case None{}:
      "None"

def show_maybe_span(m: Maybe<&2, Ast.Span>) -> String:
  match m:
    case Some{x}:
      "Some(" ++ show_span(x) ++ ")"
    case None{}:
      "None"

def show_link(+x: DocumentLinks.DocumentLink) -> String:
  q(DocumentLinks.document_link_target(x)) ++ "|raw=" ++
    show_maybe_string(DocumentLinks.document_link_raw_target(x)) ++ "|logical=" ++
    show_maybe_string(DocumentLinks.document_link_logical_target(x)) ++ "|use=" ++
    show_span(DocumentLinks.document_link_span(x)) ++ "|dest=" ++
    show_maybe_span(DocumentLinks.document_link_destination_span(x)) ++ "|def=" ++
    show_maybe_span(DocumentLinks.document_link_definition_span(x))

def show_links_first(xs: List<&2, DocumentLinks.DocumentLink>) -> String:
  match xs:
    case Nil{}:
      "missing"
    case h <> t:
      show_link(h)

def show_first(+input: String) -> String:
  show_links_first(DocumentLinks.document_links(Markdown.parse_markdown(input)))

def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  ifs(IO(Unit), String.eq(expected, actual),
    u => IO.print("PASS " ++ name),
    u => IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected: " ++ expected ++ "\nactual:   " ++ actual))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- expect_equal("angle-destination-provenance",
      "\"a%20b.md\"|raw=Some(\"a b.md\")|logical=Some(\"a b.md\")|use=0-23|dest=Some(15-21)|def=None",
      show_first("[Angle space](<a b.md>)"))
    Unit <- expect_equal("entity-destination-provenance",
      "\"a&b.md\"|raw=Some(\"a&amp;b.md\")|logical=Some(\"a&b.md\")|use=0-20|dest=Some(9-19)|def=None",
      show_first("[Entity](a&amp;b.md)"))
    Unit <- expect_equal("unicode-angle-destination-provenance",
      "\"%C3%A9.md\"|raw=Some(\"é.md\")|logical=Some(\"é.md\")|use=0-24|dest=Some(17-22)|def=None",
      show_first("[Unicode angle](<é.md>)"))
    Unit <- expect_equal("percent-encoded-destination-provenance",
      "\"%2E%2E/x.md\"|raw=Some(\"%2E%2E/x.md\")|logical=Some(\"%2E%2E/x.md\")|use=0-26|dest=Some(14-25)|def=None",
      show_first("[Encoded dot](%2E%2E/x.md)"))
    Unit <- expect_equal("reference-destination-provenance",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=16-24|dest=Some(5-14)|def=Some(0-14)",
      show_first("[x]: target.md\n\n[use][x]"))
    IO.print("document link provenance smoke: all checks passed")
