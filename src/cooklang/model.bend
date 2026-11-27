import Base
import ../ast.bend as Ast

type Rational is Data:
  Rational{num: Nat, den: Nat}

type Frontmatter is Data:
  Frontmatter{raw: String, span: Ast.Span}

type Ingredient is Data:
  Ingredient{name: String, quantity: Maybe<&2, String>, units: Maybe<&2, String>,
    preparation: Maybe<&2, String>, is_recipe_reference: Bool, span: Ast.Span}

type Cookware is Data:
  Cookware{name: String, quantity: Maybe<&2, String>, span: Ast.Span}

type Timer is Data:
  Timer{name: String, quantity: Maybe<&2, String>, units: Maybe<&2, String>, span: Ast.Span}

type CookPart is Data:
  CookText{text: String, span: Ast.Span}
  CookIngredient{ingredient: Ingredient, span: Ast.Span}
  CookCookware{cookware: Cookware, span: Ast.Span}
  CookTimer{timer: Timer, span: Ast.Span}
  CookLineBreak{span: Ast.Span}

type CookBlock is Data:
  CookStep{parts: List<&2, CookPart>, span: Ast.Span}
  CookNote{text: String, span: Ast.Span}
  CookSection{name: String, blocks: List<&2, CookBlock>, span: Ast.Span}

type Recipe is Data:
  Recipe{frontmatter: Maybe<&2, Frontmatter>, blocks: List<&2, CookBlock>}

def recipe_empty() -> Recipe:
  Recipe{None{}, []}
