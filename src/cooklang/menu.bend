import Base
import ./model.bend as Model

# Deterministic plain-text serialization of the Cooklang menu view.  A menu is
# ordinary Cooklang: every top-level section is a day/meal, and recipe
# references in that section are its scaling directives.  This module is only a
# view; it does not resolve paths, schedule dates, deduplicate references, or
# build shopping lists.

# Cooklang text output never emits a raw NUL.  All other scalar values are
# source text and pass through unchanged, keeping this a plain-text dump rather
# than an escaping or markup layer.
def sanitize_menu_nul(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{0}, t}:
      SCon{'�', sanitize_menu_nul(t)}
    case SCon{h, t}:
      SCon{h, sanitize_menu_nul(t)}

# A reference's scaling directive is preserved as source text.  Braces occur
# exactly when the token carried a quantity field; a non-empty units field is
# separated by `%`.  Empty units canonicalize away, as in Cooklang's canonical
# serializer.
def reference_inside_braces(+quantity: String, units: Maybe<&2, String>) -> String:
  match units:
    case None{}:
      sanitize_menu_nul(quantity)
    case Some{+u}:
      Bool.pick(String, String.is_empty(u), sanitize_menu_nul(quantity),
        sanitize_menu_nul(quantity) ++ "%" ++ sanitize_menu_nul(u))

def reference_directive(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      ""
    case Some{+q}:
      "{" ++ reference_inside_braces(q, units) ++ "}"

def render_reference(+name: String, quantity: Maybe<&2, String>,
    units: Maybe<&2, String>) -> String:
  sanitize_menu_nul(name) ++ reference_directive(quantity, units)

def part_references(part: Model.CookPart) -> List<&2, String>:
  match part:
    case Model.CookText{text, span}:
      Nil{}
    case Model.CookIngredient{ingredient, span}:
      match ingredient:
        case Model.Ingredient{+name, +quantity, +units, preparation, +is_recipe_reference, span}:
          Bool.pick(List<&2, String>, is_recipe_reference,
            [render_reference(name, quantity, units)], Nil{})
    case Model.CookCookware{cookware, span}:
      Nil{}
    case Model.CookTimer{timer, span}:
      Nil{}
    case Model.CookLineBreak{span}:
      Nil{}

def parts_references(parts: List<&2, Model.CookPart>) -> List<&2, String>:
  match parts:
    case Nil{}:
      Nil{}
    case h <> t:
      List.append(&2, String, part_references(h), parts_references(t))

# Collect in step order.  References are occurrences, not a set: duplicates are
# meaningful repeated directives and are retained.  Notes contain only plain
# text in the typed model, so there are no token payloads to collect from them.
def block_references(blocks: List<&2, Model.CookBlock>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          List.append(&2, String, parts_references(parts), block_references(t))
        case Model.CookNote{text, span}:
          block_references(t)
        case Model.CookSection{name, blocks, span}:
          List.append(&2, String, block_references(blocks), block_references(t))

# The dump has one line per top-level section.  There is always one space after
# the colon; references are then separated by single spaces.  Thus a section
# without references is `Name: ` plus its newline.  Non-section top-level blocks
# are not menu structure and are intentionally ignored.
def render_menu_day(+name: String, blocks: List<&2, Model.CookBlock>) -> String:
  sanitize_menu_nul(name) ++ ": " ++ String.join(block_references(blocks), " ") ++ "\n"

def render_menu_blocks(blocks: List<&2, Model.CookBlock>) -> String:
  match blocks:
    case Nil{}:
      ""
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          render_menu_blocks(t)
        case Model.CookNote{text, span}:
          render_menu_blocks(t)
        case Model.CookSection{+name, blocks, span}:
          render_menu_day(name, blocks) ++ render_menu_blocks(t)

# Public entry point.  The empty recipe, and recipes without top-level
# sections, serialize to the empty string.
def render_menu(+recipe: Model.Recipe) -> String:
  match recipe:
    case Model.Recipe{frontmatter, +blocks}:
      render_menu_blocks(blocks)
