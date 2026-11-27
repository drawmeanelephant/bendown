import Base
import ./src/ast.bend as Ast
import ./src/text.bend as Text
import ./src/parser/markdown.bend as Markdown
import ./src/parser/textile.bend as Textile
import ./src/cooklang/model.bend as Model
import ./src/cooklang/parser.bend as CookParser
import ./src/render/html.bend as Html
import ./src/parallel/batch.bend as Batch
import ./src/cooklang/scaling_laws.bend as ScalingLaws

law input_ceiling_rejects:
  for +input: String
  for +max_input_bytes: Nat
  for ev: {Nat.is_lt(max_input_bytes, Text.utf8_length(input)) == True{} : Bool}
  {Markdown.parse_markdown_bounded(input, max_input_bytes) == None{} : Maybe<&2, Ast.Document>}

law zero_limit_accepts_empty:
  {Markdown.parse_markdown_bounded("", 0n) == Some{Markdown.empty_document()} : Maybe<&2, Ast.Document>}


law markdown_parse_deterministic:
  for +input: String
  {Markdown.parse_markdown(input) == Markdown.parse_markdown(input) : Ast.Document}

law textile_parse_deterministic:
  for +input: String
  {Textile.parse_textile(input) == Textile.parse_textile(input) : Ast.Document}

law cook_parse_deterministic:
  for +input: String
  {CookParser.parse_cooklang(input) == CookParser.parse_cooklang(input) : Model.Recipe}

law render_deterministic:
  for +doc: Ast.Document
  {Html.render_document(doc) == Html.render_document(doc) : String}

law parallel_batch_equivalent:
  for -A: Data
  for -B: Data
  for -f: A -> B
  for xs: List<&2, A>
  {Batch.seq_map(~A, ~B, ~f, xs) == Batch.par_map(~A, ~B, ~f, xs) : List<&2, B>}

law textile_input_ceiling_rejects:
  for +input: String
  for +max_input_bytes: Nat
  for ev: {Nat.is_gt(Text.utf8_length(input), max_input_bytes) == True{} : Bool}
  {Textile.parse_textile_bounded(input, max_input_bytes) == None{} : Maybe<&2, Ast.Document>}

law textile_zero_limit_accepts_empty:
  {Textile.parse_textile_bounded("", 0n) == Some{Ast.Document{[]}} : Maybe<&2, Ast.Document>}

law cook_input_ceiling_rejects:
  for +input: String
  for +max_input_bytes: Nat
  for ev: {Nat.is_le(Text.utf8_length(input), max_input_bytes) == False{} : Bool}
  {CookParser.parse_cooklang_bounded(input, max_input_bytes) == None{} : Maybe<&2, Model.Recipe>}

law cook_zero_limit_accepts_empty:
  {CookParser.parse_cooklang_bounded("", 0n) == Some{Model.Recipe{None{}, []}} : Maybe<&2, Model.Recipe>}
