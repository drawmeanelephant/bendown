import Base
import ./model.bend as Model
import ./rational.bend as Rational
import ./scale.bend as Scale

# Exact-rational scaling laws.
#
# The core operations below are deliberately explicit about their scope: they
# are the ideal arithmetic kernel of scaling, not the implementation's public
# rational multiplier.  In particular, they have no immediate-Nat overflow
# gates and they do not try to rediscover a greatest common divisor.  The
# cancellation operation instead receives the positive common factor it is
# asked to remove.  The inverse round-trip law is therefore a theorem about
# exact multiplication followed by exact cancellation of the inverse factor's
# known common factor.  Nothing in this file silently weakens those scopes into a
# claim about Rational.mul, its overflow gates, or canonical normalization by
# the implementation's fuelled gcd.

def core_mul(+a: Model.Rational, +b: Model.Rational) -> Model.Rational:
  match a b:
    case Model.Rational{+n1, +d1} Model.Rational{+n2, +d2}:
      Model.Rational{Nat.mul(n1, n2), Nat.mul(d1, d2)}

def core_cancel(+value: Model.Rational, +factor: Nat) -> Model.Rational:
  match value:
    case Model.Rational{+num, +den}:
      Model.Rational{Nat.div(num, factor), Nat.div(den, factor)}

def core_inverse_roundtrip(+value: Model.Rational, +num: Nat, +den: Nat) -> Model.Rational:
  core_cancel(
    core_mul(core_mul(value, Model.Rational{num, den}), Model.Rational{den, num}),
    Nat.mul(num, den))

# A checked variant of exact cancellation.  Unlike core_cancel, it returns
# None unless the factor is nonzero and both components are observably
# divisible by it.  It still
# does not discover a gcd; the caller supplies the candidate common factor.
def core_cancel_gate(+num: Nat, +den: Nat, +factor: Nat, divisible: Bool) -> Maybe<&2, Model.Rational>:
  match divisible:
    case False{}:
      None{}
    case True{}:
      Some{Model.Rational{Nat.div(num, factor), Nat.div(den, factor)}}

def core_cancel_checked(+value: Model.Rational, +factor: Nat) -> Maybe<&2, Model.Rational>:
  match value:
    case Model.Rational{+num, +den}:
      core_cancel_gate(num, den, factor,
        Bool.and(Nat.is_ne(factor, 0n), Bool.and(Nat.is_eq(Nat.mod(num, factor), 0n), Nat.is_eq(Nat.mod(den, factor), 0n))))

def core_inverse_roundtrip_checked(+value: Model.Rational, +num: Nat, +den: Nat) -> Maybe<&2, Model.Rational>:
  core_cancel_checked(
    core_mul(core_mul(value, Model.Rational{num, den}), Model.Rational{den, num}),
    Nat.mul(num, den))

# The exact inverse-scaling invariant of the ideal arithmetic kernel.  The
# successor patterns make the rational denominator and both factor components
# nonzero structurally rather than through boolean side conditions.
law core_inverse_scaling_exact:
  for +num: Nat
  for +den_pred: Nat
  for +factor_num_pred: Nat
  for +factor_den_pred: Nat
  {core_inverse_roundtrip(Model.Rational{num, 1n+den_pred}, 1n+factor_num_pred, 1n+factor_den_pred) == Model.Rational{num, 1n+den_pred} : Model.Rational}

# The same inverse invariant through checked cancellation: divisibility of
# both inverse-product components is verified, and the successful result is
# exactly the input rational.
law core_inverse_scaling_exact_checked:
  for +num: Nat
  for +den_pred: Nat
  for +factor_num_pred: Nat
  for +factor_den_pred: Nat
  {core_inverse_roundtrip_checked(Model.Rational{num, 1n+den_pred}, 1n+factor_num_pred, 1n+factor_den_pred) == Some{Model.Rational{num, 1n+den_pred}} : Maybe<&2, Model.Rational>}

law core_mul_one_right:
  for +num: Nat
  for +den: Nat
  {core_mul(Model.Rational{num, den}, Model.Rational{1n, 1n}) == Model.Rational{num, den} : Model.Rational}

law core_mul_one_left:
  for +num: Nat
  for +den: Nat
  {core_mul(Model.Rational{1n, 1n}, Model.Rational{num, den}) == Model.Rational{num, den} : Model.Rational}

law core_cancel_one:
  for +num: Nat
  for +den: Nat
  {core_cancel(Model.Rational{num, den}, 1n) == Model.Rational{num, den} : Model.Rational}

# Cross-multiplication equivalence of the raw (uncancelled) inverse scaling
# product.  This is the semantic rational equality underlying the exact
# cancellation theorem; it does not by itself claim componentwise canonical
# normalization.
law core_raw_inverse_scaling_equivalent:
  for +num: Nat
  for +den: Nat
  for +factor_num: Nat
  for +factor_den: Nat
  {Nat.mul(Nat.mul(Nat.mul(num, factor_num), factor_den), den) == Nat.mul(num, Nat.mul(Nat.mul(den, factor_den), factor_num)) : Nat}

