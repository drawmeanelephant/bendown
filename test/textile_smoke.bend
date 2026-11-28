import Base
import ../src/ast.bend as Ast
import ../src/parser/textile.bend as Textile

# Deterministic structural inspector.  Strings are escaped so each fixture
# occupies one output line.  The printer covers the shared AST rather than
# assuming Textile-specific constructors.
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

def show_attrs(xs: List<&2, Ast.Attr>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.Attr{key, value} <> rest:
      q(key) ++ "=" ++ q(value) ++ "," ++ show_attrs(rest)

def show_align(a: Ast.Alignment) -> String:
  match a:
    case Ast.AlignNone{}:
      "none"
    case Ast.AlignLeft{}:
      "left"
    case Ast.AlignCenter{}:
      "center"
    case Ast.AlignRight{}:
      "right"

def show_aligns(xs: List<&2, Ast.Alignment>) -> String:
  match xs:
    case Nil{}:
      ""
    case x <> rest:
      show_align(x) ++ "," ++ show_aligns(rest)

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
    case Ast.IBold{children, span} <> rest:
      "B[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IItalic{children, span} <> rest:
      "I[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IDeleted{children, span} <> rest:
      "D[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IInserted{children, span} <> rest:
      "Ins[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ISuperscript{children, span} <> rest:
      "Sup[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ISubscript{children, span} <> rest:
      "Sub[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ISpan{children, attrs, span} <> rest:
      "Span[" ++ show_inlines(children) ++ "]{" ++ show_attrs(attrs) ++ "}" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ILink{children, href, title, span, destination} <> rest:
      "L[" ++ show_inlines(children) ++ "](" ++ q(href) ++ "," ++
        show_maybe_string(title) ++ ")" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IImage{src, alt, title, span, destination} <> rest:
      "Img(" ++ q(src) ++ "," ++ q(alt) ++ "," ++ show_maybe_string(title) ++ ")" ++
        show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IAutolink{href, label, span, destination} <> rest:
      "A(" ++ q(href) ++ "," ++ q(label) ++ ")" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IRawHtml{text, span} <> rest:
      "Raw" ++ q(text) ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.ISoftBreak{span} <> rest:
      "Soft" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IHardBreak{span} <> rest:
      "Hard" ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case Ast.IFootnoteRef{number, span} <> rest:
      "Foot" ++ U32.show(number) ++ show_span(span) ++ ";" ++ show_inlines(rest)
    case x <> rest:
      "I?;" ++ show_inlines(rest)

# Bend checks definitions in file order, so list items use this intentionally
# shallow block printer rather than a mutually recursive reference back to
# show_blocks.  A nested list is still visible as a `List?` node with its item
# count; the top-level list cases below assert the exact nesting behavior.
def show_item_blocks(xs: List<&2, Ast.Block>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.BParagraph{children, attrs, span} <> rest:
      "P[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_item_blocks(rest)
    case Ast.BHeading{level, children, attrs, span} <> rest:
      "H" ++ U32.show(level) ++ "[" ++ show_inlines(children) ++ "]" ++ show_span(span) ++ ";" ++ show_item_blocks(rest)
    case Ast.BList{ordered, start, tight, items, span} <> rest:
      "List?(" ++ Bool.show(ordered) ++ "," ++ U32.show(start) ++ "," ++ Bool.show(tight) ++
        ",items=" ++ Nat.show(List.length(&2, Ast.ListItem, items)) ++ ")" ++ show_span(span) ++ ";" ++ show_item_blocks(rest)
    case x <> rest:
      "B?;" ++ show_item_blocks(rest)

def show_list_items(xs: List<&2, Ast.ListItem>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.ListItem{blocks, span} <> rest:
      "Item{" ++ show_item_blocks(blocks) ++ "}" ++ show_span(span) ++ ";" ++ show_list_items(rest)

def show_table_cells(xs: List<&2, Ast.TableCell>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span} <> rest:
      "Cell(" ++ Bool.show(header) ++ "," ++ show_align(align) ++ "," ++ U32.show(colspan) ++
        "," ++ U32.show(rowspan) ++ ")[" ++ show_inlines(children) ++ "]{" ++ show_attrs(attrs) ++ "}" ++
        show_span(span) ++ ";" ++ show_table_cells(rest)

def show_table_rows(xs: List<&2, Ast.TableRow>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.TableRow{cells, attrs, span} <> rest:
      "Row{" ++ show_table_cells(cells) ++ "}{" ++ show_attrs(attrs) ++ "}" ++ show_span(span) ++ ";" ++ show_table_rows(rest)

def show_blocks(xs: List<&2, Ast.Block>) -> String:
  match xs:
    case Nil{}:
      ""
    case Ast.BParagraph{children, attrs, span} <> rest:
      "P[" ++ show_inlines(children) ++ "]{" ++ show_attrs(attrs) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BHeading{level, children, attrs, span} <> rest:
      "H" ++ U32.show(level) ++ "[" ++ show_inlines(children) ++ "]{" ++ show_attrs(attrs) ++ "}" ++
        show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BThematicBreak{span} <> rest:
      "HR" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BCodeBlock{text, info, attrs, span} <> rest:
      "Code(" ++ show_maybe_string(info) ++ ")" ++ q(text) ++ "{" ++ show_attrs(attrs) ++ "}" ++
        show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BHtmlBlock{text, span} <> rest:
      "Html" ++ q(text) ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BBlockQuote{blocks, attrs, cite, span} <> rest:
      "Q{" ++ show_blocks(blocks) ++ "}{" ++ show_attrs(attrs) ++ "}," ++ show_maybe_string(cite) ++
        show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BList{ordered, start, tight, items, span} <> rest:
      "List(" ++ Bool.show(ordered) ++ "," ++ U32.show(start) ++ "," ++ Bool.show(tight) ++
        "){" ++ show_list_items(items) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BTable{alignments, rows, span} <> rest:
      "Table{" ++ show_aligns(alignments) ++ "}{" ++ show_table_rows(rows) ++ "}" ++ show_span(span) ++ ";" ++ show_blocks(rest)
    case Ast.BRawPassthrough{text, span} <> rest:
      "Pass" ++ q(text) ++ show_span(span) ++ ";" ++ show_blocks(rest)
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
  IO.print(name ++ "=" ++ inspect_document(Textile.parse_textile(input)))

def print_bounded(name: String, input: String, max: Nat) -> IO(Unit):
  IO.print(name ++ "=" ++ inspect_maybe(Textile.parse_textile_bounded(input, max)))

def main() -> IO(Unit):
  do IO<Unit>:
    print_case("empty", "")
    print_case("paragraph-crlf", "alpha\r\nbeta\rgamma")
    print_case("headings", "h1. Alpha\n\nh6(hero#main). Omega\n")
    print_case("quote", "bq. First line.\nSecond line.\n\nplain")
    print_case("lists-basic", "* one\n* two\n\n# first\n# second\n")
    print_case("lists-nested", "* outer\n** inner\n** second\n* next\nafter\n")
    print_case("lists-mixed", "* bullet\n# number\n")
    print_case("lists-cross-nested", "* Fuel could be:\n** Coal\n** Gasoline\n* Humans need only:\n## Water\n## Protein")
    print_case("inline-phrases", "_em_ *strong* __it__ **bold** -del- +ins+ ^sup^ ~sub~ %span% @code@\n")
    print_case("inline-nested", "Textile is *_way_* cool.\nNested _*inner*_ phrases.\n*one _and *two*_ three*.")
    print_case("inline-boundaries", "c*oo*l a^2 50% * x* *x * ***triple*** unmatched*\n")
    print_case("link-image", "\"Google (G)\":http://google.com and !openwindow1.gif(Bunny.)! end")
    print_case("link-basic", "I searched \"Google\":http://google.com.\n\"E-mail me please\":mailto:someone@example.com\nA \"relative\":/path and a \"quoted (T)\":/u.")
    print_case("image-linked", "!openwindow1.gif!:https://hobix.com/\n!img.png(Logo)!:https://example.test/")
    print_case("block-attrs", "p(example1#big-red2). Red here\n\np{color:blue;margin:30px}. Spacey blue\n\np()>. Pad both\n\np<>. Justify")
    print_case("table", "|_. name|_. age|\n| alice | 30 |\n")
    print_case("table-inline", "| *em* | _em2_ | \"link\":http://u | @code@ | !img.png! |")
    print_case("escape-inline", "pre ==x *literal* y== post")
    print_case("escape-block", "==\nline *one*\nline two\n==\nafter")
    print_case("escape-unclosed", "==\nline *one*\n")
    print_case("malformed", "*open \"broken: and !image\n")
    print_case("unicode", "h2. café\n\né _x_\n")
    print_bounded("bound-empty-zero", "", 0n)
    print_bounded("bound-nonempty-zero", "x", 0n)
    print_bounded("bound-ascii-fit", "abc", 3n)
    print_bounded("bound-ascii-small", "abc", 2n)
    print_bounded("bound-unicode-fit", "é", 2n)
    print_bounded("bound-unicode-small", "é", 1n)

#|empty=Doc{}
#|paragraph-crlf=Doc{P[T"alpha"@0-5;Hard@5-6;T"beta"@6-10;Hard@10-11;T"gamma"@11-16;]{}@0-16;}
#|headings=Doc{H1[T"Alpha"@4-9;]{}@0-10;H6[T"Omega"@26-31;]{"class"="hero","id"="main",}@11-32;}
#|quote=Doc{Q{P[T"First line."@4-15;Hard@15-16;T"Second line."@16-28;]{}@4-28;}{},None@0-29;P[T"plain"@30-35;]{}@30-35;}
#|lists-basic=Doc{List(False,1,True){Item{P[T"one"@0-3;]@0-0;}@0-0;Item{P[T"two"@0-3;]@0-0;}@0-0;}@0-0;List(True,1,True){Item{P[T"first"@0-5;]@0-0;}@0-0;Item{P[T"second"@0-6;]@0-0;}@0-0;}@0-0;}
#|lists-nested=Doc{List(False,1,True){Item{P[T"outer"@0-5;]@0-0;List?(False,1,True,items=2)@0-0;}@0-0;Item{P[T"next"@0-4;]@0-0;}@0-0;}@0-0;P[T"after"@34-39;]{}@34-40;}
#|lists-mixed=Doc{List(False,1,True){Item{P[T"bullet"@0-6;]@0-0;}@0-0;}@0-0;List(True,1,True){Item{P[T"number"@0-6;]@0-0;}@0-0;}@0-0;}
#|lists-cross-nested=Doc{List(False,1,True){Item{P[T"Fuel could be:"@0-14;]@0-0;List?(False,1,True,items=2)@0-0;}@0-0;Item{P[T"Humans need only:"@0-17;]@0-0;List?(True,1,True,items=2)@0-0;}@0-0;}@0-0;}
#|inline-phrases=Doc{P[E[T"em"@1-3;]@0-4;T" "@4-5;S[T"strong"@6-12;]@5-13;T" "@13-14;I[T"it"@16-18;]@14-20;T" "@20-21;B[T"bold"@23-27;]@21-29;T" "@29-30;D[T"del"@31-34;]@30-35;T" "@35-36;Ins[T"ins"@37-40;]@36-41;T" "@41-42;Sup[T"sup"@43-46;]@42-47;T" "@47-48;Sub[T"sub"@49-52;]@48-53;T" "@53-54;Span[T"span"@55-59;]{}@54-60;T" "@60-61;C"code"@61-67;]{}@0-68;}
#|inline-nested=Doc{P[T"Textile is "@0-11;S[E[T"way"@13-16;]@12-17;]@11-18;T" cool."@18-24;Hard@24-25;T"Nested "@25-32;E[S[T"inner"@34-39;]@33-40;]@32-41;T" phrases."@41-50;Hard@50-51;S[T"one "@52-56;E[T"and "@57-61;S[T"two"@62-65;]@61-66;]@56-67;T" three"@67-73;]@51-74;T"."@74-75;]{}@0-75;}
#|inline-boundaries=Doc{P[T"c"@0-1;T"*"@1-2;T"oo"@2-4;T"*"@4-5;T"l a"@5-8;T"^"@8-9;T"2 50"@9-13;T"%"@13-14;T" "@14-15;T"*"@15-16;T" x"@16-18;T"*"@18-19;T" "@19-20;S[T"x "@21-23;T"*"@23-24;T" "@24-25;T"***"@25-28;T"triple"@28-34;T"***"@34-37;T" unmatched"@37-47;]@20-48;]{}@0-49;}
#|link-image=Doc{P[L[T"Google"@1-7;]("http://google.com",Some("G"))@0-30;T" and "@30-35;Img("openwindow1.gif","Bunny.",Some("Bunny."))@35-60;T" end"@60-64;]{}@0-64;}
#|link-basic=Doc{P[T"I searched "@0-11;L[T"Google"@12-18;]("http://google.com",None)@11-37;T"."@37-38;Hard@38-39;L[T"E-mail me please"@40-56;]("mailto:someone@example.com",None)@39-84;Hard@84-85;T"A "@85-87;L[T"relative"@88-96;]("/path",None)@87-103;T" and a "@103-110;L[T"quoted"@111-117;]("/u",Some("T"))@110-125;T"."@125-126;]{}@0-126;}
#|image-linked=Doc{P[L[Img("openwindow1.gif","",None)@0-17;]("https://hobix.com/",None)@0-36;Hard@36-37;L[Img("img.png","Logo",Some("Logo"))@37-52;]("https://example.test/",None)@37-74;]{}@0-74;}
#|block-attrs=Doc{P[T"Red here"@22-30;]{"class"="example1","id"="big-red2",}@0-31;P[T"Spacey blue"@59-70;]{"style"="color:blue; margin:30px;",}@32-71;P[T"Pad both"@78-86;]{"style"="padding-left:1em; padding-right:1em; text-align:right;",}@72-87;P[T"Justify"@93-100;]{"style"="text-align:justify;",}@88-100;}
#|table=Doc{Table{none,none,}{Row{Cell(True,none,1,1)[T"name"@0-4;]{}@0-0;Cell(True,none,1,1)[T"age"@0-3;]{}@0-0;}{}@0-0;Row{Cell(False,none,1,1)[T" alice "@0-7;]{}@0-0;Cell(False,none,1,1)[T" 30 "@0-4;]{}@0-0;}{}@0-0;}@0-32;}
#|table-inline=Doc{Table{none,none,none,none,none,}{Row{Cell(False,none,1,1)[T" "@0-1;S[T"em"@2-4;]@1-5;T" "@5-6;]{}@0-0;Cell(False,none,1,1)[T" "@0-1;E[T"em2"@2-5;]@1-6;T" "@6-7;]{}@0-0;Cell(False,none,1,1)[T" "@0-1;L[T"link"@2-6;]("http://u",None)@1-16;T" "@16-17;]{}@0-0;Cell(False,none,1,1)[T" "@0-1;C"code"@1-7;T" "@7-8;]{}@0-0;Cell(False,none,1,1)[T" "@0-1;Img("img.png","",None)@1-10;T" "@10-11;]{}@0-0;}{}@0-0;}@0-55;}
#|escape-inline=Doc{P[T"pre "@0-4;T"x *literal* y"@6-19;T" post"@21-26;]{}@0-26;}
#|escape-block=Doc{Pass"line *one*\nline two"@0-26;P[T"after"@26-31;]{}@26-31;}
#|escape-unclosed=Doc{P[T"=="@0-2;Hard@2-3;T"line "@3-8;S[T"one"@9-12;]@8-13;]{}@0-14;}
#|malformed=Doc{P[T"*"@0-1;T"open "@1-6;T"\""@6-7;T"broken: and "@7-19;T"!"@19-20;T"image"@20-25;]{}@0-26;}
#|unicode=Doc{H2[T"café"@4-9;]{}@0-10;P[T"é "@11-14;E[T"x"@15-16;]@14-17;]{}@11-18;}
#|bound-empty-zero=Some(Doc{})
#|bound-nonempty-zero=None
#|bound-ascii-fit=Some(Doc{P[T"abc"@0-3;]{}@0-3;})
#|bound-ascii-small=None
#|bound-unicode-fit=Some(Doc{P[T"é"@0-2;]{}@0-2;})
#|bound-unicode-small=None
