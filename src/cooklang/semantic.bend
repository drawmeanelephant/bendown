import Base
import ./model.bend as Model

def maybe_string_eq(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      String.eq(x, y)
    case None{} Some{y}:
      False{}
    case Some{x} None{}:
      False{}

def bool_eq(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}:
      True{}
    case False{} False{}:
      True{}
    case True{} False{}:
      False{}
    case False{} True{}:
      False{}

def ingredient_eq(a: Model.Ingredient, b: Model.Ingredient) -> Bool:
  match a b:
    case Model.Ingredient{an, aq, au, ap, ar, aspan} Model.Ingredient{bn, bq, bu, bp, br, bspan}:
      Bool.and(String.eq(an, bn), Bool.and(maybe_string_eq(aq, bq),
        Bool.and(maybe_string_eq(au, bu), Bool.and(maybe_string_eq(ap, bp), bool_eq(ar, br)))))

def cookware_eq(a: Model.Cookware, b: Model.Cookware) -> Bool:
  match a b:
    case Model.Cookware{an, aq, aspan} Model.Cookware{bn, bq, bspan}:
      Bool.and(String.eq(an, bn), maybe_string_eq(aq, bq))

def timer_eq(a: Model.Timer, b: Model.Timer) -> Bool:
  match a b:
    case Model.Timer{an, aq, au, aspan} Model.Timer{bn, bq, bu, bspan}:
      Bool.and(String.eq(an, bn), Bool.and(maybe_string_eq(aq, bq), maybe_string_eq(au, bu)))

def bool_and(a: Bool, b: Bool) -> Bool:
  Bool.and(a, b)

def part_eq(a: Model.CookPart, b: Model.CookPart) -> Bool:
  match a b:
    case Model.CookText{atext, aspan} Model.CookText{btext, bspan}:
      String.eq(atext, btext)
    case Model.CookIngredient{ai, aspan} Model.CookIngredient{bi, bspan}:
      ingredient_eq(ai, bi)
    case Model.CookCookware{ac, aspan} Model.CookCookware{bc, bspan}:
      cookware_eq(ac, bc)
    case Model.CookTimer{at, aspan} Model.CookTimer{bt, bspan}:
      timer_eq(at, bt)
    case Model.CookLineBreak{aspan} Model.CookLineBreak{bspan}:
      True{}
    case Model.CookText{atext, aspan} other:
      False{}
    case Model.CookIngredient{ai, aspan} other:
      False{}
    case Model.CookCookware{ac, aspan} other:
      False{}
    case Model.CookTimer{at, aspan} other:
      False{}
    case Model.CookLineBreak{aspan} other:
      False{}

def parts_eq(a: List<&2, Model.CookPart>, b: List<&2, Model.CookPart>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case ah <> at bh <> bt:
      Bool.and(part_eq(ah, bh), parts_eq(at, bt))
    case Nil{} bh <> bt:
      False{}
    case ah <> at Nil{}:
      False{}

def blocks_eq(a: List<&2, Model.CookBlock>, b: List<&2, Model.CookBlock>) -> Bool:
  match a:
    case Nil{}:
      match b:
        case Nil{}:
          True{}
        case bh <> bt:
          False{}
    case ah <> at:
      match ah:
        case Model.CookStep{ap, aspan}:
          match b:
            case Nil{}:
              False{}
            case bh <> bt:
              match bh:
                case Model.CookStep{bp, bspan}:
                  Bool.and(parts_eq(ap, bp), blocks_eq(at, bt))
                case Model.CookNote{btext, bspan}:
                  False{}
                case Model.CookSection{bn, bb, bspan}:
                  False{}
        case Model.CookNote{atext, aspan}:
          match b:
            case Nil{}:
              False{}
            case bh <> bt:
              match bh:
                case Model.CookStep{bp, bspan}:
                  False{}
                case Model.CookNote{btext, bspan}:
                  Bool.and(String.eq(atext, btext), blocks_eq(at, bt))
                case Model.CookSection{bn, bb, bspan}:
                  False{}
        case Model.CookSection{an, ab, aspan}:
          match b:
            case Nil{}:
              False{}
            case bh <> bt:
              match bh:
                case Model.CookStep{bp, bspan}:
                  False{}
                case Model.CookNote{btext, bspan}:
                  False{}
                case Model.CookSection{bn, bb, bspan}:
                  Bool.and(String.eq(an, bn),
                    Bool.and(blocks_eq(ab, bb), blocks_eq(at, bt)))

def frontmatter_eq_some(af: Model.Frontmatter, b: Maybe<&2, Model.Frontmatter>) -> Bool:
  match af:
    case Model.Frontmatter{araw, aspan}:
      match b:
        case None{}:
          False{}
        case Some{bf}:
          match bf:
            case Model.Frontmatter{braw, bspan}:
              String.eq(araw, braw)

def frontmatter_eq(a: Maybe<&2, Model.Frontmatter>, b: Maybe<&2, Model.Frontmatter>) -> Bool:
  match a:
    case None{}:
      match b:
        case None{}:
          True{}
        case Some{bf}:
          False{}
    case Some{af}:
      frontmatter_eq_some(af, b)

def recipe_eq(a: Model.Recipe, b: Model.Recipe) -> Bool:
  match a b:
    case Model.Recipe{af, ab} Model.Recipe{bf, bb}:
      Bool.and(frontmatter_eq(af, bf), blocks_eq(ab, bb))
