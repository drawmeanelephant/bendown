import Base
import ../src/ast.bend as Ast
import ../src/render/html.bend as Html

type RewriteCfg is Data:
  RewriteCfg{prefix: String}

def rewrite_with_prefix(ctx: RewriteCfg, target: String) -> String:
  match ctx:
    case RewriteCfg{prefix}:
      prefix ++ target

def check_fin(+name: String, +actual: String, +expected: String, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      do IO<Unit>:
        IO.print("FAIL " ++ name)
        IO.print("expected: " ++ String.quote(expected))
        IO.print("actual:   " ++ String.quote(actual))
        IO.die(Unit, 1, "render link rewrite smoke test failed")

def check(+name: String, +actual: String, +expected: String) -> IO(Unit):
  check_fin(name, actual, expected, String.eq(actual, expected))

def one_inline(x: Ast.Inline) -> List<&2, Ast.Inline>:
  x <> Nil{}

def no_attrs() -> List<&2, Ast.Attr>:
  {[] : List<&2, Ast.Attr>}

def no_alignments() -> List<&2, Ast.Alignment>:
  {[] : List<&2, Ast.Alignment>}

def one_block(x: Ast.Block) -> List<&2, Ast.Block>:
  x <> Nil{}

def four_blocks(a: Ast.Block, b: Ast.Block, c: Ast.Block, d: Ast.Block) -> List<&2, Ast.Block>:
  a <> b <> c <> d <> Nil{}

def one_item(x: Ast.ListItem) -> List<&2, Ast.ListItem>:
  x <> Nil{}

def one_cell(x: Ast.TableCell) -> List<&2, Ast.TableCell>:
  x <> Nil{}

def one_row(x: Ast.TableRow) -> List<&2, Ast.TableRow>:
  x <> Nil{}

def text_inline(+text: String) -> Ast.Inline:
  Ast.IText{text, Ast.span_empty()}

def some_string(+x: String) -> Maybe<&2, String>:
  Some{x}

def no_string() -> Maybe<&2, String>:
  None{}

def inline_link(children: List<&2, Ast.Inline>, +target: String,
  title: Maybe<&2, String>, span: Ast.Span) -> Ast.Inline:
  Ast.ILink{children, target, title, span}

def autolink_inline(+href: String, +label: String, span: Ast.Span) -> Ast.Inline:
  Ast.IAutolink{href, label, span}

def image_inline(+src: String, +alt: String, title: Maybe<&2, String>, span: Ast.Span) -> Ast.Inline:
  Ast.IImage{src, alt, title, span}

def emph_inline(children: List<&2, Ast.Inline>, span: Ast.Span) -> Ast.Inline:
  Ast.IEmph{children, span}

def blockquote_block(blocks: List<&2, Ast.Block>, cite: Maybe<&2, String>, span: Ast.Span) -> Ast.Block:
  Ast.BBlockQuote{blocks, no_attrs(), cite, span}

def list_item_block(blocks: List<&2, Ast.Block>, span: Ast.Span) -> Ast.ListItem:
  Ast.ListItem{blocks, span}

def tight_bullet_list(items: List<&2, Ast.ListItem>, span: Ast.Span) -> Ast.Block:
  Ast.BList{False{}, 1, True{}, items, span}

def table_cell_block(children: List<&2, Ast.Inline>, span: Ast.Span) -> Ast.TableCell:
  Ast.TableCell{False{}, Ast.AlignNone{}, 1, 1, children, no_attrs(), span}

def table_row_block(cells: List<&2, Ast.TableCell>, span: Ast.Span) -> Ast.TableRow:
  Ast.TableRow{cells, no_attrs(), span}

def table_block(rows: List<&2, Ast.TableRow>, span: Ast.Span) -> Ast.Block:
  Ast.BTable{no_alignments(), rows, span}

def paragraph_block(children: List<&2, Ast.Inline>) -> Ast.Block:
  Ast.BParagraph{children, no_attrs(), Ast.span_empty()}

def rewrite_test_document() -> Ast.Document:
  top_link = inline_link(one_inline(text_inline("top")), "top.md", some_string("top-title"), Ast.span_empty())
  top = paragraph_block(one_inline(top_link))

  autolink = autolink_inline("quote.md", "quote-label", Ast.span_empty())
  quote_body = paragraph_block(one_inline(autolink))
  quote = blockquote_block(one_block(quote_body), some_string("cite.md"), Ast.span_empty())

  image = image_inline("image.png", "alt&", some_string("image-title"), Ast.span_empty())
  image_body = paragraph_block(one_inline(image))
  item = list_item_block(one_block(image_body), Ast.span_empty())
  list = tight_bullet_list(one_item(item), Ast.span_empty())

  cell_link = inline_link(one_inline(text_inline("cell")), "cell.md", no_string(), Ast.span_empty())
  cell_emph = emph_inline(one_inline(cell_link), Ast.span_empty())
  cell = table_cell_block(one_inline(cell_emph), Ast.span_empty())
  row = table_row_block(one_cell(cell), Ast.span_empty())
  table = table_block(one_row(row), Ast.span_empty())

  Ast.Document{four_blocks(top, quote, list, table)}

def rewritten_with_prefix(+prefix: String, document: Ast.Document) -> String:
  Html.render_document_with_link_rewrite(~RewriteCfg, ~rewrite_with_prefix,
    RewriteCfg{prefix}, document)

def identity_rewritten(document: Ast.Document) -> String:
  Html.render_document_with_link_rewrite(~Unit, ~Html.identity_link_rewrite, Unit{}, document)

def nested_expected() -> String:
  "<p><a href=\"/site/?k=1&amp;v=top.md\" title=\"top-title\">top</a></p>\n" ++
    "<blockquote cite=\"cite.md\">\n" ++
    "<p><a href=\"/site/?k=1&amp;v=quote.md\">quote-label</a></p>\n" ++
    "</blockquote>\n" ++
    "<ul>\n" ++
    "<li><img src=\"/site/?k=1&amp;v=image.png\" alt=\"alt&amp;\" title=\"image-title\" /></li>\n" ++
    "</ul>\n" ++
    "<table>\n" ++
    "<tr><td><em><a href=\"/site/?k=1&amp;v=cell.md\">cell</a></em></td></tr>\n" ++
    "</table>\n"

def main() -> IO(Unit):
  do IO<Unit>:
    check("rewrite-reaches-nested-containers",
      rewritten_with_prefix("/site/?k=1&v=", rewrite_test_document()),
      nested_expected())

    check("identity-matches-ordinary-renderer",
      identity_rewritten(rewrite_test_document()),
      Html.render_document(rewrite_test_document()))

    IO.print("render link rewrite smoke: all checks passed")

#|PASS rewrite-reaches-nested-containers
#|PASS identity-matches-ordinary-renderer
#|render link rewrite smoke: all checks passed
