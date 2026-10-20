# julia-checks.jl - runs one analysis for julia-static-analysis.
#
# Usage: julia --startup-file=no [--project=ROOT] julia-checks.jl CHECK [ARG...]
#
#   syntax  FILE...   every file must parse (Base.JuliaSyntax)
#   format  FILE...   every file must already be formatted (JuliaFormatter, project style)
#   jet     ROOT      JET.report_package on the project's module
#   imports ROOT      ExplicitImports hygiene checks on the project's module
#   aqua    ROOT      Aqua.test_all on the project's module
#
# Exit status 0 means the check passed. The analysis packages are found through
# JULIA_LOAD_PATH, which julia-static-analysis points at the standards tools environment.

using TOML

fail(msg) = (println(stderr, msg); exit(1))

function project_module(root)
    project = joinpath(root, "Project.toml")
    isfile(project) || fail("no Project.toml in $root")
    name = get(TOML.parsefile(project), "name", nothing)
    name === nothing && fail("Project.toml in $root has no name")
    return Symbol(name)
end

function load_project(root)
    name = project_module(root)
    try
        return Base.require(Main, name)
    catch e
        fail(
            "cannot load $name (is the project instantiated?): " *
            first(split(sprint(showerror, e), '\n')),
        )
    end
end

function need(pkg::Symbol)
    try
        return Base.require(Main, pkg)
    catch
        fail(
            "required analyzer missing: $pkg; bootstrap separately with julia-install-tools",
        )
    end
end

#######################################################################

function check_syntax(files)
    JS = Base.JuliaSyntax
    bad = 0
    for f in files
        try
            JS.parseall(JS.SyntaxNode, read(f, String); filename = f)
        catch e
            bad += 1
            println("syntax error: $f\n  ", first(split(sprint(showerror, e), '\n')))
        end
    end
    bad == 0 || exit(1)
    println("Syntax passed: $(length(files)) files")
end

function check_format(files)
    JF = need(:JuliaFormatter)
    unformatted = [
        f for f in files if
        !Base.invokelatest(JF.format_file, f; overwrite = false, verbose = false)
    ]
    isempty(unformatted) ||
        fail("not formatted (run JuliaFormatter):\n  " * join(unformatted, "\n  "))
    println("Format passed: $(length(files)) files")
end

function check_jet(root)
    JET = need(:JET)
    mod = load_project(root)
    result = Base.invokelatest(
        JET.report_package,
        mod;
        target_modules = (mod,),
        toplevel_logger = nothing,
    )
    reports = Base.invokelatest(JET.get_reports, result)
    isempty(reports) && return println("JET passed")
    seen = Set{String}()
    for r in reports
        site = r.vst[1]
        text = Base.invokelatest(sprint, JET.print_report_message, r)
        line = "$(site.file):$(site.line) " * first(split(text, '\n'))
        line in seen || (push!(seen, line); println(line))
    end
    fail("JET found $(length(seen)) problems")
end

# Hygiene checks that must pass, and advisory ones that are only reported.
const ENFORCED_IMPORT_CHECKS = (
    :check_no_stale_explicit_imports,
    :check_all_explicit_imports_via_owners,
    :check_all_qualified_accesses_via_owners,
    :check_no_self_qualified_accesses,
)
const ADVISORY_IMPORT_CHECKS =
    (:check_no_implicit_imports, :check_all_explicit_imports_are_public)

function run_import_check(EI, name, mod)
    try
        Base.invokelatest(getfield(EI, name), mod)
        return nothing
    catch e
        return string(name) *
               ": " *
               join(first(split(sprint(showerror, e), '\n'), 6), "\n    ")
    end
end

function check_imports(root)
    EI = need(:ExplicitImports)
    mod = load_project(root)
    for name in ADVISORY_IMPORT_CHECKS
        msg = run_import_check(EI, name, mod)
        msg === nothing || println("advisory  ", msg)
    end
    problems =
        filter(!isnothing, [run_import_check(EI, n, mod) for n in ENFORCED_IMPORT_CHECKS])
    isempty(problems) || fail(join(problems, "\n"))
    println("Imports passed")
end

function check_aqua(root)
    Aqua = need(:Aqua)
    Test = need(:Test)
    mod = load_project(root)
    try
        Base.invokelatest(Aqua.test_all, mod)
    catch e
        fail("Aqua failed: " * first(split(sprint(showerror, e), '\n')))
    end
    println("Aqua passed")
end

#######################################################################

const CHECKS = Dict(
    "syntax" => check_syntax,
    "format" => check_format,
    "jet" => check_jet,
    "imports" => check_imports,
    "aqua" => check_aqua,
)

function main(args)
    isempty(args) && fail("usage: julia-checks.jl syntax|format|jet|imports|aqua ARG...")
    check = get(CHECKS, args[1], nothing)
    check === nothing && fail("unknown check $(args[1])")
    arg = args[1] in ("syntax", "format") ? args[2:end] : args[2]
    check(arg)
end

main(ARGS)
