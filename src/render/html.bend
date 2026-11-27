import Base
import ../ast.bend as Ast
import ../text.bend as Text

# Rendering profile. Html uses HTML void tags and permits raw passthrough;
# Xhtml uses XML void tags and escapes raw passthrough conservatively.
type HtmlProfile is Data:
  Html{}
  Xhtml{}

# Characters which cannot be represented safely in the UTF-8/HTML output.
# Tab, LF and CR are preserved; other C0 controls, DEL, C1 controls,
# surrogate code points and out-of-range code points become U+FFFD.
def bad_char_code(+x: U32) -> Bool:
  +c0 = Bool.and(U32.is_lt(x, 32),
    Bool.not(Bool.or(U32.is_eq(x, 9), Bool.or(U32.is_eq(x, 10), U32.is_eq(x, 13)))))
  +c1 = Bool.and(U32.is_ge(x, 128), U32.is_le(x, 159))
  +surrogate = Bool.and(U32.is_ge(x, 55296), U32.is_le(x, 57343))
  Bool.or(c0, Bool.or(U32.is_eq(x, 127), Bool.or(c1, Bool.or(surrogate,
    U32.is_gt(x, 1114111)))))

def sanitize_char(c: Char) -> Char:
  match c:
    case Chr{+x}:
      Bool.pick(Char, bad_char_code(x), Chr{65533}, Chr{x})

