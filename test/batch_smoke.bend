import Base
import ../src/parallel/batch.bend as Batch
import ../src/parallel/engine.bend as Engine

# Batch engine smoke checks.  Every line printed is either PASS or FAIL; the
# run is deterministic because fibers print nothing themselves and every join
# happens in input order.  The IO checks use a fixed fixture directory which
# is removed before and after the run; two simultaneous runs of this test on
# one host would share that directory, so run it serially.

# --- small helpers ---------------------------------------------------------

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

def output_names(xs: List<&2, Engine.DocOutput>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Engine.DocOutput{+name, html, targets} <> t:
      name <> output_names(t)

def graph_edges(g: Batch.LinkGraph) -> List<&2, Batch.LinkEdge>:
  match g:
    case Batch.LinkGraph{xe}:
      xe

# --- pure fixtures ---------------------------------------------------------

def src_a() -> String:
  "# Alpha\n\nsee [x](x.md) and [b](b.md).\n"

def src_b() -> String:
  "# Beta\n\n> quote [q](q.md)\n\n- item [i](i.md) and ![pix](im.png)\n"

def src_c() -> String:
  "# Gamma café\n\nplain text only, with ünicode émphasis.\n"

def src_d() -> String:
  ""

def src_e() -> String:
  "tail *em [e](e.md) end*\n"

def pure_docs() -> List<&2, Engine.DocInput>:
  {[ Engine.DocInput{"a.md", src_a()}
   , Engine.DocInput{"b.md", src_b()}
   , Engine.DocInput{"c.md", src_c()}
   , Engine.DocInput{"d.md", src_d()}
   , Engine.DocInput{"e.md", src_e()}
   ] : List<&2, Engine.DocInput>}

def pure_sources() -> List<&2, String>:
  {[src_a(), src_b(), src_c(), src_d(), src_e()] : List<&2, String>}

def pure_names() -> List<&2, String>:
  {["a.md", "b.md", "c.md", "d.md", "e.md"] : List<&2, String>}

# The expected edge list of the pure batch, in batch order: document a first,
# then b, then c/d/e.  Inside each document the order is document order.
def expected_edges() -> List<&2, Batch.LinkEdge>:
  {[ Batch.LinkEdge{"a.md", "x.md"}
   , Batch.LinkEdge{"a.md", "b.md"}
   , Batch.LinkEdge{"b.md", "q.md"}
   , Batch.LinkEdge{"b.md", "i.md"}
   , Batch.LinkEdge{"b.md", "im.png"}
   , Batch.LinkEdge{"e.md", "e.md"}
   ] : List<&2, Batch.LinkEdge>}

# --- IO fixtures -----------------------------------------------------------

def fix_dir() -> String:
  "/tmp/bendown_batch_smoke"

def fix_a() -> String:
  "/tmp/bendown_batch_smoke/a.md"

def fix_b() -> String:
  "/tmp/bendown_batch_smoke/b.md"

def fix_c() -> String:
  "/tmp/bendown_batch_smoke/c.md"

def fix_missing() -> String:
  "/tmp/bendown_batch_smoke/missing.md"

def fix_list() -> List<&2, String>:
  {[fix_a(), fix_b(), fix_c()] : List<&2, String>}

def fix_scrambled() -> List<&2, String>:
  {[fix_c(), fix_a(), fix_b()] : List<&2, String>}

# The pure expectation for the fixture batch: same names, same sources.
def fix_source_bc(+path: String) -> String:
  Engine.ifs(String, String.eq(path, fix_b()),
    u => src_b(),
    u => src_c())

def fix_source(+path: String) -> String:
  Engine.ifs(String, String.eq(path, fix_a()),
    u => src_a(),
    u => fix_source_bc(path))

def fix_inputs(xs: List<&2, String>) -> List<&2, Engine.DocInput>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      Engine.DocInput{h, fix_source(h)} <> fix_inputs(t)

def outer_html_ok(+h1: String, +h3: String) -> Bool:
  Bool.and(String.eq(h1, Engine.render_one(src_a())), String.eq(h3, Engine.render_one(src_c())))

# a single outcome that must be exactly the InputTooLarge error slot
def too_large_ok(rs: List<&2, Engine.DocOutcome>) -> Bool:
  match rs:
    case Engine.DocErr{+n, +m} <> Nil{}:
      Bool.and(String.eq(n, fix_a()), String.eq(m, "InputTooLarge"))
    case u:
      False{}

# io-error-slot check: three outcomes, the middle one an error, the outer two
# exactly the pure pipeline's outputs.
def error_slot_ok(rs: List<&2, Engine.DocOutcome>) -> Bool:
  match rs:
    case Engine.DocOk{+n1, +h1, +t1} <> Engine.DocErr{+n2, +m2} <> Engine.DocOk{+n3, +h3, +t3} <> Nil{}:
      Bool.and(String.eq(n1, fix_a()),
        Bool.and(String.eq(n2, fix_missing()),
          Bool.and(String.eq(n3, fix_c()), outer_html_ok(h1, h3))))
    case u:
      False{}

def maybe_paths_eq(m: Maybe<&2, List<&2, String>>, +expected: List<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+paths}:
      Engine.str_list_eq(paths, expected)

def maybe_outcomes_eq(m: Maybe<&2, List<&2, Engine.DocOutcome>>, +expected: List<&2, Engine.DocOutcome>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+rs}:
      Engine.doc_outcome_list_eq(rs, expected)

# --- main ------------------------------------------------------------------

def main() -> IO(Unit):
  do IO<Unit>:
    # pure checks
    +docs : List<&2, Engine.DocInput> = pure_docs()
    +outs : List<&2, Engine.DocOutput> = Engine.batch_process_par(docs)
    Unit <- report("pure-order", Engine.str_list_eq(output_names(outs), pure_names()))
    Unit <- report("par-eq-seq", Engine.doc_output_list_eq(outs, Engine.batch_process_seq(docs)))
    +srcs : List<&2, String> = pure_sources()
    Unit <- report("render-par-eq-seq",
      Engine.str_list_eq(Engine.batch_render_par(srcs), Engine.batch_render_seq(srcs)))
    Unit <- report("tree-eq-pairwise",
      Engine.str_list_eq(Engine.batch_render_par(srcs),
        Batch.par_map(~String, ~String, ~Engine.render_one, srcs)))
    Unit <- report("tree-fuel-fallback",
      Engine.str_list_eq(Engine.par_tree_go(~String, ~String, ~Engine.render_one, 0n, srcs),
        Engine.batch_render_seq(srcs)))
    Unit <- report("graph-order", Engine.edge_list_eq(graph_edges(Engine.batch_graph_seq(outs)), expected_edges()))
    Unit <- report("graph-par-eq-seq", Engine.graph_eq(Engine.batch_graph_par(outs), Engine.batch_graph_seq(outs)))
    # io fixture setup
    c0 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/rm", ["-rf", fix_dir()], "", 1024, 5000)
    c1 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/mkdir", ["-p", fix_dir()], "", 1024, 5000)
    Unit <- write_text_file(fix_a(), src_a())
    Unit <- write_text_file(fix_b(), src_b())
    Unit <- write_text_file(fix_c(), src_c())
    Unit <- write_text_file(fix_dir() ++ "/decoy.txt", "not markdown\n")
    # io checks
    +rs : List<&2, Engine.DocOutcome> <- Engine.process_paths_par(fix_list(), 1048576)
    Unit <- report("io-explicit-order",
      Engine.doc_outcome_list_eq(rs, Engine.oks_of_outputs(Engine.batch_process_seq(fix_inputs(fix_list())))))
    rs2 : List<&2, Engine.DocOutcome> <- Engine.process_paths_par(fix_scrambled(), 1048576)
    Unit <- report("io-scrambled-order",
      Engine.doc_outcome_list_eq(rs2, Engine.oks_of_outputs(Engine.batch_process_seq(fix_inputs(fix_scrambled())))))
    m : Maybe<&2, List<&2, String>> <- Engine.find_markdown_paths(fix_dir())
    Unit <- report("io-find-paths", maybe_paths_eq(m, fix_list()))
    md : Maybe<&2, List<&2, Engine.DocOutcome>> <- Engine.process_dir_par(fix_dir(), 1048576)
    Unit <- report("io-dir-eq-explicit", maybe_outcomes_eq(md, rs))
    rs3 : List<&2, Engine.DocOutcome> <- Engine.process_paths_par(
      {[fix_a(), fix_missing(), fix_c()] : List<&2, String>}, 1048576)
    Unit <- report("io-error-slot", error_slot_ok(rs3))
    rs4 : List<&2, Engine.DocOutcome> <- Engine.process_paths_par({[fix_a()] : List<&2, String>}, 10)
    Unit <- report("io-too-large", too_large_ok(rs4))
    # cleanup (silent)
    c2 : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/rm", ["-rf", fix_dir()], "", 1024, 5000)
    IO.print("batch-smoke-done")

#|PASS pure-order
#|PASS par-eq-seq
#|PASS render-par-eq-seq
#|PASS tree-eq-pairwise
#|PASS tree-fuel-fallback
#|PASS graph-order
#|PASS graph-par-eq-seq
#|PASS io-explicit-order
#|PASS io-scrambled-order
#|PASS io-find-paths
#|PASS io-dir-eq-explicit
#|PASS io-error-slot
#|PASS io-too-large
#|batch-smoke-done
