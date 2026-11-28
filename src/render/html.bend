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

def identity_link_rewrite(ctx: Unit, target: String) -> String:
  target

def render_inlines_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  xs: List<&2, Ast.Inline>, +profile: HtmlProfile, +ctx: C) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      match h:
        case Ast.IText{text, span}:
          escape_html(text) ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ICode{text, span}:
          "<code>" ++ escape_html(text) ++ "</code>" ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IEmph{children, span}:
          "<em>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</em>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IStrong{children, span}:
          "<strong>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</strong>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IBold{children, span}:
          "<b>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</b>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IItalic{children, span}:
          "<i>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</i>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IDeleted{children, span}:
          "<del>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</del>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IInserted{children, span}:
          "<ins>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</ins>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ISuperscript{children, span}:
          "<sup>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</sup>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ISubscript{children, span}:
          "<sub>" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</sub>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ISpan{children, attrs, span}:
          "<span" ++ render_attrs(attrs) ++ ">" ++ render_inlines_with_link_rewrite(~C, ~rewrite,
            children, profile, ctx) ++ "</span>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ILink{children, href, title, span, destination}:
          "<a href=\"" ++ escape_html(rewrite(ctx, href)) ++ "\"" ++ render_title_attr(title) ++ ">" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</a>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IImage{src, alt, title, span, destination}:
          "<img src=\"" ++ escape_html(rewrite(ctx, src)) ++ "\" alt=\"" ++ escape_html(alt) ++ "\"" ++
            render_title_attr(title) ++ void_close(profile) ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IAutolink{href, label, span, destination}:
          "<a href=\"" ++ escape_html(rewrite(ctx, href)) ++ "\">" ++ escape_html(label) ++ "</a>" ++
            render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IRawHtml{text, span}:
          render_raw_fragment(profile, text) ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.ISoftBreak{span}:
          "\n" ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IHardBreak{span}:
          "<br" ++ void_close(profile) ++ "\n" ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)
        case Ast.IFootnoteRef{+number, span}:
          "<sup class=\"footnote-ref\"><a href=\"#fn-" ++ U32.show(number) ++ "\">" ++
            U32.show(number) ++ "</a></sup>" ++ render_inlines_with_link_rewrite(~C, ~rewrite, t, profile, ctx)

def render_inlines(xs: List<&2, Ast.Inline>, +profile: HtmlProfile) -> String:
  render_inlines_with_link_rewrite(~Unit, ~identity_link_rewrite, xs, profile, Unit{})

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
def render_table_cell_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  cell: Ast.TableCell, column: Maybe<&2, Ast.Alignment>, +profile: HtmlProfile, +ctx: C) -> String:
  match cell:
    case Ast.TableCell{header, align, colspan, rowspan, children, attrs, span}:
      +tag = Bool.pick(String, header, "th", "td")
      "<" ++ tag ++
        render_attrs(table_cell_attrs(attrs, effective_cell_align(align, column), colspan, rowspan)) ++
        ">" ++ render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</" ++ tag ++ ">"

def render_table_cell(cell: Ast.TableCell, column: Maybe<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  render_table_cell_with_link_rewrite(~Unit, ~identity_link_rewrite, cell, column, profile, Unit{})

def effective_colspan(+colspan: U32) -> U32:
  Bool.pick(U32, U32.is_eq(colspan, 0), 1, colspan)

def table_cell_colspan(cell: Ast.TableCell) -> U32:
  match cell:
    case Ast.TableCell{header, align, +colspan, rowspan, children, attrs, span}:
      effective_colspan(colspan)

def render_table_cells_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  cells: List<&2, Ast.TableCell>, columns: List<&2, Ast.Alignment>, +profile: HtmlProfile,
  +ctx: C) -> String:
  match cells:
    case Nil{}:
      ""
    case +h <> t:
      match columns:
        case Nil{}:
          render_table_cell_with_link_rewrite(~C, ~rewrite, h, None{}, profile, ctx) ++
            render_table_cells_with_link_rewrite(~C, ~rewrite, t, Nil{}, profile, ctx)
        case column <> rest_columns:
          +span = table_cell_colspan(h)
          render_table_cell_with_link_rewrite(~C, ~rewrite, h, Some{column}, profile, ctx) ++
            render_table_cells_with_link_rewrite(~C, ~rewrite, t,
              List.drop(&2, Ast.Alignment, rest_columns, U32.to_nat(U32.sub(span, 1))), profile, ctx)