# Deterministic escaping used for both text and attribute values.  Quotes are
# escaped everywhere, which is slightly conservative in text but valid in both
# HTML and XHTML.
def escape_html(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{'&', t}:
      "&amp;" ++ escape_html(t)
    case SCon{'<', t}:
      "&lt;" ++ escape_html(t)
    case SCon{'>', t}:
      "&gt;" ++ escape_html(t)
    case SCon{'"', t}:
      "&quot;" ++ escape_html(t)
    case SCon{h, t}:
      Text.char_string(sanitize_char(h)) ++ escape_html(t)

# Attribute names are conservatively reduced to ASCII letters, digits and
# '-', '.', ':' and '_'.  Every other character becomes '_'.  This keeps a
# hostile or malformed attribute key from breaking out of the tag.
def attr_name_char_ok(+x: U32) -> Bool:
  +digit = Bool.and(U32.is_ge(x, 48), U32.is_le(x, 57))
  +upper = Bool.and(U32.is_ge(x, 65), U32.is_le(x, 90))
  +lower = Bool.and(U32.is_ge(x, 97), U32.is_le(x, 122))
  +punct = Bool.or(U32.is_eq(x, 45), Bool.or(U32.is_eq(x, 46),
    Bool.or(U32.is_eq(x, 58), U32.is_eq(x, 95))))
  Bool.or(digit, Bool.or(upper, Bool.or(lower, punct)))

def attr_name_char(c: Char) -> Char:
  match c:
    case Chr{+x}:
      Bool.pick(Char, attr_name_char_ok(x), Chr{x}, Chr{95})

def sanitize_attr_name(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{h, t}:
      Text.char_string(attr_name_char(h)) ++ sanitize_attr_name(t)

def render_attr_named(name: String, value: String) -> String:
  match name:
    case SNil{}:
      ""
    case u:
      " " ++ u ++ "=\"" ++ escape_html(value) ++ "\""

def render_attr_pair(key: String, value: String) -> String:
  render_attr_named(sanitize_attr_name(key), value)

def attrs_for_key.fin(key: String, value: String, rest: String, same: Bool) -> String:
  match same:
    case True{}:
      render_attr_pair(key, value) ++ rest
    case False{}:
      rest

# Render every attribute with exactly this key, stably and in input order.
def attrs_for_key(attrs: List<&2, Ast.Attr>, +wanted: String) -> String:
  match attrs:
    case Nil{}:
      ""
    case Ast.Attr{+key, value} <> t:
      attrs_for_key.fin(key, value, attrs_for_key(t, wanted), String.eq(key, wanted))

def priority_attr_key(+key: String) -> Bool:
  Bool.or(String.eq(key, "id"), Bool.or(String.eq(key, "class"),
    Bool.or(String.eq(key, "style"), String.eq(key, "lang"))))

def other_attrs.fin(key: String, value: String, rest: String, priority: Bool) -> String:
  match priority:
    case True{}:
      rest
    case False{}:
      render_attr_pair(key, value) ++ rest

# Render the non-priority attributes stably and in input order.
def other_attrs(attrs: List<&2, Ast.Attr>) -> String:
  match attrs:
    case Nil{}:
      ""
    case Ast.Attr{+key, value} <> t:
      other_attrs.fin(key, value, other_attrs(t), priority_attr_key(key))

# Required deterministic order: style, class, id, lang, then all other
# attributes in input order.  Duplicate keys are retained; their relative
# order is stable.
def render_attrs(+attrs: List<&2, Ast.Attr>) -> String:
  attrs_for_key(attrs, "style") ++ attrs_for_key(attrs, "class") ++
    attrs_for_key(attrs, "id") ++ attrs_for_key(attrs, "lang") ++ other_attrs(attrs)

def void_close(profile: HtmlProfile) -> String:
  match profile:
    case Html{}:
      " />"
    case Xhtml{}:
      " />"

def render_title_attr(title: Maybe<&2, String>) -> String:
  match title:
    case None{}:
      ""
    case Some{value}:
      " title=\"" ++ escape_html(value) ++ "\""

def render_raw_fragment(profile: HtmlProfile, text: String) -> String:
  match profile:
    case Html{}:
      text
    case Xhtml{}:
      escape_html(text)

def drop_leading_linebreaks(s: String) -> String:
  match s:
    case SCon{'\n', t}:
      drop_leading_linebreaks(t)
    case SCon{'\r', t}:
      drop_leading_linebreaks(t)
    case u:
      u

# Raw blocks are normalized so the serialized block finishes in exactly one
# newline, no matter how many line breaks ended the input fragment.
def strip_trailing_linebreaks(s: String) -> String:
  String.reverse(drop_leading_linebreaks(String.reverse(s)))

def render_verbatim_block(profile: HtmlProfile, text: String) -> String:
  render_raw_fragment(profile, strip_trailing_linebreaks(text)) ++ "\n"

def render_inlines(xs: List<&2, Ast.Inline>, +profile: HtmlProfile) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      match h:
        case Ast.IText{text, span}:
          escape_html(text) ++ render_inlines(t, profile)
        case Ast.ICode{text, span}:
          "<code>" ++ escape_html(text) ++ "</code>" ++ render_inlines(t, profile)
        case Ast.IEmph{children, span}:
          "<em>" ++ render_inlines(children, profile) ++ "</em>" ++ render_inlines(t, profile)
        case Ast.IStrong{children, span}:
          "<strong>" ++ render_inlines(children, profile) ++ "</strong>" ++ render_inlines(t, profile)
        case Ast.IBold{children, span}:
          "<b>" ++ render_inlines(children, profile) ++ "</b>" ++ render_inlines(t, profile)
        case Ast.IItalic{children, span}:
          "<i>" ++ render_inlines(children, profile) ++ "</i>" ++ render_inlines(t, profile)
        case Ast.IDeleted{children, span}:
          "<del>" ++ render_inlines(children, profile) ++ "</del>" ++ render_inlines(t, profile)
        case Ast.IInserted{children, span}:
          "<ins>" ++ render_inlines(children, profile) ++ "</ins>" ++ render_inlines(t, profile)
        case Ast.ISuperscript{children, span}:
          "<sup>" ++ render_inlines(children, profile) ++ "</sup>" ++ render_inlines(t, profile)
        case Ast.ISubscript{children, span}:
          "<sub>" ++ render_inlines(children, profile) ++ "</sub>" ++ render_inlines(t, profile)
        case Ast.ISpan{children, attrs, span}:
          "<span" ++ render_attrs(attrs) ++ ">" ++ render_inlines(children, profile) ++
            "</span>" ++ render_inlines(t, profile)
        case Ast.ILink{children, href, title, span}:
          "<a href=\"" ++ escape_html(href) ++ "\"" ++ render_title_attr(title) ++ ">" ++
            render_inlines(children, profile) ++ "</a>" ++ render_inlines(t, profile)
        case Ast.IImage{src, alt, title, span}:
          "<img src=\"" ++ escape_html(src) ++ "\" alt=\"" ++ escape_html(alt) ++ "\"" ++
            render_title_attr(title) ++ void_close(profile) ++ render_inlines(t, profile)
        case Ast.IAutolink{href, label, span}:
          "<a href=\"" ++ escape_html(href) ++ "\">" ++ escape_html(label) ++ "</a>" ++
            render_inlines(t, profile)
        case Ast.IRawHtml{text, span}:
          render_raw_fragment(profile, text) ++ render_inlines(t, profile)
        case Ast.ISoftBreak{span}:
          "\n" ++ render_inlines(t, profile)
        case Ast.IHardBreak{span}:
          "<br" ++ void_close(profile) ++ "\n" ++ render_inlines(t, profile)
        case Ast.IFootnoteRef{+number, span}:
          "<sup class=\"footnote-ref\"><a href=\"#fn-" ++ U32.show(number) ++ "\">" ++
            U32.show(number) ++ "</a></sup>" ++ render_inlines(t, profile)

def clamp_heading_level(+level: U32) -> U32:
  Bool.pick(U32, U32.is_lt(level, 1), 1,
    Bool.pick(U32, U32.is_gt(level, 6), 6, level))

def render_code_open(info: Maybe<&2, String>) -> String:
  match info:
    case None{}:
      "<code>"
    case Some{language}:
      "<code class=\"language-" ++ escape_html(language) ++ "\">"

def render_cite_attr(cite: Maybe<&2, String>) -> String:
  match cite:
    case None{}:
      ""
    case Some{value}:
      " cite=\"" ++ escape_html(value) ++ "\""

def ordered_list_open(+start: U32, one: Bool) -> String:
  match one:
    case True{}:
      "<ol>\n"
    case False{}:
      "<ol start=\"" ++ U32.show(start) ++ "\">\n"

def list_open(ordered: Bool, +start: U32) -> String:
  match ordered:
    case True{}:
      ordered_list_open(start, U32.is_eq(start, 1))
    case False{}:
      "<ul>\n"

def list_close(ordered: Bool) -> String:
  match ordered:
    case True{}:
      "</ol>\n"
    case False{}:
      "</ul>\n"

def append_attr_if(attrs: List<&2, Ast.Attr>, +key: String, +value: String, yes: Bool) ->
  List<&2, Ast.Attr>:
  match yes:
    case True{}:
      List.append(&2, Ast.Attr, attrs, [Ast.Attr{key, value}])
    case False{}:
      attrs

def append_alignment_attr(attrs: List<&2, Ast.Attr>, align: Ast.Alignment) ->
  List<&2, Ast.Attr>:
  match align:
    case Ast.AlignNone{}:
      attrs
    case Ast.AlignLeft{}:
      List.append(&2, Ast.Attr, attrs, [Ast.Attr{"align", "left"}])
    case Ast.AlignCenter{}:
      List.append(&2, Ast.Attr, attrs, [Ast.Attr{"align", "center"}])
    case Ast.AlignRight{}:
      List.append(&2, Ast.Attr, attrs, [Ast.Attr{"align", "right"}])

def table_cell_attrs(attrs: List<&2, Ast.Attr>, align: Ast.Alignment,
  +colspan: U32, +rowspan: U32) -> List<&2, Ast.Attr>:
  a0 = append_alignment_attr(attrs, align)
  a1 = append_attr_if(a0, "colspan", U32.show(colspan), U32.is_gt(colspan, 1))
  append_attr_if(a1, "rowspan", U32.show(rowspan), U32.is_gt(rowspan, 1))

# A cell's explicit alignment wins; AlignNone falls back to the table's
# column alignment when one exists.
def effective_cell_align(align: Ast.Alignment, column: Maybe<&2, Ast.Alignment>) -> Ast.Alignment:
  match align:
    case Ast.AlignNone{}:
      match column:
        case None{}:
          Ast.AlignNone{}
        case Some{value}:
          value
    case u:
      u

# Tables contain inline text rather than nested blocks, so their rows and
# cells are ordinary structurally recursive lists and do not need the block
# recursion budget below.
def render_table_cell(cell: Ast.TableCell, column: Maybe<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  match cell:
    case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span}:
      +tag = Bool.pick(String, header, "th", "td")
      "<" ++ tag ++
        render_attrs(table_cell_attrs(attrs, effective_cell_align(align, column), colspan, rowspan)) ++
        ">" ++ render_inlines(children, profile) ++ "</" ++ tag ++ ">"

def effective_colspan(+colspan: U32) -> U32:
  Bool.pick(U32, U32.is_eq(colspan, 0), 1, colspan)

def table_cell_colspan(cell: Ast.TableCell) -> U32:
  match cell:
    case Ast.TableCell{header, align, +colspan, rowspan, children, attrs, span}:
      effective_colspan(colspan)

def render_table_cells(cells: List<&2, Ast.TableCell>, columns: List<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  match cells:
    case Nil{}:
      ""
    case +h <> t:
      match columns:
        case Nil{}:
          render_table_cell(h, None{}, profile) ++ render_table_cells(t, Nil{}, profile)
        case column <> rest_columns:
          +span = table_cell_colspan(h)
          render_table_cell(h, Some{column}, profile) ++
            render_table_cells(t,
              List.drop(&2, Ast.Alignment, rest_columns, U32.to_nat(U32.sub(span, 1))), profile)

def render_table_rows(rows: List<&2, Ast.TableRow>, +alignments: List<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  match rows:
    case Nil{}:
      ""
    case Ast.TableRow{cells, attrs, span} <> t:
      "<tr" ++ render_attrs(attrs) ++ ">" ++ render_table_cells(cells, alignments, profile) ++
        "</tr>\n" ++ render_table_rows(t, alignments, profile)

# A tight-list paragraph without attributes has no <p> wrapper.  Attributes
# force the wrapper back on: dropping them would lose document information.
def render_paragraph_tight(attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>,
  profile: HtmlProfile) -> String:
  match attrs:
    case Nil{}:
      render_inlines(children, profile) ++ "\n"
    case u:
      "<p" ++ render_attrs(u) ++ ">" ++ render_inlines(children, profile) ++ "</p>\n"

def render_paragraph_block(children: List<&2, Ast.Inline>, attrs: List<&2, Ast.Attr>,
  profile: HtmlProfile, tight: Bool) -> String:
  match tight:
    case True{}:
      render_paragraph_tight(attrs, children, profile)
    case False{}:
      "<p" ++ render_attrs(attrs) ++ ">" ++ render_inlines(children, profile) ++ "</p>\n"

# The same tight-paragraph rule for a one-block item, without the newline that
# belongs to block layout; this keeps the common tight-list case on one line.
def render_tight_single_paragraph(attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>,
  profile: HtmlProfile) -> String:
  match attrs:
    case Nil{}:
      render_inlines(children, profile)
    case u:
      "<p" ++ render_attrs(u) ++ ">" ++ render_inlines(children, profile) ++ "</p>"

# A single recursive dispatcher for blocks and list items.  Bend does not
# admit mutual recursion, so the Nat budget makes the recursion structurally
# obvious to the termination checker.  The public entry points use a large
# fixed budget; exhaustion conservatively emits no text for the unrendered
# remainder.
type BlockWork is Data:
  WorkBlock{block: Ast.Block, tight_para: Bool}
  WorkBlocks{blocks: List<&2, Ast.Block>, tight_para: Bool}
  WorkItems{items: List<&2, Ast.ListItem>, tight: Bool}

def render_block_work(+fuel: Nat, +profile: HtmlProfile, work: BlockWork) -> String:
  match fuel:
    case 0n:
      ""
    case 1n++f:
      match work:
        case WorkBlock{block, tight_para}:
          match block:
            case Ast.BParagraph{children, attrs, span}:
              render_paragraph_block(children, attrs, profile, tight_para)
            case Ast.BHeading{+level, children, attrs, span}:
              +n = clamp_heading_level(level)
              "<h" ++ U32.show(n) ++ render_attrs(attrs) ++ ">" ++
                render_inlines(children, profile) ++ "</h" ++ U32.show(n) ++ ">\n"
            case Ast.BThematicBreak{span}:
              "<hr" ++ void_close(profile) ++ "\n"
            case Ast.BCodeBlock{text, info, attrs, span}:
              "<pre" ++ render_attrs(attrs) ++ ">" ++ render_code_open(info) ++
                escape_html(text) ++ "</code></pre>\n"
            case Ast.BHtmlBlock{text, span}:
              render_verbatim_block(profile, text)
            case Ast.BBlockQuote{blocks, attrs, cite, span}:
              "<blockquote" ++ render_attrs(attrs) ++ render_cite_attr(cite) ++ ">\n" ++
                render_block_work(f, profile, WorkBlocks{blocks, False{}}) ++ "</blockquote>\n"
            case Ast.BList{+ordered, +start, tight, items, span}:
              list_open(ordered, start) ++ render_block_work(f, profile, WorkItems{items, tight}) ++
                list_close(ordered)
            case Ast.BTable{alignments, rows, span}:
              "<table>\n" ++ render_table_rows(rows, alignments, profile) ++ "</table>\n"
            case Ast.BRawPassthrough{text, span}:
              render_verbatim_block(profile, text)
        case WorkBlocks{blocks, +tight_para}:
          match blocks:
            case Nil{}:
              ""
            case h <> t:
              render_block_work(f, profile, WorkBlock{h, tight_para}) ++
                render_block_work(f, profile, WorkBlocks{t, tight_para})
        case WorkItems{items, +tight}:
          match items:
            case Nil{}:
              ""
            case Ast.ListItem{blocks, span} <> t:
              match blocks:
                case Ast.BParagraph{children, attrs, span} <> Nil{}:
                  match tight:
                    case True{}:
                      "<li>" ++ render_tight_single_paragraph(attrs, children, profile) ++ "</li>\n" ++
                        render_block_work(f, profile, WorkItems{t, tight})
                    case False{}:
                      "<li>\n" ++ render_paragraph_block(children, attrs, profile, False{}) ++ "</li>\n" ++
                        render_block_work(f, profile, WorkItems{t, tight})
                case u:
                  "<li>\n" ++ render_block_work(f, profile, WorkBlocks{u, tight}) ++ "</li>\n" ++
                    render_block_work(f, profile, WorkItems{t, tight})

def render_block_budget() -> Nat:
  4294967295n

def render_inline_with_profile(profile: HtmlProfile, inline: Ast.Inline) -> String:
  render_inlines([inline], profile)

# The fuel-taking forms are explicit control over the recursion budget needed
# by Bend's no-mutual-recursion rule.  The ordinary profile forms use the
# maximum U32 value expressed as a Nat budget above.
def render_block_with_profile_fuel(profile: HtmlProfile, block: Ast.Block, fuel: Nat) -> String:
  render_block_work(fuel, profile, WorkBlock{block, False{}})

def render_document_with_profile_fuel(profile: HtmlProfile, document: Ast.Document, fuel: Nat) -> String:
  match document:
    case Ast.Document{blocks}:
      render_block_work(fuel, profile, WorkBlocks{blocks, False{}})

def render_block_with_profile(profile: HtmlProfile, block: Ast.Block) -> String:
  render_block_with_profile_fuel(profile, block, render_block_budget())

def render_document_with_profile(profile: HtmlProfile, document: Ast.Document) -> String:
  render_document_with_profile_fuel(profile, document, render_block_budget())

def render_inline(inline: Ast.Inline) -> String:
  render_inline_with_profile(Html{}, inline)

def render_block(block: Ast.Block) -> String:
  render_block_with_profile(Html{}, block)

def render_document(document: Ast.Document) -> String:
  render_document_with_profile(Html{}, document)

def render_inline_xhtml(inline: Ast.Inline) -> String:
  render_inline_with_profile(Xhtml{}, inline)

def render_block_xhtml(block: Ast.Block) -> String:
  render_block_with_profile(Xhtml{}, block)

def render_document_xhtml(document: Ast.Document) -> String:
  render_document_with_profile(Xhtml{}, document)
