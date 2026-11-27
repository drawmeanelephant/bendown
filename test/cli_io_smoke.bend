import Base
import ../src/cli_io.bend as CliIO

def main() -> IO(Unit):
  do IO<Unit>:
    s : String <- CliIO.read_stdin_limited(3)
    IO.print(s)
