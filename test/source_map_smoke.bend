import Base
import ../src/ast.bend as Ast
import ../src/source_map.bend as SourceMap

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      U32.show(start) ++ "-" ++ U32.show(end)

def ifs(-A: Type, z: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match z:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def expect_equal(+name: String, +expected: String, +actual: String) -> IO(Unit):
  ifs(IO(Unit), String.eq(expected, actual),
    u => IO.print("PASS " ++ name),
    u => IO.die(Unit, 1, "FAIL " ++ name ++ "\nexpected: " ++ expected ++ "\nactual:   " ++ actual))

def main() -> IO(Unit):
  do IO<Unit>:
    +crlf : String = "[x]: target.md\r\n\r\n[use][x]\r\n"
    +crlfmap : SourceMap.SourceMap = SourceMap.source_map_from_original(crlf)
    Unit <- expect_equal("crlf-normalized-use-start",
      "18", U32.show(SourceMap.source_map_original_offset(crlfmap, 16)))
    Unit <- expect_equal("crlf-normalized-use-span",
      "18-26", show_span(SourceMap.source_map_original_span(crlfmap, Ast.Span{16, 24})))
    Unit <- expect_equal("crlf-reference-destination-span",
      "5-14", show_span(SourceMap.source_map_original_span(crlfmap, Ast.Span{5, 14})))
    +lfmap : SourceMap.SourceMap = SourceMap.source_map_from_original("alpha\nbeta")
    Unit <- expect_equal("lf-offset-identity",
      "8", U32.show(SourceMap.source_map_original_offset(lfmap, 8)))
    IO.print("source map smoke: all checks passed")
