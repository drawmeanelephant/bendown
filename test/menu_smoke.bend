import Base
import ../src/cooklang/parser.bend as Parser
import ../src/cooklang/menu.bend as Menu

def expect_menu_gate(+name: String, +expected: String, +actual: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": expected " ++ expected ++ ", got " ++ actual)

def expect_menu(+name: String, +input: String, +expected: String) -> IO(Unit):
  expect_menu_gate(name, expected, Menu.render_menu(Parser.parse_cooklang(input)), String.eq(expected, Menu.render_menu(Parser.parse_cooklang(input))))

def main() -> IO(Unit):
  do IO<Unit>:
    expect_menu("empty", "", "")
    expect_menu("one-day", "= Monday\n@./mains/pasta carbonara{2}\n", "Monday: ./mains/pasta carbonara{2}\n")
    expect_menu("empty-day", "= Empty\n\n= Full\n@./x{2}\n", "Empty: \nFull: ./x{2}\n")
    expect_menu("units-empty", "= Day\n@./x{} and @./y{4%servings}\n", "Day: ./x{} ./y{4%servings}\n")
    expect_menu("top-level-ignored", "intro\n\n= Day\n@./x{1}\n", "Day: ./x{1}\n")
    IO.print("menu smoke: all checks passed")
