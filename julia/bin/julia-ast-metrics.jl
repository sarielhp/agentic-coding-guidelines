# julia-ast-metrics.jl - AST metrics extractor used by julia-audit.
#
# Usage: julia --startup-file=no julia-ast-metrics.jl [--library|--script] FILE...
#
# --library / --script set whether the files that follow are library code (files in a
# package's src/ or ext/ are included into a module even without a `module` line).
#
# Parses every file with the JuliaSyntax parser that ships inside Julia
# (Base.JuliaSyntax, Julia >= 1.10) and prints one tab-separated record per line:
#
#   FILE  path  total_lines  library(0|1)
#   DEF   path  name  first_line  last_line  body_lines  depth  cognitive  cyclomatic  args
#   FIND  path  line  warn|trap  rule  message
#   ERR   path  message
#
# The policy (limits, tiers, exit codes) lives in julia-audit; this file only measures.
# Metric definitions follow ruby-audit: depth counts enclosing branches, loops and
# closures; cognitive complexity charges 1 + nesting for each branch, loop and catch,
# 1 for an elseif, and 1 for each run of the same boolean operator.

isdefined(Base, :JuliaSyntax) ||
    (println(stderr, "julia-ast-metrics: needs Julia >= 1.10"); exit(2))

const JS = Base.JuliaSyntax

const RESOURCE_CALLS = Set([
    "open",
    "cd",
    "mktempdir",
    "mktemp",
    "lock",
    "withenv",
    "redirect_stdout",
    "redirect_stderr",
    "redirect_stdin",
    "redirect_stdio",
    "cleanup",
])
const TERMINAL_CALLS = Set(["throw", "error", "rethrow", "exit"])
const EVAL_CALLS = Set(["eval", "include", "include_string", "evalfile"])

mutable struct Metrics
    depth::Int
    cognitive::Int
    cyclomatic::Int
end

#######################################################################
# Small helpers

clean(s) = replace(string(s), r"[\t\r\n]+" => " ")

function name_text(n)
    JS.is_leaf(n) && return string(something(n.val, ""))
    return JS.sourcetext(n)
end

last_segment(text) = lstrip(String(last(split(text, '.'))), ':')

"Name of the function called by a prefix call node, or \"\" for operators."
function callee(n)
    JS.kind(n) == JS.K"call" || return ""
    JS.is_infix_op_call(n) && return ""
    JS.is_postfix_op_call(n) && return ""
    kids = JS.children(n)
    isempty(kids) && return ""
    return last_segment(name_text(kids[1]))
end

function macro_name(n)
    JS.kind(n) == JS.K"macrocall" || return ""
    kids = JS.children(n)
    isempty(kids) && return ""
    return lstrip(last_segment(JS.sourcetext(kids[1])), '@')
end

line_of(n) = JS.source_line(n)
last_line_of(n) = JS.source_location(n.source, JS.last_byte(n))[1]

function code_line_flags(lines)
    flags = falses(length(lines))
    in_block = false
    for (i, l) in enumerate(lines)
        s = strip(l)
        if in_block
            occursin("=#", s) && (in_block = false)
            continue
        end
        if startswith(s, "#=")
            occursin("=#", s) || (in_block = true)
            continue
        end
        flags[i] = !(isempty(s) || startswith(s, "#"))
    end
    return flags
end

#######################################################################
# Definitions

"Strip `where` and return-type annotations to reach the `call` node of a signature."
function signature_call(sig)
    while JS.kind(sig) in (JS.K"where", JS.K"::")
        kids = JS.children(sig)
        isempty(kids) && return sig
        sig = kids[1]
    end
    return sig
end

function definition_name(sig)
    call = signature_call(sig)
    kind = JS.kind(call)
    if kind == JS.K"call"
        kids = JS.children(call)
        isempty(kids) && return "<anonymous>"
        head = JS.is_infix_op_call(call) && length(kids) >= 2 ? kids[2] : kids[1]
        return name_text(head)
    end
    kind == JS.K"tuple" && return "<anonymous>"
    return name_text(call)
end

function argument_count(sig)
    call = signature_call(sig)
    JS.kind(call) == JS.K"call" || return 0
    kids = JS.children(call)
    isempty(kids) && return 0
    count = length(kids) - 1
    for k in kids[2:end]
        if JS.kind(k) == JS.K"parameters"
            count += length(JS.children(k)) - 1
        end
    end
    return count
end

#######################################################################
# Complexity walk (the same model as ruby-audit)

function resource_call(n)
    JS.kind(n) == JS.K"call" && return callee(n) in RESOURCE_CALLS
    return false
end

# Per-node traversal state: current nesting, whether this node continues an `if` chain,
# whether it is a resource-managing `do` block, and the parent node.
struct State
    nest::Int
    flat::Bool
    resource_do::Bool
    parent::Any
end

const BRANCH_KINDS = (JS.K"if", JS.K"elseif", JS.K"?")
const LOOP_KINDS = (JS.K"while", JS.K"for")
const BOOLEAN_KINDS = (JS.K"&&", JS.K"||")

