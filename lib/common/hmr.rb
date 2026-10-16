## hot module reloading
require 'rbconfig'

module Lich
  module Common
    module HMR
      # What a reload of one file may raise and still leave Lich running.
      # StandardError alone misses the common failures: a typo in the edited
      # file is a SyntaxError (a ScriptError), and a file whose body is not
      # safe to re-run can overflow the stack (SystemStackError). Either one
      # used to escape into the client thread and stop it reading input.
      RELOAD_ERRORS = [StandardError, ScriptError, SystemStackError].freeze

      # RbConfig keys for Ruby's own library directories.
      RUBY_LIB_DIR_KEYS = %w[rubylibdir rubyarchdir sitelibdir sitearchdir vendorlibdir vendorarchdir].freeze

      def self.clear_cache
        Gem.clear_paths
      end

      def self.msg(message)
        return _respond message if defined?(:_respond) && message.include?("<b>")
        return respond message if defined?(:respond)
        puts message
      end

      def self.loaded
        $LOADED_FEATURES.select { |path| path.end_with?(".rb") }
      end

      # Directories holding Ruby's standard library and installed gems,
      # resolved through symlinks so they compare with resolved file paths.
      #
      # @return [Array<String>] each ending in a path separator
      def self.foreign_roots
        dirs = RUBY_LIB_DIR_KEYS.map { |key| RbConfig::CONFIG[key] }
        dirs.concat(Gem.path)
        dirs.concat(Gem.loaded_specs.values.map(&:full_gem_path))
        dirs.compact.reject(&:empty?).filter_map do |dir|
          File.join(File.realpath(dir), '')
        rescue SystemCallError
          nil
        end.uniq
      end

      # True for a loaded file that is not Lich's to reload: part of Ruby
      # itself or of an installed gem. Their bodies are not written to be
      # re-run; reloading rexml (which `;hmr xml` matches) overflows the stack
      # and leaves REXML broken for the rest of the session.
      #
      # @param path [String] a $LOADED_FEATURES entry
      # @param roots [Array<String>] from {foreign_roots}
      # @return [Boolean]
      def self.foreign?(path, roots = foreign_roots)
        # Ruby records some built-in features (thread.rb, set.rb) without a
        # path; load would resolve them against $LOAD_PATH.
        return true unless File.absolute_path?(path)

        real = begin
          File.realpath(path)
        rescue SystemCallError
          path
        end
        roots.any? { |root| real.start_with?(root) }
      end

      def self.reload(pattern)
        self.clear_cache
        matched = self.loaded.grep(pattern)
        roots = self.foreign_roots unless matched.empty?
        skipped, loaded_paths = matched.partition { |file| self.foreign?(file, roots) }
        unless skipped.empty?
          self.msg "<b>[lich.hmr] skipped %d file(s) that belong to Ruby or an installed gem</b>" % skipped.size
        end
        unless loaded_paths.empty?
          loaded_paths.each { |file|
            begin
              load(file)
              self.msg "<b>[lich.hmr] reloaded %s</b>" % file
            rescue *RELOAD_ERRORS => exception
              self.msg exception.message
              self.msg exception.backtrace.join("\n")
            end
          }
        else
          self.msg "<b>[lich.hmr] nothing matching regex pattern: %s</b>" % pattern.source if skipped.empty?
        end
      end
    end
  end
end
