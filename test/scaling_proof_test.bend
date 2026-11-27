import Base
import ../src/cooklang/model.bend as Model
import ../src/cooklang/rational.bend as Rational
import ../src/cooklang/scaling_laws.bend as Core
import ../src/cooklang/scaling_proof.bend as ScalingProof

def rational_eq(+a: Model.Rational, +b: Model.Rational) -> Bool:
  match a b:
    case Model.Rational{+n1, +d1} Model.Rational{+n2, +d2}:
      Bool.and(Nat.is_eq(n1, n2), Nat.is_eq(d1, d2))

def expect_rational_gate(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)
    case True{}:
      IO.print("PASS " ++ name)

def expect_rational(+name: String, +expected: Model.Rational, +actual: Model.Rational) -> IO(Unit):
  expect_rational_gate(name, rational_eq(expected, actual))

def expect_maybe_rational(+name: String, +expected: Model.Rational, actual: Maybe<&2, Model.Rational>) -> IO(Unit):
  match actual:
    case None{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": unexpected None")
    case Some{value}:
      expect_rational(name, expected, value)

def expect_none(+name: String, actual: Maybe<&2, Model.Rational>) -> IO(Unit):
  match actual:
    case None{}:
      IO.print("PASS " ++ name)
    case Some{value}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": unexpected Some")

def main() -> IO(Unit):
  do IO<Unit>:
    expect_rational("core inverse roundtrip 3/2 by 2/5",
      Model.Rational{3n, 2n},
      Core.core_inverse_roundtrip(Model.Rational{3n, 2n}, 2n, 5n))
    expect_rational("core inverse roundtrip zero",
      Model.Rational{0n, 1n},
      Core.core_inverse_roundtrip(Model.Rational{0n, 1n}, 7n, 3n))
    expect_rational("core exact common-factor cancellation",
      Model.Rational{3n, 5n},
      Core.core_cancel(Model.Rational{6n, 10n}, 2n))
    expect_maybe_rational("core checked common-factor cancellation",
      Model.Rational{3n, 5n},
      Core.core_cancel_checked(Model.Rational{6n, 10n}, 2n))
    expect_maybe_rational("core checked inverse roundtrip",
      Model.Rational{3n, 2n},
      Core.core_inverse_roundtrip_checked(Model.Rational{3n, 2n}, 2n, 5n))
    expect_none("core checked cancellation rejects zero factor",
      Core.core_cancel_checked(Model.Rational{3n, 2n}, 0n))
    expect_rational("core multiply by one",
      Model.Rational{4n, 7n},
      Core.core_mul(Model.Rational{4n, 7n}, Model.Rational{1n, 1n}))
    expect_maybe_rational("implementation zero normalization",
      Model.Rational{0n, 1n}, Rational.make(0n, 7n))
    expect_maybe_rational("implementation integer normalization",
      Model.Rational{11n, 1n}, Rational.make(11n, 1n))
    expect_maybe_rational("implementation equal-ratio normalization",
      Model.Rational{1n, 1n}, Rational.make(5n, 5n))
    expect_maybe_rational("implementation equal-ratio factor",
      Model.Rational{1n, 1n}, Rational.make_factor(5n, 5n))
    expect_none("implementation zero denominator rejected", Rational.make(3n, 0n))
    expect_none("implementation zero factor numerator rejected", Rational.make_factor(0n, 3n))
    expect_none("implementation zero factor denominator rejected", Rational.make_factor(3n, 0n))

#| PASS core inverse roundtrip 3/2 by 2/5
#| PASS core inverse roundtrip zero
#| PASS core exact common-factor cancellation
#| PASS core checked common-factor cancellation
#| PASS core checked inverse roundtrip
#| PASS core checked cancellation rejects zero factor
#| PASS core multiply by one
#| PASS implementation zero normalization
#| PASS implementation integer normalization
#| PASS implementation equal-ratio normalization
#| PASS implementation equal-ratio factor
#| PASS implementation zero denominator rejected
#| PASS implementation zero factor numerator rejected
#| PASS implementation zero factor denominator rejected
