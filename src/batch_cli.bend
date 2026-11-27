import Base
import ./parallel/engine.bend as Engine

# Standalone native batch CLI.  The combined single-binary CLI currently hits
# a Bend compiler machine-stack limit when Markdown, Textile, Cooklang and the
# batch engine are linked together, so batch is a separate executable.

def render_target_lines(+source: String, targets: List<&2, String>) -> String:
  match targets:
    case Nil{}:
      ""
    case +target <> rest:
      source ++ " -> " ++ target ++ "\n" ++ render_target_lines(source, rest)

def outcome_target_lines(outcome: Engine.DocOutcome) -> String:
  match outcome:
    case Engine.DocOk{+name, html, targets}:
      render_target_lines(name, targets)
    case Engine.DocErr{name, message}:
      ""

def batch_target_lines(outcomes: List<&2, Engine.DocOutcome>) -> String:
  match outcomes:
    case Nil{}:
      ""
    case h <> t:
      outcome_target_lines(h) ++ batch_target_lines(t)

def render_batch_outcome(outcome: Engine.DocOutcome) -> String:
  match outcome:
    case Engine.DocOk{+name, +html, targets}:
      "== " ++ name ++ "\n" ++ html
    case Engine.DocErr{+name, +message}:
      "== " ++ name ++ "\nERROR: " ++ message ++ "\n"

def render_batch_documents(outcomes: List<&2, Engine.DocOutcome>) -> String:
  match outcomes:
    case Nil{}:
      ""
    case h <> t:
      render_batch_outcome(h) ++ render_batch_documents(t)

def render_batch_report(+outcomes: List<&2, Engine.DocOutcome>) -> String:
  render_batch_documents(outcomes) ++ "== links\n" ++ batch_target_lines(outcomes)

def emit_batch_result(result: Maybe<&2, List<&2, Engine.DocOutcome>>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit, 2, "BatchDiscoveryFailed")
    case Some{outcomes}:
      IO.write(render_batch_report(outcomes))

def run_batch_one(+dir: String, sequential: Bool) -> IO(Unit):
  match sequential:
    case True{}:
      do IO<Unit>:
        outcomes : Maybe<&2, List<&2, Engine.DocOutcome>> <- Engine.process_dir_seq(dir, 67108864)
        emit_batch_result(outcomes)
    case False{}:
      do IO<Unit>:
        outcomes : Maybe<&2, List<&2, Engine.DocOutcome>> <- Engine.process_dir_par(dir, 67108864)
        emit_batch_result(outcomes)

def run_batch_dir(args: List<String>) -> IO(Unit):
  match args:
    case program <> "--seq" <> dir <> rest:
      run_batch_one(dir, True{})
    case program <> dir <> rest:
      run_batch_one(dir, False{})
    case other:
      IO.die(Unit, 2, "usage: bendown-batch [--seq] DIRECTORY")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run_batch_dir(args)