def render_table_cells(cells: List<&2, Ast.TableCell>, columns: List<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  render_table_cells_with_link_rewrite(~Unit, ~identity_link_rewrite, cells, columns, profile, Unit{})

def render_table_rows_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  rows: List<&2, Ast.TableRow>, +alignments: List<&2, Ast.Alignment>, +profile: HtmlProfile,
  +ctx: C) -> String:
  match rows:
    case Nil{}:
      ""
    case Ast.TableRow{cells, attrs, span} <> t:
      "<tr" ++ render_attrs(attrs) ++ ">" ++
        render_table_cells_with_link_rewrite(~C, ~rewrite, cells, alignments, profile, ctx) ++
        "</tr>\n" ++ render_table_rows_with_link_rewrite(~C, ~rewrite, t, alignments, profile, ctx)

def render_table_rows(rows: List<&2, Ast.TableRow>, +alignments: List<&2, Ast.Alignment>,
  +profile: HtmlProfile) -> String:
  render_table_rows_with_link_rewrite(~Unit, ~identity_link_rewrite, rows, alignments, profile, Unit{})

# A tight-list paragraph without attributes has no <p> wrapper.  Attributes
# force the wrapper back on: dropping them would lose document information.
def render_paragraph_tight_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>, profile: HtmlProfile, +ctx: C) -> String:
  match attrs:
    case Nil{}:
      render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "\n"
    case u:
      "<p" ++ render_attrs(u) ++ ">" ++
        render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</p>\n"

def render_paragraph_tight(attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>,
  profile: HtmlProfile) -> String:
  render_paragraph_tight_with_link_rewrite(~Unit, ~identity_link_rewrite, attrs, children, profile, Unit{})

def render_paragraph_block_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  children: List<&2, Ast.Inline>, attrs: List<&2, Ast.Attr>, profile: HtmlProfile, tight: Bool,
  +ctx: C) -> String:
  match tight:
    case True{}:
      render_paragraph_tight_with_link_rewrite(~C, ~rewrite, attrs, children, profile, ctx)
    case False{}:
      "<p" ++ render_attrs(attrs) ++ ">" ++
        render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</p>\n"

def render_paragraph_block(children: List<&2, Ast.Inline>, attrs: List<&2, Ast.Attr>,
  profile: HtmlProfile, tight: Bool) -> String:
  render_paragraph_block_with_link_rewrite(~Unit, ~identity_link_rewrite, children, attrs, profile, tight, Unit{})

# The same tight-paragraph rule for a one-block item, without the newline that
# belongs to block layout; this keeps the common tight-list case on one line.
def render_tight_single_paragraph_with_link_rewrite(~C: Data,
  ~rewrite: C -> String -> String, attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>,
  profile: HtmlProfile, +ctx: C) -> String:
  match attrs:
    case Nil{}:
      render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx)
    case u:
      "<p" ++ render_attrs(u) ++ ">" ++ render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</p>"

def render_tight_single_paragraph(attrs: List<&2, Ast.Attr>, children: List<&2, Ast.Inline>,
  profile: HtmlProfile) -> String:
  render_tight_single_paragraph_with_link_rewrite(~Unit, ~identity_link_rewrite, attrs, children,
    profile, Unit{})

# A single recursive dispatcher for blocks and list items.  Bend does not
# admit mutual recursion, so the Nat budget makes the recursion structurally
# obvious to the termination checker.  The public entry points use a large
# fixed budget; exhaustion conservatively emits no text for the unrendered
# remainder.
type BlockWork is Data:
  WorkBlock{block: Ast.Block, tight_para: Bool}
  WorkBlocks{blocks: List<&2, Ast.Block>, tight_para: Bool}
  WorkTightItemBlocks{blocks: List<&2, Ast.Block>, first: Bool}
  WorkItems{items: List<&2, Ast.ListItem>, tight: Bool}

