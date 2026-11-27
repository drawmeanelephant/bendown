import Base
import ./model.bend as Model

# Exact rational arithmetic over Bend's immediate Nat range.  Rational values
# produced here are normalized: the denominator is non-zero, zero is 0/1, and
# numerator and denominator are coprime.

type QuantityClass is Data:
  QuantityEmpty{}
  QuantityScalable{}
  QuantityFixed{}

type ParsedQuantity is Data:
  ParsedQuantity{value: Model.Rational, decimal_family: Bool}

type ScaledQuantity is Data:
  ScaledQuantity{klass: QuantityClass, original: String, scaled: String, changed: Bool}

type DigitScan is Data:
  DigitScan{digits: String, rest: String}

type AddMod is Data:
  AddMod{value: Nat, wrapped: Bool}

type Mul10State is Data:
  Mul10State{acc: Nat, wraps: Nat}

type DecimalState is Data:
  DecimalState{rem: Nat, digits_rev: String}

type DecimalExpansion is Data:
  DecimalExpansion{digits: String, remainder: Nat, complete: Bool}

# The runtime's largest immediate Nat, 2^48 - 1.  Arithmetic that would pass
# this bound is rejected before evaluating the overflowing operation.
def nat_max() -> Nat:
  Nat.add(Nat.mul(281474n, 1000000000n), 976710655n)

# ---------------------------------------------------------------------------
# Checked Nat arithmetic and normalization
# ---------------------------------------------------------------------------

def nat_add_gate(a: Nat, b: Nat, fits: Bool) -> Maybe<&2, Nat>:
  match fits:
    case False{}:
      None{}
    case True{}:
      Some{Nat.add(a, b)}

def nat_add_maybe(+a: Nat, +b: Nat) -> Maybe<&2, Nat>:
  nat_add_gate(a, b, Nat.is_le(a, Nat.sub(nat_max(), b)))

def nat_mul_fits(+a: Nat, +b: Nat) -> Bool:
  match b:
    case 0n:
      True{}
    case 1n+bp:
      Nat.is_le(a, Nat.div(nat_max(), b))

def nat_mul_gate(a: Nat, b: Nat, fits: Bool) -> Maybe<&2, Nat>:
  match fits:
    case False{}:
      None{}
    case True{}:
      Some{Nat.mul(a, b)}

def nat_mul_maybe(+a: Nat, +b: Nat) -> Maybe<&2, Nat>:
  nat_mul_gate(a, b, nat_mul_fits(a, b))

def nonzero_gate(+n: Nat, zero: Bool) -> Maybe<&2, Nat>:
  match zero:
    case False{}:
      Some{n}
    case True{}:
      None{}

def nonzero_nat(+n: Nat) -> Maybe<&2, Nat>:
  nonzero_gate(n, Nat.is_eq(n, 0n))

# Euclid's algorithm, structurally recursive on fuel.  For positive inputs the
# modulo Euclidean algorithm never needs max(a,b) steps (the modulus strictly
# decreases), so max(a,b) is a safe structural bound; the zero-fuel case also
# gives the correct gcd(0,0) = 0 fallback and keeps the function total.
def gcd_loop(fuel: Nat, a: Nat, +b: Nat) -> Nat:
  match fuel:
    case 0n:
      a
    case 1n+p:
      match b:
        case 0n:
          a
        case 1n+bp:
          gcd_loop(p, b, Nat.mod(a, b))

def gcd(+a: Nat, +b: Nat) -> Nat:
  gcd_loop(Nat.max(a, b), a, b)

# Normalize num/den.  A zero denominator is rejected.  Because gcd(0,den) is
# den, a zero numerator canonically becomes 0/1.
def make_gate(+num: Nat, +den: Nat, zero_den: Bool) -> Maybe<&2, Model.Rational>:
  match zero_den:
    case False{}:
      +g = gcd(num, den)
      Some{Model.Rational{Nat.div(num, g), Nat.div(den, g)}}
    case True{}:
      None{}

