import Base
import ../src/ast.bend as Ast
import ../src/cooklang/model.bend as Model
import ../src/cooklang/parser.bend as Parser
import ../src/cooklang/html.bend as CookHtml
import ../src/cooklang/menu.bend as CookMenu

# Fixed-input smoke tests for the isolated Cooklang HTML and menu renderers.
# The HTML vocabulary expectations are explicit strings so any byte drift in
# wrappers, attribute order, spacing, escaping, or block grouping fails loudly.

def span0() -> Ast.Span:
  Ast.Span{0, 0}

def basic_input() -> String:
  "Add @salt, @ground black pepper{2} and @milk{1/2%cup}.\n\nSimmer in #frying pan{2} for ~{25%minutes}, then let it ~rest.\n"

def basic_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\">salt</li>\n",
    "<li class=\"ingredient\" data-quantity=\"2\"><span class=\"quantity\">2</span> ground black pepper</li>\n",
    "<li class=\"ingredient\" data-quantity=\"1/2\" data-units=\"cup\"><span class=\"quantity\">1/2 cup</span> milk</li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li>Add <span class=\"ingredient\">salt</span>, <span class=\"ingredient\" data-quantity=\"2\">ground black pepper</span> and <span class=\"ingredient\" data-quantity=\"1/2\" data-units=\"cup\">milk</span>.</li>\n",
    "<li>Simmer in <span class=\"cookware\" data-quantity=\"2\">frying pan</span> for <time class=\"timer\" data-quantity=\"25\" data-units=\"minutes\" datetime=\"PT25M\">25 minutes</time>, then let it <time class=\"timer\">rest</time>.</li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def sections_input() -> String:
  "= Dough\n\nMix @flour{200%g} and @water{100%ml} together until smooth.\n\n== Filling ==\nCombine @cheese{100%g}(grated) and @spinach{50%g}, then season.\n\n> Serve the same day.\n"

def sections_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\" data-quantity=\"200\" data-units=\"g\"><span class=\"quantity\">200 g</span> flour</li>\n",
    "<li class=\"ingredient\" data-quantity=\"100\" data-units=\"ml\"><span class=\"quantity\">100 ml</span> water</li>\n",
    "<li class=\"ingredient\" data-quantity=\"100\" data-units=\"g\"><span class=\"quantity\">100 g</span> cheese <span class=\"preparation\">grated</span></li>\n",
    "<li class=\"ingredient\" data-quantity=\"50\" data-units=\"g\"><span class=\"quantity\">50 g</span> spinach</li>\n",
    "</ul>\n",
    "</section>\n",
    "<section>\n",
    "<h2>Dough</h2>\n",
    "<ol class=\"steps\">\n",
    "<li>Mix <span class=\"ingredient\" data-quantity=\"200\" data-units=\"g\">flour</span> and <span class=\"ingredient\" data-quantity=\"100\" data-units=\"ml\">water</span> together until smooth.</li>\n",
    "</ol>\n",
    "</section>\n",
    "<section>\n",
    "<h2>Filling</h2>\n",
    "<ol class=\"steps\">\n",
    "<li>Combine <span class=\"ingredient\" data-quantity=\"100\" data-units=\"g\">cheese <span class=\"preparation\">grated</span></span> and <span class=\"ingredient\" data-quantity=\"50\" data-units=\"g\">spinach</span>, then season.</li>\n",
    "</ol>\n",
    "<aside class=\"note\">Serve the same day.</aside>\n",
    "</section>\n",
    "</article>\n"
  ])

def duplicate_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\" data-quantity=\"1\" data-units=\"g\"><span class=\"quantity\">1 g</span> salt</li>\n",
    "<li class=\"ingredient\" data-quantity=\"3\" data-units=\"g\"><span class=\"quantity\">3 g</span> Salt</li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li><span class=\"ingredient\" data-quantity=\"1\" data-units=\"g\">salt</span> then <span class=\"ingredient\" data-quantity=\"2\" data-units=\"kg\">salt</span> and <span class=\"ingredient\" data-quantity=\"3\" data-units=\"g\">Salt</span></li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def refs_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"recipe-ref\" data-ref=\"./sauces/Hollandaise\">./sauces/Hollandaise</li>\n",
    "<li class=\"recipe-ref\" data-ref=\"./plain\">./plain</li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li>Use <span class=\"recipe-ref\" data-ref=\"./sauces/Hollandaise\">./sauces/Hollandaise</span> and <span class=\"recipe-ref\" data-ref=\"./plain\">./plain</span>.</li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def timer_input() -> String:
  "a ~{25%minutes} b ~oven{3%hours} c ~{1%day} d ~{1.5%minutes} e ~{2%fortnights} f ~rest g ~{01%minutes} h ~{9223372036854775808%minutes} i ~{9223372036854775807%minutes} j ~{2%HOURS}\n"

