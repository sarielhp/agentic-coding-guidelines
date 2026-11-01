# frozen_string_literal: true

# Small, conservative source scanner shared by the formatter and checker.
module TexSource
  VERBATIM_MARKER = /\\(begin|end)\{(verbatim\*?|Verbatim|lstlisting|minted|comment)\}/
  OPAQUE_COMMAND = /\\(?:verb\*?|lstinline|mintinline|url|path|nolinkurl)(?![A-Za-z])/

  def self.escaped?(text, index)
    count = 0
    index -= 1
    while index >= 0 && text[index] == '\\'
      count += 1
      index -= 1
    end
    count.odd?
  end

  def self.code_and_comment(line)
    line.each_char.with_index do |character, index|
      next unless character == '%' && !escaped?(line, index)

      return [line[0...index], line[index..]]
    end
    [line, '']
  end

  def self.opaque_command?(line)
    line.to_enum(:scan, OPAQUE_COMMAND).any? do
      !escaped?(line, Regexp.last_match.begin(0))
    end
  end

  def self.protected_lines(source)
    environment = nil
    source.lines.map do |line|
      code = environment ? line : code_and_comment(line).first
      next true if opaque_command?(code)

      inside = !environment.nil?
      environment, marker_found = environment_after(code, environment)
      inside || marker_found
    end
  end

  def self.environment_after(code, environment)
    marker_found = false
    code.to_enum(:scan, VERBATIM_MARKER).each do
      match = Regexp.last_match
      next if escaped?(code, match.begin(0))

      marker_found = true
      environment = match[2] if match[1] == 'begin' && environment.nil?
      environment = nil if match[1] == 'end' && environment == match[2]
    end
    [environment, marker_found]
  end
end
