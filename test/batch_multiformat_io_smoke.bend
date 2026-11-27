import Base
import ../src/parallel/engine.bend as Engine

# IO discovery smoke for the multi-format batch engine.  Uses one fixed
# fixture directory; run serially.

def report(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.print("FAIL " ++ name)

def write_finish(p: File & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (file, result) = p
  do IO<Unit>:
    Unit <- IO.pass(Unit, result)
    File.close(file)

def write_text_file(+path: String, +text: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    p : File & Result<&1, &1, (U32 & String), Unit> <- File.write(f, text)
    write_finish(p)

def dir() -> String:
  "/tmp/bendown_batch_multi"

def pa() -> String:
  dir() ++ "/a.md"

def pb() -> String:
  dir() ++ "/b.textile"

def pc() -> String:
  dir() ++ "/c.cook"

def expected_paths() -> List<&2, String>:
  {[pa(), pb(), pc()] : List<&2, String>}

def maybe_paths_eq(m: Maybe<&2, List<&2, String>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+paths}:
      Engine.str_list_eq(paths, expected_paths())

def outcome_name(o: Engine.DocOutcome) -> String:
  match o:
    case Engine.DocOk{+name, html, targets}:
      name
    case Engine.DocErr{+name, message}:
      name

def outcome_names(xs: List<&2, Engine.DocOutcome>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      outcome_name(h) <> outcome_names(t)

def maybe_outcome_names_eq(m: Maybe<&2, List<&2, Engine.DocOutcome>>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+xs}:
      Engine.str_list_eq(outcome_names(xs), expected_paths())

def main() -> IO(Unit):
  do IO<Unit>:
    c0 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/rm", ["-rf", dir()], "", 1024, 5000)
    c1 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/mkdir", ["-p", dir()], "", 1024, 5000)
    Unit <- write_text_file(pa(), "[x](x.md)\n")
    Unit <- write_text_file(pb(), "\"x\":x.textile\n")
    Unit <- write_text_file(pc(), "= Day\n@./x{2}\n")
    Unit <- write_text_file(dir() ++ "/decoy.txt", "ignored\n")
    paths : Maybe<&2, List<&2, String>> <- Engine.find_markup_paths(dir())
    Unit <- report("discovers-md-textile-cook", maybe_paths_eq(paths))
    outcomes : Maybe<&2, List<&2, Engine.DocOutcome>> <- Engine.process_dir_par(dir(), 1048576)
    Unit <- report("processes-discovered-formats", maybe_outcome_names_eq(outcomes))
    c2 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/rm", ["-rf", dir()], "", 1024, 5000)
    IO.print("batch multiformat io smoke: done")

#|PASS discovers-md-textile-cook
#|PASS processes-discovered-formats
