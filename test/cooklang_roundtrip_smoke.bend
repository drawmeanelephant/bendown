import Base
import ../src/cooklang/model.bend as Model
import ../src/cooklang/parser.bend as Parser
import ../src/cooklang/serialize.bend as Serializer
import ../src/cooklang/semantic.bend as Semantic

def semantic_roundtrip(+input: String) -> Bool:
  +first = Parser.parse_cooklang(input)
  +canonical = Serializer.serialize_recipe(first)
  Semantic.recipe_eq(Parser.parse_cooklang(canonical), first)

def expect_roundtrip_gate(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def expect_roundtrip(+name: String, +input: String) -> IO(Unit):
  expect_roundtrip_gate(name, semantic_roundtrip(input))

def main() -> IO(Unit):
  do IO<Unit>:
    expect_roundtrip("empty", "")
    expect_roundtrip("basic", "Add @flour{1/2%cup} and @salt.\n")
    expect_roundtrip("cookware-timer", "Use #pan{2} and wait ~oven{10%minutes}.\n")
    expect_roundtrip("unicode", "Add @🧂 and stir.\n")
    expect_roundtrip("note", "> a note\n> continued\n")
    expect_roundtrip("section", "= Dough\n\nMix @flour{2%cup}.\n\n= Bake\n\nBake ~oven{20%minutes}.\n")
    expect_roundtrip("frontmatter", "---\nservings: 2\n---\n\nAdd @salt.\n")
    expect_roundtrip("forced-break", "first\\\nsecond\n")
    IO.print("cooklang semantic roundtrip smoke: all checks passed")
