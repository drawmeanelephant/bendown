import Base
import ../src/parallel/engine.bend as Engine

def expect_gate(+name: String, +expected: String, +actual: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected:\n" ++ expected ++ "\nactual:\n" ++ actual)

def first_target_or_empty(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      h

def expect_doc_output(+name: String, +expected_html: String, +expected_target: String, output: Engine.DocOutput) -> IO(Unit):
  match output:
    case Engine.DocOutput{+outname, +html, targets}:
      +first_target = first_target_or_empty(targets)
      +ok = Bool.and(String.eq(html, expected_html), String.eq(first_target, expected_target))
      expect_gate(name, expected_html ++ "\nTARGET:" ++ expected_target, html ++ "\nTARGET:" ++ first_target, ok)

def expect_doc(+name: String, +path: String, +source: String, +expected_html: String, +expected_target: String) -> IO(Unit):
  expect_doc_output(name, expected_html, expected_target, Engine.process_doc(Engine.DocInput{path, source}))

def main() -> IO(Unit):
  do IO<Unit>:
    expect_doc("markdown-format", "a.md", "[x](y)\n", "<p><a href=\"y\">x</a></p>\n", "y")
    expect_doc("textile-format", "a.textile", "\"x\":y\n", "<p><a href=\"y\">x</a></p>\n", "y")
    expect_doc("cook-format", "a.cook", "= Day\n@./x{2}\n", "<article class=\"recipe\">\n<section class=\"ingredients\">\n<h2>Ingredients</h2>\n<ul>\n<li class=\"recipe-ref\" data-ref=\"./x\">./x</li>\n</ul>\n</section>\n<section>\n<h2>Day</h2>\n<ol class=\"steps\">\n<li><span class=\"recipe-ref\" data-ref=\"./x\">./x</span></li>\n</ol>\n</section>\n</article>\n", "./x")
    IO.print("batch formats smoke: all checks passed")
