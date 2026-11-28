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
      "\"a%20b.md\"|raw=Some(\"<a b.md>\")|logical=Some(\"a b.md\")|use=0-23|dest=Some(14-22)|def=None",
      show_first("[Angle space](<a b.md>)"))
    Unit <- expect_equal("entity-destination-provenance",
      "\"a&b.md\"|raw=Some(\"a&amp;b.md\")|logical=Some(\"a&b.md\")|use=0-20|dest=Some(9-19)|def=None",
      show_first("[Entity](a&amp;b.md)"))
    Unit <- expect_equal("html5-named-entity-destination-provenance",
      "\"a%E2%80%A6b.md\"|raw=Some(\"a&hellip;b.md\")|logical=Some(\"a…b.md\")|use=0-18|dest=Some(4-17)|def=None",
      show_first("[x](a&hellip;b.md)"))
    Unit <- expect_equal("unicode-angle-destination-provenance",
      "\"%C3%A9.md\"|raw=Some(\"<é.md>\")|logical=Some(\"é.md\")|use=0-24|dest=Some(16-23)|def=None",
      show_first("[Unicode angle](<é.md>)"))
    Unit <- expect_equal("percent-encoded-destination-provenance",
      "\"%2E%2E/x.md\"|raw=Some(\"%2E%2E/x.md\")|logical=Some(\"%2E%2E/x.md\")|use=0-26|dest=Some(14-25)|def=None",
      show_first("[Encoded dot](%2E%2E/x.md)"))
    Unit <- expect_equal("reference-destination-provenance",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=16-24|dest=Some(5-14)|def=Some(0-14)",
      show_first("[x]: target.md\n\n[use][x]"))
    Unit <- expect_equal("angle-spelling-is-exact",
      "\"a.md\"|raw=Some(\"<a.md>\")|logical=Some(\"a.md\")|use=0-11|dest=Some(4-10)|def=None",
      show_first("[x](<a.md>)"))
    Unit <- expect_equal("image-angle-destination-provenance",
      "\"a%20b.md\"|raw=Some(\"<a b.md>\")|logical=Some(\"a b.md\")|use=0-16|dest=Some(7-15)|def=None",
      show_first("![alt](<a b.md>)"))
    Unit <- expect_equal("shortcut-reference-provenance",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=16-19|dest=Some(5-14)|def=Some(0-14)",
      show_first("[x]: target.md\n\n[x]"))
    Unit <- expect_equal("collapsed-reference-provenance",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=16-21|dest=Some(5-14)|def=Some(0-14)",
      show_first("[x]: target.md\n\n[x][]"))
    Unit <- expect_equal("reference-angle-entity-provenance",
      "\"a&%C3%A9.md\"|raw=Some(\"<a&amp;é.md>\")|logical=Some(\"a&é.md\")|use=20-28|dest=Some(5-18)|def=Some(0-18)",
      show_first("[x]: <a&amp;é.md>\n\n[use][x]"))
    Unit <- expect_equal("email-autolink-logical-target",
      "\"mailto:user@example.com\"|raw=Some(\"user@example.com\")|logical=Some(\"mailto:user@example.com\")|use=0-18|dest=Some(1-17)|def=None",
      show_first("<user@example.com>"))
    Unit <- expect_equal("atx-heading-link-original-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=2-16|dest=Some(6-15)|def=None",
      show_first("# [x](target.md)"))
    Unit <- expect_equal("paragraph-leading-indent-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=2-16|dest=Some(6-15)|def=None",
      show_first("  [x](target.md)"))
    Unit <- expect_equal("paragraph-continuation-indent-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=5-19|dest=Some(9-18)|def=None",
      show_first("aa\n  [x](target.md)"))
    Unit <- expect_equal("quote-continuation-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=7-21|dest=Some(11-20)|def=None",
      show_first("> aa\n> [x](target.md)"))
    Unit <- expect_equal("quote-continuation-without-space-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=6-20|dest=Some(10-19)|def=None",
      show_first("> aa\n>[x](target.md)"))
    Unit <- expect_equal("quote-partial-tab-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=2-16|dest=Some(6-15)|def=None",
      show_first(">\t[x](target.md)"))
    Unit <- expect_equal("quote-partial-tab-heading-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=4-18|dest=Some(8-17)|def=None",
      show_first(">\t# [x](target.md)"))
    Unit <- expect_equal("list-continuation-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=7-21|dest=Some(11-20)|def=None",
      show_first("- aa\n  [x](target.md)"))
    Unit <- expect_equal("quote-multiline-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=2-27|dest=Some(17-26)|def=None",
      show_first("> [long\n> label](target.md)"))
    Unit <- expect_equal("inline-newline-before-destination",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=0-15|dest=Some(5-14)|def=None",
      show_first("[x](\ntarget.md)"))
    Unit <- expect_equal("hard-break-then-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=5-19|dest=Some(9-18)|def=None",
      show_first("aa  \n[x](target.md)"))
    Unit <- expect_equal("lazy-quote-continuation-link-spans",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=8-22|dest=Some(12-21)|def=None",
      show_first("> aa\nbb [x](target.md)"))
    Unit <- expect_equal("unicode-reference-byte-preserving-strip",
      "\"%C3%A9%20target.md\"|raw=Some(\"<é target.md>\")|logical=Some(\"é target.md\")|use=24-35|dest=Some(8-22)|def=Some(0-22)",
      show_first("[éé]: <é target.md>\n\n[use][éé]"))
    Unit <- expect_equal("multiline-reference-byte-preserving-strip",
      "\"target.md\"|raw=Some(\"target.md\")|logical=Some(\"target.md\")|use=29-37|dest=Some(5-14)|def=Some(0-27)",
      show_first("[x]: target.md\n  \"é title\"\n\n[use][x]"))
    Unit <- expect_equal("empty-angle-reference-provenance",
      "\"\"|raw=Some(\"<>\")|logical=Some(\"\")|use=9-17|dest=Some(5-7)|def=Some(0-7)",
      show_first("[x]: <>\n\n[use][x]"))
    Unit <- expect_equal("html-block-literal-is-not-reference",
      "missing",
      show_first("<div>\n[x]: /url\n\n[x]\n"))
    Unit <- expect_equal("closed-html-block-literal-is-not-reference",
      "missing",
      show_first("<script>\n[x]: /url\n</script>\n\n[x]\n"))
    Unit <- expect_equal("reference-after-html-block-still-works",
      "\"/url\"|raw=Some(\"/url\")|logical=Some(\"/url\")|use=20-23|dest=Some(14-18)|def=Some(9-18)",
      show_first("<div>\nx\n\n[x]: /url\n\n[x]\n"))
    Unit <- expect_equal("blockquote-reference-provenance",
      "\"/u\"|raw=Some(\"/u\")|logical=Some(\"/u\")|use=0-8|dest=Some(17-19)|def=Some(12-19)",
      show_first("[use][x]\n\n> [x]: /u\n"))
    Unit <- expect_equal("list-reference-provenance",
      "\"/u\"|raw=Some(\"/u\")|logical=Some(\"/u\")|use=0-8|dest=Some(17-19)|def=Some(12-19)",
      show_first("[use][x]\n\n- [x]: /u\n"))
    Unit <- expect_equal("nested-blockquote-reference-provenance",
      "\"/u\"|raw=Some(\"/u\")|logical=Some(\"/u\")|use=0-8|dest=Some(19-21)|def=Some(14-21)",
      show_first("[use][x]\n\n> > [x]: /u\n"))
    Unit <- expect_equal("blockquote-multiline-reference-provenance",
      "\"/u\"|raw=Some(\"/u\")|logical=Some(\"/u\")|use=0-8|dest=Some(17-19)|def=Some(12-27)",
      show_first("[use][x]\n\n> [x]: /u\n>   \"t\"\n"))
    Unit <- expect_equal("blockquote-next-line-destination-provenance",
      "\"/u\"|raw=Some(\"/u\")|logical=Some(\"/u\")|use=0-8|dest=Some(19-21)|def=Some(12-21)",
      show_first("[use][x]\n\n> [x]:\n> /u\n"))
    IO.print("document link provenance smoke: all checks passed")
