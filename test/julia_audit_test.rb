# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'

# Acceptance tests for julia/bin/julia-audit and its Julia metrics helper.
# They need Julia >= 1.10 on PATH (the helper uses the parser inside Julia) and are
# skipped otherwise.
class JuliaAuditTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  AUDIT = File.join(ROOT, 'julia', 'bin', 'julia-audit')
  HELPER = File.join(ROOT, 'julia', 'bin', 'julia-ast-metrics.jl')

  def setup
    skip 'julia is not on PATH' unless system('julia', '--version', out: File::NULL, err: File::NULL)
    @tmp = Dir.mktmpdir('julia-audit-test')
    @src = File.join(@tmp, 'src')
    FileUtils.mkdir_p(@src)
    File.write(File.join(@tmp, 'Project.toml'), "name = \"Fixture\"\nuuid = \"00000000-0000-0000-0000-000000000001\"\n")
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp
  end

  def source(name, text)
    path = File.join(@src, name)
    File.write(path, text)
    path
  end

  def audit(*, chdir: @tmp)
    Open3.capture3([AUDIT, AUDIT], *, chdir: chdir)
  end

  def metrics(path)
    out, err, status = Open3.capture3('julia', '--startup-file=no', HELPER, path)
    assert status.success?, err
    out.lines.map { |line| line.chomp.split("\t") }.group_by(&:first)
  end

  def definition(path, name)
    row = metrics(path).fetch('DEF', []).find { |fields| fields[2] == name }
    refute_nil row, "no definition #{name}"
    { lines: row[5].to_i, depth: row[6].to_i, cognitive: row[7].to_i, cyclomatic: row[8].to_i, args: row[9].to_i }
  end

  def plain(text)
    text.gsub(/\e\[[0-9;]*m/, '')
  end

  # --- Metric definitions ------------------------------------------------------

  def test_nesting_depth_and_cognitive_complexity_follow_the_model
    path = source('a.jl', <<~JULIA)
      function nested(x)
          if x > 1
              for i in 1:x
                  if i > 2
                      x += 1
                  end
              end
          elseif x < 0
              return 0
          end
          return x && true || false
      end
    JULIA
    m = definition(path, 'nested')
    assert_equal 3, m[:depth]
    # if 1, for 1+1, inner if 1+2, elseif 1, '||' 1, '&&' 1
    assert_equal 9, m[:cognitive]
    assert_equal 7, m[:cyclomatic]
  end

  def test_runs_of_the_same_boolean_operator_count_once
    path = source('b.jl', "f(a, b, c, d) = a && b && c\ng(a, b, c, d) = a && b || c && d\n")
    assert_equal 1, definition(path, 'f')[:cognitive]
    assert_equal 3, definition(path, 'g')[:cognitive]
  end

  def test_closures_nest_but_resource_blocks_do_not
    path = source('c.jl', <<~JULIA)
      function closure(v)
          return map(x -> x > 1 ? 1 : 2, v)
      end

      function resource(path)
          open(path) do io
              readline(io)
          end
      end
    JULIA
    assert_equal 2, definition(path, 'closure')[:depth]
    assert_equal 0, definition(path, 'resource')[:depth]
  end

  def test_nested_definitions_are_measured_separately
    path = source('d.jl', <<~JULIA)
      function outer(x)
          function inner(y)
              if y > 0
                  return 1
              end
              return 0
          end
          return inner(x)
      end
    JULIA
    assert_equal 0, definition(path, 'outer')[:cognitive]
    assert_equal 1, definition(path, 'inner')[:cognitive]
  end

  def test_signature_lines_and_comments_do_not_count_as_body_lines
    path = source('e.jl', <<~JULIA)
      function wide(
          a::Int,
          b::Int;
          c = 1,
      )
          # a comment

          return a + b + c
      end
    JULIA
    m = definition(path, 'wide')
    assert_equal 1, m[:lines]
    assert_equal 3, m[:args]
  end

  # --- Policy ------------------------------------------------------------------

  def test_compliant_code_passes
    source('ok.jl', "function ok(x)\n    return x + 1\nend\n")
    out, err, status = audit
    assert status.success?, err
    assert_match(/Code metrics check passed/, plain(out))
  end

  def test_depth_above_the_limit_fails_unless_raised
    deep = (1..5).map { |i| "#{'    ' * i}if x > #{i}" }.join("\n")
    close = (1..5).map { |i| "#{'    ' * (6 - i)}end" }.join("\n")
    source('deep.jl', "function deep(x)\n#{deep}\n#{'    ' * 6}x += 1\n#{close}\n    return x\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/depth 5 > 4/, plain(out))
    _, err, relaxed = audit('--max-depth', '5', '--max-complexity', '99')
    assert relaxed.success?, err
  end

  def test_complexity_above_the_limit_fails
    branches = (1..16).map { |i| "    if x == #{i}\n        x += 1\n    end" }.join("\n")
    source('cc.jl', "function busy(x)\n#{branches}\n    return x\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/complexity 16 > 15/, plain(out))
  end

  def test_declarative_methods_may_use_the_longer_limit
    flat = (1..100).map { |i| "    v#{i} = #{i}" }.join("\n")
    source('flat.jl', "function flat()\n#{flat}\n    return v1\nend\n")
    out, err, status = audit
    assert status.success?, "#{out}#{err}"
    busy = "    x = 0\n#{(1..6).map { |i| "    if x == #{i}\n        x += 1\n    end" }.join("\n")}\n#{flat}\n"
    source('long.jl', "function long()\n#{busy}    return x\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/lines \d+ > 80/, plain(out))
  end

  def test_file_length_limits
    body = (1..30).map { |i| "const C#{i} = #{i}" }.join("\n")
    source('big.jl', "#{body}\n")
    out, _, status = audit('--soft-file-lines', '10', '--max-file-lines', '20')
    refute status.success?
    assert_match(/exceeds hard limit of 20/, plain(out))
    source('big.jl', "# julia-audit: allow-long-file\n#{body}\n")
    _, err, status = audit('--soft-file-lines', '10', '--max-file-lines', '20')
    assert status.success?, err
  end

  def test_tests_are_excluded_unless_requested
    FileUtils.mkdir_p(File.join(@tmp, 'test'))
    File.write(File.join(@tmp, 'test', 'runtests.jl'), "function bad(x)\n    try\n        x\n    catch\n    end\nend\n")
    source('ok.jl', "ok(x) = x\n")
    _, err, status = audit
    assert status.success?, err
    _, _, status = audit('--include-tests')
    refute status.success?
  end

  # --- Idiom and trap rules ----------------------------------------------------

  def test_else_after_terminal_is_a_warning_that_strict_mode_fails
    source('else.jl', "function f(x)\n    if x\n        return 1\n    else\n        return 2\n    end\nend\n")
    out, _, status = audit
    assert status.success?
    assert_match(/else-after-terminal/, plain(out))
    _, _, strict = audit('--strict')
    refute strict.success?
  end

  def test_swallowed_exceptions_are_traps
    source('catch.jl', "function f()\n    try\n        error(\"x\")\n    catch\n    end\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/\[swallowed-exception\]/, plain(out))
  end

  def test_exit_in_library_code_is_a_trap_but_not_in_scripts
    source('lib.jl', "function f(x)\n    x < 0 && exit(1)\n    return x\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/\[exit-in-library\]/, plain(out))
    FileUtils.rm_f(File.join(@src, 'lib.jl'))
    script = File.join(@tmp, 'tool.jl')
    File.write(script, "#!/usr/bin/env julia\nfunction main(x)\n    x < 0 && exit(1)\nend\n")
    _, err, ok = audit(script)
    assert ok.success?, err
  end

  def test_fastmath_requires_an_allow_marker
    source('fm.jl', "function f(v)\n    s = 0.0\n    for x in v\n        @fastmath s += x\n    end\n    return s\nend\n")
    out, _, status = audit
    refute status.success?
    assert_match(/\[fastmath\]/, plain(out))
    marked = "        @fastmath s += x # julia-audit: allow-fastmath\n"
    source('fm.jl', "function f(v)\n    s = 0.0\n    for x in v\n#{marked}    end\n    return s\nend\n")
    _, err, status = audit
    assert status.success?, err
  end

  def test_runtime_eval_and_function_globals_are_traps
    source('ev.jl', "function f(x)\n    global state = x\n    return eval(:(1 + 1))\nend\n")
    out, _, status = audit
    refute status.success?
    text = plain(out)
    assert_match(/\[global-in-function\]/, text)
    assert_match(/\[runtime-eval\]/, text)
  end

  def test_struct_fields_and_module_globals_are_style_warnings
    source('m.jl', "module M\ncounter = 0\nconst OK = 1\nstruct S\n    a\n    b::Int\nend\nend\n")
    out, _, status = audit
    assert status.success?
    text = plain(out)
    assert_match(/\[untyped-field\].*'a'/, text)
    assert_match(/\[nonconst-global\].*'counter'/, text)
    refute_match(/'OK'/, text)
  end

  def test_argument_count_warns
    source('args.jl', "many(a, b, c, d, e, f) = a\n")
    out, _, status = audit
    assert status.success?
    assert_match(/many takes 6 arguments/, plain(out))
  end

  # --- Failures ----------------------------------------------------------------

  def test_syntax_errors_fail_the_audit
    source('bad.jl', "function f(\n")
    out, _, status = audit
    refute status.success?
    assert_match(/Parse error/, plain(out))
  end

  def test_missing_targets_and_missing_julia_are_reported
    _, err, status = audit('nonexistent_dir')
    refute status.success?
    assert_match(/no Julia sources/, err)
    source('ok.jl', "ok(x) = x\n")
    env_path = ENV.fetch('PATH')
    out, err, status = Open3.capture3({ 'PATH' => RbConfig.ruby.sub(%r{/[^/]*\z}, '') }, RbConfig.ruby, AUDIT, chdir: @tmp)
    refute status.success?, "#{out}#{err}#{env_path}"
    assert_match(/required analyzer missing: julia/, err)
  end
end