def timer_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<ol class=\"steps\">\n",
    "<li>a <time class=\"timer\" data-quantity=\"25\" data-units=\"minutes\" datetime=\"PT25M\">25 minutes</time> b <time class=\"timer\" data-quantity=\"3\" data-units=\"hours\" datetime=\"PT3H\">oven (3 hours)</time> c <time class=\"timer\" data-quantity=\"1\" data-units=\"day\" datetime=\"P1D\">1 day</time> d <time class=\"timer\" data-quantity=\"1.5\" data-units=\"minutes\">1.5 minutes</time> e <time class=\"timer\" data-quantity=\"2\" data-units=\"fortnights\">2 fortnights</time> f <time class=\"timer\">rest</time> g <time class=\"timer\" data-quantity=\"01\" data-units=\"minutes\">01 minutes</time> h <time class=\"timer\" data-quantity=\"9223372036854775808\" data-units=\"minutes\">9223372036854775808 minutes</time> i <time class=\"timer\" data-quantity=\"9223372036854775807\" data-units=\"minutes\" datetime=\"PT9223372036854775807M\">9223372036854775807 minutes</time> j <time class=\"timer\" data-quantity=\"2\" data-units=\"HOURS\" datetime=\"PT2H\">2 HOURS</time></li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def empty_tokens_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\">x</li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li><span class=\"ingredient\">x</span> <span class=\"cookware\">y</span> <time class=\"timer\"></time> z <time class=\"timer\" data-quantity=\"2\">2 </time> n <time class=\"timer\">name</time> u <time class=\"timer\" data-units=\"minutes\">minutes</time></li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def grouping_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<ol class=\"steps\">\n",
    "<li>step1</li>\n",
    "</ol>\n",
    "<aside class=\"note\">note</aside>\n",
    "<ol class=\"steps\">\n",
    "<li>step2</li>\n",
    "<li>step3</li>\n",
    "</ol>\n",
    "<aside class=\"note\">note2</aside>\n",
    "</article>\n"
  ])

def unicode_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\">🧂</li>\n",
    "<li class=\"ingredient\" data-quantity=\"1\" data-units=\"g\"><span class=\"quantity\">1 g</span> x <span class=\"preparation\">finely chopped</span></li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li>Add some <span class=\"ingredient\">🧂</span> and <span class=\"ingredient\" data-quantity=\"1\" data-units=\"g\">x <span class=\"preparation\">finely chopped</span></span>.</li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def attr_escape_input() -> String:
  "A & < > \" ' @x{a&<>\"%u&<>\"}(p&<>\") #pan{q&<>\"} ~{2%minutes}\n"

def attr_escape_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\" data-quantity=\"a&amp;&lt;&gt;&quot;\" data-units=\"u&amp;&lt;&gt;&quot;\"><span class=\"quantity\">a&amp;&lt;&gt;&quot; u&amp;&lt;&gt;&quot;</span> x <span class=\"preparation\">p&amp;&lt;&gt;&quot;</span></li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li>A &amp; &lt; &gt; &quot; ' <span class=\"ingredient\" data-quantity=\"a&amp;&lt;&gt;&quot;\" data-units=\"u&amp;&lt;&gt;&quot;\">x <span class=\"preparation\">p&amp;&lt;&gt;&quot;</span></span> <span class=\"cookware\" data-quantity=\"q&amp;&lt;&gt;&quot;\">pan</span> <time class=\"timer\" data-quantity=\"2\" data-units=\"minutes\" datetime=\"PT2M\">2 minutes</time></li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def control_recipe() -> Model.Recipe:
  Model.Recipe{None{}, [
    Model.CookStep{[
      Model.CookText{"A\u{0}B\u{1}C\u{7f}D\u{85}E\tF\nG\"&<>é🧂", span0()}
    ], span0()}
  ]}

def control_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<ol class=\"steps\">\n",
    "<li>A\u{FFFD}B\u{FFFD}C\u{FFFD}D\u{FFFD}E\tF\nG&quot;&amp;&lt;&gt;é🧂</li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def frontmatter_expected() -> String:
  String.concat([
    "<article class=\"recipe\">\n",
    "<section class=\"ingredients\">\n",
    "<h2>Ingredients</h2>\n",
    "<ul>\n",
    "<li class=\"ingredient\" data-quantity=\"200\" data-units=\"g\"><span class=\"quantity\">200 g</span> pasta</li>\n",
    "</ul>\n",
    "</section>\n",
    "<ol class=\"steps\">\n",
    "<li>Boil <span class=\"ingredient\" data-quantity=\"200\" data-units=\"g\">pasta</span> in salted water.</li>\n",
    "</ol>\n",
    "</article>\n"
  ])

def menu_input() -> String:
  "= Monday\n@./mains/pasta carbonara{2} \\\n@./sides/green salad{}\n\n= Day 1 (2026-03-07)\n@./breakfast/shakshuka{4%servings}\n\n= Empty Day\n"

