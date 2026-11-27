import Base
import ../src/parallel/batch.bend as Batch

def id_string(x: String) -> String:
  x

law par_eq_seq:
  for +xs: List<&2, String>
  {Batch.par_map(~String, ~String, ~id_string, xs) == Batch.seq_map(~String, ~String, ~id_string, xs) : List<&2, String>}

def par_eq_seq(xs):
  match xs:
    case Nil{}:
      {==}
    case x <> Nil{}:
      {==}
    case x <> y <> rest:
      %par_eq_seq(rest) : {id_string(x) <> id_string(y) <> Batch.par_map(~String, ~String, ~id_string, rest) == id_string(x) <> id_string(y) <> _ : List<&2, String>}
      {==}

def main() -> {Batch.par_map(~String, ~String, ~id_string, ["a"]) == Batch.seq_map(~String, ~String, ~id_string, ["a"]) : List<&2, String>}:
  par_eq_seq(["a"])
