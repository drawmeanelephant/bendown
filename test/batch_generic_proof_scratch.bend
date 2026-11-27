import Base
import ../src/parallel/batch.bend as Batch

law batch_equivalent:
  for -A: Data
  for -B: Data
  for -f: A -> B
  for xs: List<&2, A>
  {Batch.seq_map(~A, ~B, ~f, xs) == Batch.par_map(~A, ~B, ~f, xs) : List<&2, B>}

def batch_equivalent(A, B, f, xs):
  match xs:
    case Nil{}:
      {==}
    case x <> Nil{}:
      {==}
    case x <> y <> rest:
      %batch_equivalent(A, B, f, rest) : {f(x) <> (f(y) <> Batch.seq_map(~A, ~B, ~f, rest)) == f(x) <> (f(y) <> _) : List<&2, B>}
      {==}
