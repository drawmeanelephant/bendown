import Base
import ../src/ast.bend as Ast
import ../src/cooklang/model.bend as Model
import ../src/cooklang/rational.bend as Rational
import ../src/cooklang/scale.bend as Scale

def expect_equal_bool(
  +name: String, +expected: String, +actual: String, ok: Bool
) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": expected " ++ expected ++ ", got " ++ actual)
    case True{}:
      IO.print("PASS " ++ name)

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  expect_equal_bool(name, expected, actual, String.eq(expected, actual))

def expect_amount(
  +name: String, +amount: String, +num: Nat, +den: Nat, +expected: String
) -> IO(Unit):
  expect_equal(name, expected,
    Rational.scaled_text(Rational.scale_amount(amount, num, den)))

def expect_class(+name: String, +amount: String, +expected: String) -> IO(Unit):
  expect_equal(name, expected, Rational.class_name(Rational.classify_quantity(amount)))

def factor_text(factor: Maybe<&2, Model.Rational>) -> String:
  match factor:
    case None{}:
      "none"
    case Some{value}:
      Rational.format_rational(value, False{})

def maybe_text(quantity: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      "-"
    case Some{text}:
      text

def ingredient_line(ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{name, quantity, units, preparation, is_recipe_reference, span}:
      "I:" ++ name ++ ":" ++ maybe_text(quantity) ++ ":" ++
        maybe_text(units) ++ ":" ++ Bool.show(is_recipe_reference)

def cookware_line(cookware: Model.Cookware) -> String:
  match cookware:
    case Model.Cookware{name, quantity, span}:
      "C:" ++ name ++ ":" ++ maybe_text(quantity)

def timer_line(timer: Model.Timer) -> String:
  match timer:
    case Model.Timer{name, quantity, units, span}:
      "T:" ++ name ++ ":" ++ maybe_text(quantity) ++ ":" ++ maybe_text(units)

def part_lines(part: Model.CookPart) -> List<&2, String>:
  match part:
    case Model.CookText{text, span}:
      []
    case Model.CookIngredient{ingredient, span}:
      [ingredient_line(ingredient)]
    case Model.CookCookware{cookware, span}:
      [cookware_line(cookware)]
    case Model.CookTimer{timer, span}:
      [timer_line(timer)]
    case Model.CookLineBreak{span}:
      []

def parts_lines(parts: List<&2, Model.CookPart>) -> List<&2, String>:
  match parts:
    case Nil{}:
      []
    case h <> t:
      List.append(&2, String, part_lines(h), parts_lines(t))

def blocks_lines(blocks: List<&2, Model.CookBlock>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      []
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          List.append(&2, String, parts_lines(parts), blocks_lines(t))
        case Model.CookNote{text, span}:
          blocks_lines(t)
        case Model.CookSection{name, blocks, span}:
          List.append(&2, String, blocks_lines(blocks), blocks_lines(t))

def render_recipe(recipe: Model.Recipe) -> String:
  match recipe:
    case Model.Recipe{frontmatter, blocks}:
      String.join(blocks_lines(blocks), "|")

def span0() -> Ast.Span:
  Ast.Span{0, 0}

def ingredient(
  +name: String, quantity: Maybe<&2, String>, units: Maybe<&2, String>, is_ref: Bool
) -> Model.CookPart:
  Model.CookIngredient{Model.Ingredient{name, quantity, units, None{}, is_ref, span0()}, span0()}

def sample_recipe() -> Model.Recipe:
  Model.Recipe{None{}, [
    Model.CookStep{[
      ingredient("flour", Some{"1/2"}, Some{"cup"}, False{}),
      ingredient("salt", Some{"=1"}, Some{"tsp"}, False{}),
      ingredient("./bread", Some{"2"}, Some{"servings"}, True{}),
      ingredient("herbs", Some{"two small"}, None{}, False{}),
      Model.CookCookware{Model.Cookware{"pan", Some{"2"}, span0()}, span0()},
      Model.CookTimer{Model.Timer{"oven", Some{"10"}, Some{"minutes"}, span0()}, span0()}
    ], span0()},
    Model.CookSection{"main", [
      Model.CookStep{[
        ingredient("rice", Some{"1/4"}, Some{"cup"}, False{})
      ], span0()}
    ], span0()}
  ]}

def check_scaled_recipe(scaled: Maybe<&2, Model.Recipe>) -> IO(Unit):
  match scaled:
    case None{}:
      IO.die(Unit, 1, "FAIL recipe scaling returned None")
    case Some{recipe}:
      expect_equal("recipe scaling and passthrough",
        "I:flour:1:cup:False|I:salt:=1:tsp:False|I:./bread:2:servings:True|I:herbs:two small:-:False|C:pan:2|T:oven:10:minutes|I:rice:1/2:cup:False",
        render_recipe(recipe))

def check_zero_denominator(scaled: Maybe<&2, Model.Recipe>) -> IO(Unit):
  match scaled:
    case None{}:
      IO.print("PASS zero denominator rejected")
    case Some{recipe}:
      IO.die(Unit, 1, "FAIL zero denominator was accepted")

def check_zero_numerator(scaled: Maybe<&2, Model.Recipe>) -> IO(Unit):
  match scaled:
    case None{}:
      IO.print("PASS zero numerator rejected")
    case Some{recipe}:
      IO.die(Unit, 1, "FAIL zero numerator was accepted")

def main() -> IO(Unit):
  do IO<Unit>:
    expect_amount("1/2 times 2", "1/2", 2n, 1n, "1")
    expect_amount("1/2 times 3", "1/2", 3n, 1n, "3/2")
    expect_amount("1.5 times 3", "1.5", 3n, 1n, "4.5")
    expect_amount("1 1/2 times 2", "1 1/2", 2n, 1n, "3")
    expect_amount("amount reduction", "2/4", 1n, 1n, "1/2")
    expect_amount("factor reduction", "1", 2n, 4n, "1/2")
    expect_amount("decimal nonterminating result", "0.1", 4n, 3n, "2/15")
    expect_amount("decimal terminating result", "0.1", 3n, 2n, "0.15")
    expect_amount("decimal twelve digits", "0.000000000001", 1n, 1n, "0.000000000001")
    expect_amount("decimal thirteen digits falls back", "0.0000000000001", 1n, 1n, "1/10000000000000")
    expect_amount("decimal whole result is integer", "1.5", 2n, 1n, "3")
    expect_amount("trimmed spaced fraction", " 1 / 2 ", 2n, 1n, "1")
    expect_amount("empty quantity unchanged", "", 2n, 1n, "")
    expect_amount("leading zero unchanged", "02", 2n, 1n, "02")
    expect_amount("zero-denominator amount unchanged", "1/0", 2n, 1n, "1/0")
    expect_amount("improper mixed unchanged", "1 3/2", 2n, 1n, "1 3/2")
    expect_amount("overflow unchanged", "281474976710655", 2n, 1n, "281474976710655")
    expect_amount("cross-cancelled overflow avoided", "281474976710655", 1n, Rational.nat_max(), "1")
    expect_amount("unrepresentable decimal unchanged", "0.123456789012345", 2n, 1n, "0.123456789012345")
    expect_amount("fixed quantity unchanged", "=1", 2n, 1n, "=1")
    expect_amount("nonnumeric quantity unchanged", "some", 2n, 1n, "some")
    expect_class("classify empty", "", "empty")
    expect_class("classify integer", "2", "scalable")
    expect_class("classify fraction", "1 / 2", "scalable")
    expect_class("classify decimal beyond Nat", "0.123456789012345", "scalable")
    expect_class("classify huge integer", "999999999999999999999", "scalable")
    expect_class("classify leading zero", "02", "fixed")
    expect_class("classify improper mixed", "1 3/2", "fixed")
    expect_class("classify fixed leading equals", "=1/2", "fixed")
    expect_equal("parse factor mixed", "3/2", factor_text(Rational.parse_factor("1 1/2")))
    expect_equal("parse factor zero rejected", "none", factor_text(Rational.parse_factor("0")))
    check_scaled_recipe(Scale.scale_recipe_factor(sample_recipe(), 2n, 1n))
    check_zero_denominator(Scale.scale_recipe_factor(sample_recipe(), 2n, 0n))
    check_zero_numerator(Scale.scale_recipe_factor(sample_recipe(), 0n, 1n))

#| PASS 1/2 times 2
#| PASS 1/2 times 3
#| PASS 1.5 times 3
#| PASS 1 1/2 times 2
#| PASS amount reduction
#| PASS factor reduction
#| PASS decimal nonterminating result
#| PASS decimal terminating result
#| PASS decimal twelve digits
#| PASS decimal thirteen digits falls back
#| PASS decimal whole result is integer
#| PASS trimmed spaced fraction
#| PASS empty quantity unchanged
#| PASS leading zero unchanged
#| PASS zero-denominator amount unchanged
#| PASS improper mixed unchanged
#| PASS overflow unchanged
#| PASS cross-cancelled overflow avoided
#| PASS unrepresentable decimal unchanged
#| PASS fixed quantity unchanged
#| PASS nonnumeric quantity unchanged
#| PASS classify empty
#| PASS classify integer
#| PASS classify fraction
#| PASS classify decimal beyond Nat
#| PASS classify huge integer
#| PASS classify leading zero
#| PASS classify improper mixed
#| PASS classify fixed leading equals
#| PASS parse factor mixed
#| PASS parse factor zero rejected
#| PASS recipe scaling and passthrough
#| PASS zero denominator rejected
#| PASS zero numerator rejected
