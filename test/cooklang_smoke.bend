import Base
import ../src/ast.bend as Ast
import ../src/cooklang/model.bend as Model
import ../src/cooklang/parser.bend as Parser
import ../src/cooklang/serialize.bend as Serializer

# Fixed-input structural and serialization smoke tests.  Strings are escaped so
# every inspected recipe occupies exactly one pinned output line.
def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\\', t}:
      "\\\\" ++ esc(t)
    case SCon{'\n', t}:
      "\\n" ++ esc(t)
    case SCon{'\r', t}:
      "\\r" ++ esc(t)
    case SCon{'"', t}:
      "\\\"" ++ esc(t)
    case SCon{'\t', t}:
      "\\t" ++ esc(t)
    case SCon{h, t}:
      SCon{h, esc(t)}

def q(s: String) -> String:
  "\"" ++ esc(s) ++ "\""

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      "@" ++ U32.show(start) ++ "-" ++ U32.show(end)

def show_maybe_string(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "None"
    case Some{x}:
      "Some(" ++ q(x) ++ ")"

def show_ingredient(ingredient: Model.Ingredient) -> String:
  match ingredient:
    case Model.Ingredient{name, quantity, units, preparation, is_recipe_reference, span}:
      "I(" ++ q(name) ++ "," ++ show_maybe_string(quantity) ++ "," ++
        show_maybe_string(units) ++ "," ++ show_maybe_string(preparation) ++
        ",ref=" ++ Bool.show(is_recipe_reference) ++ ")" ++ show_span(span)

def show_cookware(cookware: Model.Cookware) -> String:
  match cookware:
    case Model.Cookware{name, quantity, span}:
      "C(" ++ q(name) ++ "," ++ show_maybe_string(quantity) ++ ")" ++ show_span(span)

def show_timer(timer: Model.Timer) -> String:
  match timer:
    case Model.Timer{name, quantity, units, span}:
      "Tmr(" ++ q(name) ++ "," ++ show_maybe_string(quantity) ++ "," ++
        show_maybe_string(units) ++ ")" ++ show_span(span)

def show_parts(parts: List<&2, Model.CookPart>) -> String:
  match parts:
    case Nil{}:
      ""
    case Model.CookText{text, span} <> rest:
      "T" ++ q(text) ++ show_span(span) ++ ";" ++ show_parts(rest)
    case Model.CookIngredient{ingredient, span} <> rest:
      show_ingredient(ingredient) ++ ";" ++ show_parts(rest)
    case Model.CookCookware{cookware, span} <> rest:
      show_cookware(cookware) ++ ";" ++ show_parts(rest)
    case Model.CookTimer{timer, span} <> rest:
      show_timer(timer) ++ ";" ++ show_parts(rest)
    case Model.CookLineBreak{span} <> rest:
      "Br" ++ show_span(span) ++ ";" ++ show_parts(rest)

def show_blocks(blocks: List<&2, Model.CookBlock>) -> String:
  match blocks:
    case Nil{}:
      ""
    case Model.CookStep{parts, span} <> rest:
      "Step[" ++ show_parts(parts) ++ "]" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Model.CookNote{text, span} <> rest:
      "Note" ++ q(text) ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Model.CookSection{name, blocks, span} <> rest:
      "Section" ++ q(name) ++ "{" ++ show_blocks(blocks) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)

def show_frontmatter(frontmatter: Maybe<&2, Model.Frontmatter>) -> String:
  match frontmatter:
    case None{}:
      "None"
    case Some{fm}:
      match fm:
        case Model.Frontmatter{raw, span}:
          "Some(" ++ q(raw) ++ show_span(span) ++ ")"

def inspect_recipe(recipe: Model.Recipe) -> String:
  match recipe:
    case Model.Recipe{frontmatter, blocks}:
      "Recipe{fm=" ++ show_frontmatter(frontmatter) ++ ";" ++ show_blocks(blocks) ++ "}"

def inspect_bounded(m: Maybe<&2, Model.Recipe>) -> String:
  match m:
    case None{}:
      "None"
    case Some{recipe}:
      "Some(" ++ q(Serializer.serialize_recipe(recipe)) ++ ")"

def print_parse(name: String, input: String) -> IO(Unit):
  IO.print(name ++ "=" ++ inspect_recipe(Parser.parse_cooklang(input)))

def print_bounded(name: String, input: String, max: Nat) -> IO(Unit):
  IO.print(name ++ "=" ++ inspect_bounded(Parser.parse_cooklang_bounded(input, max)))

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

