import Base
import ../src/html_entities.bend as HtmlEntities

def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def show_maybe(m: Maybe<&2, String>) -> String:
  match m:
    case Some{x}:
      "Some(" ++ x ++ ")"
    case None{}:
      "None"

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  ifs(IO(Unit), String.eq(expected, actual),
    u => IO.print("PASS " ++ name),
    u => IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected: " ++ expected ++ "\nactual:   " ++ actual))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- expect_equal("amp", "Some(&)",
      show_maybe(HtmlEntities.html5_named_entity_value("amp")))
    Unit <- expect_equal("uppercase-amp", "Some(&)",
      show_maybe(HtmlEntities.html5_named_entity_value("AMP")))
    Unit <- expect_equal("hellip", "Some(…)",
      show_maybe(HtmlEntities.html5_named_entity_value("hellip")))
    Unit <- expect_equal("multi-codepoint-ngE", "Some(≧̸)",
      show_maybe(HtmlEntities.html5_named_entity_value("ngE")))
    Unit <- expect_equal("newline", "Some(\n)",
      show_maybe(HtmlEntities.html5_named_entity_value("NewLine")))
    Unit <- expect_equal("tab", "Some(\t)",
      show_maybe(HtmlEntities.html5_named_entity_value("Tab")))
    Unit <- expect_equal("unknown", "None",
      show_maybe(HtmlEntities.html5_named_entity_value("MadeUpEntity")))
    Unit <- expect_equal("prefix-is-not-enough", "None",
      show_maybe(HtmlEntities.html5_named_entity_value("am")))
    IO.print("html entities smoke: all checks passed")
