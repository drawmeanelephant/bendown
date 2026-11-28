import Base
import ../src/ast.bend as Ast
import ../src/parser/markdown.bend as Markdown

# Deterministic structural inspector.  It is deliberately small and total:
# every recursion is over a constructor-owned sublist or the tail of the same
# list.  Strings are escaped so every fixture occupies exactly one output line.
def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{'\\', t}:
      "\\\\" ++ esc(t)
    case SCon{'\n', t}:
      "\\n" ++ esc(t)
    case SCon{'"', t}:
      "\\\"" ++ esc(t)
    case SCon{'\t', t}:
      "\\t" ++ esc(t)
    case SCon{h, t}:
      SCon{h, esc(t)}

def q(s: String) -> String:
  "\"" ++ esc(s) ++ "\""

def show_span(sp: Ast.Span) -> String:
  match sp:
    case Ast.Span{start, end}:
      "@" ++ U32.show(start) ++ "-" ++ U32.show(end)

def show_maybe_string(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "None"
    case Some{x}:
      "Some(" ++ q(x) ++ ")"

def show_inlines(xs: List<&2, Ast.Inline>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.IText{text, span} <> rest:
      "T" ++ q(text) ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ICode{text, span} <> rest:
      "C" ++ q(text) ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IEmph{children, span} <> rest:
      "E[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IStrong{children, span} <> rest:
      "S[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ILink{children, href, title, span, destination} <> rest:
      "L[" ++ show_inlines(children) ++ "](" ++ q(href) ++ "," ++
        show_maybe_string(title) ++ ")" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IImage{src, alt, title, span, destination} <> rest:
      "Img(" ++ q(src) ++ "," ++ q(alt) ++ "," ++ show_maybe_string(title) ++ ")" ++
        show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IAutolink{href, label, span, destination} <> rest:
      "A(" ++ q(href) ++ "," ++ q(label) ++ ")" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ISoftBreak{span} <> rest:
      "Soft" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IHardBreak{span} <> rest:
      "Hard" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case x <> rest:
      "I?;" ++ show_inlines(rest)

def show_list_items(xs: List<&2, Ast.ListItem>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.ListItem{Ast.BParagraph{children, attrs, span} <> bs, ispan} <> rest:
      "Item(P[" ++ show_inlines(children) ++ "]);" ++ show_list_items(rest)
    case Ast.ListItem{blocks, ispan} <> rest:
      "Item(?);" ++ show_list_items(rest)

def show_blocks(xs: List<&2, Ast.Block>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.BParagraph{children, attrs, span} <> rest:
      "P[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BHeading{level, children, attrs, span} <> rest:
      "H" ++ U32.show(level) ++ "[" ++ show_inlines(children) ++ "]" ++
        show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BThematicBreak{span} <> rest:
      "HR" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BCodeBlock{text, info, attrs, span} <> rest:
      "Code(" ++ show_maybe_string(info) ++ ")" ++ q(text) ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BBlockQuote{blocks, attrs, cite, span} <> rest:
      "Q{" ++ show_blocks(blocks) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BList{ordered, start, tight, items, span} <> rest:
      "List(" ++ Bool.show(ordered) ++ "," ++ U32.show(start) ++ "," ++ Bool.show(tight) ++
        "){" ++ show_list_items(items) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case x <> rest:
      "B?;" ++ show_blocks(rest)

def inspect_document(doc: Ast.Document) -> String:
  match doc:
    case Ast.Document{blocks}:
      "Doc{" ++ show_blocks(blocks) ++ "}"

def inspect_maybe(m: Maybe<&2, Ast.Document>) -> String:
  match m:
    case None{}:
      "None"
    case Some{doc}:
      "Some(" ++ inspect_document(doc) ++ ")"

def print_case(name: String, input: String) -> IO(Unit):
  IO.print(name ++ "=" ++ inspect_document(Markdown.parse_markdown(input)))

def print_bounded(name: String, input: String, max: Nat) -> IO(Unit):
  IO.print(name ++ "=" ++ inspect_maybe(Markdown.parse_markdown_bounded(input, max)))

def main() -> IO(Unit):
  do IO<Unit>:
    print_case("empty", "")
    print_case("paragraph-crlf", "alpha\r\nbeta\rgamma")
    print_case("headings", "# Alpha ###\n\nBeta\n====\n\nGamma\n---\n")
    print_case("thematic", "***\n\n- - -\n")
    print_case("fence", "```zig\nconst x = 1;\n```\nafter")
    print_case("indented", "para\n\n    code <x>\n    second\nafter")
    print_case("quote", "> # Quote\n> text *em*\n> \n> second\noutside")
    print_case("lists", "- one\n- two with `code`\n\n1. first\n2. second\n")
    print_case("inline", "Text `code` and *em* and **strong** and [link](https://e.test \"Title\") plus ![alt](img.png) and <https://example.com>.\n")
    print_case("malformed", "*open [broken](x and `code\n")
    print_case("unicode", "é *x*\n")
    print_case("edge-headings", "#\n#5 bolt\n###   \n")
    print_case("edge-fences", "~~~info\nx\n~~~~\n\n```bad`info\nnot fence\n")
    print_case("nested-emphasis", "*outer **inner** outer*\n")
    print_case("emphasis-whitespace", "x * open * and a*b*c\n")
    print_case("email", "<user@example.com>\n")
    print_case("nested-quote", "> > nested\n")
    print_case("ordered-start", "3. three\n4. four\n")
    print_case("list-continuation", "- one\n  continued\n- two\n")
    print_bounded("bound-empty-zero", "", 0n)
    print_bounded("bound-nonempty-zero", "x", 0n)
    print_bounded("bound-ascii-fit", "abc", 3n)
    print_bounded("bound-ascii-small", "abc", 2n)
    print_bounded("bound-unicode-fit", "é", 2n)
    print_bounded("bound-unicode-small", "é", 1n)

#|empty=Doc{}
#|paragraph-crlf=Doc{P[T"alpha"@0-5;Soft@5-6;T"beta"@6-10;Soft@10-11;T"gamma"@11-16;]@0-16;}
#|headings=Doc{H1[T"Alpha"@0-5;]@0-11;H1[T"Beta"@13-17;]@13-22;H2[T"Gamma"@24-29;]@24-33;}
#|thematic=Doc{HR@0-3;HR@5-10;}
#|fence=Doc{Code(Some("zig"))"const x = 1;\n"@0-23;P[T"after"@24-29;]@24-29;}
#|indented=Doc{P[T"para"@0-4;]@0-4;Code(None)"code <x>\nsecond\n"@6-29;P[T"after"@30-35;]@30-35;}
#|quote=Doc{Q{H1[T"Quote"@2-7;]@2-9;P[T"text "@12-17;E[T"em"@18-20;]@17-21;]@12-21;P[T"second"@27-33;Soft@33-34;T"outside"@34-41;]@27-41;}@0-41;}
#|lists=Doc{List(False,1,True){Item(P[T"one"@2-5;]);Item(P[T"two with "@8-17;C"code"@17-23;]);}@0-23;List(True,1,True){Item(P[T"first"@28-33;]);Item(P[T"second"@37-43;]);}@25-43;}
#|inline=Doc{P[T"Text "@0-5;C"code"@5-11;T" and "@11-16;E[T"em"@17-19;]@16-20;T" and "@20-25;S[T"strong"@27-33;]@25-35;T" and "@35-40;L[T"link"@41-45;]("https://e.test",Some("Title"))@40-70;T" plus "@70-76;Img("img.png","alt",None)@76-91;T" and "@91-96;A("https://example.com","https://example.com")@96-117;T"."@117-118;]@0-118;}
#|malformed=Doc{P[T"*"@0-1;T"open "@1-6;T"["@6-7;T"broken](x and "@7-21;T"`"@21-22;T"code"@22-26;]@0-26;}
#|unicode=Doc{P[T"é "@0-3;E[T"x"@4-5;]@3-6;]@0-6;}
#|edge-headings=Doc{H1[]@0-1;P[T"#5 bolt"@2-9;]@2-9;H3[]@10-16;}
#|edge-fences=Doc{Code(Some("info"))"x\n"@0-14;P[T"```"@16-19;T"bad"@19-22;T"`"@22-23;T"info"@23-27;Soft@27-28;T"not fence"@28-37;]@16-37;}
#|nested-emphasis=Doc{P[E[T"outer "@1-7;S[T"inner"@9-14;]@7-16;T" outer"@16-22;]@0-23;]@0-23;}
#|emphasis-whitespace=Doc{P[T"x "@0-2;T"*"@2-3;T" open "@3-9;T"*"@9-10;T" and a"@10-16;E[T"b"@17-18;]@16-19;T"c"@19-20;]@0-20;}
#|email=Doc{P[A("mailto:user@example.com","user@example.com")@0-18;]@0-18;}
#|nested-quote=Doc{Q{Q{P[T"nested"@4-10;]@4-10;}@2-10;}@0-10;}
#|ordered-start=Doc{List(True,3,True){Item(P[T"three"@3-8;]);Item(P[T"four"@12-16;]);}@0-16;}
#|list-continuation=Doc{List(False,1,True){Item(P[T"one"@2-5;Soft@5-6;T"continued"@6-15;]);Item(P[T"two"@20-23;]);}@0-23;}
#|bound-empty-zero=Some(Doc{})
#|bound-nonempty-zero=None
#|bound-ascii-fit=Some(Doc{P[T"abc"@0-3;]@0-3;})
#|bound-ascii-small=None
#|bound-unicode-fit=Some(Doc{P[T"é"@0-2;]@0-2;})
#|bound-unicode-small=None
