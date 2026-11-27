import Base
import ../ast.bend as Ast
import ../text.bend as Text
import ../parser/markdown.bend as Markdown
import ../parser/textile.bend as Textile
import ../render/html.bend as Html
import ../cooklang/model.bend as CookModel
import ../cooklang/parser.bend as CookParser
import ../cooklang/html.bend as CookHtml
import ./batch.bend as Batch

# Parallel batch-processing engine, second milestone.
#
# Three layers, in order:
#
#   1. A pure ordered batch core.  `par_tree_map` is a structural
#      divide-and-conquer fork-join map: the input list is halved, the halves
#      are mapped in parallel, and the results are appended in order.  The
#      Nat fuel makes the recursion structurally obvious to the termination
#      checker; if the fuel ever ran out the fallback is the sequential map,
#      so the function is correct for every fuel value.
#   2. A pure link-graph layer over the model in `batch.bend`: link targets
#      are extracted from parsed documents in document order, and per-document
#      graphs are concatenated in batch order, sequentially or as a tree.
#   3. An IO adapter layer: read an explicit list of files in concurrent
#      reader fibers (`IO.fork`/`IO.join`), join strictly in input order, and
#      run the per-document transformation through the pure parallel map, so
#      the batch result is deterministic and the compute is multi-core.  A
#      clearly separated host adapter (`find_markdown_paths`) discovers `.md`
#      files by running the platform `/usr/bin/find` binary through
#      `Process.run` and sorting the result in Bend, since raw `find` output
#      order is filesystem-dependent.
#
# The pure sections use no IO, no `@unsafe`, no foreign effects and no mutual
# recursion: every recursion is structural or fueled, and computed Booleans
# are branched on through the one-shot-continuation `ifs` eliminator.

# Boolean eliminator with one-shot closure continuations (the same isolation
# pattern the parser uses: Bend cannot match on a computed local value).
def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

# ---------------------------------------------------------------------------
# Pure core: structural fork-join map
# ---------------------------------------------------------------------------

# The worker.  `fuel` starts at the input length; every level spends one fuel
# and halves the list, so the fuel is always sufficient -- but the design never
# relies on that, because an empty fuel falls back to the correct sequential
# map.  The split and the append both preserve order, so the result list is in
# exactly the input order.
def par_tree_go(~A: Data, ~B: Data, ~f: A -> B, +fuel: Nat, xs: List<&2, A>) -> List<&2, B>:
  match fuel:
    case 0n:
      Batch.seq_map(~A, ~B, ~f, xs)
    case 1n++p:
      match xs:
        case Nil{}:
          Nil{}
        case x <> Nil{}:
          f(x) <> Nil{}
        case x <> y <> rest:
          +full = {x <> y <> rest : List<&2, A>}
          +len = List.length(&2, A, full)
          +half = Nat.div(len, 2n)
          left = List.take(&2, A, full, half)
          right = List.drop(&2, A, full, half)
          a b = par_tree_go(~A, ~B, ~f, p, left) par_tree_go(~A, ~B, ~f, p, right)
          List.append(&2, B, a, b)

# Balanced parallel map.  Unlike the pairwise `Batch.par_map`, which forks one
# pair at a time along a linear chain, this forks a balanced binary tree, so
# both branches of every parallel call are the same size.  Order is preserved
# exactly; `batch_smoke.bend` checks equivalence with the sequential map on
# concrete batches.  Note: the halving itself is sequential list traversal,
# so this demonstrates structure and determinism, not a performance claim.
def par_tree_map(~A: Data, ~B: Data, ~f: A -> B, +xs: List<&2, A>) -> List<&2, B>:
  par_tree_go(~A, ~B, ~f, List.length(&2, A, xs), xs)

# ---------------------------------------------------------------------------
# Pure core: list utilities
# ---------------------------------------------------------------------------

