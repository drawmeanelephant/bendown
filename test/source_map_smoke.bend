import Base
import ../src/ast.bend as Ast
import ../src/source_map.bend as SourceMap
import ../src/document_links.bend as DocumentLinks
import ../src/parser/markdown.bend as Markdown

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      U32.show(start) ++ "-" ++ U32.show(end)

def show_maybe_span(m: Maybe<&2, Ast.Span>) -> String:
  match m:
    case Some{x}:
      "Some(" ++ show_span(x) ++ ")"
    case None{}:
      "None"

def show_mapped_first(links: List<&2, DocumentLinks.DocumentLink>, +map: SourceMap.SourceMap) -> String:
  match links:
    case Nil{}:
      "missing"
    case +h <> t:
      +mapped = SourceMap.source_map_original_document_link(map, h)
      show_span(DocumentLinks.document_link_span(mapped)) ++ "|dest=" ++
        show_maybe_span(DocumentLinks.document_link_destination_span(mapped)) ++ "|def=" ++
        show_maybe_span(DocumentLinks.document_link_definition_span(mapped))

def show_mapped_first_input(+input: String) -> String:
  show_mapped_first(DocumentLinks.document_links(Markdown.parse_markdown(input)),
    SourceMap.source_map_from_original(input))

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
    +crlf : String = "[x]: target.md\r\n\r\n[use][x]\r\n"
    +crlfmap : SourceMap.SourceMap = SourceMap.source_map_from_original(crlf)
    Unit <- expect_equal("crlf-normalized-use-start",
      "18", U32.show(SourceMap.source_map_original_offset(crlfmap, 16)))
    Unit <- expect_equal("crlf-normalized-use-span",
      "18-26", show_span(SourceMap.source_map_original_span(crlfmap, Ast.Span{16, 24})))
    Unit <- expect_equal("crlf-reference-destination-span",
      "5-14", show_span(SourceMap.source_map_original_span(crlfmap, Ast.Span{5, 14})))
    +lfmap : SourceMap.SourceMap = SourceMap.source_map_from_original("alpha\nbeta")
    Unit <- expect_equal("lf-offset-identity",
      "8", U32.show(SourceMap.source_map_original_offset(lfmap, 8)))
    Unit <- expect_equal("mixed-newline-unicode-document-link-original-spans",
      "6-20|dest=Some(10-19)|def=None",
      show_mapped_first_input("é\r\na\n[x](target.md)\r\n"))
    Unit <- expect_equal("crlf-reference-document-link-original-spans",
      "18-26|dest=Some(5-14)|def=Some(0-14)",
      show_mapped_first_input("[x]: target.md\r\n\r\n[use][x]\r\n"))
    Unit <- expect_equal("crlf-quote-continuation-document-link-original-spans",
      "8-22|dest=Some(12-21)|def=None",
      show_mapped_first_input("> aa\r\n> [x](target.md)\r\n"))
    Unit <- expect_equal("crlf-blockquote-reference-document-link-original-spans",
      "0-8|dest=Some(19-21)|def=Some(14-21)",
      show_mapped_first_input("[use][x]\r\n\r\n> [x]: /u\r\n"))
    Unit <- expect_equal("crlf-blockquote-partial-tab-reference-original-spans",
      "13-21|dest=Some(7-9)|def=Some(2-9)",
      show_mapped_first_input(">\t[x]: /u\r\n\r\n[use][x]\r\n"))
    IO.print("source map smoke: all checks passed")