"Charge the node's cognitive and cyclomatic cost to `m`."
function charge!(m::Metrics, k, st::State)
    if k in BRANCH_KINDS
        m.cognitive += st.flat ? 1 : 1 + st.nest
        m.cyclomatic += 1
    elseif k in LOOP_KINDS || k == JS.K"catch"
        m.cognitive += 1 + st.nest
        m.cyclomatic += 1
    elseif k in BOOLEAN_KINDS
        m.cyclomatic += 1
        continues_run = st.parent !== nothing && JS.kind(st.parent) == k
        continues_run || (m.cognitive += 1)
    elseif k == JS.K"filter"
        m.cognitive += 1
        m.cyclomatic += 1
    end
    return nothing
end

"Nesting level of the node's children."
function inner_nest(k, st::State)
    k in LOOP_KINDS && return st.nest + 1
    k in BRANCH_KINDS && return st.flat ? st.nest : st.nest + 1
    k == JS.K"->" && return st.nest + 1
    k == JS.K"do" && return st.resource_do ? st.nest : st.nest + 1
    return st.nest
end

function walk!(m::Metrics, n, st::State)
    JS.is_leaf(n) && return nothing
    k = JS.kind(n)
    # Nested definitions are measured on their own.
    (k == JS.K"function" || k == JS.K"macro") && return nothing

    charge!(m, k, st)
    cur = inner_nest(k, st)
    m.depth = max(m.depth, cur)

    resource = resource_call(n)
    continues_if = k == JS.K"if" || k == JS.K"elseif"
    for c in JS.children(n)
        ck = JS.kind(c)
        walk!(
            m,
            c,
            State(cur, continues_if && ck == JS.K"elseif", resource && ck == JS.K"do", n),
        )
    end
    return nothing
end

function measure_definition(n, flags)
    kids = JS.children(n)
    length(kids) < 2 && return nothing
    sig, body = kids[1], kids[end]
    m = Metrics(0, 0, 1)
    walk!(m, body, State(0, false, false, nothing))
    first_l, last_l = line_of(n), last_line_of(n)
    total = count(@view flags[first_l:last_l])
    sig_total = count(@view flags[line_of(sig):last_line_of(sig)])
    long_form = last_l > first_l
    body_lines = max(total - max(sig_total, 1) - (long_form ? 1 : 0), 1)
    return (
        definition_name(sig),
        first_l,
        last_l,
        body_lines,
        m.depth,
        m.cognitive,
        m.cyclomatic,
        argument_count(sig),
    )
end

#######################################################################
# Findings (idiom and trap rules)

struct Finding
    line::Int
    severity::String
    rule::String
    message::String
end

terminal_kind(stmt) =
    JS.kind(stmt) in (JS.K"return", JS.K"break", JS.K"continue") ||
    (JS.kind(stmt) == JS.K"call" && callee(stmt) in TERMINAL_CALLS)

function terminal_name(stmt)
    JS.kind(stmt) == JS.K"call" && return callee(stmt)
    return string(JS.kind(stmt))
end

function check_else_after_terminal!(out, n)
    kids = JS.children(n)
    length(kids) >= 3 || return
    then_block = kids[2]
    JS.kind(then_block) == JS.K"block" || return
    stmts = JS.children(then_block)
    isempty(stmts) && return
    terminal_kind(stmts[end]) || return
    push!(
        out,
        Finding(
            line_of(kids[3]),
            "warn",
            "else-after-terminal",
            "unnecessary 'else' after terminal statement '$(terminal_name(stmts[end]))'",
        ),
    )
end

function check_catch!(out, n, ctx)
    body = JS.children(n)[end]
    JS.kind(body) == JS.K"block" &&
        isempty(JS.children(body)) &&
        push!(
            out,
            Finding(
                line_of(n),
                "trap",
                "swallowed-exception",
                "empty catch block silently swallows every exception; handle it or rethrow",
            ),
        )
end

function check_global!(out, n, ctx)
    ctx.in_function || return
    push!(
        out,
        Finding(
            line_of(n),
            "trap",
            "global-in-function",
            "assigning a global inside a function hides state; pass it explicitly or use a const container",
        ),
    )
end

function check_macrocall!(out, n, ctx)
    name = macro_name(n)
    if name == "fastmath"
        push!(
            out,
            Finding(
                line_of(n),
                "trap",
                "fastmath",
                "@fastmath changes floating-point semantics; justify with '# julia-audit: allow-fastmath'",
            ),
        )
    elseif name == "eval" && ctx.in_function
        push!(
            out,
            Finding(
                line_of(n),
                "trap",
                "runtime-eval",
                "@eval inside a function evaluates code at run time; use dispatch or generated functions",
            ),
        )
    end
end

function check_call!(out, n, ctx)
    ctx.in_function || return
    name = callee(n)
    if name in EVAL_CALLS
        push!(
            out,
            Finding(
                line_of(n),
                "trap",
                "runtime-eval",
                "'$name' inside a function evaluates code at run time; move it to module level",
            ),
        )
    elseif name == "exit" && ctx.library
        push!(
            out,
            Finding(
                line_of(n),
                "trap",
                "exit-in-library",
                "library code must throw an exception, not call exit",
            ),
        )
    end