def make(+num: Nat, +den: Nat) -> Maybe<&2, Model.Rational>:
  make_gate(num, den, Nat.is_eq(den, 0n))

def normalize(+value: Model.Rational) -> Maybe<&2, Model.Rational>:
  match value:
    case Model.Rational{+num, +den}:
      make(num, den)

# Exact multiplication with cross-cancellation before multiplication.  This
# keeps intermediate products as small as the reduced result and avoids
# spurious overflow in cases such as (a/b) * (b/c).
def mul_reduced(
  +n1: Nat, +d1: Nat, +n2: Nat, +d2: Nat
) -> Maybe<&2, Model.Rational>:
  do Maybe<&2, Model.Rational>:
    +g1 : Nat = gcd(n1, d2)
    +g2 : Nat = gcd(n2, d1)
    +a1 : Nat = Nat.div(n1, g1)
    +a2 : Nat = Nat.div(n2, g2)
    +b1 : Nat = Nat.div(d1, g2)
    +b2 : Nat = Nat.div(d2, g1)
    rn : Nat <- nat_mul_maybe(a1, a2)
    rd : Nat <- nat_mul_maybe(b1, b2)
    out : Model.Rational <- make(rn, rd)
    return out

def mul_valid(
  n1: Nat, d1: Nat, n2: Nat, d2: Nat, valid: Bool
) -> Maybe<&2, Model.Rational>:
  match valid:
    case False{}:
      None{}
    case True{}:
      mul_reduced(n1, d1, n2, d2)

def mul(+a: Model.Rational, +b: Model.Rational) -> Maybe<&2, Model.Rational>:
  match a b:
    case Model.Rational{+n1, +d1} Model.Rational{+n2, +d2}:
      mul_valid(n1, d1, n2, d2,
        Bool.and(Nat.is_ne(d1, 0n), Nat.is_ne(d2, 0n)))

def make_factor(+num: Nat, +den: Nat) -> Maybe<&2, Model.Rational>:
  do Maybe<&2, Model.Rational>:
    nz_num : Nat <- nonzero_nat(num)
    nz_den : Nat <- nonzero_nat(den)
    factor : Model.Rational <- make(nz_num, nz_den)
    return factor

def mul_factor(+q: Model.Rational, +num: Nat, +den: Nat) -> Maybe<&2, Model.Rational>:
  do Maybe<&2, Model.Rational>:
    factor : Model.Rational <- make_factor(num, den)
    out : Model.Rational <- mul(q, factor)
    return out

# ---------------------------------------------------------------------------
# Quantity-text scanning and parsing
# ---------------------------------------------------------------------------

