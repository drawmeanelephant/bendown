import Base
import ./src/ast.bend as Ast
import ./src/text.bend as Text
import ./src/parser/markdown.bend as Markdown
import ./src/parser/textile.bend as Textile
import ./src/cooklang/model.bend as Model
import ./src/cooklang/parser.bend as CookParser
import ./src/render/html.bend as Html
import ./src/parallel/batch.bend as Batch
import ./src/cooklang/scaling_proof.bend as ScalingProof
import ./LAWS.bend as Laws

def Laws.input_ceiling_rejects(input, max_input_bytes, ev):
  %Equal.sym(Bool, Nat.is_lt(max_input_bytes, Text.utf8_length(input)), True{}, ev) : {Markdown.markdown_gate(input, _) == None{} : Maybe<&2, Ast.Document>}
  {==}

def Laws.zero_limit_accepts_empty():
  {==}


def Laws.markdown_parse_deterministic(input):
  {==}

def Laws.textile_parse_deterministic(input):
  {==}

def Laws.cook_parse_deterministic(input):
  {==}

def Laws.render_deterministic(doc):
  {==}

def Laws.parallel_batch_equivalent(A, B, f, xs):
  match xs:
    case Nil{}:
      {==}
    case x <> Nil{}:
      {==}
    case x <> y <> rest:
      %Laws.parallel_batch_equivalent(A, B, f, rest) : {f(x) <> (f(y) <> Batch.seq_map(~A, ~B, ~f, rest)) == f(x) <> (f(y) <> _) : List<&2, B>}
      {==}

def Laws.textile_input_ceiling_rejects(input, max_input_bytes, ev):
  %Equal.sym(Bool, Nat.is_gt(Text.utf8_length(input), max_input_bytes), True{}, ev) : {Textile.parse_textile_bounded_gate(input, _) == None{} : Maybe<&2, Ast.Document>}
  {==}

def Laws.textile_zero_limit_accepts_empty():
  {==}

def Laws.cook_input_ceiling_rejects(input, max_input_bytes, ev):
  %Equal.sym(Bool, Nat.is_le(Text.utf8_length(input), max_input_bytes), False{}, ev) : {CookParser.ck_if(Maybe<&2, Model.Recipe>, _, u => Some{CookParser.parse_cooklang(input)}, u => None{}) == None{} : Maybe<&2, Model.Recipe>}
  {==}

def Laws.cook_zero_limit_accepts_empty():
  {==}
