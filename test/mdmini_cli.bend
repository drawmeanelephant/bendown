import Base
import ../src/cli_io.bend as CliIO
import ../src/parser/markdown.bend as Markdown
import ../src/render/html.bend as Html

def main() -> IO(Unit):
  do IO<Unit>:
    input : String <- CliIO.read_stdin_limited(67108864)
    IO.write(Html.render_document(Markdown.parse_markdown(input)))