# Cooklang's quantity classification trims only ASCII space and tab.
def drop_qty_spaces(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{' ', t}:
      drop_qty_spaces(t)
    case SCon{'\t', t}:
      drop_qty_spaces(t)
    case SCon{h, t}:
      SCon{h, t}

def trim_quantity(s: String) -> String:
  String.reverse(drop_qty_spaces(String.reverse(drop_qty_spaces(s))))

def scan_digits_finish(acc: String, rest: String) -> DigitScan:
  DigitScan{String.reverse(acc), rest}

def scan_digits_go(s: String, acc: String) -> DigitScan:
  match s:
    case SNil{}:
      scan_digits_finish(acc, SNil{})
    case SCon{'0', t}:
      scan_digits_go(t, SCon{'0', acc})
    case SCon{'1', t}:
      scan_digits_go(t, SCon{'1', acc})
    case SCon{'2', t}:
      scan_digits_go(t, SCon{'2', acc})
    case SCon{'3', t}:
      scan_digits_go(t, SCon{'3', acc})
    case SCon{'4', t}:
      scan_digits_go(t, SCon{'4', acc})
    case SCon{'5', t}:
      scan_digits_go(t, SCon{'5', acc})
    case SCon{'6', t}:
      scan_digits_go(t, SCon{'6', acc})
    case SCon{'7', t}:
      scan_digits_go(t, SCon{'7', acc})
    case SCon{'8', t}:
      scan_digits_go(t, SCon{'8', acc})
    case SCon{'9', t}:
      scan_digits_go(t, SCon{'9', acc})
    case SCon{h, t}:
      scan_digits_finish(acc, SCon{h, t})

def scan_digits(s: String) -> DigitScan:
  scan_digits_go(s, SNil{})

# Strict component parser: a multi-digit component may not have a leading zero.
# Nat.read also enforces the immediate-Nat range, so overlarge components are
# unrepresentable rather than silently truncated.
def parse_digit_text(s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{'0', t}:
      match t:
        case SNil{}:
          Some{0n}
        case SCon{h2, t2}:
          None{}
    case SCon{h, t}:
      Nat.read(SCon{h, t})

# ---------------------------------------------------------------------------
# Capacity-independent form recognition
# ---------------------------------------------------------------------------
# Classification is lexical/semantic, not a matter of whether the immediate Nat
# range can hold the value.  These validators mirror the parser without reading
# numeric values, so a huge but well-formed decimal still classifies as
# scalable; scaling then conservatively passes it through if it cannot be
# represented exactly as a Nat.

def valid_digit_text(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'0', t}:
      match t:
        case SNil{}:
          True{}
        case SCon{h, t2}:
          False{}
    case SCon{h, t}:
      True{}

def nonzero_digit_text(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'0', t}:
      False{}
    case SCon{h, t}:
      True{}

def digit_string_lt_len(+a: String, +b: String, c: Cmp) -> Bool:
  match c:
    case LT{}:
      True{}
    case EQ{}:
      String.is_lt(a, b)
    case GT{}:
      False{}

# Numeric comparison for digit strings already known to have no leading zeros:
# first by length, then lexicographically.
def digit_string_lt(+a: String, +b: String) -> Bool:
  digit_string_lt_len(a, b, Nat.cmp(String.length(a), String.length(b)))

def valid_fraction_rest(digits: String, rest: String) -> Bool:
  match rest:
    case SNil{}:
      nonzero_digit_text(digits)
    case SCon{h, t}:
      False{}

def valid_fraction_scan(scan: DigitScan) -> Bool:
  match scan:
    case DigitScan{digits, rest}:
      valid_fraction_rest(digits, rest)

def valid_fraction_after_slash(s: String) -> Bool:
  valid_fraction_scan(scan_digits(drop_qty_spaces(s)))

def valid_mixed_den_rest(+num_digits: String, +den_digits: String, rest: String) -> Bool:
  match rest:
    case SNil{}:
      Bool.and(valid_digit_text(num_digits),
        Bool.and(nonzero_digit_text(den_digits), digit_string_lt(num_digits, den_digits)))
    case SCon{h, t}:
      False{}

def valid_mixed_den_scan(num_digits: String, scan: DigitScan) -> Bool:
  match scan:
    case DigitScan{digits, rest}:
      valid_mixed_den_rest(num_digits, digits, rest)

def valid_mixed_rest(num_digits: String, rest: String) -> Bool:
  match rest:
    case SCon{'/', tail}:
      valid_mixed_den_scan(num_digits, scan_digits(tail))
    case SNil{}:
      False{}
    case SCon{h, t}:
      False{}

def valid_mixed_scan(scan: DigitScan) -> Bool:
  match scan:
    case DigitScan{digits, rest}:
      valid_mixed_rest(digits, rest)

def valid_decimal_digits(digits: String) -> Bool:
  match digits:
    case SNil{}:
      False{}
    case SCon{h, t}:
      True{}

def valid_decimal_rest(digits: String, rest: String) -> Bool:
  match rest:
    case SNil{}:
      valid_decimal_digits(digits)
    case SCon{h, t}:
      False{}

def valid_decimal_scan(scan: DigitScan) -> Bool:
  match scan:
    case DigitScan{digits, rest}:
      valid_decimal_rest(digits, rest)

def valid_after_space(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'/', tail}:
      valid_fraction_after_slash(tail)
    case SCon{h, t}:
      valid_mixed_scan(scan_digits(SCon{h, t}))

def valid_after_whole(rest: String) -> Bool:
  match rest:
    case SNil{}:
      True{}
    case SCon{'.', tail}:
      valid_decimal_scan(scan_digits(tail))
    case SCon{'/', tail}:
      valid_fraction_after_slash(tail)
    case SCon{' ', tail}:
      valid_after_space(drop_qty_spaces(tail))
    case SCon{'\t', tail}:
      valid_after_space(drop_qty_spaces(tail))
    case SCon{h, t}:
      False{}

def valid_start_whole(valid: Bool, rest: String) -> Bool:
  match valid:
    case False{}:
      False{}
    case True{}:
      valid_after_whole(rest)

def valid_start_digits(digits: String, rest: String) -> Bool:
  match digits:
    case SNil{}:
      False{}
    case SCon{h, t}:
      valid_start_whole(valid_digit_text(SCon{h, t}), rest)

def valid_start_scan(scan: DigitScan) -> Bool:
  match scan:
    case DigitScan{digits, rest}:
      valid_start_digits(digits, rest)

def valid_quantity_trimmed(s: String) -> Bool:
  valid_start_scan(scan_digits(s))

def parsed_quantity(+num: Nat, +den: Nat, decimal_family: Bool) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    value : Model.Rational <- make(num, den)
    return ParsedQuantity{value, decimal_family}

def finish_fraction_digits(+numer: Nat, digits: String) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    den0 : Nat <- parse_digit_text(digits)
    den : Nat <- nonzero_nat(den0)
    out : ParsedQuantity <- parsed_quantity(numer, den, False{})
    return out

def finish_fraction_rest(+numer: Nat, digits: String, rest: String) -> Maybe<&2, ParsedQuantity>:
  match rest:
    case SNil{}:
      finish_fraction_digits(numer, digits)
    case SCon{h, t}:
      None{}

def finish_fraction_scan(+numer: Nat, scan: DigitScan) -> Maybe<&2, ParsedQuantity>:
  match scan:
    case DigitScan{digits, rest}:
      finish_fraction_rest(numer, digits, rest)

# Parses the denominator of a simple fraction.  Spaces/tabs after the slash are
# part of Cooklang's accepted spaces-around-slash form.
def parse_fraction_after_slash(+numer: Nat, s: String) -> Maybe<&2, ParsedQuantity>:
  finish_fraction_scan(numer, scan_digits(drop_qty_spaces(s)))

def require_true(b: Bool) -> Maybe<&2, Unit>:
  match b:
    case False{}:
      None{}
    case True{}:
      Some{Unit{}}

def finish_mixed_compute(+whole: Nat, +num: Nat, +den: Nat) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    proper : Unit <- require_true(Nat.is_lt(num, den))
    product : Nat <- nat_mul_maybe(whole, den)
    total : Nat <- nat_add_maybe(product, num)
    out : ParsedQuantity <- parsed_quantity(total, den, False{})
    return out

def finish_mixed_digits(+whole: Nat, num_digits: String, den_digits: String) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    num0 : Nat <- parse_digit_text(num_digits)
    den0 : Nat <- parse_digit_text(den_digits)
    den : Nat <- nonzero_nat(den0)
    out : ParsedQuantity <- finish_mixed_compute(whole, num0, den)
    return out

def finish_mixed_den_rest(+whole: Nat, num_digits: String, den_digits: String, rest: String) -> Maybe<&2, ParsedQuantity>:
  match rest:
    case SNil{}:
      finish_mixed_digits(whole, num_digits, den_digits)
    case SCon{h, t}:
      None{}

def finish_mixed_den_scan(+whole: Nat, num_digits: String, scan: DigitScan) -> Maybe<&2, ParsedQuantity>:
  match scan:
    case DigitScan{digits, rest}:
      finish_mixed_den_rest(whole, num_digits, digits, rest)

def finish_mixed_rest(+whole: Nat, num_digits: String, rest: String) -> Maybe<&2, ParsedQuantity>:
  match rest:
    case SCon{'/', tail}:
      finish_mixed_den_scan(whole, num_digits, scan_digits(tail))
    case SNil{}:
      None{}
    case SCon{h, t}:
      None{}

def finish_mixed_scan(+whole: Nat, scan: DigitScan) -> Maybe<&2, ParsedQuantity>:
  match scan:
    case DigitScan{digits, rest}:
      finish_mixed_rest(whole, digits, rest)

def pow10_loop(n: Nat) -> Nat:
  match n:
    case 0n:
      1n
    case 1n+p:
      Nat.mul(10n, pow10_loop(p))

def pow10_gate(n: Nat, small: Bool) -> Maybe<&2, Nat>:
  match small:
    case False{}:
      None{}
    case True{}:
      Some{pow10_loop(n)}

# 10^14 fits in the immediate Nat range, but 10^15 does not.
def pow10_maybe(+n: Nat) -> Maybe<&2, Nat>:
  pow10_gate(n, Nat.is_le(n, 14n))

def finish_decimal_compute(+whole: Nat, +frac: Nat, +p10: Nat) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    scaled_whole : Nat <- nat_mul_maybe(whole, p10)
    num : Nat <- nat_add_maybe(scaled_whole, frac)
    out : ParsedQuantity <- parsed_quantity(num, p10, True{})
    return out

def finish_decimal_nonempty(+whole: Nat, +digits: String) -> Maybe<&2, ParsedQuantity>:
  do Maybe<&2, ParsedQuantity>:
    frac : Nat <- Nat.read(digits)
    p10 : Nat <- pow10_maybe(String.length(digits))
    out : ParsedQuantity <- finish_decimal_compute(whole, frac, p10)
    return out

def finish_decimal_digits(+whole: Nat, digits: String) -> Maybe<&2, ParsedQuantity>:
  match digits:
    case SNil{}:
      None{}
    case SCon{h, t}:
      finish_decimal_nonempty(whole, SCon{h, t})

def finish_decimal_rest(+whole: Nat, digits: String, rest: String) -> Maybe<&2, ParsedQuantity>:
  match rest:
    case SNil{}:
      finish_decimal_digits(whole, digits)
    case SCon{h, t}:
      None{}

def finish_decimal_scan(+whole: Nat, scan: DigitScan) -> Maybe<&2, ParsedQuantity>:
  match scan:
    case DigitScan{digits, rest}:
      finish_decimal_rest(whole, digits, rest)

# After spaces following the whole part, either a slash means a simple fraction
# with space before the slash, or digits start a mixed number.  Anything else is
# nonnumeric.  In a mixed number the fraction itself is written compactly as
# num/den; additional spaces around that slash are not part of the mixed form.
def parse_after_space(+whole: Nat, s: String) -> Maybe<&2, ParsedQuantity>:
  match s:
    case SNil{}:
      None{}
    case SCon{'/', tail}:
      parse_fraction_after_slash(whole, tail)
    case SCon{h, t}:
      finish_mixed_scan(whole, scan_digits(SCon{h, t}))

def parse_after_whole(+whole: Nat, rest: String) -> Maybe<&2, ParsedQuantity>:
  match rest:
    case SNil{}:
      parsed_quantity(whole, 1n, False{})
    case SCon{'.', tail}:
      finish_decimal_scan(whole, scan_digits(tail))
    case SCon{'/', tail}:
      parse_fraction_after_slash(whole, tail)
    case SCon{' ', tail}:
      parse_after_space(whole, drop_qty_spaces(tail))
    case SCon{'\t', tail}:
      parse_after_space(whole, drop_qty_spaces(tail))
    case SCon{h, t}:
      None{}

def parse_start_whole(mwhole: Maybe<&2, Nat>, rest: String) -> Maybe<&2, ParsedQuantity>:
  match mwhole:
    case None{}:
      None{}
    case Some{whole}:
      parse_after_whole(whole, rest)

def parse_start_digits(digits: String, rest: String) -> Maybe<&2, ParsedQuantity>:
  match digits:
    case SNil{}:
      None{}
    case SCon{h, t}:
      parse_start_whole(parse_digit_text(SCon{h, t}), rest)

def parse_start_scan(scan: DigitScan) -> Maybe<&2, ParsedQuantity>:
  match scan:
    case DigitScan{digits, rest}:
      parse_start_digits(digits, rest)

def parse_quantity_trimmed(s: String) -> Maybe<&2, ParsedQuantity>:
  parse_start_scan(scan_digits(s))

# Parses a scalable authored amount.  Empty and fixed amounts both return None;
# classify_quantity distinguishes those two classes.
def parse_quantity(s: String) -> Maybe<&2, ParsedQuantity>:
  parse_quantity_trimmed(trim_quantity(s))

def classify_valid(valid: Bool) -> QuantityClass:
  match valid:
    case False{}:
      QuantityFixed{}
    case True{}:
      QuantityScalable{}

def classify_trimmed(s: String) -> QuantityClass:
  match s:
    case SNil{}:
      QuantityEmpty{}
    case SCon{h, t}:
      classify_valid(valid_quantity_trimmed(SCon{h, t}))

def classify_quantity(s: String) -> QuantityClass:
  classify_trimmed(trim_quantity(s))

def class_name(klass: QuantityClass) -> String:
  match klass:
    case QuantityEmpty{}:
      "empty"
    case QuantityScalable{}:
      "scalable"
    case QuantityFixed{}:
      "fixed"

def factor_nonzero_gate(+value: Model.Rational, zero_num: Bool) -> Maybe<&2, Model.Rational>:
  match zero_num:
    case False{}:
      Some{value}
    case True{}:
      None{}

def factor_from_rational(+value: Model.Rational) -> Maybe<&2, Model.Rational>:
  match value:
    case Model.Rational{+num, +den}:
      factor_nonzero_gate(Model.Rational{num, den}, Nat.is_eq(num, 0n))

def factor_from_parsed_some(parsed: ParsedQuantity) -> Maybe<&2, Model.Rational>:
  match parsed:
    case ParsedQuantity{value, decimal_family}:
      factor_from_rational(value)

def factor_from_parsed(parsed: Maybe<&2, ParsedQuantity>) -> Maybe<&2, Model.Rational>:
  match parsed:
    case None{}:
      None{}
    case Some{p}:
      factor_from_parsed_some(p)

# Factors use the same scalable source forms as quantities, but a zero factor
# is rejected: scaling a recipe to nothing is degenerate.
def parse_factor(s: String) -> Maybe<&2, Model.Rational>:
  factor_from_parsed(parse_quantity(s))

# ---------------------------------------------------------------------------
# Canonical formatting
# ---------------------------------------------------------------------------

def fraction_text(+num: Nat, +den: Nat) -> String:
  Nat.show(num) ++ "/" ++ Nat.show(den)

def bool_to_nat(b: Bool) -> Nat:
  match b:
    case False{}:
      0n
    case True{}:
      1n

# strip_factor divides n by factor as many times as possible.  A denominator in
# the immediate Nat range cannot contain more than 47 factors of 2 (or 20
# factors of 5), so a fixed 48-step structural loop is enough.  Once division
# stops, factor^0 = 1 leaves n unchanged for the remaining steps; this avoids a
# non-structural recursion on the quotient.
def strip_factor_go(fuel: Nat, +n: Nat, +factor: Nat) -> Nat:
  match fuel:
    case 0n:
      n
    case 1n+p:
      divisible = Bool.and(Nat.is_ne(n, 0n), Nat.is_eq(Nat.mod(n, factor), 0n))
      divisor = Nat.pow(factor, bool_to_nat(divisible))
      strip_factor_go(p, Nat.div(n, divisor), factor)

def strip_factor(+n: Nat, +factor: Nat) -> Nat:
  strip_factor_go(48n, n, factor)

def terminating_den(+den: Nat) -> Bool:
  Nat.is_eq(strip_factor(strip_factor(den, 2n), 5n), 1n)

# Modular addition for positive modulus m, with a,b < m.  It never forms a sum
# larger than m, so decimal expansion does not overflow merely because 10*r
# would exceed the immediate Nat range.
def add_mod_finish(a: Nat, b: Nat, c: Nat, small: Bool) -> AddMod:
  match small:
    case False{}:
      AddMod{Nat.sub(a, c), True{}}
    case True{}:
      AddMod{Nat.add(a, b), False{}}

def add_mod(+a: Nat, +b: Nat, +m: Nat) -> AddMod:
  +c = Nat.sub(m, b)
  add_mod_finish(a, b, c, Nat.is_lt(a, c))

def nat_inc_if(n: Nat, inc: Bool) -> Nat:
  match inc:
    case False{}:
      n
    case True{}:
      1n+n

def mul10_accumulate(step: AddMod, wraps: Nat) -> Mul10State:
  match step:
    case AddMod{value, wrapped}:
      Mul10State{value, nat_inc_if(wraps, wrapped)}

# Ten modular additions compute both 10*r mod den and floor(10*r/den).  The
# wrap count is the next decimal digit (always 0..9 because r < den).
def mul10_go(fuel: Nat, +r: Nat, +den: Nat, state: Mul10State) -> Mul10State:
  match fuel:
    case 0n:
      state
    case 1n+p:
      Mul10State{acc, wraps} = state
      mul10_go(p, r, den, mul10_accumulate(add_mod(acc, r, den), wraps))

def mul10_mod(+r: Nat, +den: Nat) -> Mul10State:
  mul10_go(10n, r, den, Mul10State{0n, 0n})

def decimal_digit_char(+digit: Nat) -> Char:
  Chr{U32.from_nat(Nat.add(48n, digit))}

def decimal_step_from_mul(step: Mul10State, digits_rev: String) -> DecimalState:
  match step:
    case Mul10State{acc, wraps}:
      DecimalState{acc, SCon{decimal_digit_char(wraps), digits_rev}}

# Oliver's canonical text policy caps decimal emission at 12 fractional
# digits.  A denominator needing more digits still terminates mathematically,
# but falls back to the reduced fraction so emitted decimals are exact rather
# than truncated.  The remainder is matched directly as a parameter field, so
# no non-structural or mutually recursive decision procedure is needed.
def decimal_digits_go(fuel: Nat, +den: Nat, state: DecimalState) -> DecimalExpansion:
  match fuel:
    case 0n:
      DecimalState{rem, digits_rev} = state
      match rem:
        case 0n:
          DecimalExpansion{String.reverse(digits_rev), 0n, True{}}
        case 1n+rp:
          DecimalExpansion{String.reverse(digits_rev), 1n+rp, False{}}
    case 1n+p:
      DecimalState{rem, digits_rev} = state
      match rem:
        case 0n:
          DecimalExpansion{String.reverse(digits_rev), 0n, True{}}
        case 1n+rp:
          decimal_digits_go(p, den,
            decimal_step_from_mul(mul10_mod(1n+rp, den), digits_rev))

def decimal_digits(+den: Nat, +rem: Nat) -> DecimalExpansion:
  decimal_digits_go(12n, den, DecimalState{rem, SNil{}})

def format_decimal_complete(
  digits: String, intpart: Nat, +num: Nat, +den: Nat, complete: Bool
) -> String:
  match complete:
    case False{}:
      fraction_text(num, den)
    case True{}:
      Nat.show(intpart) ++ "." ++ digits

def format_decimal_done(
  expansion: DecimalExpansion, intpart: Nat, +num: Nat, +den: Nat
) -> String:
  match expansion:
    case DecimalExpansion{digits, remainder, complete}:
      format_decimal_complete(digits, intpart, num, den, complete)

def format_decimal(+num: Nat, +den: Nat) -> String:
  format_decimal_done(decimal_digits(den, Nat.mod(num, den)), Nat.div(num, den), num, den)

def format_decimal_gate(+num: Nat, +den: Nat, terminating: Bool) -> String:
  match terminating:
    case False{}:
      fraction_text(num, den)
    case True{}:
      format_decimal(num, den)

def format_nonwhole(+num: Nat, +den: Nat, decimal_family: Bool) -> String:
  match decimal_family:
    case False{}:
      fraction_text(num, den)
    case True{}:
      format_decimal_gate(num, den, terminating_den(den))

def format_whole_gate(+num: Nat, +den: Nat, decimal_family: Bool, whole: Bool) -> String:
  match whole:
    case False{}:
      format_nonwhole(num, den, decimal_family)
    case True{}:
      Nat.show(num)

# Canonical output: whole values are integers; non-whole values are reduced
# fractions except decimal-family sources whose reduced denominator terminates
# within the 12-fractional-digit emission bound.
def format_rational(+value: Model.Rational, decimal_family: Bool) -> String:
  match value:
    case Model.Rational{+num, +den}:
      format_whole_gate(num, den, decimal_family, Nat.is_eq(den, 1n))

# ---------------------------------------------------------------------------
# Amount scaling
# ---------------------------------------------------------------------------

def unchanged_quantity(+original: String, klass: QuantityClass) -> ScaledQuantity:
  ScaledQuantity{klass, original, original, False{}}

def finish_scale_mul(
  scaled: Maybe<&2, Model.Rational>, +original: String, klass: QuantityClass, decimal_family: Bool
) -> ScaledQuantity:
  match scaled:
    case None{}:
      unchanged_quantity(original, klass)
    case Some{value}:
      +scaled = format_rational(value, decimal_family)
      ScaledQuantity{klass, original, scaled, Bool.not(String.eq(original, scaled))}

def finish_scale_parsed_some(
  parsed: ParsedQuantity, +original: String, klass: QuantityClass, +num: Nat, +den: Nat
) -> ScaledQuantity:
  match parsed:
    case ParsedQuantity{value, decimal_family}:
      finish_scale_mul(mul_factor(value, num, den), original, klass, decimal_family)

def finish_scale_parsed(
  parsed: Maybe<&2, ParsedQuantity>, +original: String, klass: QuantityClass, +num: Nat, +den: Nat
) -> ScaledQuantity:
  match parsed:
    case None{}:
      unchanged_quantity(original, klass)
    case Some{p}:
      finish_scale_parsed_some(p, original, klass, num, den)

def scale_amount_scalable(+original: String, klass: QuantityClass, +num: Nat, +den: Nat) -> ScaledQuantity:
  finish_scale_parsed(parse_quantity(original), original, klass, num, den)

def scale_amount_classified(+original: String, klass: QuantityClass, +num: Nat, +den: Nat) -> ScaledQuantity:
  match klass:
    case QuantityEmpty{}:
      unchanged_quantity(original, klass)
    case QuantityFixed{}:
      unchanged_quantity(original, klass)
    case QuantityScalable{}:
      scale_amount_scalable(original, klass, num, den)

# Scales one authored quantity string.  Empty, fixed, nonnumeric, invalid, and
# unrepresentable/overflowing amounts are byte-for-byte pass-throughs.
def scale_amount(+original: String, +num: Nat, +den: Nat) -> ScaledQuantity:
  scale_amount_classified(original, classify_quantity(original), num, den)

def scaled_text(result: ScaledQuantity) -> String:
  match result:
    case ScaledQuantity{klass, original, scaled, changed}:
      scaled

def scaled_changed(result: ScaledQuantity) -> Bool:
  match result:
    case ScaledQuantity{klass, original, scaled, changed}:
      changed
