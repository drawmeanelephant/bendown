import Base
import ../src/unicode_casefold.bend as UnicodeCasefold

def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  ifs(IO(Unit), String.eq(expected, actual),
    u => IO.print("PASS " ++ name),
    u => IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected: " ++ String.quote(expected) ++ "\nactual:   " ++ String.quote(actual)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- expect_equal("ascii-uppercase", "a", UnicodeCasefold.unicode_casefold_char('A'))
    Unit <- expect_equal("ascii-lowercase-identity", "x", UnicodeCasefold.unicode_casefold_char('x'))
    Unit <- expect_equal("latin-umlaut", "ä", UnicodeCasefold.unicode_casefold_char('Ä'))
    Unit <- expect_equal("latin-sharp-s-expansion", "ss", UnicodeCasefold.unicode_casefold_char('ß'))
    Unit <- expect_equal("capital-sharp-s-expansion", "ss", UnicodeCasefold.unicode_casefold_char('ẞ'))
    Unit <- expect_equal("turkish-dotted-i-expansion", "i̇", UnicodeCasefold.unicode_casefold_char('İ'))
    Unit <- expect_equal("latin-ligature-expansion", "ff", UnicodeCasefold.unicode_casefold_char('ﬀ'))
    Unit <- expect_equal("greek-alpha-ypogegrammeni-expansion", "αι", UnicodeCasefold.unicode_casefold_char('ᾼ'))
    Unit <- expect_equal("armenian-capital", "ա", UnicodeCasefold.unicode_casefold_char('Ա'))
    IO.print("unicode casefold smoke: all checks passed")
