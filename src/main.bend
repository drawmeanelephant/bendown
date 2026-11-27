import Base
import ./ast.bend as Ast
import ./cli_io.bend as CliIO
import ./parser/markdown.bend as Markdown
import ./parser/textile.bend as Textile
import ./render/html.bend as Html
import ./cooklang/model.bend as Model
import ./cooklang/parser.bend as CookParser
import ./cooklang/serialize.bend as CookSerialize
import ./cooklang/rational.bend as CookRational
import ./cooklang/scale.bend as CookScale
import ./cooklang/menu.bend as CookMenu
import ./cooklang/html.bend as CookHtml


# Native CLI for single-document operations.  Batch mode is intentionally
# a separate executable in src/batch_cli.bend: linking both command surfaces
# into one binary currently exceeds the Bend compiler's machine stack.
type CliConfig is Data:
  CliConfig{operation: String, from: String, xhtml: Bool, factor: String, input: Maybe<&2, String>, error: Maybe<&2, String>}

def default_cli_config() -> CliConfig:
  CliConfig{"render", "markdown", False{}, "1", None{}, None{}}

def cli_set_operation(cfg: CliConfig, +operation: String) -> CliConfig:
  match cfg:
    case CliConfig{oldop, from, xhtml, factor, input, error}:
      CliConfig{operation, from, xhtml, factor, input, error}

def cli_set_from(cfg: CliConfig, +from: String) -> CliConfig:
  match cfg:
    case CliConfig{operation, oldfrom, xhtml, factor, input, error}:
      CliConfig{operation, from, xhtml, factor, input, error}

def cli_set_factor(cfg: CliConfig, +factor: String) -> CliConfig:
  match cfg:
    case CliConfig{operation, from, xhtml, oldfactor, input, error}:
      CliConfig{operation, from, xhtml, factor, input, error}

def cli_set_xhtml(cfg: CliConfig) -> CliConfig:
  match cfg:
    case CliConfig{operation, from, oldxhtml, factor, input, error}:
      CliConfig{operation, from, True{}, factor, input, error}

def cli_set_error(cfg: CliConfig, +message: String) -> CliConfig:
  match cfg:
    case CliConfig{operation, from, xhtml, factor, input, olderror}:
      CliConfig{operation, from, xhtml, factor, input, Some{message}}

def cli_set_to_decide(cfg: CliConfig, +value: String, is_xhtml: Bool, is_html: Bool) -> CliConfig:
  match is_xhtml:
    case True{}:
      cli_set_xhtml(cfg)
    case False{}:
      match is_html:
        case True{}:
          cfg
        case False{}:
          cli_set_error(cfg, "unsupported output profile")

def cli_set_to(cfg: CliConfig, +value: String) -> CliConfig:
  cli_set_to_decide(cfg, value, String.eq(value, "xhtml"), String.eq(value, "html"))


def cli_set_input(cfg: CliConfig, +path: String) -> CliConfig:
  match cfg:
    case CliConfig{operation, from, xhtml, factor, input, error}:
      match input:
        case None{}:
          CliConfig{operation, from, xhtml, factor, Some{path}, error}
        case Some{old}:
          CliConfig{operation, from, xhtml, factor, Some{old}, Some{"multiple input paths"}}

def cli_config_input(cfg: CliConfig) -> Maybe<&2, String>:
  match cfg:
    case CliConfig{operation, from, xhtml, factor, input, error}:
      input

def cli_config_operation(cfg: CliConfig) -> String:
  match cfg:
    case CliConfig{+operation, from, xhtml, factor, input, error}:
      operation

def parse_cli_go(xs: List<String>, cfg: CliConfig) -> CliConfig:
  match xs:
    case Nil{}:
      cfg
    case "--from" <> value <> rest:
      parse_cli_go(rest, cli_set_from(cfg, value))
    case "--factor" <> value <> rest:
      parse_cli_go(rest, cli_set_factor(cfg, value))
    case "--to" <> value <> rest:
      parse_cli_go(rest, cli_set_to(cfg, value))
    case "--xhtml" <> rest:
      parse_cli_go(rest, cli_set_xhtml(cfg))
    case "render" <> rest:
      parse_cli_go(rest, cli_set_operation(cfg, "render"))
    case "serialize" <> rest:
      parse_cli_go(rest, cli_set_operation(cfg, "serialize"))
    case "scale" <> rest:
      parse_cli_go(rest, cli_set_operation(cfg, "scale"))
    case "menu" <> rest:
      parse_cli_go(rest, cli_set_operation(cfg, "menu"))
    case word <> rest:
      parse_cli_go(rest, cli_set_input(cfg, word))

def parse_cli_args(xs: List<String>) -> CliConfig:
  match xs:
    case Nil{}:
      default_cli_config()
    case program <> rest:
      parse_cli_go(rest, default_cli_config())

def read_input(input: Maybe<&2, String>, +max: U32) -> IO(String):
  match input:
    case None{}:
      CliIO.read_stdin_limited(max)
    case Some{path}:
      CliIO.read_file_limited(path, max)

def maybe_render_document(result: Maybe<&2, Ast.Document>, xhtml: Bool) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{doc}:
      match xhtml:
        case True{}:
          Some{Html.render_document_xhtml(doc)}
        case False{}:
          Some{Html.render_document(doc)}

def render_markdown_output(+input: String, xhtml: Bool) -> Maybe<&2, String>:
  maybe_render_document(Markdown.parse_markdown_bounded(input, 67108864n), xhtml)

