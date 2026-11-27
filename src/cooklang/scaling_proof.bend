import Base
import ./model.bend as Model
import ./rational.bend as Rational
import ./scaling_laws.bend as ScalingLaws

# ---------------------------------------------------------------------------
# Nat semiring lemmas over Base's structural Nat.add and Nat.mul
# ---------------------------------------------------------------------------

def nat_add_zero(a: Nat) -> {a == Nat.add(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_add_zero(p) : {1n+p == 1n+_ : Nat}
      {==}

def nat_add_succ(a: Nat, -b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_add_succ(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def nat_add_comm(a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      %nat_add_zero(b) : {b == _ : Nat}
      {==}
    case 1n+p:
      %nat_add_succ(b, p) : {1n+Nat.add(p, b) == _ : Nat}
      %nat_add_comm(p, b) : {1n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def nat_add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

def nat_add_swap(x: Nat, +y: Nat, +z: Nat) -> {Nat.add(x, Nat.add(y, z)) == Nat.add(y, Nat.add(x, z)) : Nat}:
  match x:
    case 0n:
      {==}
    case 1n+q:
      %nat_add_succ(y, Nat.add(q, z)) : {1n+Nat.add(q, Nat.add(y, z)) == _ : Nat}
      %nat_add_swap(q, y, z) : {1n+Nat.add(q, Nat.add(y, z)) == 1n+_ : Nat}
      {==}

def nat_mul_zero(a: Nat) -> {Nat.mul(a, 0n) == 0n : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      nat_mul_zero(p)

def nat_mul_succ(+a: Nat, +b: Nat) -> {Nat.add(a, Nat.mul(a, b)) == Nat.mul(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n++p:
      %nat_mul_succ(p, b) : {1n+Nat.add(p, Nat.add(b, Nat.mul(p, b))) == 1n+Nat.add(b, _) : Nat}
      %nat_add_swap(p, b, Nat.mul(p, b)) : {1n+Nat.add(p, Nat.add(b, Nat.mul(p, b))) == 1n+_ : Nat}
      {==}

def nat_mul_comm(+a: Nat, +b: Nat) -> {Nat.mul(a, b) == Nat.mul(b, a) : Nat}:
  match a:
    case 0n:
      %nat_mul_zero(b) : {_ == Nat.mul(b, 0n) : Nat}
      {==}
    case 1n++p:
      %nat_mul_succ(b, p) : {Nat.add(b, Nat.mul(p, b)) == _ : Nat}
      %nat_mul_comm(p, b) : {Nat.add(b, Nat.mul(p, b)) == Nat.add(b, _) : Nat}
      {==}

def nat_mul_dist(a: Nat, -b: Nat, +c: Nat) -> {Nat.add(Nat.mul(a, c), Nat.mul(b, c)) == Nat.mul(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_mul_dist(p, b, c) : {Nat.add(Nat.add(c, Nat.mul(p, c)), Nat.mul(b, c)) == Nat.add(c, _) : Nat}
      %nat_add_assoc(c, Nat.mul(p, c), Nat.mul(b, c)) : {_ == Nat.add(c, Nat.add(Nat.mul(p, c), Nat.mul(b, c))) : Nat}
      {==}

def nat_mul_one(a: Nat) -> {Nat.mul(a, 1n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_mul_one(p) : {1n+Nat.mul(p, 1n) == 1n+_ : Nat}
      {==}

def nat_mul_one_left(a: Nat) -> {Nat.mul(1n, a) == a : Nat}:
  %nat_add_zero(a) : {_ == a : Nat}
  {==}

# ---------------------------------------------------------------------------
# Core operation identities
# ---------------------------------------------------------------------------

def ScalingLaws.core_mul_one_right(num, den):
  %nat_mul_one(num) : {Model.Rational{Nat.mul(num, 1n), Nat.mul(den, 1n)} == Model.Rational{_, den} : Model.Rational}
  %nat_mul_one(den) : {Model.Rational{Nat.mul(num, 1n), Nat.mul(den, 1n)} == Model.Rational{Nat.mul(num, 1n), _} : Model.Rational}
  {==}

def ScalingLaws.core_mul_one_left(num, den):
  %nat_mul_one_left(num) : {Model.Rational{Nat.add(num, 0n), Nat.add(den, 0n)} == Model.Rational{_, den} : Model.Rational}
  %nat_mul_one_left(den) : {Model.Rational{Nat.add(num, 0n), Nat.add(den, 0n)} == Model.Rational{Nat.add(num, 0n), _} : Model.Rational}
  {==}

def ScalingLaws.rational_zero_denominator_rejects(num):
  {==}

# ---------------------------------------------------------------------------
# Exact division by a positive factor in Base's iterated divmod
# ---------------------------------------------------------------------------

def nat_add_zero_right(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  Equal.sym(Nat, a, Nat.add(a, 0n), nat_add_zero(a))

# Finish one divisor-length cycle of Nat.divmod.go.  At entry the remainder
# countdown is m and the remainder is r, so the divisor's predecessor is
# r + m.  After 1+m input steps the quotient has advanced by one and the
# remainder is zero again.
def divmod_cycle_finish(
  m: Nat, +rest: Nat, +q: Nat, +r: Nat
) -> {Nat.divmod.go(Nat.add(1n+m, rest), m, q, r) == Nat.divmod.go(rest, Nat.add(r, m), 1n+q, 0n) : Nat & Nat}:
  match m:
    case 0n:
      %nat_add_zero(r) : {Nat.divmod.go(rest, r, 1n+q, 0n) == Nat.divmod.go(rest, _, 1n+q, 0n) : Nat & Nat}
      {==}
    case 1n+mp:
      %nat_add_succ(r, mp) : {Nat.divmod.go(Nat.add(2n+mp, rest), 1n+mp, q, r) == Nat.divmod.go(rest, _, 1n+q, 0n) : Nat & Nat}
      divmod_cycle_finish(mp, rest, q, 1n+r)

def divmod_front_cycle(
  +bp: Nat, +rest: Nat, +q: Nat
) -> {Nat.divmod.go(Nat.add(1n+bp, rest), bp, q, 0n) == Nat.divmod.go(rest, bp, 1n+q, 0n) : Nat & Nat}:
  divmod_cycle_finish(bp, rest, q, 0n)

def nat_add_succ_right(a: Nat, -b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  Equal.sym(Nat, 1n+Nat.add(a, b), Nat.add(a, 1n+b), nat_add_succ(a, b))

# Running the division loop over x copies of the positive divisor 1+bp,
# starting from quotient q and remainder zero, adds exactly x to the quotient
# and leaves remainder zero.  This is the structural heart of exact division:
# no Euclidean gcd or quotient-uniqueness argument is needed.
def divmod_mul_go(
  x: Nat, +bp: Nat, +q: Nat
) -> {Nat.divmod.go(Nat.mul(x, 1n+bp), bp, q, 0n) == (Nat.add(x, q), 0n) : Nat & Nat}:
  match x:
    case 0n:
      {==}
    case 1n++p:
      step1 = divmod_front_cycle(bp, Nat.mul(p, 1n+bp), q)
      step2 = divmod_mul_go(p, bp, 1n+q)
      joined = Equal.trans(Nat & Nat,
        Nat.divmod.go(Nat.add(1n+bp, Nat.mul(p, 1n+bp)), bp, q, 0n),
        Nat.divmod.go(Nat.mul(p, 1n+bp), bp, 1n+q, 0n),
        (Nat.add(p, 1n+q), 0n),
        step1, step2)
      %nat_add_succ_right(p, q) : {Nat.divmod.go(Nat.add(1n+bp, Nat.mul(p, 1n+bp)), bp, q, 0n) == (_, 0n) : Nat & Nat}
      joined

# Exact division: multiplying first and then dividing by the same positive
# factor returns the multiplicand.  This is proved for Base's actual Nat.div,
# not for a shadow division operation.
def nat_div_mul(+x: Nat, +bp: Nat) -> {Nat.div(Nat.mul(x, 1n+bp), 1n+bp) == x : Nat}:
  projected = Equal.cong(Nat & Nat, Nat, p => Pair.fst(Nat, Nat, p),
    Nat.divmod.go(Nat.mul(x, 1n+bp), bp, 0n, 0n),
    (Nat.add(x, 0n), 0n),
    divmod_mul_go(x, bp, 0n))
  %nat_add_zero_right(x) : {Nat.div(Nat.mul(x, 1n+bp), 1n+bp) == _ : Nat}
  projected

def nat_div_one(+x: Nat) -> {Nat.div(x, 1n) == x : Nat}:
  %nat_mul_one(x) : {Nat.div(_, 1n) == x : Nat}
  nat_div_mul(x, 0n)

def ScalingLaws.core_cancel_one(num, den):
  %nat_div_one(num) : {Model.Rational{Nat.div(num, 1n), Nat.div(den, 1n)} == Model.Rational{_, den} : Model.Rational}
  %nat_div_one(den) : {Model.Rational{Nat.div(num, 1n), Nat.div(den, 1n)} == Model.Rational{Nat.div(num, 1n), _} : Model.Rational}
  {==}

def nat_mul_assoc(a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(Nat.mul(a, b), c) == Nat.mul(a, Nat.mul(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n++p:
      %nat_mul_dist(b, Nat.mul(p, b), c) : {_ == Nat.add(Nat.mul(b, c), Nat.mul(p, Nat.mul(b, c))) : Nat}
      %nat_mul_assoc(p, b, c) : {Nat.add(Nat.mul(b, c), Nat.mul(Nat.mul(p, b), c)) == Nat.add(Nat.mul(b, c), _) : Nat}
      {==}

def nat_mul_assoc_right(+a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(a, Nat.mul(b, c)) == Nat.mul(Nat.mul(a, b), c) : Nat}:
  Equal.sym(Nat, Nat.mul(Nat.mul(a, b), c), Nat.mul(a, Nat.mul(b, c)), nat_mul_assoc(a, b, c))

# Reorder the denominator product of the inverse round-trip into one explicit
# multiplication by the known common factor n*d.  The equation is oriented as
# target == implementation-order product, which is the direction rewriting uses.
def inverse_den_rearrange(+y: Nat, +n: Nat, +d: Nat)
  -> {Nat.mul(y, Nat.mul(n, d)) == Nat.mul(Nat.mul(y, d), n) : Nat}:
  %nat_mul_assoc_right(y, d, n) : {Nat.mul(y, Nat.mul(n, d)) == _ : Nat}
  %nat_mul_comm(n, d) : {Nat.mul(y, Nat.mul(n, d)) == Nat.mul(y, _) : Nat}
  {==}

# The inverse round-trip proof.  It first exposes the inverse factor's product
# as the same common factor in numerator and denominator, then applies exact
# division by that positive factor.  No gcd discovery is claimed here.
def ScalingLaws.core_inverse_scaling_exact(num, den_pred, factor_num_pred, factor_den_pred):
  %nat_mul_assoc_right(num, 1n+factor_num_pred, 1n+factor_den_pred) : {Model.Rational{Nat.div(_, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.div(Nat.mul(Nat.mul(1n+den_pred, 1n+factor_den_pred), 1n+factor_num_pred), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred))} == Model.Rational{num, 1n+den_pred} : Model.Rational}
  %inverse_den_rearrange(1n+den_pred, 1n+factor_num_pred, 1n+factor_den_pred) : {Model.Rational{Nat.div(Nat.mul(num, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.div(_, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred))} == Model.Rational{num, 1n+den_pred} : Model.Rational}
  %nat_div_mul(num, Nat.add(factor_den_pred, Nat.mul(factor_num_pred, 1n+factor_den_pred))) : {Model.Rational{Nat.div(Nat.mul(num, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.div(Nat.mul(1n+den_pred, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred))} == Model.Rational{_, 1n+den_pred} : Model.Rational}
  %nat_div_mul(1n+den_pred, Nat.add(factor_den_pred, Nat.mul(factor_num_pred, 1n+factor_den_pred))) : {Model.Rational{Nat.div(Nat.mul(num, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.div(Nat.mul(1n+den_pred, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred))} == Model.Rational{Nat.div(Nat.mul(num, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), _} : Model.Rational}
  {==}

# ---------------------------------------------------------------------------
# Special cases of the implementation's rational normalization
# ---------------------------------------------------------------------------

def nat_div_self(+bp: Nat) -> {Nat.div(1n+bp, 1n+bp) == 1n : Nat}:
  %nat_mul_one_left(1n+bp) : {Nat.div(_, 1n+bp) == 1n : Nat}
  nat_div_mul(1n, bp)

# For a positive denominator, the implementation's fuelled Euclidean loop
# computes gcd(0, 1+p) = 1+p.  No general gcd correctness theorem is needed:
# the first modulo of zero is zero, and the next iteration returns the
# accumulated divisor.
def gcd_zero_positive(p: Nat) -> {Rational.gcd(0n, 1n+p) == 1n+p : Nat}:
  match p:
    case 0n:
      {==}
    case 1n+pp:
      {==}

def gcd_zero_positive_right(p: Nat) -> {1n+p == Rational.gcd(0n, 1n+p) : Nat}:
  Equal.sym(Nat, Rational.gcd(0n, 1n+p), 1n+p, gcd_zero_positive(p))

def ScalingLaws.rational_zero_normalizes(den_pred):
  %gcd_zero_positive_right(den_pred) : {Some{Model.Rational{Nat.div(0n, _), Nat.div(1n+den_pred, _)}} == Some{Model.Rational{0n, 1n}} : Maybe<&2, Model.Rational>}
  %nat_div_self(den_pred) : {Some{Model.Rational{0n, Nat.div(1n+den_pred, 1n+den_pred)}} == Some{Model.Rational{0n, _}} : Maybe<&2, Model.Rational>}
  {==}

def ScalingLaws.rational_normalize_zero(den_pred):
  ScalingLaws.rational_zero_normalizes(den_pred)

def ScalingLaws.core_cancel_exact_common_factor(num, den, factor_pred):
  %nat_div_mul(num, factor_pred) : {Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), Nat.div(Nat.mul(den, 1n+factor_pred), 1n+factor_pred)} == Model.Rational{_, den} : Model.Rational}
  %nat_div_mul(den, factor_pred) : {Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), Nat.div(Nat.mul(den, 1n+factor_pred), 1n+factor_pred)} == Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), _} : Model.Rational}
  {==}

# A three-factor rotation, oriented target == implementation-order product for
# use as a rewrite toward the canonical inverse-scaling product.
def nat_mul_rotate3(+y: Nat, +n: Nat, +d: Nat)
  -> {Nat.mul(y, Nat.mul(n, d)) == Nat.mul(n, Nat.mul(d, y)) : Nat}:
  %nat_mul_assoc(n, d, y) : {Nat.mul(y, Nat.mul(n, d)) == _ : Nat}
  %nat_mul_comm(y, Nat.mul(n, d)) : {Nat.mul(y, Nat.mul(n, d)) == _ : Nat}
  {==}

def ScalingLaws.core_raw_inverse_scaling_equivalent(num, den, factor_num, factor_den):
  %inverse_den_rearrange(den, factor_num, factor_den) : {Nat.mul(Nat.mul(Nat.mul(num, factor_num), factor_den), den) == Nat.mul(num, _) : Nat}
  %nat_mul_assoc_right(Nat.mul(num, factor_num), factor_den, den) : {_ == Nat.mul(num, Nat.mul(den, Nat.mul(factor_num, factor_den))) : Nat}
  %nat_mul_assoc_right(num, factor_num, Nat.mul(factor_den, den)) : {_ == Nat.mul(num, Nat.mul(den, Nat.mul(factor_num, factor_den))) : Nat}
  %nat_mul_rotate3(den, factor_num, factor_den) : {Nat.mul(num, _) == Nat.mul(num, Nat.mul(den, Nat.mul(factor_num, factor_den))) : Nat}
  {==}

def ScalingLaws.scale_factor_zero_numerator_rejects(recipe, den):
  {==}

def ScalingLaws.scale_factor_zero_denominator_rejects(recipe, num_pred):
  {==}

# gcd(x, 1) = 1 for the implementation's fuelled Euclidean loop.  The proof
# uses the exact-division development above only for the mod-by-one fact; it
# does not require a general Euclidean-algorithm correctness proof.
def nat_mod_one(+x: Nat) -> {Nat.mod(x, 1n) == 0n : Nat}:
  %nat_mul_one(x) : {Nat.mod(_, 1n) == 0n : Nat}
  Equal.cong(Nat & Nat, Nat, p => Pair.snd(Nat, Nat, p),
    Nat.divmod.go(Nat.mul(x, 1n), 0n, 0n, 0n),
    (Nat.add(x, 0n), 0n),
    divmod_mul_go(x, 0n, 0n))

def nat_max_zero(a: Nat) -> {Nat.max(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

def nat_max_zero_right(a: Nat) -> {a == Nat.max(a, 0n) : Nat}:
  Equal.sym(Nat, Nat.max(a, 0n), a, nat_max_zero(a))

def nat_mod_one_right(+x: Nat) -> {0n == Nat.mod(x, 1n) : Nat}:
  Equal.sym(Nat, Nat.mod(x, 1n), 0n, nat_mod_one(x))

def gcd_loop_zero_right(fuel: Nat, +a: Nat) -> {Rational.gcd_loop(fuel, a, 0n) == a : Nat}:
  match fuel:
    case 0n:
      {==}
    case 1n+p:
      {==}

def gcd_one_right(x: Nat) -> {Rational.gcd(x, 1n) == 1n : Nat}:
  match x:
    case 0n:
      {==}
    case 1n++p:
      %nat_max_zero_right(p) : {Rational.gcd_loop(_, 1n, Nat.mod(1n+p, 1n)) == 1n : Nat}
      %nat_mod_one_right(1n+p) : {Rational.gcd_loop(p, 1n, _) == 1n : Nat}
      gcd_loop_zero_right(p, 1n)

def gcd_one_right_flip(x: Nat) -> {1n == Rational.gcd(x, 1n) : Nat}:
  Equal.sym(Nat, Rational.gcd(x, 1n), 1n, gcd_one_right(x))

def ScalingLaws.rational_integer_normalizes(num):
  %gcd_one_right_flip(num) : {Some{Model.Rational{Nat.div(num, _), Nat.div(1n, Rational.gcd(num, 1n))}} == Some{Model.Rational{num, 1n}} : Maybe<&2, Model.Rational>}
  %gcd_one_right_flip(num) : {Some{Model.Rational{Nat.div(num, 1n), Nat.div(1n, _)}} == Some{Model.Rational{num, 1n}} : Maybe<&2, Model.Rational>}
  %nat_div_one(num) : {Some{Model.Rational{Nat.div(num, 1n), Nat.div(1n, 1n)}} == Some{Model.Rational{_, 1n}} : Maybe<&2, Model.Rational>}
  %nat_div_one(1n) : {Some{Model.Rational{Nat.div(num, 1n), Nat.div(1n, 1n)}} == Some{Model.Rational{Nat.div(num, 1n), _}} : Maybe<&2, Model.Rational>}
  {==}

def ScalingLaws.rational_normalize_integer(num):
  ScalingLaws.rational_integer_normalizes(num)

# gcd(x, x) = x for positive x in the implementation's fuelled Euclidean loop.
# This is the second special-case gcd fact used by the normalization laws.
def nat_max_refl(a: Nat) -> {Nat.max(a, a) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %nat_max_refl(p) : {1n+Nat.max(p, p) == 1n+_ : Nat}
      {==}

def nat_max_refl_right(a: Nat) -> {a == Nat.max(a, a) : Nat}:
  Equal.sym(Nat, Nat.max(a, a), a, nat_max_refl(a))

def nat_mod_self_positive(+bp: Nat) -> {Nat.mod(1n+bp, 1n+bp) == 0n : Nat}:
  %nat_mul_one_left(1n+bp) : {Nat.mod(_, 1n+bp) == 0n : Nat}
  Equal.cong(Nat & Nat, Nat, p => Pair.snd(Nat, Nat, p),
    Nat.divmod.go(Nat.mul(1n, 1n+bp), bp, 0n, 0n),
    (Nat.add(1n, 0n), 0n),
    divmod_mul_go(1n, bp, 0n))

def nat_mod_self_positive_right(+bp: Nat) -> {0n == Nat.mod(1n+bp, 1n+bp) : Nat}:
  Equal.sym(Nat, Nat.mod(1n+bp, 1n+bp), 0n, nat_mod_self_positive(bp))

def gcd_same_positive(+bp: Nat) -> {Rational.gcd(1n+bp, 1n+bp) == 1n+bp : Nat}:
  %nat_max_refl_right(1n+bp) : {Rational.gcd_loop(_, 1n+bp, 1n+bp) == 1n+bp : Nat}
  %nat_mod_self_positive_right(bp) : {Rational.gcd_loop(bp, 1n+bp, _) == 1n+bp : Nat}
  gcd_loop_zero_right(bp, 1n+bp)

def gcd_same_positive_flip(+bp: Nat) -> {1n+bp == Rational.gcd(1n+bp, 1n+bp) : Nat}:
  Equal.sym(Nat, Rational.gcd(1n+bp, 1n+bp), 1n+bp, gcd_same_positive(bp))

def ScalingLaws.rational_equal_ratio_normalizes_one(pred):
  %gcd_same_positive_flip(pred) : {Some{Model.Rational{Nat.div(1n+pred, _), Nat.div(1n+pred, Rational.gcd(1n+pred, 1n+pred))}} == Some{Model.Rational{1n, 1n}} : Maybe<&2, Model.Rational>}
  %gcd_same_positive_flip(pred) : {Some{Model.Rational{Nat.div(1n+pred, 1n+pred), Nat.div(1n+pred, _)}} == Some{Model.Rational{1n, 1n}} : Maybe<&2, Model.Rational>}
  %nat_div_self(pred) : {Some{Model.Rational{Nat.div(1n+pred, 1n+pred), Nat.div(1n+pred, 1n+pred)}} == Some{Model.Rational{_, 1n}} : Maybe<&2, Model.Rational>}
  %nat_div_self(pred) : {Some{Model.Rational{Nat.div(1n+pred, 1n+pred), Nat.div(1n+pred, 1n+pred)}} == Some{Model.Rational{Nat.div(1n+pred, 1n+pred), _}} : Maybe<&2, Model.Rational>}
  {==}

def nat_mod_mul(+x: Nat, +bp: Nat) -> {Nat.mod(Nat.mul(x, 1n+bp), 1n+bp) == 0n : Nat}:
  Equal.cong(Nat & Nat, Nat, p => Pair.snd(Nat, Nat, p),
    Nat.divmod.go(Nat.mul(x, 1n+bp), bp, 0n, 0n),
    (Nat.add(x, 0n), 0n),
    divmod_mul_go(x, bp, 0n))

def nat_mod_mul_right(+x: Nat, +bp: Nat) -> {0n == Nat.mod(Nat.mul(x, 1n+bp), 1n+bp) : Nat}:
  Equal.sym(Nat, Nat.mod(Nat.mul(x, 1n+bp), 1n+bp), 0n, nat_mod_mul(x, bp))

def ScalingLaws.core_cancel_checked_exact_common_factor(num, den, factor_pred):
  %nat_mod_mul_right(num, factor_pred) : {ScalingLaws.core_cancel_gate(Nat.mul(num, 1n+factor_pred), Nat.mul(den, 1n+factor_pred), 1n+factor_pred, Bool.and(Nat.is_eq(_, 0n), Nat.is_eq(Nat.mod(Nat.mul(den, 1n+factor_pred), 1n+factor_pred), 0n))) == Some{Model.Rational{num, den}} : Maybe<&2, Model.Rational>}
  %nat_mod_mul_right(den, factor_pred) : {ScalingLaws.core_cancel_gate(Nat.mul(num, 1n+factor_pred), Nat.mul(den, 1n+factor_pred), 1n+factor_pred, Nat.is_eq(_, 0n)) == Some{Model.Rational{num, den}} : Maybe<&2, Model.Rational>}
  %nat_div_mul(num, factor_pred) : {Some{Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), Nat.div(Nat.mul(den, 1n+factor_pred), 1n+factor_pred)}} == Some{Model.Rational{_, den}} : Maybe<&2, Model.Rational>}
  %nat_div_mul(den, factor_pred) : {Some{Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), Nat.div(Nat.mul(den, 1n+factor_pred), 1n+factor_pred)}} == Some{Model.Rational{Nat.div(Nat.mul(num, 1n+factor_pred), 1n+factor_pred), _}} : Maybe<&2, Model.Rational>}
  {==}

def ScalingLaws.core_inverse_scaling_exact_checked(num, den_pred, factor_num_pred, factor_den_pred):
  %nat_mul_assoc_right(num, 1n+factor_num_pred, 1n+factor_den_pred) : {ScalingLaws.core_cancel_checked(Model.Rational{_, Nat.mul(Nat.mul(1n+den_pred, 1n+factor_den_pred), 1n+factor_num_pred)}, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)) == Some{Model.Rational{num, 1n+den_pred}} : Maybe<&2, Model.Rational>}
  %inverse_den_rearrange(1n+den_pred, 1n+factor_num_pred, 1n+factor_den_pred) : {ScalingLaws.core_cancel_checked(Model.Rational{Nat.mul(num, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)), _}, Nat.mul(1n+factor_num_pred, 1n+factor_den_pred)) == Some{Model.Rational{num, 1n+den_pred}} : Maybe<&2, Model.Rational>}
  ScalingLaws.core_cancel_checked_exact_common_factor(num, 1n+den_pred, Nat.add(factor_den_pred, Nat.mul(factor_num_pred, 1n+factor_den_pred)))

def ScalingLaws.rational_factor_equal_ratio_is_one(pred):
  ScalingLaws.rational_equal_ratio_normalizes_one(pred)

def ScalingLaws.rational_factor_zero_numerator_rejects(den):
  {==}

def ScalingLaws.rational_factor_zero_denominator_rejects(num_pred):
  {==}

def ScalingLaws.core_cancel_checked_zero_factor_rejects(num, den):
  {==}