def menu_expected() -> String:
  "Monday: ./mains/pasta carbonara{2} ./sides/green salad{}\nDay 1 (2026-03-07): ./breakfast/shakshuka{4%servings}\nEmpty Day: \n"

def nul_menu_recipe() -> Model.Recipe:
  Model.Recipe{None{}, [
    Model.CookSection{"A\u{0}Day", [
      Model.CookStep{[
        Model.CookIngredient{Model.Ingredient{"./x\u{0}y", Some{"1\u{0}2"}, Some{"s\u{0}v"},
          None{}, True{}, span0()}, span0()}
      ], span0()}
    ], span0()}
  ]}

def expect_equal_bool(
  +name: String, +expected: String, +actual: String, ok: Bool
) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": expected " ++ String.quote(expected) ++ ", got " ++ String.quote(actual))
    case True{}:
      IO.print("PASS " ++ name)

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  expect_equal_bool(name, expected, actual, String.eq(expected, actual))

def expect_render(+name: String, +input: String, +expected: String) -> IO(Unit):
  expect_equal(name, expected, CookHtml.render_recipe(Parser.parse_cooklang(input)))

def expect_menu(+name: String, +input: String, +expected: String) -> IO(Unit):
  expect_equal(name, expected, CookMenu.render_menu(Parser.parse_cooklang(input)))

def main() -> IO(Unit):
  do IO<Unit>:
    expect_render("html empty recipe", "", "<article class=\"recipe\">\n</article>\n")
    expect_menu("menu empty recipe", "", "")
    expect_render("html plain text", "plain text & simple\n",
      "<article class=\"recipe\">\n<ol class=\"steps\">\n<li>plain text &amp; simple</li>\n</ol>\n</article>\n")
    expect_render("html basic tokens", basic_input(), basic_expected())
    expect_render("html cookware timers are not indexed", "#pan{1} for ~{1%minute}\n",
      "<article class=\"recipe\">\n<ol class=\"steps\">\n<li><span class=\"cookware\" data-quantity=\"1\">pan</span> for <time class=\"timer\" data-quantity=\"1\" data-units=\"minute\" datetime=\"PT1M\">1 minute</time></li>\n</ol>\n</article>\n")
    expect_render("html sections notes preparations", sections_input(), sections_expected())
    expect_render("html ingredient first occurrence dedup", "@salt{1%g} then @salt{2%kg} and @Salt{3%g}\n", duplicate_expected())
    expect_render("html recipe references", "Use @./sauces/Hollandaise{150%g} and @./plain{2}.\n", refs_expected())
    expect_render("html timer forms and datetime bounds", timer_input(), timer_expected())
    expect_render("html empty token payloads", "@x{} #y{} ~{} z ~{2} n ~name{} u ~{%minutes}\n", empty_tokens_expected())
    expect_render("html forced line break", "first\\\nsecond\n",
      "<article class=\"recipe\">\n<ol class=\"steps\">\n<li>first<br>second</li>\n</ol>\n</article>\n")
    expect_render("html notes split step lists", "step1\n\n> note\n\nstep2\n\nstep3\n\n> note2\n", grouping_expected())
    expect_render("html unnamed section", "= \nstep\n",
      "<article class=\"recipe\">\n<section>\n<ol class=\"steps\">\n<li>step</li>\n</ol>\n</section>\n</article>\n")
    expect_render("html unicode ingredient", "Add some @🧂 and @x{1%g}(finely chopped).\n", unicode_expected())
    expect_render("html text and attribute escaping", attr_escape_input(), attr_escape_expected())
    expect_equal("html unicode control sanitization", control_expected(), CookHtml.render_recipe(control_recipe()))
    expect_render("html frontmatter omitted", "---\ntitle: Pasta\nservings: 2\n---\n\nBoil @pasta{200%g} in salted water.\n", frontmatter_expected())
    expect_menu("menu sections references and empty day", menu_input(), menu_expected())
    expect_menu("menu ignores top-level steps", "@./mains/ignored{2}\n\n= Day\n@./mains/kept{1}\n", "Day: ./mains/kept{1}\n")
    expect_equal("menu nul sanitization", "A\u{FFFD}Day: ./x\u{FFFD}y{1\u{FFFD}2%s\u{FFFD}v}\n",
      CookMenu.render_menu(nul_menu_recipe()))

#|PASS html empty recipe
#|PASS menu empty recipe
#|PASS html plain text
#|PASS html basic tokens
#|PASS html cookware timers are not indexed
#|PASS html sections notes preparations
#|PASS html ingredient first occurrence dedup
#|PASS html recipe references
#|PASS html timer forms and datetime bounds
#|PASS html empty token payloads
#|PASS html forced line break
#|PASS html notes split step lists
#|PASS html unnamed section
#|PASS html unicode ingredient
#|PASS html text and attribute escaping
#|PASS html unicode control sanitization
#|PASS html frontmatter omitted
#|PASS menu sections references and empty day
#|PASS menu ignores top-level steps
#|PASS menu nul sanitization
