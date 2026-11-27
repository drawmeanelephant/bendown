import Base
import ../src/ast.bend as Ast
import ../src/render/html.bend as Html

def check_fin(+name: String, +actual: String, +expected: String, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      do IO<Unit>:
        IO.print("FAIL " ++ name)
        IO.print("expected: " ++ String.quote(expected))
        IO.print("actual:   " ++ String.quote(actual))
        IO.die(Unit, 1, "render smoke test failed")

def check(+name: String, +actual: String, +expected: String) -> IO(Unit):
  check_fin(name, actual, expected, String.eq(actual, expected))

def text_block(text: String) -> Ast.Block:
  Ast.BParagraph{[Ast.IText{text, Ast.span_empty()}], [], Ast.span_empty()}

def main() -> IO(Unit):
  do IO<Unit>:
    check("empty-document",
      Html.render_document(Ast.Document{[]}),
      "")

    check("inline-emphasis",
      Html.render_inline(Ast.IEmph{[Ast.IText{"x", Ast.span_empty()}], Ast.span_empty()}),
      "<em>x</em>")

    check("inline-tags",
      Html.render_document(Ast.Document{[
        Ast.BParagraph{[
          Ast.IBold{[Ast.IText{"b", Ast.span_empty()}], Ast.span_empty()},
          Ast.IItalic{[Ast.IText{"i", Ast.span_empty()}], Ast.span_empty()},
          Ast.IDeleted{[Ast.IText{"d", Ast.span_empty()}], Ast.span_empty()},
          Ast.IInserted{[Ast.IText{"in", Ast.span_empty()}], Ast.span_empty()},
          Ast.ISuperscript{[Ast.IText{"sup", Ast.span_empty()}], Ast.span_empty()},
          Ast.ISubscript{[Ast.IText{"sub", Ast.span_empty()}], Ast.span_empty()},
          Ast.ISpan{[Ast.IText{"span", Ast.span_empty()}], [Ast.Attr{"class", "spc"}, Ast.Attr{"id", "sp"}], Ast.span_empty()},
          Ast.IAutolink{"https://a/?x=1&y=2", "A&", Ast.span_empty()}
        ], [], Ast.span_empty()}
      ]}),
      "<p><b>b</b><i>i</i><del>d</del><ins>in</ins><sup>sup</sup><sub>sub</sub><span class=\"spc\" id=\"sp\">span</span><a href=\"https://a/?x=1&amp;y=2\">A&amp;</a></p>\n")

    check("attribute-order-and-escaping",
      Html.render_document(Ast.Document{[
        Ast.BParagraph{
          [Ast.IText{"A&B <tag> \"q\"", Ast.span_empty()}],
          [
            Ast.Attr{"data-z", "last"},
            Ast.Attr{"lang", "en"},
            Ast.Attr{"id", "pid"},
            Ast.Attr{"class", "cls"},
            Ast.Attr{"style", "color:red"},
            Ast.Attr{"title", "T&\"<"}
          ],
          Ast.span_empty()
        }
      ]}),
      "<p style=\"color:red\" class=\"cls\" id=\"pid\" lang=\"en\" data-z=\"last\" title=\"T&amp;&quot;&lt;\">A&amp;B &lt;tag&gt; &quot;q&quot;</p>\n")

    check("control-replacement",
      Html.render_document(Ast.Document{[
        text_block(SCon{Chr{0}, SCon{'\t', SCon{Chr{31}, "x"}}})
      ]}),
      "<p>" ++ SCon{Chr{65533}, SCon{'\t', SCon{Chr{65533}, "x</p>\n"}}})

    check("inline-family",
      Html.render_document(Ast.Document{[
        Ast.BParagraph{[
          Ast.IStrong{[Ast.IText{"bold", Ast.span_empty()}], Ast.span_empty()},
          Ast.IText{" ", Ast.span_empty()},
          Ast.ICode{"a<b", Ast.span_empty()},
          Ast.IText{" ", Ast.span_empty()},
          Ast.ILink{[Ast.IText{"link", Ast.span_empty()}], "https://x/?a=1&b=2", Some{"ti\"tle"}, Ast.span_empty()},
          Ast.IText{" ", Ast.span_empty()},
          Ast.IImage{"im&g.png", "a\"b", None{}, Ast.span_empty()},
          Ast.ISoftBreak{Ast.span_empty()},
          Ast.IText{"after", Ast.span_empty()},
          Ast.IHardBreak{Ast.span_empty()},
          Ast.IFootnoteRef{7, Ast.span_empty()}
        ], [], Ast.span_empty()}
      ]}),
      "<p><strong>bold</strong> <code>a&lt;b</code> <a href=\"https://x/?a=1&amp;b=2\" title=\"ti&quot;tle\">link</a> <img src=\"im&amp;g.png\" alt=\"a&quot;b\" />\nafter<br />\n<sup class=\"footnote-ref\"><a href=\"#fn-7\">7</a></sup></p>\n")

    check("heading-code-quote-list-table",
      Html.render_document(Ast.Document{[
        Ast.BHeading{7, [Ast.IText{"H", Ast.span_empty()}], [], Ast.span_empty()},
        Ast.BThematicBreak{Ast.span_empty()},
        Ast.BCodeBlock{"if (a < b) {\n  c &= \"d\";\n}\n", Some{"c++"}, [Ast.Attr{"id", "code"}], Ast.span_empty()},
        Ast.BBlockQuote{[text_block("quote")], [], Some{"https://q/?a=1&b=2"}, Ast.span_empty()},
        Ast.BList{False{}, 1, True{}, [
          Ast.ListItem{[text_block("one")], Ast.span_empty()},
          Ast.ListItem{[
            text_block("two"),
            Ast.BList{True{}, 3, False{}, [
              Ast.ListItem{[text_block("nested")], Ast.span_empty()}
            ], Ast.span_empty()}
          ], Ast.span_empty()}
        ], Ast.span_empty()},
        Ast.BTable{[Ast.AlignLeft{}, Ast.AlignCenter{}, Ast.AlignRight{}], [
          Ast.TableRow{[
            Ast.TableCell{True{}, Ast.AlignNone{}, 1, 1, [Ast.IText{"H&", Ast.span_empty()}], [], Ast.span_empty()}
          ], [], Ast.span_empty()},
          Ast.TableRow{[
            Ast.TableCell{False{}, Ast.AlignRight{}, 2, 3, [Ast.IText{"V<", Ast.span_empty()}], [Ast.Attr{"data-k", "v"}], Ast.span_empty()},
            Ast.TableCell{False{}, Ast.AlignNone{}, 1, 1, [Ast.IText{"Z", Ast.span_empty()}], [], Ast.span_empty()}
          ], [Ast.Attr{"class", "body"}], Ast.span_empty()}
        ], Ast.span_empty()}
      ]}),
      "<h6>H</h6>\n" ++
        "<hr />\n" ++
        "<pre id=\"code\"><code class=\"language-c++\">if (a &lt; b) {\n  c &amp;= &quot;d&quot;;\n}\n</code></pre>\n" ++
        "<blockquote cite=\"https://q/?a=1&amp;b=2\">\n<p>quote</p>\n</blockquote>\n" ++
        "<ul>\n<li>one</li>\n<li>two\n<ol start=\"3\">\n<li>\n<p>nested</p>\n</li>\n</ol>\n</li>\n</ul>\n" ++
        "<table>\n<tr><th align=\"left\">H&amp;</th></tr>\n<tr class=\"body\"><td data-k=\"v\" align=\"right\" colspan=\"2\" rowspan=\"3\">V&lt;</td><td align=\"right\">Z</td></tr>\n</table>\n")

    check("html-verbatim",
      Html.render_document(Ast.Document{[
        Ast.BHtmlBlock{"<div x=\"1\">raw</div>\n\n", Ast.span_empty()},
        Ast.BRawPassthrough{"<b>pass</b>\n", Ast.span_empty()}
      ]}),
      "<div x=\"1\">raw</div>\n<b>pass</b>\n")

    check("xhtml-verbatim-and-voids",
      Html.render_document_xhtml(Ast.Document{[
        Ast.BThematicBreak{Ast.span_empty()},
        Ast.BHtmlBlock{"<div x=\"1\">raw</div>\n\n", Ast.span_empty()},
        Ast.BParagraph{[
          Ast.IImage{"im.png", "alt", None{}, Ast.span_empty()},
          Ast.IHardBreak{Ast.span_empty()},
          Ast.IText{"x", Ast.span_empty()}
        ], [], Ast.span_empty()}
      ]}),
      "<hr />\n&lt;div x=&quot;1&quot;&gt;raw&lt;/div&gt;\n<p><img src=\"im.png\" alt=\"alt\" /><br />\nx</p>\n")

    check("html-inline-raw",
      Html.render_inline(Ast.IRawHtml{"<b>&</b>", Ast.span_empty()}),
      "<b>&</b>")

    check("xhtml-inline-raw",
      Html.render_inline_xhtml(Ast.IRawHtml{"<b>&</b>", Ast.span_empty()}),
      "&lt;b&gt;&amp;&lt;/b&gt;")

    check("block-entry-xhtml",
      Html.render_block_xhtml(Ast.BThematicBreak{Ast.span_empty()}),
      "<hr />\n")

    check("profile-parameter-xhtml",
      Html.render_document_with_profile(Html.Xhtml{},
        Ast.Document{[Ast.BThematicBreak{Ast.span_empty()}]}),
      "<hr />\n")

    check("explicit-fuel",
      Html.render_document_with_profile_fuel(Html.Html{},
        Ast.Document{[Ast.BThematicBreak{Ast.span_empty()}]}, 32n),
      "<hr />\n")

    IO.print("render smoke: all checks passed")

#|PASS empty-document
#|PASS inline-emphasis
#|PASS inline-tags
#|PASS attribute-order-and-escaping
#|PASS control-replacement
#|PASS inline-family
#|PASS heading-code-quote-list-table
#|PASS html-verbatim
#|PASS xhtml-verbatim-and-voids
#|PASS html-inline-raw
#|PASS xhtml-inline-raw
#|PASS block-entry-xhtml
#|PASS profile-parameter-xhtml
#|PASS explicit-fuel
#|render smoke: all checks passed