# Exact cancellation of an explicitly represented common positive factor.
# This is the small normalization step proved for the ideal core: it is not a
# claim that the implementation's gcd rediscovers that factor.
law core_cancel_exact_common_factor:
  for +num: Nat
  for +den: Nat
  for +factor_pred: Nat
  {core_cancel(Model.Rational{Nat.mul(num, 1n+factor_pred), Nat.mul(den, 1n+factor_pred)}, 1n+factor_pred) == Model.Rational{num, den} : Model.Rational}

# The checked cancellation operation succeeds on an explicitly represented
# common positive factor and returns the quotients exactly.
law core_cancel_checked_exact_common_factor:
  for +num: Nat
  for +den: Nat
  for +factor_pred: Nat
  {core_cancel_checked(Model.Rational{Nat.mul(num, 1n+factor_pred), Nat.mul(den, 1n+factor_pred)}, 1n+factor_pred) == Some{Model.Rational{num, den}} : Maybe<&2, Model.Rational>}

# Checked cancellation rejects a zero factor before attempting division.
law core_cancel_checked_zero_factor_rejects:
  for +num: Nat
  for +den: Nat
  {core_cancel_checked(Model.Rational{num, den}, 0n) == None{} : Maybe<&2, Model.Rational>}

# Implementation-facing normalization facts.  These are intentionally narrower
# than full normalization idempotence: they are the zero and zero-denominator
# cases provable without a correctness proof of the implementation's
# fuelled Euclidean gcd.
law rational_zero_denominator_rejects:
  for +num: Nat
  {Rational.make(num, 0n) == None{} : Maybe<&2, Model.Rational>}

law rational_zero_normalizes:
  for +den_pred: Nat
  {Rational.make(0n, 1n+den_pred) == Some{Model.Rational{0n, 1n}} : Maybe<&2, Model.Rational>}

law rational_normalize_zero:
  for +den_pred: Nat
  {Rational.normalize(Model.Rational{0n, 1n+den_pred}) == Some{Model.Rational{0n, 1n}} : Maybe<&2, Model.Rational>}

# A positive ratio with equal numerator and denominator normalizes to one.
# This is the implementation-facing numerator=denominator special case; the
# general coprimality/normalization-idempotence theorem remains out of scope.
law rational_equal_ratio_normalizes_one:
  for +pred: Nat
  {Rational.make(1n+pred, 1n+pred) == Some{Model.Rational{1n, 1n}} : Maybe<&2, Model.Rational>}

# The scaling-factor constructor also canonicalizes a positive numerator=
# denominator factor to one.  This is as close as the present development gets
# to implementation inverse scaling in that restricted case: the subsequent
# multiplication remains behind the overflow-gate wall documented below.
law rational_factor_equal_ratio_is_one:
  for +pred: Nat
  {Rational.make_factor(1n+pred, 1n+pred) == Some{Model.Rational{1n, 1n}} : Maybe<&2, Model.Rational>}

# Denominator-one values are already canonical.  This is a general
# implementation-facing normalization theorem, but still much narrower than
# idempotence for arbitrary coprime numerator/denominator pairs.
law rational_integer_normalizes:
  for +num: Nat
  {Rational.make(num, 1n) == Some{Model.Rational{num, 1n}} : Maybe<&2, Model.Rational>}

law rational_normalize_integer:
  for +num: Nat
  {Rational.normalize(Model.Rational{num, 1n}) == Some{Model.Rational{num, 1n}} : Maybe<&2, Model.Rational>}

# The implementation factor constructor rejects zero components before any
# arithmetic is attempted.
law rational_factor_zero_numerator_rejects:
  for +den: Nat
  {Rational.make_factor(0n, den) == None{} : Maybe<&2, Model.Rational>}

law rational_factor_zero_denominator_rejects:
  for +num_pred: Nat
  {Rational.make_factor(1n+num_pred, 0n) == None{} : Maybe<&2, Model.Rational>}

# No implementation-level multiplication round-trip is stated here.  Such a
# theorem currently hits two independent proof-engineering walls: Rational.mul's
# overflow gate mentions the 2^48-1 immediate-Nat bound (whose unary expansion
# overflows the checker's proof normalization), and canonical normalization of
# arbitrary ratios requires a general Euclidean-gcd/coprime-cancellation
# development.  The implementation-facing laws below are therefore deliberately
# limited to the gate and normalization cases in this file that avoid both walls.
#
# The public recipe scaler rejects degenerate factors.  These are control-flow
# laws only; they do not depend on the arithmetic normalization proof.
law scale_factor_zero_numerator_rejects:
  for +recipe: Model.Recipe
  for +den: Nat
  {Scale.scale_recipe_factor(recipe, 0n, den) == None{} : Maybe<&2, Model.Recipe>}

law scale_factor_zero_denominator_rejects:
  for +recipe: Model.Recipe
  for +num_pred: Nat
  {Scale.scale_recipe_factor(recipe, 1n+num_pred, 0n) == None{} : Maybe<&2, Model.Recipe>}
