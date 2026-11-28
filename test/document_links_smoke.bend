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
    case SCon{'\t', t}:
      "\\t" ++ esc(t)
    case SCon{h, t}:
      SCon{h, esc(t)}

def q(s: String) -> String:
  "\"" ++ esc(s) ++ "\""

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      "@" ++ U32.show(start) ++ "-" ++ U32.show(end)

def show_kind(kind: DocumentLinks.DocumentLinkKind) -> String:
  match kind:
    case DocumentLinks.DocumentLinkInline{}:
      "inline"
    case DocumentLinks.DocumentLinkAutolink{}:
      "autolink"
    case DocumentLinks.DocumentLinkImage{}:
      "image"

def show_link(+x: DocumentLinks.DocumentLink) -> String:
  show_kind(DocumentLinks.document_link_kind(x)) ++ "(" ++ q(DocumentLinks.document_link_target(x)) ++ ")" ++
    show_span(DocumentLinks.document_link_span(x))

def show_links(xs: List<&2, DocumentLinks.DocumentLink>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      show_link(h) ++ ";" ++ show_links(t)

def show_strs(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      q(h) ++ ";" ++ show_strs(t)

def markdown_nested() -> String:
  "[head](head.md)\n\nintro [a](a.md) <https://example.com> ![pix](img.png) and *[em](em.md)*\n\n> quote [q](q.md)\n\n- item [i](i.md)\n"

def markdown_nested_link_label() -> String:
  "[![alt](img.png)](outer.md)\n"

def markdown_nested_continuation_order() -> String:
  "[a](a.md) *em [b](b.md)* [c](c.md)\n\n> quote [q](q.md)\n\n- item [i](i.md)\n- item [j](j.md)\n"

def no_inlines() -> List<&2, Ast.Inline>:
  {[] : List<&2, Ast.Inline>}

def one_inline(x: Ast.Inline) -> List<&2, Ast.Inline>:
  x <> Nil{}

def no_attrs() -> List<&2, Ast.Attr>:
  {[] : List<&2, Ast.Attr>}

def no_alignments() -> List<&2, Ast.Alignment>:
  {[] : List<&2, Ast.Alignment>}

def inline_link(children: List<&2, Ast.Inline>, +target: String, span: Ast.Span) -> Ast.Inline:
  Ast.ILink{children, target, None{}, span, None{}}

def image_inline(+target: String, +alt: String, span: Ast.Span) -> Ast.Inline:
  Ast.IImage{target, alt, None{}, span, None{}}

def heading_block(children: List<&2, Ast.Inline>, span: Ast.Span) -> Ast.Block:
  Ast.BHeading{1, children, no_attrs(), span}

def table_cell(children: List<&2, Ast.Inline>, span: Ast.Span) -> Ast.TableCell:
  Ast.TableCell{False{}, Ast.AlignNone{}, 1, 1, children, no_attrs(), span}

def two_cells(x: Ast.TableCell, y: Ast.TableCell) -> List<&2, Ast.TableCell>:
  x <> y <> Nil{}

def one_row(x: Ast.TableRow) -> List<&2, Ast.TableRow>:
  x <> Nil{}

def table_row(cells: List<&2, Ast.TableCell>, span: Ast.Span) -> Ast.TableRow:
  Ast.TableRow{cells, no_attrs(), span}

def table_block(rows: List<&2, Ast.TableRow>, span: Ast.Span) -> Ast.Block:
  Ast.BTable{no_alignments(), rows, span}

def one_block(x: Ast.Block) -> List<&2, Ast.Block>:
  x <> Nil{}

def synthetic_heading_doc() -> Ast.Document:
  link = inline_link(no_inlines(), "synthetic.md", Ast.Span{2, 22})
  heading = heading_block(one_inline(link), Ast.Span{0, 23})
  Ast.Document{one_block(heading)}

def synthetic_table_doc() -> Ast.Document:
  link = inline_link(no_inlines(), "cell.md", Ast.Span{4, 18})
  image = image_inline("pic.png", "pic", Ast.Span{21, 35})
  first = table_cell(one_inline(link), Ast.Span{3, 19})
  second = table_cell(one_inline(image), Ast.Span{20, 36})
  row = table_row(two_cells(first, second), Ast.Span{2, 37})
  table = table_block(one_row(row), Ast.Span{0, 40})
  Ast.Document{one_block(table)}

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

def markdown_links(+input: String) -> String:
  show_links(DocumentLinks.document_links(Markdown.parse_markdown(input)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- expect_equal("empty", "", markdown_links(""))
    Unit <- expect_equal("synthetic-heading-span",
      "inline(\"synthetic.md\")@2-22;",
      show_links(DocumentLinks.document_links(synthetic_heading_doc())))
    Unit <- expect_equal("markdown-order-spans",
      "inline(\"head.md\")@0-15;inline(\"a.md\")@23-32;autolink(\"https://example.com\")@33-54;image(\"img.png\")@55-70;inline(\"em.md\")@76-87;inline(\"q.md\")@98-107;inline(\"i.md\")@116-125;",
      markdown_links(markdown_nested()))
    Unit <- expect_equal("markdown-nested-link-label-preorder",
      "inline(\"outer.md\")@0-27;image(\"img.png\")@1-16;",
      markdown_links(markdown_nested_link_label()))
    Unit <- expect_equal("synthetic-table-cell-order-spans",
      "inline(\"cell.md\")@4-18;image(\"pic.png\")@21-35;",
      show_links(DocumentLinks.document_links(synthetic_table_doc())))
    Unit <- expect_equal("target-projection-order",
      "\"head.md\";\"a.md\";\"https://example.com\";\"img.png\";\"em.md\";\"q.md\";\"i.md\";",
      show_strs(DocumentLinks.document_link_targets(Markdown.parse_markdown(markdown_nested()))))
    Unit <- expect_equal("nested-continuation-target-order",
      "\"a.md\";\"b.md\";\"c.md\";\"q.md\";\"i.md\";\"j.md\";",
      show_strs(DocumentLinks.document_link_targets(Markdown.parse_markdown(markdown_nested_continuation_order()))))
    IO.print("document links smoke: all checks passed")
