import Base
import ./model.bend as Model

# Deterministic Cooklang HTML renderer.  Cooklang defines recipe semantics, not
# an HTML vocabulary; this module therefore documents and implements one small
# deterministic publication vocabulary informed by Oliver's documented policy.
# It is pure: no IO, no filesystem,
# no recipe-reference resolution, and no shopping-list or aggregation logic.

# Bend cannot match on a freshly computed Boolean, so conditional recursion goes
# through this eliminator whose parameter is the value being matched.
def html_if(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# ---------------------------------------------------------------------------
# Escaping and scalar sanitization
# ---------------------------------------------------------------------------

# Tab, LF and CR are meaningful whitespace and are preserved.  Other C0
# controls, DEL, C1 controls, surrogate code points, and out-of-range code
# points are replaced by U+FFFD.  This intentionally mirrors the conservative
# escaping seam in src/render/html.bend rather than introducing a second policy.
def bad_char_code(+x: U32) -> Bool:
  +c0 = Bool.and(U32.is_lt(x, 32),
    Bool.not(Bool.or(U32.is_eq(x, 9), Bool.or(U32.is_eq(x, 10), U32.is_eq(x, 13)))))
  +c1 = Bool.and(U32.is_ge(x, 128), U32.is_le(x, 159))
  +surrogate = Bool.and(U32.is_ge(x, 55296), U32.is_le(x, 57343))
  Bool.or(c0, Bool.or(U32.is_eq(x, 127), Bool.or(c1, Bool.or(surrogate,
    U32.is_gt(x, 1114111)))))

def sanitize_char(c: Char) -> Char:
  match c:
    case Chr{+x}:
      Bool.pick(Char, bad_char_code(x), Chr{65533}, Chr{x})

# Escape text and double-quoted attribute values with one deterministic rule.
# Escaping quotes in text is conservative but valid HTML, and keeps this module
# byte-for-byte aligned with the repository's existing HTML escaping policy.
def escape_html(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{'&', t}:
      "&amp;" ++ escape_html(t)
    case SCon{'<', t}:
      "&lt;" ++ escape_html(t)
    case SCon{'>', t}:
      "&gt;" ++ escape_html(t)
    case SCon{'"', t}:
      "&quot;" ++ escape_html(t)
    case SCon{h, t}:
      SCon{sanitize_char(h), escape_html(t)}

# ---------------------------------------------------------------------------
# Small rendering helpers
# ---------------------------------------------------------------------------

def nonempty_attr(+name: String, +value: String) -> String:
  Bool.pick(String, String.is_empty(value), "",
    " " ++ name ++ "=\"" ++ escape_html(value) ++ "\"")

# Empty quantity/unit strings are present in the Cooklang token model whenever
# braces occur, but they are not useful machine-readable values.  Attributes are
# therefore emitted only for non-empty payloads.
def maybe_nonempty_attr(+name: String, value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      ""
    case Some{+text}:
      nonempty_attr(name, text)

def quantity_attrs(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  maybe_nonempty_attr("data-quantity", quantity) ++
    maybe_nonempty_attr("data-units", units)

def units_visible_suffix(units: Maybe<&2, String>) -> String:
  match units:
    case None{}:
      ""
    case Some{+text}:
      Bool.pick(String, String.is_empty(text), "", " " ++ escape_html(text))

def units_visible_text(units: Maybe<&2, String>) -> String:
  match units:
    case None{}:
      ""
    case Some{+text}:
      escape_html(text)

# A preparation is emitted whenever it is present, even when it is the empty
# string: the token model distinguishes an empty preparation from no shorthand.
def preparation_html(preparation: Maybe<&2, String>) -> String:
  match preparation:
    case None{}:
      ""
    case Some{+text}:
      " <span class=\"preparation\">" ++ escape_html(text) ++ "</span>"

def ingredient_text_html(+name: String, preparation: Maybe<&2, String>) -> String:
  escape_html(name) ++ preparation_html(preparation)

# The ingredients index shows the first occurrence's quantity.  Empty quantity
# strings produce no visible quantity pill; non-empty units join it with one
# space.  The trailing space after the span, when present, separates the pill
# from the ingredient name.
def quantity_index_html(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      ""
    case Some{+q}:
      Bool.pick(String, String.is_empty(q), "",
        "<span class=\"quantity\">" ++ escape_html(q) ++
          units_visible_suffix(units) ++ "</span> ")

# ---------------------------------------------------------------------------
# Ingredients index: first occurrence, exact case-sensitive name deduplication
# ---------------------------------------------------------------------------

def collect_part_ingredients(parts: List<&2, Model.CookPart>) -> List<&2, Model.Ingredient>:
  match parts:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Model.CookText{text, span}:
          collect_part_ingredients(t)
        case Model.CookIngredient{ingredient, span}:
          ingredient <> collect_part_ingredients(t)
        case Model.CookCookware{cookware, span}:
          collect_part_ingredients(t)
        case Model.CookTimer{timer, span}:
          collect_part_ingredients(t)
        case Model.CookLineBreak{span}:
          collect_part_ingredients(t)

# One structurally recursive walk over the block tree.  Section children are
# visited before following blocks, preserving document order for the flat
# section representation produced by the parser.
def collect_block_ingredients(blocks: List<&2, Model.CookBlock>) -> List<&2, Model.Ingredient>:
  match blocks:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          List.append(&2, Model.Ingredient, collect_part_ingredients(parts),
            collect_block_ingredients(t))
        case Model.CookNote{text, span}:
          collect_block_ingredients(t)
        case Model.CookSection{name, blocks, span}:
          List.append(&2, Model.Ingredient, collect_block_ingredients(blocks),
            collect_block_ingredients(t))

def ingredient_name(+ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{name, quantity, units, preparation, is_recipe_reference, span}:
      name

def ingredient_name_seen(+name: String, seen: List<&2, String>) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case h <> t:
      html_if(Bool, String.eq(name, h),
        u => True{},
        u => ingredient_name_seen(name, t))

# Keep the first occurrence of each exact ingredient name.  No case folding,
# Unicode normalization, quantity merging, or shopping-list semantics are done.
def dedup_ingredients_go(xs: List<&2, Model.Ingredient>, +seen: List<&2, String>,
    +acc: List<&2, Model.Ingredient>) -> List<&2, Model.Ingredient>:
  match xs:
    case Nil{}:
      List.reverse(&2, Model.Ingredient, acc)
    case +ingredient <> +rest:
      html_if(List<&2, Model.Ingredient>, ingredient_name_seen(ingredient_name(ingredient), seen),
        u => dedup_ingredients_go(rest, seen, acc),
        u => dedup_ingredients_go(rest, ingredient_name(ingredient) <> seen,
          ingredient <> acc))

def dedup_ingredients(xs: List<&2, Model.Ingredient>) -> List<&2, Model.Ingredient>:
  dedup_ingredients_go(xs, Nil{}, Nil{})

# ---------------------------------------------------------------------------
# Inline tokens and index entries
# ---------------------------------------------------------------------------

def recipe_ref_attrs(+name: String) -> String:
  " data-ref=\"" ++ escape_html(name) ++ "\""

def render_inline_ingredient(+ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{+name, +quantity, +units, +preparation, +is_recipe_reference, span}:
      Bool.pick(String, is_recipe_reference,
        "<span class=\"recipe-ref\"" ++ recipe_ref_attrs(name) ++ ">" ++
          escape_html(name) ++ "</span>",
        "<span class=\"ingredient\"" ++ quantity_attrs(quantity, units) ++ ">" ++
          ingredient_text_html(name, preparation) ++ "</span>")

def render_index_ingredient(+ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{+name, +quantity, +units, +preparation, +is_recipe_reference, span}:
      Bool.pick(String, is_recipe_reference,
        "<li class=\"recipe-ref\"" ++ recipe_ref_attrs(name) ++ ">" ++
          escape_html(name) ++ "</li>",
        "<li class=\"ingredient\"" ++ quantity_attrs(quantity, units) ++ ">" ++
          quantity_index_html(quantity, units) ++ ingredient_text_html(name, preparation) ++ "</li>")

def render_index_items(xs: List<&2, Model.Ingredient>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      render_index_ingredient(h) ++ "\n" ++ render_index_items(t)

def render_ingredient_index(xs: List<&2, Model.Ingredient>) -> String:
  match xs:
    case Nil{}:
      ""
    case entries:
      "<section class=\"ingredients\">\n<h2>Ingredients</h2>\n<ul>\n" ++
        render_index_items(entries) ++ "</ul>\n</section>\n"

# ---------------------------------------------------------------------------
# Cookware and timers
# ---------------------------------------------------------------------------

def render_cookware(+cookware: Model.Cookware) -> String:
  match cookware:
    case Model.Cookware{+name, +quantity, span}:
      "<span class=\"cookware\"" ++ maybe_nonempty_attr("data-quantity", quantity) ++
        ">" ++ escape_html(name) ++ "</span>"

def ascii_lower(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{Char.to_lower(h), ascii_lower(t)}

type TimerUnit is Data:
  TimerUnitNone{}
  TimerUnitDay{}
  TimerUnitHour{}
  TimerUnitMinute{}
  TimerUnitSecond{}

def timer_unit_day(+u: String) -> Bool:
  Bool.or(String.eq(u, "day"), String.eq(u, "days"))

def timer_unit_hour(+u: String) -> Bool:
  Bool.or(String.eq(u, "h"), Bool.or(String.eq(u, "hr"),
    Bool.or(String.eq(u, "hrs"), Bool.or(String.eq(u, "hour"), String.eq(u, "hours")))))

def timer_unit_minute(+u: String) -> Bool:
  Bool.or(String.eq(u, "m"), Bool.or(String.eq(u, "min"),
    Bool.or(String.eq(u, "mins"), Bool.or(String.eq(u, "minute"), String.eq(u, "minutes")))))

def timer_unit_second(+u: String) -> Bool:
  Bool.or(String.eq(u, "s"), Bool.or(String.eq(u, "sec"),
    Bool.or(String.eq(u, "secs"), Bool.or(String.eq(u, "second"), String.eq(u, "seconds")))))

# Recognize the documented singular/plural and common abbreviated unit forms,
# case-insensitively for ASCII.  Unknown units simply have no datetime value.
def timer_duration_unit(+units: String) -> TimerUnit:
  +lower = ascii_lower(units)
  Bool.pick(TimerUnit, timer_unit_day(lower), TimerUnitDay{},
    Bool.pick(TimerUnit, timer_unit_hour(lower), TimerUnitHour{},
      Bool.pick(TimerUnit, timer_unit_minute(lower), TimerUnitMinute{},
        Bool.pick(TimerUnit, timer_unit_second(lower), TimerUnitSecond{}, TimerUnitNone{}))))

def ascii_digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(Char.is_digit(h), ascii_digits(t))

def nonzero_digit(+c: Char) -> Bool:
  +x = Char.to_u32(c)
  Bool.and(U32.is_ge(x, 49), U32.is_le(x, 57))

# ISO duration output is intentionally limited to canonical whole-number text:
# either exactly "0" or digits without a leading zero.  Fractions, signs, words,
# and ranges stay data-only.
def canonical_whole_number(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'0', SNil{}}:
      True{}
    case SCon{h, t}:
      Bool.and(nonzero_digit(h), ascii_digits(t))

# Conservative signed-64-bit ceiling for machine-readable durations.  Larger
# digit strings remain valid timer data but do not receive an ISO duration.
# Canonical digit strings have no leading zeroes, so length plus lexicographic
# comparison is exact decimal comparison here.
def canonical_whole_i64(+s: String) -> Bool:
  +len = String.length(s)
  Bool.and(canonical_whole_number(s),
    Bool.or(Nat.is_lt(len, 19n),
      Bool.and(Nat.is_eq(len, 19n), String.is_le(s, "9223372036854775807"))))

def datetime_attr_for(+quantity: String, unit: TimerUnit) -> String:
  match unit:
    case TimerUnitNone{}:
      ""
    case TimerUnitDay{}:
      " datetime=\"P" ++ escape_html(quantity) ++ "D\""
    case TimerUnitHour{}:
      " datetime=\"PT" ++ escape_html(quantity) ++ "H\""
    case TimerUnitMinute{}:
      " datetime=\"PT" ++ escape_html(quantity) ++ "M\""
    case TimerUnitSecond{}:
      " datetime=\"PT" ++ escape_html(quantity) ++ "S\""

def timer_datetime_attr(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      ""
    case Some{+q}:
      match units:
        case None{}:
          ""
        case Some{+u}:
          Bool.pick(String, canonical_whole_i64(q),
            datetime_attr_for(q, timer_duration_unit(u)), "")

def timer_quantity_prefix(+quantity: String) -> String:
  Bool.pick(String, String.is_empty(quantity), "", escape_html(quantity) ++ " ")

# Unnamed timers show quantity and units.  The quantity branch deliberately
# leaves the separating space even for empty units; this is the pinned text
# policy for braced timers.
def anonymous_timer_text(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      units_visible_text(units)
    case Some{+q}:
      timer_quantity_prefix(q) ++ units_visible_text(units)

# Named timers are bare when there is no non-empty quantity; with a braced
# non-empty quantity they render as `name (quantity units)`, omitting the inner
# unit separator when units are empty.
def named_timer_text(+name: String, quantity: Maybe<&2, String>,
    units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      escape_html(name)
    case Some{+q}:
      Bool.pick(String, String.is_empty(q), escape_html(name),
        escape_html(name) ++ " (" ++ escape_html(q) ++ units_visible_suffix(units) ++ ")")

def timer_text(+name: String, +quantity: Maybe<&2, String>, +units: Maybe<&2, String>) -> String:
  Bool.pick(String, String.is_empty(name), anonymous_timer_text(quantity, units),
    named_timer_text(name, quantity, units))

def render_timer(+timer: Model.Timer) -> String:
  match timer:
    case Model.Timer{+name, +quantity, +units, span}:
      "<time class=\"timer\"" ++ maybe_nonempty_attr("data-quantity", quantity) ++
        maybe_nonempty_attr("data-units", units) ++ timer_datetime_attr(quantity, units) ++
        ">" ++ timer_text(name, quantity, units) ++ "</time>"

# ---------------------------------------------------------------------------
# Steps, notes, sections, and the recipe wrapper
# ---------------------------------------------------------------------------

def render_part_html(part: Model.CookPart) -> String:
  match part:
    case Model.CookText{+text, span}:
      escape_html(text)
    case Model.CookIngredient{+ingredient, span}:
      render_inline_ingredient(ingredient)
    case Model.CookCookware{+cookware, span}:
      render_cookware(cookware)
    case Model.CookTimer{+timer, span}:
      render_timer(timer)
    case Model.CookLineBreak{span}:
      "<br>"

def render_parts_html(parts: List<&2, Model.CookPart>) -> String:
  match parts:
    case Nil{}:
      ""
    case h <> t:
      render_part_html(h) ++ render_parts_html(t)

def render_step_item(parts: List<&2, Model.CookPart>) -> String:
  "<li>" ++ render_parts_html(parts) ++ "</li>\n"

def close_steps(open: Bool) -> String:
  match open:
    case True{}:
      "</ol>\n"
    case False{}:
      ""

def section_heading(+name: String) -> String:
  Bool.pick(String, String.is_empty(name), "",
    "<h2>" ++ escape_html(name) ++ "</h2>\n")

# Render maximal contiguous runs of step blocks as one ordered list.  Notes and
# sections close the current list; this keeps the document order stable without
# inventing grouping that is not present in the model.
def render_blocks_html(blocks: List<&2, Model.CookBlock>, open_steps: Bool) -> String:
  match blocks:
    case Nil{}:
      close_steps(open_steps)
    case h <> t:
      match h:
        case Model.CookStep{parts, span}:
          match open_steps:
            case True{}:
              render_step_item(parts) ++ render_blocks_html(t, True{})
            case False{}:
              "<ol class=\"steps\">\n" ++ render_step_item(parts) ++
                render_blocks_html(t, True{})
        case Model.CookNote{+text, span}:
          close_steps(open_steps) ++ "<aside class=\"note\">" ++ escape_html(text) ++
            "</aside>\n" ++ render_blocks_html(t, False{})
        case Model.CookSection{+name, blocks, span}:
          close_steps(open_steps) ++ "<section>\n" ++ section_heading(name) ++
            render_blocks_html(blocks, False{}) ++ "</section>\n" ++
            render_blocks_html(t, False{})

# Public entry point.  Frontmatter is data and deliberately has no HTML
# rendering.  The result is a deterministic HTML fragment, not a complete HTML
# document; embedding and document metadata remain consumer responsibilities.
def render_recipe(+recipe: Model.Recipe) -> String:
  match recipe:
    case Model.Recipe{frontmatter, +blocks}:
      "<article class=\"recipe\">\n" ++
        render_ingredient_index(dedup_ingredients(collect_block_ingredients(blocks))) ++
        render_blocks_html(blocks, False{}) ++ "</article>\n"
