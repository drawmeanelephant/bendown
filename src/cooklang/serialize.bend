import Base
import ../ast.bend as Ast
import ./model.bend as Model
import ./parser.bend as Parser

# Deterministic canonical Cooklang serializer.  This is not a byte-identical
# source round trip: it emits one valid canonical spelling of the typed model.

def ser_if(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# Cooklang treats NUL as opaque input.  Canonical text output never emits a
# raw NUL; like Oliver's output seams, it is replaced by U+FFFD.
def sanitize_nul(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{0}, t}:
      SCon{'�', sanitize_nul(t)}
    case SCon{h, t}:
      SCon{h, sanitize_nul(t)}

def maybe_text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      SNil{}
    case Some{x}:
      sanitize_nul(x)

def braced_units(+quantity: String, +units: String) -> String:
  ser_if(String, String.is_empty(units),
    u => "{" ++ sanitize_nul(quantity) ++ "}",
    u => "{" ++ sanitize_nul(quantity) ++ "%" ++ sanitize_nul(units) ++ "}")

def ingredient_braces(quantity: Maybe<&2, String>, units: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      SNil{}
    case Some{+q}:
      match units:
        case None{}:
          "{" ++ sanitize_nul(q) ++ "}"
        case Some{+u}:
          braced_units(q, u)

def plain_braces(quantity: Maybe<&2, String>) -> String:
  match quantity:
    case None{}:
      SNil{}
    case Some{+q}:
      "{" ++ sanitize_nul(q) ++ "}"

def preparation_text(prep: Maybe<&2, String>) -> String:
  match prep:
    case None{}:
      SNil{}
    case Some{+p}:
      "(" ++ sanitize_nul(p) ++ ")"

def render_ingredient(ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{+name, +quantity, +units, +preparation, is_recipe_reference, span}:
      "@" ++ sanitize_nul(name) ++ ingredient_braces(quantity, units) ++
        preparation_text(preparation)

def render_cookware(cookware: Model.Cookware) -> String:
  match cookware:
    case Model.Cookware{+name, +quantity, span}:
      "#" ++ sanitize_nul(name) ++ plain_braces(quantity)

def render_timer(timer: Model.Timer) -> String:
  match timer:
    case Model.Timer{+name, +quantity, +units, span}:
      "~" ++ sanitize_nul(name) ++ ingredient_braces(quantity, units)


# Lexical safety for literal text.  Joining source lines can make a malformed
# line-local token look valid in the normalized model (for example the text
# `@x{ }` came from `@x{\n}`).  Canonical output cannot use Oliver's original
# source spans in this Bend model, so instead it conservatively writes one
# existing space inside such a token-shaped region as a newline.  Parsing that
# newline joins it back to the same space while keeping the token literal.
type ProtectMode is Data:
  ProtectNormal{}
  ProtectBrace{replaced: Bool}
  ProtectWaitPrep{}
  ProtectPrep{replaced: Bool}

type ProtectOpen is Data:
  ProtectOpenNone{}
  ProtectOpenBrace{}
  ProtectOpenPrep{}
  ProtectOpenName{out: String}

def protect_word_start(+c: Char) -> Bool:
  Bool.or(Parser.word_char(c), Char.is_eq(c, '.'))

def protect_rev_scan(s: String, +seen: Bool, +first_valid: Bool) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{+h, +t}:
      ser_if(Bool, Parser.token_marker(h),
        u => Bool.or(Bool.and(seen, first_valid), Char.is_eq(h, '~')),
        u =>
          ser_if(Bool, Parser.unicode_space(h),
            v =>
              ser_if(Bool, seen,
                w => protect_rev_scan(t, True{}, False{}),
                w => False{}),
            v =>
              ser_if(Bool, Bool.and(Parser.unicode_punctuation(h),
                  Bool.not(Parser.multiword_exception(h))),
                w => False{},
                w => protect_rev_scan(t, True{}, protect_word_start(h)))))

def protect_prefix_valid(+out_rev: String) -> Bool:
  protect_rev_scan(out_rev, False{}, False{})

# Replace one ASCII space in the reversed candidate name with a newline.  The
# scan walks backward through the name and stops at its marker; validation has
# already established that this region is token-shaped.
def protect_rev_insert(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{+h, +t}:
      ser_if(Maybe<&2, String>, Parser.token_marker(h),
        u => None{},
        u =>
          ser_if(Maybe<&2, String>, Char.is_eq(h, ' '),
            v => Some{SCon{'\n', t}},
            v => Parser.ck_maybe(String, Maybe<&2, String>, protect_rev_insert(t),
              +rest => Some{SCon{h, rest}},
              w => None{})))

def brace_close_index_go(s: String, idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{'}', t}:
      Some{idx}
    case SCon{'{', t}:
      None{}
    case SCon{'\n', t}:
      None{}
    case SCon{h, t}:
      brace_close_index_go(t, 1n+idx)

def prep_close_index_go(s: String, idx: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{')', t}:
      Some{idx}
    case SCon{'(', t}:
      None{}
    case SCon{'\n', t}:
      None{}
    case SCon{h, t}:
      prep_close_index_go(t, 1n+idx)

def prep_has_space_after(+after_close: String) -> Bool:
  match after_close:
    case SCon{'(', +t}:
      Parser.ck_maybe(Nat, Bool, prep_close_index_go(t, 0n),
        +idx => String.contains(String.take(t, idx), " "),
        w => False{})
    case x:
      False{}

def brace_content_has_space(+tail: String, +idx: Nat) -> Bool:
  String.contains(String.take(tail, idx), " ")

def protect_open_with_close(+out_rev: String, +tail: String, +idx: Nat) -> ProtectOpen:
  ser_if(ProtectOpen, brace_content_has_space(tail, idx),
    u => ProtectOpenBrace{},
    u =>
      +after_close = String.drop(tail, 1n+idx)
      ser_if(ProtectOpen, prep_has_space_after(after_close),
        v => ProtectOpenPrep{},
        v =>
          Parser.ck_maybe(String, ProtectOpen, protect_rev_insert(out_rev),
            +newout => ProtectOpenName{newout},
            w => ProtectOpenNone{})))

def protect_open_case(+out_rev: String, +tail: String) -> ProtectOpen:
  ser_if(ProtectOpen, protect_prefix_valid(out_rev),
    u =>
      Parser.ck_maybe(Nat, ProtectOpen, brace_close_index_go(tail, 0n),
        +idx => protect_open_with_close(out_rev, tail, idx),
        w => ProtectOpenNone{}),
    u => ProtectOpenNone{})

def starts_open_paren(+s: String) -> Bool:
  match s:
    case SCon{'(', t}:
      True{}
    case x:
      False{}

def protect_open_elim(-A: Type, choice: ProtectOpen, none: Unit -> A,
    brace: Unit -> A, prep: Unit -> A, name: String -> A) -> A:
  match choice:
    case ProtectOpenNone{}:
      none(Unit{})
    case ProtectOpenBrace{}:
      brace(Unit{})
    case ProtectOpenPrep{}:
      prep(Unit{})
    case ProtectOpenName{+out}:
      name(out)

def protect_literal_go(s: String, +out: String, mode: ProtectMode) -> String:
  match s:
    case SNil{}:
      String.reverse(out)
    case SCon{'{', +t}:
      match mode:
        case ProtectNormal{}:
          protect_open_elim(String, protect_open_case(out, t),
            v => protect_literal_go(t, SCon{'{', out}, ProtectNormal{}),
            v => protect_literal_go(t, SCon{'{', out}, ProtectBrace{False{}}),
            v => protect_literal_go(t, SCon{'{', out}, ProtectWaitPrep{}),
            +newout => protect_literal_go(t, SCon{'{', newout}, ProtectNormal{}))
        case ProtectBrace{+replaced}:
          protect_literal_go(t, SCon{'{', out}, ProtectBrace{replaced})
        case ProtectWaitPrep{}:
          protect_literal_go(t, SCon{'{', out}, ProtectWaitPrep{})
        case ProtectPrep{+replaced}:
          protect_literal_go(t, SCon{'{', out}, ProtectPrep{replaced})
    case SCon{' ', +t}:
      match mode:
        case ProtectNormal{}:
          protect_literal_go(t, SCon{' ', out}, ProtectNormal{})
        case ProtectBrace{+replaced}:
          ser_if(String, replaced,
            u => protect_literal_go(t, SCon{' ', out}, ProtectBrace{replaced}),
            u => protect_literal_go(t, SCon{'\n', out}, ProtectBrace{True{}}))
        case ProtectWaitPrep{}:
          protect_literal_go(t, SCon{' ', out}, ProtectWaitPrep{})
        case ProtectPrep{+replaced}:
          ser_if(String, replaced,
            u => protect_literal_go(t, SCon{' ', out}, ProtectPrep{replaced}),
            u => protect_literal_go(t, SCon{'\n', out}, ProtectPrep{True{}}))
    case SCon{'}', +t}:
      match mode:
        case ProtectNormal{}:
          protect_literal_go(t, SCon{'}', out}, ProtectNormal{})
        case ProtectBrace{replaced}:
          protect_literal_go(t, SCon{'}', out}, ProtectNormal{})
        case ProtectWaitPrep{}:
          ser_if(String, starts_open_paren(t),
            u => protect_literal_go(t, SCon{'}', out}, ProtectPrep{False{}}),
            u => protect_literal_go(t, SCon{'}', out}, ProtectNormal{}))
        case ProtectPrep{+replaced}:
          protect_literal_go(t, SCon{'}', out}, ProtectPrep{replaced})
    case SCon{')', +t}:
      match mode:
        case ProtectNormal{}:
          protect_literal_go(t, SCon{')', out}, ProtectNormal{})
        case ProtectBrace{+replaced}:
          protect_literal_go(t, SCon{')', out}, ProtectBrace{replaced})
        case ProtectWaitPrep{}:
          protect_literal_go(t, SCon{')', out}, ProtectWaitPrep{})
        case ProtectPrep{replaced}:
          protect_literal_go(t, SCon{')', out}, ProtectNormal{})
    case SCon{h, t}:
      match mode:
        case ProtectNormal{}:
          protect_literal_go(t, SCon{h, out}, ProtectNormal{})
        case ProtectBrace{+replaced}:
          protect_literal_go(t, SCon{h, out}, ProtectBrace{replaced})
        case ProtectWaitPrep{}:
          protect_literal_go(t, SCon{h, out}, ProtectWaitPrep{})
        case ProtectPrep{+replaced}:
          protect_literal_go(t, SCon{h, out}, ProtectPrep{replaced})

def protect_literal_text(+s: String) -> String:
  protect_literal_go(s, SNil{}, ProtectNormal{})


# Contextual lexical safety across part boundaries.  An unbraced token followed
# by normalized join text can accidentally become a braced multiword token, and
# a braced ingredient followed by text starting with `(` can accidentally gain
# a preparation.  Rewriting one join space as a physical newline preserves the
# parsed text exactly; where no such space exists, a `[- -]` barrier preserves
# the zero-width boundary instead.  The same barrier protects a literal trailing
# backslash from becoming a forced line-break marker.
type TailRisk is Data:
  TailNone{}
  TailName{}
  TailPrep{}

def scan_multiword_hit(+s: String) -> Bool:
  Parser.ck_maybe(Parser.NameScan, Bool, Parser.scan_multiword(s),
    +hit => True{},
    u => False{})

def drop_ascii_spaces(s: String) -> String:
  match s:
    case SCon{' ', t}:
      drop_ascii_spaces(t)
    case x:
      x

def valid_brace_group(+text: String) -> Bool:
  match text:
    case SCon{'{', +rest}:
      Parser.ck_maybe(Nat, Bool, brace_close_index_go(rest, 0n),
        +idx => True{},
        u => False{})
    case x:
      False{}

def protect_compact_name(+text: String) -> String:
  ser_if(String, scan_multiword_hit(text),
    u => "[- -]" ++ text,
    u =>
      ser_if(String, valid_brace_group(text),
        v => "[- -]" ++ text,
        v => text))

def protect_name_continuation(+text: String) -> String:
  match text:
    case SCon{' ', +rest}:
      +unspaced = drop_ascii_spaces(rest)
      ser_if(String, Bool.and(Parser.valid_token_start(unspaced), scan_multiword_hit(unspaced)),
        u => SCon{'\n', rest},
        u => SCon{' ', rest})
    case x:
      protect_compact_name(x)

def replace_prep_space_go(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{' ', t}:
      SCon{'\n', t}
    case SCon{')', t}:
      SCon{')', t}
    case SCon{h, t}:
      SCon{h, replace_prep_space_go(t)}

def valid_prep_group(+text: String) -> Bool:
  match text:
    case SCon{'(', +rest}:
      Parser.ck_maybe(Nat, Bool, prep_close_index_go(rest, 0n),
        +idx => True{},
        u => False{})
    case x:
      False{}

def protect_prep_continuation(+text: String) -> String:
  match text:
    case SCon{'(', +rest}:
      ser_if(String, prep_has_space_after(SCon{'(', rest}),
        u => SCon{'(', replace_prep_space_go(rest)},
        u =>
          ser_if(String, valid_prep_group(SCon{'(', rest}),
            v => "[- -]" ++ SCon{'(', rest},
            v => SCon{'(', rest}))
    case x:
      x

def protect_context_text(risk: TailRisk, +text: String) -> String:
  match risk:
    case TailNone{}:
      text
    case TailName{}:
      protect_name_continuation(text)
    case TailPrep{}:
      protect_prep_continuation(text)

def quantity_tail_risk(quantity: Maybe<&2, String>, +braced: TailRisk, +unbraced: TailRisk) -> TailRisk:
  match quantity:
    case None{}:
      unbraced
    case Some{q}:
      braced

def ingredient_tail_risk(ingredient: Model.Ingredient) -> TailRisk:
  match ingredient:
    case Model.Ingredient{name, quantity, units, preparation, is_recipe_reference, span}:
      quantity_tail_risk(quantity, TailPrep{}, TailName{})

def cookware_tail_risk(cookware: Model.Cookware) -> TailRisk:
  match cookware:
    case Model.Cookware{name, quantity, span}:
      quantity_tail_risk(quantity, TailNone{}, TailName{})

def timer_tail_risk(timer: Model.Timer) -> TailRisk:
  match timer:
    case Model.Timer{name, quantity, units, span}:
      quantity_tail_risk(quantity, TailNone{}, TailName{})

def protect_trailing_backslash(+text: String, +at_end: Bool) -> String:
  ser_if(String, Bool.and(at_end, String.ends_with(text, "\\")),
    u => text ++ "[- -]",
    u => text)

def render_context_text(+text: String, risk: TailRisk, +at_end: Bool) -> String:
  sanitize_nul(protect_trailing_backslash(protect_literal_text(protect_context_text(risk, text)), at_end))

def render_part_list_go(parts: List<&2, Model.CookPart>, risk: TailRisk) -> List<&2, String>:
  match parts:
    case Nil{}:
      Nil{}
    case Model.CookText{+text, span} <> +t:
      render_context_text(text, risk, List.is_empty(&2, Model.CookPart, t)) <> render_part_list_go(t, TailNone{})
    case Model.CookIngredient{+ingredient, span} <> t:
      render_ingredient(ingredient) <> render_part_list_go(t, ingredient_tail_risk(ingredient))
    case Model.CookCookware{+cookware, span} <> t:
      render_cookware(cookware) <> render_part_list_go(t, cookware_tail_risk(cookware))
    case Model.CookTimer{+timer, span} <> t:
      render_timer(timer) <> render_part_list_go(t, timer_tail_risk(timer))
    case Model.CookLineBreak{span} <> t:
      "\\\n" <> render_part_list_go(t, TailNone{})

def render_part_list(parts: List<&2, Model.CookPart>) -> List<&2, String>:
  render_part_list_go(parts, TailNone{})

def render_step(+parts: List<&2, Model.CookPart>) -> String:
  String.concat(render_part_list(parts))

def render_note(+text: String) -> String:
  ser_if(String, String.is_empty(text),
    u => ">",
    u => "> " ++ sanitize_nul(text))

def section_header(+name: String) -> String:
  ser_if(String, String.is_empty(name),
    u => "= ",
    u =>
      ser_if(String, String.ends_with(name, "="),
        v => "= " ++ sanitize_nul(name) ++ " =",
        v => "= " ++ sanitize_nul(name)))

def render_section_with_children(+name: String, +children: String) -> String:
  ser_if(String, String.is_empty(children),
    u => section_header(name),
    u => section_header(name) ++ "\n\n" ++ children)

# Render every block as one string list element.  Section children use the
# same renderer recursively; because sections are flat in parsed recipes this
# recursion is normally shallow, and it is structurally decreasing regardless.
def render_block_list(blocks: List<&2, Model.CookBlock>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case h <> t:
      match h:
        case Model.CookStep{+parts, span}:
          render_step(parts) <> render_block_list(t)
        case Model.CookNote{+text, span}:
          render_note(text) <> render_block_list(t)
        case Model.CookSection{+name, +blocks, span}:
          +children = String.join(render_block_list(blocks), "\n\n")
          render_section_with_children(name, children) <> render_block_list(t)

def render_blocks_body(+blocks: List<&2, Model.CookBlock>) -> String:
  String.join(render_block_list(blocks), "\n\n")

def finish_blocks_body(+body: String) -> String:
  ser_if(String, String.is_empty(body),
    u => SNil{},
    u => body ++ "\n")

def render_blocks(+blocks: List<&2, Model.CookBlock>) -> String:
  finish_blocks_body(render_blocks_body(blocks))

def render_frontmatter(+raw: String) -> String:
  "---\n" ++ sanitize_nul(raw) ++ "---\n"

def combine_frontmatter_body(+front: String, +body: String) -> String:
  ser_if(String, String.is_empty(body),
    u => front,
    u => front ++ "\n" ++ body)

def serialize_parts(+fm: Maybe<&2, Model.Frontmatter>, +blocks: List<&2, Model.CookBlock>) -> String:
  match fm:
    case None{}:
      render_blocks(blocks)
    case Some{+frontmatter}:
      match frontmatter:
        case Model.Frontmatter{+raw, span}:
          combine_frontmatter_body(render_frontmatter(raw), render_blocks(blocks))

def serialize_recipe(+recipe: Model.Recipe) -> String:
  match recipe:
    case Model.Recipe{+frontmatter, +blocks}:
      serialize_parts(frontmatter, blocks)
