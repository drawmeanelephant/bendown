import Base
import ../src/parser/markdown.bend as Markdown
import ../src/render/html.bend as Html

def render_md(+input: String) -> String:
  Html.render_document(Markdown.parse_markdown(input))

def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  ifs(IO(Unit), String.eq(expected, actual),
    u => IO.print("PASS " ++ name),
    u => IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected: " ++ String.quote(expected) ++ "\nactual:   " ++ String.quote(actual)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- expect_equal("commonmark-example-218",
      "<p><a href=\"/url\">foo</a></p>\n<blockquote>\n</blockquote>\n",
      render_md("[foo]\n\n> [foo]: /url\n"))
    Unit <- expect_equal("blockquote-definition-after-heading",
      "<blockquote>\n<h1>h</h1>\n</blockquote>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("> # h\n> [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("nested-blockquote-definition",
      "<blockquote>\n<blockquote>\n</blockquote>\n</blockquote>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("> > [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("list-item-definition",
      "<ul>\n<li></li>\n</ul>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("- [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("list-nested-blockquote-definition",
      "<ul>\n<li>\n<blockquote>\n</blockquote>\n</li>\n</ul>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("- > [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("definition-cannot-interrupt-quote-paragraph",
      "<blockquote>\n<p>para\n[x]: /u</p>\n</blockquote>\n<p>[x]</p>\n",
      render_md("> para\n> [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("definition-cannot-be-lazy-paragraph-continuation",
      "<blockquote>\n<p>para\n[x]: /u</p>\n</blockquote>\n<p>[x]</p>\n",
      render_md("> para\n[x]: /u\n\n[x]\n"))
    Unit <- expect_equal("fenced-code-in-quote-stays-literal",
      "<blockquote>\n<pre><code>[x]: /u\n</code></pre>\n</blockquote>\n<p>[x]</p>\n",
      render_md("> ```\n> [x]: /u\n> ```\n\n[x]\n"))
    Unit <- expect_equal("html-block-in-quote-stays-literal",
      "<blockquote>\n<div>\n[x]: /u\n<p>[x]</p>\n</blockquote>\n",
      render_md("> <div>\n> [x]: /u\n>\n> [x]\n"))
    Unit <- expect_equal("marked-multiline-title-in-quote",
      "<blockquote>\n</blockquote>\n<p><a href=\"/u\" title=\"one\ntwo\">x</a></p>\n",
      render_md("> [x]: /u \"one\n> two\"\n\n[x]\n"))
    Unit <- expect_equal("lazy-multiline-title-in-quote",
      "<blockquote>\n</blockquote>\n<p><a href=\"/u\" title=\"one\ntwo\">x</a></p>\n",
      render_md("> [x]: /u \"one\ntwo\"\n\n[x]\n"))
    Unit <- expect_equal("destination-on-next-quote-line",
      "<blockquote>\n</blockquote>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("> [x]:\n> /u\n\n[x]\n"))
    Unit <- expect_equal("multiline-label-in-quote-with-remainder",
      "<blockquote>\n<p>bar</p>\n</blockquote>\n<p><a href=\"/url\">foo</a></p>\n",
      render_md("> [\n> foo\n> ]: /url\n> bar\n\n[foo]\n"))
    Unit <- expect_equal("false-setext-after-only-references",
      "<p>===\n[y]: /v</p>\n<p><a href=\"/u\">x</a>\n[y]</p>\n",
      render_md("[x]: /u\n===\n[y]: /v\n\n[x]\n[y]\n"))
    Unit <- expect_equal("setext-after-reference-remainder",
      "<h1>bar</h1>\n<p><a href=\"/u\">x</a>\n<a href=\"/v\">y</a></p>\n",
      render_md("[x]: /u\nbar\n===\n[y]: /v\n\n[x]\n[y]\n"))
    Unit <- expect_equal("indented-code-in-quote-stays-literal",
      "<blockquote>\n<pre><code>[x]: /u\n</code></pre>\n</blockquote>\n<p>[x]</p>\n",
      render_md(">     [x]: /u\n\n[x]\n"))
    Unit <- expect_equal("blank-line-in-title-is-rejected",
      "<blockquote>\n<p>[x]: /u &quot;one</p>\n<p>two&quot;</p>\n</blockquote>\n<p>[x]</p>\n",
      render_md("> [x]: /u \"one\n>\n> two\"\n\n[x]\n"))
    Unit <- expect_equal("trailing-junk-after-title-is-rejected",
      "<blockquote>\n<p>[x]: /u &quot;t&quot; bad</p>\n</blockquote>\n<p>[x]</p>\n",
      render_md("> [x]: /u \"t\" bad\n\n[x]\n"))
    Unit <- expect_equal("partial-tab-after-definition-is-only-remainder",
      "<blockquote>\n<p>remainder</p>\n</blockquote>\n<p><a href=\"/u\">x</a></p>\n",
      render_md("> [x]: /u\n>\tremainder\n\n[x]\n"))
    IO.print("container reference smoke: all checks passed")