def render_textile_output(+input: String, xhtml: Bool) -> Maybe<&2, String>:
  maybe_render_document(Textile.parse_textile_bounded(input, 67108864n), xhtml)

def serialize_cooklang_result(result: Maybe<&2, Model.Recipe>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{recipe}:
      Some{CookSerialize.serialize_recipe(recipe)}

def serialize_cooklang_output(+input: String) -> Maybe<&2, String>:
  serialize_cooklang_result(CookParser.parse_cooklang_bounded(input, 67108864n))

def render_cooklang_result(result: Maybe<&2, Model.Recipe>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{recipe}:
      Some{CookHtml.render_recipe(recipe)}

def render_cooklang_output(+input: String) -> Maybe<&2, String>:
  render_cooklang_result(CookParser.parse_cooklang_bounded(input, 67108864n))

def scale_factor_recipe(recipe: Model.Recipe, factor: Model.Rational) -> Maybe<&2, Model.Recipe>:
  match factor:
    case Model.Rational{+num, +den}:
      CookScale.scale_recipe_factor(recipe, num, den)

def scale_factor_maybe(recipe: Model.Recipe, factor: Maybe<&2, Model.Rational>) -> Maybe<&2, Model.Recipe>:
  match factor:
    case None{}:
      None{}
    case Some{value}:
      scale_factor_recipe(recipe, value)

def scale_recipe_maybe(result: Maybe<&2, Model.Recipe>, +factor_text: String) -> Maybe<&2, Model.Recipe>:
  match result:
    case None{}:
      None{}
    case Some{recipe}:
      scale_factor_maybe(recipe, CookRational.parse_factor(factor_text))

def maybe_serialize_recipe(result: Maybe<&2, Model.Recipe>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{recipe}:
      Some{CookSerialize.serialize_recipe(recipe)}

def scale_cooklang_output(+input: String, +factor_text: String) -> Maybe<&2, String>:
  maybe_serialize_recipe(scale_recipe_maybe(CookParser.parse_cooklang_bounded(input, 67108864n), factor_text))

def menu_cooklang_result(result: Maybe<&2, Model.Recipe>) -> Maybe<&2, String>:
  match result:
    case None{}:
      None{}
    case Some{recipe}:
      Some{CookMenu.render_menu(recipe)}

def menu_cooklang_output(+input: String) -> Maybe<&2, String>:
  menu_cooklang_result(CookParser.parse_cooklang_bounded(input, 67108864n))

def dispatch_render(+input: String, +from: String, xhtml: Bool, is_markdown: Bool, is_textile: Bool, is_cooklang: Bool) -> Maybe<&2, String>:
  match is_markdown:
    case True{}:
      render_markdown_output(input, xhtml)
    case False{}:
      match is_textile:
        case True{}:
          render_textile_output(input, xhtml)
        case False{}:
          match is_cooklang:
            case True{}:
              render_cooklang_output(input)
            case False{}:
              None{}

def dispatch_operation_render(+input: String, +from: String, xhtml: Bool) -> Maybe<&2, String>:
  dispatch_render(input, from, xhtml, String.eq(from, "markdown"), String.eq(from, "textile"), String.eq(from, "cooklang"))

def dispatch_operation_serialize(+input: String, +from: String, is_cooklang: Bool) -> Maybe<&2, String>:
  match is_cooklang:
    case True{}:
      serialize_cooklang_output(input)
    case False{}:
      None{}

def dispatch_operation_scale(+input: String, +from: String, +factor: String, is_cooklang: Bool) -> Maybe<&2, String>:
  match is_cooklang:
    case True{}:
      scale_cooklang_output(input, factor)
    case False{}:
      None{}

def dispatch_operation_menu(+input: String, +from: String, is_cooklang: Bool) -> Maybe<&2, String>:
  match is_cooklang:
    case True{}:
      menu_cooklang_output(input)
    case False{}:
      None{}

def dispatch_operation(+input: String, +operation: String, +from: String, xhtml: Bool, +factor: String,
    is_render: Bool, is_serialize: Bool, is_scale: Bool, is_menu: Bool) -> Maybe<&2, String>:
  match is_render:
    case True{}:
      dispatch_operation_render(input, from, xhtml)
    case False{}:
      match is_serialize:
        case True{}:
          dispatch_operation_serialize(input, from, String.eq(from, "cooklang"))
        case False{}:
          match is_scale:
            case True{}:
              dispatch_operation_scale(input, from, factor, String.eq(from, "cooklang"))
            case False{}:
              match is_menu:
                case True{}:
                  dispatch_operation_menu(input, from, String.eq(from, "cooklang"))
                case False{}:
                  None{}

def dispatch_config(+input: String, cfg: CliConfig) -> Maybe<&2, String>:
  match cfg:
    case CliConfig{+operation, +from, +xhtml, +factor, input_path, error}:
      match error:
        case Some{message}:
          None{}
        case None{}:
          dispatch_operation(input, operation, from, xhtml, factor,
            String.eq(operation, "render"), String.eq(operation, "serialize"), String.eq(operation, "scale"), String.eq(operation, "menu"))

def emit_output(result: Maybe<&2, String>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit, 2, "InvalidArgumentsOrInput")
    case Some{text}:
      IO.write(text)


def io_branch(z: Bool, yes: IO(Unit), no: IO(Unit)) -> IO(Unit):
  match z:
    case True{}:
      yes
    case False{}:
      no

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +cfg : CliConfig = parse_cli_args(args)
    input : String <- read_input(cli_config_input(cfg), 67108864)
    emit_output(dispatch_config(input, cfg))