def render_block_work_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  +fuel: Nat, +profile: HtmlProfile, work: BlockWork, +ctx: C) -> String:
  match fuel:
    case 0n:
      ""
    case 1n++f:
      match work:
        case WorkBlock{block, tight_para}:
          match block:
            case Ast.BParagraph{children, attrs, span}:
              render_paragraph_block_with_link_rewrite(~C, ~rewrite, children, attrs, profile, tight_para, ctx)
            case Ast.BHeading{+level, children, attrs, span}:
              +n = clamp_heading_level(level)
              "<h" ++ U32.show(n) ++ render_attrs(attrs) ++ ">" ++
                render_inlines_with_link_rewrite(~C, ~rewrite, children, profile, ctx) ++ "</h" ++ U32.show(n) ++ ">\n"
            case Ast.BThematicBreak{span}:
              "<hr" ++ void_close(profile) ++ "\n"
            case Ast.BCodeBlock{text, info, attrs, span}:
              "<pre" ++ render_attrs(attrs) ++ ">" ++ render_code_open(info) ++
                escape_html(text) ++ "</code></pre>\n"
            case Ast.BHtmlBlock{text, span}:
              render_verbatim_block(profile, text)
            case Ast.BBlockQuote{blocks, attrs, cite, span}:
              "<blockquote" ++ render_attrs(attrs) ++ render_cite_attr(cite) ++ ">\n" ++
                render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                  WorkBlocks{blocks, False{}}, ctx) ++ "</blockquote>\n"
            case Ast.BList{+ordered, +start, tight, items, span}:
              list_open(ordered, start) ++
                render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                  WorkItems{items, tight}, ctx) ++ list_close(ordered)
            case Ast.BTable{alignments, rows, span}:
              "<table>\n" ++
                render_table_rows_with_link_rewrite(~C, ~rewrite, rows, alignments, profile, ctx) ++
                "</table>\n"
            case Ast.BRawPassthrough{text, span}:
              render_verbatim_block(profile, text)
        case WorkBlocks{blocks, +tight_para}:
          match blocks:
            case Nil{}:
              ""
            case h <> t:
              render_block_work_with_link_rewrite(~C, ~rewrite, f, profile, WorkBlock{h, tight_para}, ctx) ++
                render_block_work_with_link_rewrite(~C, ~rewrite, f, profile, WorkBlocks{t, tight_para}, ctx)
        case WorkTightItemBlocks{blocks, +first}:
          match blocks:
            case Nil{}:
              ""
            case Ast.BParagraph{children, attrs, span} <> restblocks:
              match restblocks:
                case Nil{}:
                  render_tight_single_paragraph_with_link_rewrite(~C, ~rewrite, attrs, children, profile, ctx)
                case more:
                  render_paragraph_tight_with_link_rewrite(~C, ~rewrite, attrs, children, profile, ctx) ++
                    render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                      WorkTightItemBlocks{more, False{}}, ctx)
            case h <> restblocks:
              +rendered = render_block_work_with_link_rewrite(~C, ~rewrite, f, profile, WorkBlock{h, True{}}, ctx)
              +prefix = Bool.pick(String, first, "\n", "")
              prefix ++ rendered ++
                render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                  WorkTightItemBlocks{restblocks, False{}}, ctx)
        case WorkItems{items, +tight}:
          match items:
            case Nil{}:
              ""
            case Ast.ListItem{blocks, span} <> t:
              match blocks:
                case Nil{}:
                  "<li></li>\n" ++
                    render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                      WorkItems{t, tight}, ctx)
                case u:
                  match tight:
                    case True{}:
                      "<li>" ++ render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                        WorkTightItemBlocks{u, True{}}, ctx) ++ "</li>\n" ++
                        render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                          WorkItems{t, tight}, ctx)
                    case False{}:
                      "<li>\n" ++ render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                        WorkBlocks{u, False{}}, ctx) ++ "</li>\n" ++
                        render_block_work_with_link_rewrite(~C, ~rewrite, f, profile,
                          WorkItems{t, tight}, ctx)

def render_block_work(+fuel: Nat, +profile: HtmlProfile, work: BlockWork) -> String:
  render_block_work_with_link_rewrite(~Unit, ~identity_link_rewrite, fuel, profile, work, Unit{})

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

def render_document_with_link_rewrite(~C: Data, ~rewrite: C -> String -> String,
  +ctx: C, document: Ast.Document) -> String:
  match document:
    case Ast.Document{blocks}:
      render_block_work_with_link_rewrite(~C, ~rewrite, render_block_budget(), Html{},
        WorkBlocks{blocks, False{}}, ctx)

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