def expect_serialized(+name: String, +input: String, +expected: String) -> IO(Unit):
  expect_equal(name, expected, Serializer.serialize_recipe(Parser.parse_cooklang(input)))


def span0() -> Ast.Span:
  Ast.Span{0, 0}

def manual_trailing_equals_section() -> Model.Recipe:
  Model.Recipe{None{}, [
    Model.CookSection{"Odd=", [
      Model.CookStep{[Model.CookText{"x", span0()}], span0()}
    ], span0()}
  ]}

def main() -> IO(Unit):
  do IO<Unit>:
    print_parse("empty", "")
    print_parse("basic", "Add @chilli{3%items}, @ground black pepper{ 1/2 % tsp }( crushed ) and #frying pan{2}; wait ~oven{10%minutes}.\n")
    print_parse("unbraced", "@salt and @pepper\n#pan\n~rest\n")
    print_parse("recipe-refs", "Use @./sauces/Hollandaise{150%g} and @./plain{2}.\n")
    print_parse("malformed", "Message @ example{}\nRecipe # 5\nIt is ~ {5}\n@x{one{two}}\n")
    print_parse("comments", "@thyme{2%sprigs} -- testing comments\nand some text\n\nx [- c -] y\n")
    print_parse("multiline-comment", "x [- c\n\nq -] y\n")
    print_parse("comment-barrier", "@x[-c-]{1}\n")
    print_parse("forced-breaks", "first\\\nsecond\n\nfirst\\  \t\nsecond\n\nfirst\\\n\nsecond\n")
    print_parse("empty-forced-breaks", "\\\n\nx\n\\\ny\n")
    print_parse("frontmatter-crlf", "---\r\nservings: 2\r\n---\r\nStep\r\n")
    print_parse("unclosed-frontmatter", "---\r\nservings: 2\r\n")
    print_parse("notes-sections", "intro\n\n> a note\ncontinued\n\n= Dough\nstep one\n\n= Bake\nstep two\n")
    print_parse("note-forms", "> first\nsecond\n> third\n\n> \n")
    print_parse("unicode", "Add some @🧂\nLet it ~rest\u{2009}then serve\n")
    print_parse("line-split-token", "@x{\n}\n\n@x{1\n}\n")
    print_parse("dashes", "x--y\nz\n\nx---y\nz\n")
    print_bounded("bound-empty-zero", "", 0n)
    print_bounded("bound-nonempty-zero", "x", 0n)
    print_bounded("bound-ascii-fit", "abc", 3n)
    print_bounded("bound-ascii-small", "abc", 2n)
    print_bounded("bound-unicode-fit", "é", 2n)
    print_bounded("bound-unicode-small", "é", 1n)
    expect_serialized("serialize-basic", "Add @chilli{3%items}\n\nServe in #pot.\n", "Add @chilli{3%items}\n\nServe in #pot.\n")
    expect_serialized("serialize-comments", "@thyme{2%sprigs} -- testing comments\nand some text\n", "@thyme{2%sprigs}  and some text\n")
    expect_serialized("serialize-forced-eof", "first\\\n", "first\\\n\n")
    expect_serialized("serialize-sections", "== Dough ==\nstep\n", "= Dough\n\nstep\n")
    expect_serialized("serialize-note", "> first\nsecond\n", "> first second\n")
    expect_serialized("serialize-line-split-token", "@x{1\n}\n", "@x{1\n}\n")
    expect_serialized("serialize-line-split-name", "@hot\nchilli{1}\n", "@hot\nchilli{1}\n")
    expect_serialized("serialize-line-split-cookware", "#frying\npan{1}\n", "#frying\npan{1}\n")
    expect_serialized("serialize-line-split-preparation", "@x{1}(pre\np)\n", "@x{1}(pre\np)\n")
    expect_serialized("serialize-comment-barrier-braces", "@x[-c-]{1}\n", "@x[- -]{1}\n")
    expect_serialized("serialize-comment-barrier-prep", "@x{1}[-c-](prep)\n", "@x{1}[- -](prep)\n")
    expect_serialized("serialize-commented-trailing-backslash", "\\-- note\n", "\\[- -]\n")
    expect_serialized("serialize-nul", "a\u{0}b\n", "a\u{FFFD}b\n")
    expect_serialized("serialize-empty-note", "> \n", ">\n")
    expect_serialized("serialize-empty-quantities", "@x{} #y{} ~{}\n", "@x{} #y{} ~{}\n")
    expect_equal("serialize-section-name-trailing-equals", "= Odd= =\n\nx\n",
      Serializer.serialize_recipe(manual_trailing_equals_section()))

