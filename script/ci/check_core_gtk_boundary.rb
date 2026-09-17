#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists every core Ruby file that still names the GTK runtime.
#
# Adapted from lich-6's script/ci/check_core_gtk_boundary.rb. Core is
# everything under lib/ plus lich.rbw, minus the GTK directories: the GTK
# launcher (lib/common/gui/) and the script-facing GTK shim
# (lib/common/script_scope/gtk/). A file counts as naming GTK when its
# Ruby tokens include a GTK constant, an identifier containing "gtk", or a
# require of a gtk path; comments do not count.
#
# While lib/common/gui/ still exists this is a WARNING: the report is
# printed and the exit status is 0. Once the GTK launcher is deleted the
# report becomes the failure list (pass --strict, or delete the
# directory, to get a non-zero exit).

require 'find'
require 'ripper'

module LichCoreGtkBoundary
  GTK_CONSTANTS = %w[Gtk GLib Gdk GdkPixbuf Pango HAVE_GTK GtkCompaction].freeze
  GTK_DIRECTORIES = %w[lib/common/gui lib/common/script_scope/gtk].freeze
  TARGETS = %w[lich.rbw lib].freeze

  module_function

  # @param root [String] repository root
  # @return [Array<String>] "path:line:token" findings, root-relative, unique and sorted
  def findings(root)
    root = File.expand_path(root)
    excluded = GTK_DIRECTORIES.map { |directory| "#{File.join(root, directory)}#{File::SEPARATOR}" }
    results = []

    TARGETS.each do |target|
      path = File.join(root, target)
      next unless File.exist?(path)

      paths = File.file?(path) ? [path] : Find.find(path)
      paths.each do |file|
        next if excluded.any? { |prefix| file.start_with?(prefix) }
        next unless File.file?(file) && (file.end_with?('.rb') || file.end_with?('.rbw'))

        relative = file.sub("#{root}#{File::SEPARATOR}", '').tr('\\', '/')
        results.concat(file_findings(file).map { |line, token| "#{relative}:#{line}:#{token}" })
      end
    end

    results.uniq.sort
  end

  # @return [Array<String>] the root-relative paths named in {findings}
  def files(root)
    findings(root).map { |finding| finding.split(':', 2).first }.uniq
  end

  # @return [Boolean] whether the GTK launcher directory is still present
  def gtk_launcher_present?(root)
    Dir.exist?(File.join(File.expand_path(root), 'lib/common/gui'))
  end

  def file_findings(file)
    source = File.read(file)
    found = []

    Ripper.lex(source).each do |position, event, token|
      next unless (event == :on_const && GTK_CONSTANTS.include?(token)) ||
                  (event == :on_ident && token.match?(/gtk/i))

      found << [position.fetch(0), token]
    end

    source.each_line.with_index(1) do |line, line_number|
      next if line.lstrip.start_with?('#')
      next unless line.match?(/\brequire(?:_relative)?\b.*['"][^'"]*(gtk|common\/gui)/i)

      found << [line_number, 'GTK require']
    end

    found
  end
end

if $PROGRAM_NAME == __FILE__
  strict = ARGV.delete('--strict')
  verbose = ARGV.delete('--verbose')
  root = ARGV.fetch(0, Dir.pwd)
  findings = LichCoreGtkBoundary.findings(root)
  warning_only = !strict && LichCoreGtkBoundary.gtk_launcher_present?(root)

  if findings.empty?
    puts 'core names no GTK runtime idiom'
  else
    label = warning_only ? 'warning' : 'error'
    puts "#{label}: GTK runtime idiom outside #{LichCoreGtkBoundary::GTK_DIRECTORIES.join(', ')}:"
    findings.group_by { |finding| finding.split(':', 2).first }.each do |file, file_findings|
      puts "  #{file} (#{file_findings.length})"
      file_findings.each { |finding| puts "    #{finding}" } if verbose
    end
  end

  exit(findings.empty? || warning_only ? 0 : 1)
end
