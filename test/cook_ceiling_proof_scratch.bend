import Base
import ../src/text.bend as Text
import ../src/cooklang/model.bend as Model
import ../src/cooklang/parser.bend as CookParser

law cook_input_ceiling_rejects:
  for +input: String
  for +max_input_bytes: Nat
  for ev: {Nat.is_le(Text.utf8_length(input), max_input_bytes) == False{} : Bool}
  {CookParser.parse_cooklang_bounded(input, max_input_bytes) == None{} : Maybe<&2, Model.Recipe>}

def cook_input_ceiling_rejects(input, max_input_bytes, ev):
  %Equal.sym(Bool, Nat.is_le(Text.utf8_length(input), max_input_bytes), False{}, ev) : {CookParser.ck_if(Maybe<&2, Model.Recipe>, _, u => Some{CookParser.parse_cooklang(input)}, u => None{}) == None{} : Maybe<&2, Model.Recipe>}
  {==}