#|empty=Recipe{fm=None;}
#|basic=Recipe{fm=None;Step[T"Add "@0-0;I("chilli",Some("3"),Some("items"),None,ref=False)@0-0;T", "@0-0;I("ground black pepper",Some("1/2"),Some("tsp"),Some("crushed"),ref=False)@0-0;T" and "@0-0;C("frying pan",Some("2"))@0-0;T"; wait "@0-0;Tmr("oven",Some("10"),Some("minutes"))@0-0;T"."@0-0;]@0-110;}
#|unbraced=Recipe{fm=None;Step[I("salt",None,None,None,ref=False)@0-0;T" and "@0-0;I("pepper",None,None,None,ref=False)@0-0;T" "@0-0;C("pan",None)@0-0;T" "@0-0;Tmr("rest",None,None)@0-0;]@0-28;}
#|recipe-refs=Recipe{fm=None;Step[T"Use "@0-0;I("./sauces/Hollandaise",Some("150"),Some("g"),None,ref=True)@0-0;T" and "@0-0;I("./plain",Some("2"),Some(""),None,ref=True)@0-0;T"."@0-0;]@0-49;}
#|malformed=Recipe{fm=None;Step[T"Message @ example{} Recipe # 5 It is ~ {5} @x{one{two}}"@0-0;]@0-55;}
#|comments=Recipe{fm=None;Step[I("thyme",Some("2"),Some("sprigs"),None,ref=False)@0-0;T"  and some text"@0-0;]@0-50;Step[T"x  y"@0-0;]@52-63;}
#|multiline-comment=Recipe{fm=None;Step[T"x   y"@0-0;]@0-14;}
#|comment-barrier=Recipe{fm=None;Step[I("x",None,None,None,ref=False)@0-0;T"{1}"@0-0;]@0-10;}
#|forced-breaks=Recipe{fm=None;Step[T"first"@0-0;Br@0-0;T"second"@0-0;]@0-13;Step[T"first"@0-0;Br@0-0;T"second"@0-0;]@15-31;Step[T"first"@0-0;Br@0-0;]@33-39;Step[T"second"@0-0;]@41-47;}
#|empty-forced-breaks=Recipe{fm=None;Step[Br@0-0;]@0-1;Step[T"x"@0-0;Br@0-0;T"y"@0-0;]@3-8;}
#|frontmatter-crlf=Recipe{fm=Some("servings: 2\r\n"@0-23);Step[T"Step"@0-0;]@23-27;}
#|unclosed-frontmatter=Recipe{fm=None;Step[T"--- servings: 2"@0-0;]@0-16;}
#|notes-sections=Recipe{fm=None;Step[T"intro"@0-0;]@0-5;Note"a note continued"@7-25;Section"Dough"{Step[T"step one"@0-0;]@35-43;}@27-34;Section"Bake"{Step[T"step two"@0-0;]@52-60;}@45-51;}
#|note-forms=Recipe{fm=None;Note"first second third"@0-22;Note""@24-26;}
#|unicode=Recipe{fm=None;Step[T"Add some "@0-0;I("🧂",None,None,None,ref=False)@0-0;T" Let it "@0-0;Tmr("rest",None,None)@0-0;T" then serve"@0-0;]@0-40;}
#|line-split-token=Recipe{fm=None;Step[T"@x{ }"@0-0;]@0-5;Step[T"@x{1 }"@0-0;]@7-13;}
#|dashes=Recipe{fm=None;Step[T"x z"@0-0;]@0-6;Step[T"x---y z"@0-0;]@8-15;}
#|bound-empty-zero=Some("")
#|bound-nonempty-zero=None
#|bound-ascii-fit=Some("abc\n")
#|bound-ascii-small=None
#|bound-unicode-fit=Some("é\n")
#|bound-unicode-small=None
#|PASS serialize-basic
#|PASS serialize-comments
#|PASS serialize-forced-eof
#|PASS serialize-sections
#|PASS serialize-note
#|PASS serialize-line-split-token
#|PASS serialize-line-split-name
#|PASS serialize-line-split-cookware
#|PASS serialize-line-split-preparation
#|PASS serialize-comment-barrier-braces
#|PASS serialize-comment-barrier-prep
#|PASS serialize-commented-trailing-backslash
#|PASS serialize-nul
#|PASS serialize-empty-note
#|PASS serialize-empty-quantities
#|PASS serialize-section-name-trailing-equals
