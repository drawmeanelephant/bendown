import Base
import ../src/cooklang/parser.bend as Parser
import ../src/cooklang/html.bend as CookHtml

def expect_html_gate(+name: String, +expected: String, +actual: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)

def expect_html(+name: String, +input: String, +expected: String) -> IO(Unit):
  +actual = CookHtml.render_recipe(Parser.parse_cooklang(input))
  expect_html_gate(name, expected, actual, String.eq(expected, actual))

def main() -> IO(Unit):
  do IO<Unit>:
    expect_html("empty", "", "<article class=\"recipe\">\n</article>\n")
    expect_html("basic",
      "Add @salt, @ground black pepper{2} and @milk{1/2%cup}.\n\nSimmer in #frying pan{2} for ~{25%minutes}, then let it ~rest.\n",
      "<article class=\"recipe\">\n<section class=\"ingredients\">\n<h2>Ingredients</h2>\n<ul>\n<li class=\"ingredient\">salt</li>\n<li class=\"ingredient\" data-quantity=\"2\"><span class=\"quantity\">2</span> ground black pepper</li>\n<li class=\"ingredient\" data-quantity=\"1/2\" data-units=\"cup\"><span class=\"quantity\">1/2 cup</span> milk</li>\n</ul>\n</section>\n<ol class=\"steps\">\n<li>Add <span class=\"ingredient\">salt</span>, <span class=\"ingredient\" data-quantity=\"2\">ground black pepper</span> and <span class=\"ingredient\" data-quantity=\"1/2\" data-units=\"cup\">milk</span>.</li>\n<li>Simmer in <span class=\"cookware\" data-quantity=\"2\">frying pan</span> for <time class=\"timer\" data-quantity=\"25\" data-units=\"minutes\" datetime=\"PT25M\">25 minutes</time>, then let it <time class=\"timer\">rest</time>.</li>\n</ol>\n</article>\n")
    IO.print("cooklang html smoke: all checks passed")