def str_list_eq(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case +x <> xt +y <> yt:
      ifs(Bool, String.eq(x, y),
        u => str_list_eq(xt, yt),
        u => False{})
    case a b:
      False{}

# Insertion sort over Strings.  Small and structural; clarity over speed.
def insert_sorted(+x: String, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      x <> Nil{}
    case +h <> +t:
      ifs(List<&2, String>, String.is_le(x, h),
        u => x <> h <> t,
        u => h <> insert_sorted(x, t))

def sort_strs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      insert_sorted(h, sort_strs(t))

# Drops empty strings (used to drop the trailing empty line that a final
# newline produces in host command output).
def nonempty_strs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      ifs(List<&2, String>, String.is_empty(h),
        u => nonempty_strs(t),
        u => h <> nonempty_strs(t))

# ---------------------------------------------------------------------------
# Pure core: the batch transformation
# ---------------------------------------------------------------------------

# One input document: its batch identity (a path or a label) and its markdown
# source.  A named record because primitive pairs are affine, not Data.
type DocInput is Data:
  DocInput{name: String, source: String}

# One output document: the same identity, the rendered HTML and the link
# targets extracted from the parsed document, in document order.
type DocOutput is Data:
  DocOutput{name: String, html: String, targets: List<&2, String>}

# The per-document batch transformation: markdown source in, HTML plus the
# ordered link targets out.  Entirely pure and total.
def render_one(source: String) -> String:
  Html.render_document(Markdown.parse_markdown(source))

# Ordered batch render of raw sources, parallel and sequential.
def batch_render_par(xs: List<&2, String>) -> List<&2, String>:
  par_tree_map(~String, ~String, ~render_one, xs)

def batch_render_seq(xs: List<&2, String>) -> List<&2, String>:
  Batch.seq_map(~String, ~String, ~render_one, xs)

# ---------------------------------------------------------------------------
# Pure core: link target extraction
# ---------------------------------------------------------------------------

# Explicit work queue for extraction.  Bend does not admit mutual recursion,
# so blocks, items, rows, cells and inlines are all handled inside one fueled
# dispatcher, the same pattern the HTML renderer uses.  The fuel is generous;
# exhaustion conservatively yields no targets for the unvisited remainder.
type LinkWork is Data:
  LwInline{one: Ast.Inline}
  LwInlines{xs: List<&2, Ast.Inline>}
  LwBlock{one: Ast.Block}
  LwBlocks{xs: List<&2, Ast.Block>}
  LwItems{xs: List<&2, Ast.ListItem>}
  LwRows{xs: List<&2, Ast.TableRow>}
  LwCells{xs: List<&2, Ast.TableCell>}

def link_cat(xs: List<&2, String>, ys: List<&2, String>) -> List<&2, String>:
  List.append(&2, String, xs, ys)

def link_targets_work(+fuel: Nat, work: LinkWork) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n++f:
      match work:
        case LwInlines{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case h <> t:
              link_cat(link_targets_work(f, LwInline{h}), link_targets_work(f, LwInlines{t}))
        case LwInline{one}:
          match one:
            case Ast.ILink{children, href, title, span}:
              href <> link_targets_work(f, LwInlines{children})
            case Ast.IImage{src, alt, title, span}:
              src <> Nil{}
            case Ast.IAutolink{href, label, span}:
              href <> Nil{}
            case Ast.IEmph{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.IStrong{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.IBold{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.IItalic{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.IDeleted{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.IInserted{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.ISuperscript{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.ISubscript{children, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.ISpan{children, attrs, span}:
              link_targets_work(f, LwInlines{children})
            case u:
              Nil{}
        case LwBlocks{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case h <> t:
              link_cat(link_targets_work(f, LwBlock{h}), link_targets_work(f, LwBlocks{t}))
        case LwBlock{one}:
          match one:
            case Ast.BParagraph{children, attrs, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.BHeading{level, children, attrs, span}:
              link_targets_work(f, LwInlines{children})
            case Ast.BBlockQuote{blocks, attrs, cite, span}:
              link_targets_work(f, LwBlocks{blocks})
            case Ast.BList{ordered, start, tight, items, span}:
              link_targets_work(f, LwItems{items})
            case Ast.BTable{alignments, rows, span}:
              link_targets_work(f, LwRows{rows})
            case u:
              Nil{}
        case LwItems{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.ListItem{blocks, ispan} <> t:
              link_cat(link_targets_work(f, LwBlocks{blocks}), link_targets_work(f, LwItems{t}))
        case LwRows{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.TableRow{cells, attrs, span} <> t:
              link_cat(link_targets_work(f, LwCells{cells}), link_targets_work(f, LwRows{t}))
        case LwCells{xs}:
          match xs:
            case Nil{}:
              Nil{}
            case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span} <> t:
              link_cat(link_targets_work(f, LwInlines{children}), link_targets_work(f, LwCells{t}))

def link_work_fuel() -> Nat:
  4294967295n

# Every link target of a document, in document order.  Link hrefs, autolink
# hrefs and image sources all count as outbound references.  A link emits its
# own href before the targets of its children (pre-order); the children of a
# markdown link are text in practice, so this rarely matters.
def document_link_targets(doc: Ast.Document) -> List<&2, String>:
  match doc:
    case Ast.Document{blocks}:
      link_targets_work(link_work_fuel(), LwBlocks{blocks})

# Cooklang recipe references are outbound references for the batch graph.
def cook_part_targets(part: CookModel.CookPart) -> List<&2, String>:
  match part:
    case CookModel.CookIngredient{ingredient, span}:
      match ingredient:
        case CookModel.Ingredient{+name, quantity, units, preparation, is_recipe_reference, span}:
          match is_recipe_reference:
            case True{}:
              name <> Nil{}
            case False{}:
              Nil{}
    case CookModel.CookText{text, span}:
      Nil{}
    case CookModel.CookCookware{cookware, span}:
      Nil{}
    case CookModel.CookTimer{timer, span}:
      Nil{}
    case CookModel.CookLineBreak{span}:
      Nil{}

def cook_parts_targets(parts: List<&2, CookModel.CookPart>) -> List<&2, String>:
  match parts:
    case Nil{}:
      Nil{}
    case h <> t:
      link_cat(cook_part_targets(h), cook_parts_targets(t))

def cook_blocks_targets(blocks: List<&2, CookModel.CookBlock>) -> List<&2, String>:
  match blocks:
    case Nil{}:
      Nil{}
    case CookModel.CookStep{parts, span} <> t:
      link_cat(cook_parts_targets(parts), cook_blocks_targets(t))
    case CookModel.CookNote{text, span} <> t:
      cook_blocks_targets(t)
    case CookModel.CookSection{name, nested, span} <> t:
      link_cat(cook_blocks_targets(nested), cook_blocks_targets(t))

def cook_document_targets(recipe: CookModel.Recipe) -> List<&2, String>:
  match recipe:
    case CookModel.Recipe{frontmatter, blocks}:
      cook_blocks_targets(blocks)

type DocFormat is Data:
  FmtMarkdown{}
  FmtTextile{}
  FmtCook{}
  FmtUnknown{}

def format_of_path(+path: String) -> DocFormat:
  ifs(DocFormat, String.ends_with(path, ".md"),
    u => FmtMarkdown{},
    u => ifs(DocFormat, String.ends_with(path, ".textile"),
      v => FmtTextile{},
      v => ifs(DocFormat, String.ends_with(path, ".cook"),
        w => FmtCook{},
        w => FmtUnknown{})))

def process_markdown_doc(+name: String, +source: String) -> DocOutput:
  +doc = Markdown.parse_markdown(source)
  DocOutput{name, Html.render_document(doc), document_link_targets(doc)}

def process_textile_doc(+name: String, +source: String) -> DocOutput:
  +doc = Textile.parse_textile(source)
  DocOutput{name, Html.render_document(doc), document_link_targets(doc)}

def process_cook_doc(+name: String, +source: String) -> DocOutput:
  +recipe = CookParser.parse_cooklang(source)
  DocOutput{name, CookHtml.render_recipe(recipe), cook_document_targets(recipe)}

def process_format_doc(+name: String, +source: String, format: DocFormat) -> DocOutput:
  match format:
    case FmtMarkdown{}:
      process_markdown_doc(name, source)
    case FmtTextile{}:
      process_textile_doc(name, source)
    case FmtCook{}:
      process_cook_doc(name, source)
    case FmtUnknown{}:
      DocOutput{name, "", []}

# The full per-document transformation used by the batch pipeline.  The format
# is selected by file extension: `.md`, `.textile`, and `.cook` are supported;
# unknown extensions produce an empty document output rather than aborting the
# batch (discovery filters them out, but explicit path lists can contain them).
def process_doc(input: DocInput) -> DocOutput:
  match input:
    case DocInput{+name, +source}:
      process_format_doc(name, source, format_of_path(name))

# Ordered batch transformation, parallel and sequential reference.
def batch_process_par(xs: List<&2, DocInput>) -> List<&2, DocOutput>:
  par_tree_map(~DocInput, ~DocOutput, ~process_doc, xs)

def batch_process_seq(xs: List<&2, DocInput>) -> List<&2, DocOutput>:
  Batch.seq_map(~DocInput, ~DocOutput, ~process_doc, xs)

# ---------------------------------------------------------------------------
# Pure core: deterministic ordered link-graph concatenation
# ---------------------------------------------------------------------------

def edges_of_targets(+source: String, ts: List<&2, String>) -> List<&2, Batch.LinkEdge>:
  match ts:
    case Nil{}:
      Nil{}
    case +h <> t:
      Batch.LinkEdge{source, h} <> edges_of_targets(source, t)

def graph_of_output(o: DocOutput) -> Batch.LinkGraph:
  match o:
    case DocOutput{name, html, targets}:
      Batch.LinkGraph{edges_of_targets(name, targets)}

# Ordered concatenation of per-document graphs, sequential reference: the
# edges of document 1 come before those of document 2, and so on.
def batch_graph_seq(outputs: List<&2, DocOutput>) -> Batch.LinkGraph:
  Batch.graph_concat(Batch.seq_map(~DocOutput, ~Batch.LinkGraph, ~graph_of_output, outputs))

# Balanced tree concatenation.  `graph_append` concatenates edge lists in
# order and the halves are contiguous, so the tree concatenation is the same
# ordered concatenation; the smoke test checks it against the sequential one.
def graph_tree_go(+fuel: Nat, xs: List<&2, Batch.LinkGraph>) -> Batch.LinkGraph:
  match fuel:
    case 0n:
      Batch.graph_concat(xs)
    case 1n++p:
      match xs:
        case Nil{}:
          Batch.graph_empty()
        case x <> Nil{}:
          x
        case x <> y <> rest:
          +full = {x <> y <> rest : List<&2, Batch.LinkGraph>}
          +len = List.length(&2, Batch.LinkGraph, full)
          +half = Nat.div(len, 2n)
          left = List.take(&2, Batch.LinkGraph, full, half)
          right = List.drop(&2, Batch.LinkGraph, full, half)
          a b = graph_tree_go(p, left) graph_tree_go(p, right)
          Batch.graph_append(a, b)

def batch_graph_par(outputs: List<&2, DocOutput>) -> Batch.LinkGraph:
  +gs = Batch.seq_map(~DocOutput, ~Batch.LinkGraph, ~graph_of_output, outputs)
  graph_tree_go(List.length(&2, Batch.LinkGraph, gs), gs)

# Equality helpers used by the smoke checks.
def edge_eq(a: Batch.LinkEdge, b: Batch.LinkEdge) -> Bool:
  match a b:
    case Batch.LinkEdge{+as, +at} Batch.LinkEdge{+bs, +bt}:
      Bool.and(String.eq(as, bs), String.eq(at, bt))

def edge_list_eq(xs: List<&2, Batch.LinkEdge>, ys: List<&2, Batch.LinkEdge>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case +x <> xt +y <> yt:
      ifs(Bool, edge_eq(x, y),
        u => edge_list_eq(xt, yt),
        u => False{})
    case a b:
      False{}

def graph_eq(a: Batch.LinkGraph, b: Batch.LinkGraph) -> Bool:
  match a b:
    case Batch.LinkGraph{xe} Batch.LinkGraph{ye}:
      edge_list_eq(xe, ye)

def doc_output_eq(a: DocOutput, b: DocOutput) -> Bool:
  match a b:
    case DocOutput{+an, +ah, +at} DocOutput{+bn, +bh, +bt}:
      Bool.and(String.eq(an, bn), Bool.and(String.eq(ah, bh), str_list_eq(at, bt)))

def doc_output_list_eq(xs: List<&2, DocOutput>, ys: List<&2, DocOutput>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case +x <> xt +y <> yt:
      ifs(Bool, doc_output_eq(x, y),
        u => doc_output_list_eq(xt, yt),
        u => False{})
    case a b:
      False{}

# ---------------------------------------------------------------------------
# IO adapter: processing an explicit list of files
# ---------------------------------------------------------------------------

# The outcome of processing one path.  A missing or unreadable file becomes a
# DocErr in its own slot; it never aborts the rest of the batch.
type DocOutcome is Data:
  DocOk{name: String, html: String, targets: List<&2, String>}
  DocErr{name: String, message: String}

# The result of reading one file: either its text or the host error message.
# "InputTooLarge" is the engine's own message when the file exceeds the byte
# ceiling; the ceiling is enforced at read time, before parsing.
type ReadOutcome is Data:
  ReadOk{text: String}
  ReadErr{message: String}

# Lifts a pure batch output into the successful-outcome shape, so the smoke
# test can compare the IO pipeline against the pure pipeline directly.
def ok_of_output(o: DocOutput) -> DocOutcome:
  match o:
    case DocOutput{+name, +html, +targets}:
      DocOk{name, html, targets}

def oks_of_outputs(xs: List<&2, DocOutput>) -> List<&2, DocOutcome>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      ok_of_output(h) <> oks_of_outputs(t)

def read_gate(+text: String, too_big: Bool) -> ReadOutcome:
  match too_big:
    case True{}:
      ReadErr{"InputTooLarge"}
    case False{}:
      ReadOk{text}

def read_finish(file: File, +max: U32, result: Result<&1, &1, (U32 & String), String>) ->
  IO(ReadOutcome):
  match result:
    case Done{+value}:
      do IO<ReadOutcome>:
        Unit <- File.close(file)
        return read_gate(value, Nat.is_lt(U32.to_nat(max), Text.utf8_length(value)))
    case Fail{error}:
      (code, message) = error
      do IO<ReadOutcome>:
        Unit <- File.close(file)
        return ReadErr{message}

def read_deliver(p: File & Result<&1, &1, (U32 & String), String>, +max: U32) ->
  IO(ReadOutcome):
  (file, result) = p
  read_finish(file, max, result)

def read_after_open(r: Result<&1, &1, (U32 & String), File>, +max: U32) -> IO(ReadOutcome):
  match r:
    case Done{file}:
      do IO<ReadOutcome>:
        p : File & Result<&1, &1, (U32 & String), String> <- File.read(file, U32.add(max, 1))
        read_deliver(p, max)
    case Fail{error}:
      (code, message) = error
      IO.pure(ReadOutcome, ReadErr{message})

# Reads one file without ever dying: every failure is a value.  Reads at most
# max+1 bytes so a file strictly over the byte ceiling is always detected.
def read_file_outcome(+path: String, +max: U32) -> IO(ReadOutcome):
  do IO<ReadOutcome>:
    r : Result<&1, &1, (U32 & String), File> <- File.open(path, "r")
    read_after_open(r, max)

# The maximum U32 cannot be a ceiling: max+1 would wrap to zero and the
# oversize detection would silently accept an empty truncation.  Mirrors the
# gate in src/cli_io.bend, as a value rather than a fatal error.
def read_file_outcome_gate(+path: String, +max: U32, valid: Bool) -> IO(ReadOutcome):
  match valid:
    case True{}:
      read_file_outcome(path, max)
    case False{}:
      IO.pure(ReadOutcome, ReadErr{"InvalidInputLimit"})

def read_file_capped(+path: String, +max: U32) -> IO(ReadOutcome):
  read_file_outcome_gate(path, max, U32.is_ne(max, 4294967295))

# Pure: fold a read outcome into a document outcome.  This is where the
# parse, render and extraction for one file actually happen -- in the batch
# pipeline below, inside the pure parallel map of the joining fiber.
def outcome_of_read(+path: String, r: ReadOutcome) -> DocOutcome:
  match r:
    case ReadOk{text}:
      ok_of_output(process_doc(DocInput{path, text}))
    case ReadErr{+message}:
      DocErr{path, message}

# Reads and processes one path in the ambient fiber.  Never dies: per-file
# failures are values.
def process_path(+path: String, +max: U32) -> IO(DocOutcome):
  do IO<DocOutcome>:
    r : ReadOutcome <- read_file_capped(path, max)
    return outcome_of_read(path, r)

# One joined read: the path beside its outcome.  A named record because
# primitive pairs are affine, not Data.
type ReadSlot is Data:
  ReadSlot{path: String, outcome: ReadOutcome}

# Pure per-slot resolution: parse, render and extract for the successful
# reads, wrap the failures.  This is the element function the batch's pure
# parallel map is instantiated with.
def resolve_slot(slot: ReadSlot) -> DocOutcome:
  match slot:
    case ReadSlot{path, outcome}:
      outcome_of_read(path, outcome)

# Forks one reader fiber per path.  The fibers only read; they interleave on
# the event loop, so slow or many inputs overlap rather than serialize.
def fork_readers(xs: List<&2, String>, +max: U32) -> IO(List<&2, Chan(ReadOutcome)>):
  match xs:
    case Nil{}:
      IO.pure(List<&2, Chan(ReadOutcome)>, Nil{})
    case +h <> t:
      do IO<List<&2, Chan(ReadOutcome)>>:
        c : Chan(ReadOutcome) <- IO.fork(ReadOutcome, read_file_capped(h, max))
        rest : List<&2, Chan(ReadOutcome)> <- fork_readers(t, max)
        return c <> rest

# Joins the reader fibers strictly in input order and pairs each outcome with
# its path: whichever fiber finishes first, slot i always belongs to path i.
def join_readers(xs: List<&2, String>, cs: List<&2, Chan(ReadOutcome)>) ->
  IO(List<&2, ReadSlot>):
  match xs cs:
    case Nil{} Nil{}:
      IO.pure(List<&2, ReadSlot>, Nil{})
    case +p <> pt c <> ct:
      do IO<List<&2, ReadSlot>>:
        r : ReadOutcome <- IO.join(ReadOutcome, c)
        rest : List<&2, ReadSlot> <- join_readers(pt, ct)
        return ReadSlot{p, r} <> rest
    case a b:
      # unreachable: fork_readers conses exactly one channel per path
      IO.pure(List<&2, ReadSlot>, Nil{})

# The explicit-list batch adapter, in two stages:
#
#   1. IO stage: read every path in its own fiber, joined in input order.
#      Bend computations interleave on one event loop, so this stage is
#      concurrent but not multi-core -- which is fine, it is IO-bound.
#   2. Pure stage: the per-document parse/render/extract transformation runs
#      through `par_tree_map`, whose balanced parallel calls are where the
#      batch's multi-core parallelism actually lives.
#
# The outcome list is in exactly the input order either way.
def process_paths_par(+xs: List<&2, String>, +max: U32) -> IO(List<&2, DocOutcome>):
  do IO<List<&2, DocOutcome>>:
    chans : List<&2, Chan(ReadOutcome)> <- fork_readers(xs, max)
    slots : List<&2, ReadSlot> <- join_readers(xs, chans)
    return par_tree_map(~ReadSlot, ~DocOutcome, ~resolve_slot, slots)

# Sequential-compute reference over the same concurrent read stage.  This is
# used by the batch CLI's `--seq` mode so par/seq timing differences measure
# the document transformation rather than file discovery or input IO.
def process_paths_seq(+xs: List<&2, String>, +max: U32) -> IO(List<&2, DocOutcome>):
  do IO<List<&2, DocOutcome>>:
    chans : List<&2, Chan(ReadOutcome)> <- fork_readers(xs, max)
    slots : List<&2, ReadSlot> <- join_readers(xs, chans)
    return Batch.seq_map(~ReadSlot, ~DocOutcome, ~resolve_slot, slots)

# Equality helpers for outcomes, used by the smoke checks.
def doc_outcome_eq(a: DocOutcome, b: DocOutcome) -> Bool:
  match a b:
    case DocOk{+an, +ah, +at} DocOk{+bn, +bh, +bt}:
      Bool.and(String.eq(an, bn), Bool.and(String.eq(ah, bh), str_list_eq(at, bt)))
    case DocErr{+an, +am} DocErr{+bn, +bm}:
      Bool.and(String.eq(an, bn), String.eq(am, bm))
    case x y:
      False{}

def doc_outcome_list_eq(xs: List<&2, DocOutcome>, ys: List<&2, DocOutcome>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case +x <> xt +y <> yt:
      ifs(Bool, doc_outcome_eq(x, y),
        u => doc_outcome_list_eq(xt, yt),
        u => False{})
    case a b:
      False{}

# ---------------------------------------------------------------------------
# IO adapter: host directory traversal (clearly separated)
# ---------------------------------------------------------------------------
#
# Bend's Base has no directory-listing effect, so discovery shells out to the
# platform `find` binary through `Process.run` -- no shell, literal argv.
# This adapter is a host integration convenience, not a portable library
# guarantee: it assumes a POSIX `find` at /usr/bin/find (true on macOS and
# Linux), and it cannot represent filenames containing newlines, because find
# output is newline-delimited.  The raw output order is filesystem-dependent,
# so the paths are sorted in Bend before use; every downstream batch is then
# deterministic.

def format_supported(format: DocFormat) -> Bool:
  match format:
    case FmtMarkdown{}:
      True{}
    case FmtTextile{}:
      True{}
    case FmtCook{}:
      True{}
    case FmtUnknown{}:
      False{}

def supported_path(+path: String) -> Bool:
  format_supported(format_of_path(path))

def filter_supported(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      ifs(List<&2, String>, supported_path(h),
        u => h <> filter_supported(t),
        u => filter_supported(t))

def find_gate(+stdout: String, ok: Bool) -> IO(Maybe<&2, List<&2, String>>):
  match ok:
    case True{}:
      IO.pure(Maybe<&2, List<&2, String>>,
        Some{sort_strs(filter_supported(nonempty_strs(String.lines(stdout))))})
    case False{}:
      IO.pure(Maybe<&2, List<&2, String>>, None{})

def find_finish(r: Result<&1, &1, U32 & String, U32 & (String & String)>) ->
  IO(Maybe<&2, List<&2, String>>):
  match r:
    case Done{value}:
      (code, (stdout, stderr)) = value
      find_gate(stdout, U32.is_eq(code, 0))
    case Fail{error}:
      (code, message) = error
      IO.pure(Maybe<&2, List<&2, String>>, None{})

# Every regular `.md`, `.textile`, or `.cook` file under `dir`, recursively, sorted by
# Bend's String order (codepoint-wise, so byte-wise for ASCII paths).
# None{} when find itself fails or exits non-zero.
def find_markup_paths(+dir: String) -> IO(Maybe<&2, List<&2, String>>):
  do IO<Maybe<&2, List<&2, String>>>:
    r : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/usr/bin/find", [dir, "-type", "f"], "", 4194304, 30000)
    find_finish(r)

# Backwards-compatible name from the markdown-only first milestone.
def find_markdown_paths(+dir: String) -> IO(Maybe<&2, List<&2, String>>):
  find_markup_paths(dir)

def process_dir_go(m: Maybe<&2, List<&2, String>>, +max: U32) ->
  IO(Maybe<&2, List<&2, DocOutcome>>):
  match m:
    case None{}:
      IO.pure(Maybe<&2, List<&2, DocOutcome>>, None{})
    case Some{paths}:
      do IO<Maybe<&2, List<&2, DocOutcome>>>:
        rs : List<&2, DocOutcome> <- process_paths_par(paths, max)
        return Some{rs}

# Discovery plus processing: the sorted markup/recipe files under `dir`, as outcomes in
# sorted order.  None{} when discovery fails.
def process_dir_go_seq(m: Maybe<&2, List<&2, String>>, +max: U32) ->
  IO(Maybe<&2, List<&2, DocOutcome>>):
  match m:
    case None{}:
      IO.pure(Maybe<&2, List<&2, DocOutcome>>, None{})
    case Some{paths}:
      do IO<Maybe<&2, List<&2, DocOutcome>>>:
        rs : List<&2, DocOutcome> <- process_paths_seq(paths, max)
        return Some{rs}

def process_dir_par(+dir: String, +max: U32) -> IO(Maybe<&2, List<&2, DocOutcome>>):
  do IO<Maybe<&2, List<&2, DocOutcome>>>:
    m : Maybe<&2, List<&2, String>> <- find_markup_paths(dir)
    process_dir_go(m, max)

# Discovery plus sequential-compute processing, used as a baseline for
# measuring the parallel document transformation.
def process_dir_seq(+dir: String, +max: U32) -> IO(Maybe<&2, List<&2, DocOutcome>>):
  do IO<Maybe<&2, List<&2, DocOutcome>>>:
    m : Maybe<&2, List<&2, String>> <- find_markup_paths(dir)
    process_dir_go_seq(m, max)
