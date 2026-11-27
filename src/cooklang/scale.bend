import Base
import ./model.bend as Model
import ./rational.bend as Rational

# Whole-recipe exact-rational scaling.  Only ordinary ingredient quantities are
# rewritten.  Recipe references, cookware, timers, units, preparation text,
# frontmatter, spans, sections, notes, and ingredient names are carried through
# unchanged.

def scale_quantity_maybe(
  quantity: Maybe<&2, String>, +num: Nat, +den: Nat
) -> Maybe<&2, String>:
  match quantity:
    case None{}:
      None{}
    case Some{text}:
      Some{Rational.scaled_text(Rational.scale_amount(text, num, den))}

def scale_ingredient(
  ingredient: Model.Ingredient, +num: Nat, +den: Nat
) -> Model.Ingredient:
  match ingredient:
    case Model.Ingredient{name, quantity, units, preparation, +is_recipe_reference, span}:
      match is_recipe_reference:
        case True{}:
          Model.Ingredient{name, quantity, units, preparation, is_recipe_reference, span}
        case False{}:
          Model.Ingredient{name, scale_quantity_maybe(quantity, num, den),
            units, preparation, is_recipe_reference, span}

def scale_part(part: Model.CookPart, +num: Nat, +den: Nat) -> Model.CookPart:
  match part:
    case Model.CookText{text, span}:
      Model.CookText{text, span}
    case Model.CookIngredient{ingredient, span}:
      Model.CookIngredient{scale_ingredient(ingredient, num, den), span}
    case Model.CookCookware{cookware, span}:
      Model.CookCookware{cookware, span}
    case Model.CookTimer{timer, span}:
      Model.CookTimer{timer, span}
    case Model.CookLineBreak{span}:
      Model.CookLineBreak{span}

def scale_parts(
  parts: List<&2, Model.CookPart>, +num: Nat, +den: Nat
) -> List<&2, Model.CookPart>:
  match parts:
    case Nil{}:
      Nil{}
    case h <> t:
      scale_part(h, num, den) <> scale_parts(t, num, den)

# Blocks and sections are mutually shaped in the data type, but this is one
# structurally recursive function over the block list.  The section branch
# recurses both into that section's smaller block list and into the tail.
def scale_blocks(
  blocks: List<&2, Model.CookBlock>, +num: Nat, +den: Nat
) -> List<&2, Model.CookBlock>:
  match blocks:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          Model.CookStep{scale_parts(parts, num, den), span} <> scale_blocks(t, num, den)
        case Model.CookNote{text, span}:
          Model.CookNote{text, span} <> scale_blocks(t, num, den)
        case Model.CookSection{name, blocks, span}:
          Model.CookSection{name, scale_blocks(blocks, num, den), span} <>
            scale_blocks(t, num, den)

def scale_recipe_data(recipe: Model.Recipe, +num: Nat, +den: Nat) -> Model.Recipe:
  match recipe:
    case Model.Recipe{frontmatter, blocks}:
      Model.Recipe{frontmatter, scale_blocks(blocks, num, den)}

def factor_valid(+num: Nat, +den: Nat) -> Bool:
  Bool.and(Nat.is_ne(num, 0n), Nat.is_ne(den, 0n))

def scale_recipe_factor_gate(
  recipe: Model.Recipe, +num: Nat, +den: Nat, valid: Bool
) -> Maybe<&2, Model.Recipe>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Some{scale_recipe_data(recipe, num, den)}

# Public entry point.  A zero numerator or denominator is rejected with None;
# otherwise ingredient quantities are multiplied by the exact factor num/den.
def scale_recipe_factor(
  +recipe: Model.Recipe, +num: Nat, +den: Nat
) -> Maybe<&2, Model.Recipe>:
  scale_recipe_factor_gate(recipe, num, den, factor_valid(num, den))
