import Base
import ../src/text.bend as Text
import ../src/parallel/batch.bend as Batch

law newline_batch_equivalent:
  for xs: List<&2, String>
  {Batch.seq_map(~String, ~String, ~Text.normalize_newlines, xs) == Batch.par_map(~String, ~String, ~Text.normalize_newlines, xs) : List<&2, String>}

def newline_batch_equivalent(xs):
  match xs:
    case Nil{}:
      {==}
    case x <> Nil{}:
      {==}
    case x <> y <> rest:
      %newline_batch_equivalent(rest) : {Text.normalize_newlines(x) <> (Text.normalize_newlines(y) <> Batch.seq_map(~String, ~String, ~Text.normalize_newlines, rest)) == Text.normalize_newlines(x) <> (Text.normalize_newlines(y) <> _) : List<&2, String>}
      {==}