end

check_struct!(out, n, ctx) = check_struct!(out, n)

function check_block!(out, n, ctx)
    ctx.module_level && ctx.library && check_module_globals!(out, n)
end

# Node kind => checker; the walk below dispatches through this table.
const NODE_CHECKS = Dict{JS.Kind,Function}(
    JS.K"if" => (out, n, ctx) -> check_else_after_terminal!(out, n),
    JS.K"elseif" => (out, n, ctx) -> check_else_after_terminal!(out, n),
    JS.K"catch" => check_catch!,
    JS.K"global" => check_global!,
    JS.K"macrocall" => check_macrocall!,
    JS.K"call" => check_call!,
    JS.K"struct" => check_struct!,
    JS.K"block" => check_block!,
)

function collect_findings!(out, n, ctx)
    JS.is_leaf(n) && return nothing
    k = JS.kind(n)
    check = get(NODE_CHECKS, k, nothing)
    check === nothing || check(out, n, ctx)

    inner_fn = ctx.in_function || k == JS.K"function" || k == JS.K"macro"
    # Module-level statements are the direct children of a module's block.
    for c in JS.children(n)
        child_ctx = (
            in_function = inner_fn,
            library = ctx.library,
            module_level = k == JS.K"module" && JS.kind(c) == JS.K"block",
        )
        collect_findings!(out, c, child_ctx)
    end
    return nothing
end

function check_struct!(out, n)
    kids = JS.children(n)
    isempty(kids) && return
    body = kids[end]
    JS.kind(body) == JS.K"block" || return
    for f in JS.children(body)
        if JS.kind(f) == JS.K"Identifier"
            push!(
                out,
                Finding(
                    line_of(f),
                    "warn",
                    "untyped-field",
                    "struct field '$(name_text(f))' has no type; annotate it (use ::Any if intended)",
                ),
            )
        end
    end
end

function check_module_globals!(out, block)
    for s in JS.children(block)
        JS.kind(s) == JS.K"=" || continue
        lhs = JS.children(s)[1]
        JS.kind(lhs) in (JS.K"Identifier", JS.K"::") || continue
        push!(
            out,
            Finding(
                line_of(s),
                "warn",
                "nonconst-global",
                "module-level global '$(name_text(JS.kind(lhs) == JS.K"::" ? JS.children(lhs)[1] : lhs))' is not const; " *
                "use const, or keep the state in a struct",
            ),
        )
    end
end

has_module(n) =
    !JS.is_leaf(n) && (JS.kind(n) == JS.K"module" || any(has_module, JS.children(n)))

#######################################################################
# Driver

function allowed(lines, f::Finding)
    1 <= f.line <= length(lines) || return false
    return occursin("julia-audit: allow-$(f.rule)", lines[f.line])
end

function collect_definitions!(defs, n, flags)
    JS.is_leaf(n) && return
    if JS.kind(n) in (JS.K"function", JS.K"macro")
        d = measure_definition(n, flags)
        d === nothing || push!(defs, d)
    end
    for c in JS.children(n)
        collect_definitions!(defs, c, flags)
    end
end

function audit_file(path, library_default)
    text = try
        read(path, String)
    catch e
        println("ERR\t", path, "\t", clean(sprint(showerror, e)))
        return
    end
    lines = split(text, '\n')
    tree = try
        JS.parseall(JS.SyntaxNode, text; filename = path)
    catch e
        println("ERR\t", path, "\t", clean(first(split(sprint(showerror, e), '\n'))))
        return
    end
    library = library_default || has_module(tree)
    println("FILE\t", path, "\t", length(lines), "\t", library ? 1 : 0)

    flags = code_line_flags(lines)
    resize!(flags, max(length(flags), last_line_of(tree)))
    defs = Tuple[]
    collect_definitions!(defs, tree, flags)
    for (name, first_l, last_l, body, depth, cog, cyc, args) in defs
        println(
            "DEF\t",
            path,
            "\t",
            clean(name),
            "\t",
            first_l,
            "\t",
            last_l,
            "\t",
            body,
            "\t",
            depth,
            "\t",
            cog,
            "\t",
            cyc,
            "\t",
            args,
        )
    end

    findings = Finding[]
    collect_findings!(
        findings,
        tree,
        (in_function = false, library = library, module_level = false),
    )
    for f in sort(findings; by = f -> f.line)
        allowed(lines, f) && continue
        println(
            "FIND\t",
            path,
            "\t",
            f.line,
            "\t",
            f.severity,
            "\t",
            f.rule,
            "\t",
            clean(f.message),
        )
    end
end

function main(args)
    library_default = false
    for arg in args
        if arg == "--library"
            library_default = true
        elseif arg == "--script"
            library_default = false
        else
            audit_file(arg, library_default)
        end
    end
end

main(ARGS)
