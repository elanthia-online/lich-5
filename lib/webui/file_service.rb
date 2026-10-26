# frozen_string_literal: true

require 'uri'
require_relative 'errors'

module Lich
  module WebUI
    # Session-scoped, owner-attributed file roots with realpath containment.
    class FileService
      EXTENSIONS = {
        '.png' => 'image/png', '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif', '.webp' => 'image/webp', '.bmp' => 'image/bmp',
      }.freeze
      ALIAS_PATTERN = /\A[A-Za-z0-9_-]{1,128}\z/

      # Resolves the explicit filesystem roots allowed for later image registration.
      # @param application_roots [Array<String>] application-approved directories
      # @param user_allowlist [Array<String>] additional user-approved directories
      # @param logger [#call, nil] optional diagnostic sink
      def initialize(application_roots:, user_allowlist: [], logger: nil)
        @application_roots = resolve_roots(application_roots)
        @user_allowlist = resolve_roots(user_allowlist)
        @logger = logger || proc { |_level, _message| }
        @routes = {}
        @mutex = Mutex.new
      end

      # Registers an allowed image root without replacing another owner's route.
      # The same owner may update its alias; revocation releases it for reuse.
      # @param alias_name [String, Symbol] URL path segment unique within this service
      # @param directory [String] existing image directory
      # @param owner [Object] lifetime identity responsible for the route
      # @param script_root [String, nil] additional permitted script directory
      # @return [String] relative URL prefix for this alias
      # @raise [Error] when the root is disallowed or another owner holds the alias
      # @raise [ArgumentError] when the alias, owner or directory is invalid
      def register(alias_name, directory, owner:, script_root: nil)
        alias_string = alias_name.to_s
        raise ArgumentError, 'file alias has invalid syntax' unless alias_string.match?(ALIAS_PATTERN)
        raise ArgumentError, 'owner is required' unless owner

        root = resolve_directory(directory)
        permitted = permitted_roots(script_root).any? { |allowed| within?(root, allowed, allow_root: true) }
        unless permitted
          log(:warning, "WebUI file root refused owner=#{owner_label(owner)} reason=outside_allowlist")
          raise Error.new('file root is outside registered application, script, and user roots', owner: owner_label(owner))
        end

        @mutex.synchronize do
          existing = @routes[alias_string]
          if existing && !existing[:owner].equal?(owner)
            raise Error.new('file alias is already registered to another owner', owner: owner_label(owner))
          end
          @routes[alias_string] = { root: root, owner: owner, owner_id: owner.object_id }
        end
        "/files/#{alias_string}/"
      end

      # Revokes an alias only when it belongs to this exact owner object.
      # @return [Boolean] whether an owned registration was removed
      def unregister(alias_name, owner:)
        @mutex.synchronize do
          route = @routes[alias_name.to_s]
          return false unless route && route[:owner].equal?(owner)

          @routes.delete(alias_name.to_s)
          true
        end
      end

      # Revokes all file aliases belonging to the terminating owner.
      # @return [void]
      def revoke_owner(owner)
        @mutex.synchronize { @routes.delete_if { |_name, route| route[:owner].equal?(owner) } }
      end

      # Resolves an image route after one URL decode and realpath containment checks.
      # HTTP authentication is enforced by Server before calling this resolver.
      # @param alias_name [String] registered route alias
      # @param encoded_relative_path [String] URL-encoded path beneath the alias root
      # @return [Array, nil] path, MIME type, and owner label; nil for an invalid/missing file
      def resolve(alias_name, encoded_relative_path)
        route = @mutex.synchronize { @routes[alias_name.to_s]&.dup }
        return nil unless route

        relative_path = URI::DEFAULT_PARSER.unescape(encoded_relative_path.to_s)
        return nil if relative_path.empty? || relative_path.include?("\0")

        content_type = EXTENSIONS[File.extname(relative_path).downcase]
        return nil unless content_type

        candidate = File.realpath(File.expand_path(relative_path, route[:root]))
        return nil unless within?(candidate, route[:root], allow_root: false)
        return nil unless File.file?(candidate)

        [candidate, content_type, owner_label(route[:owner])]
      rescue ArgumentError, Errno::ENOENT, Errno::EACCES
        nil
      end

      # Resolves a /files/ URL through the same bounded alias/path checks.
      # @return [Array, nil] path, MIME type, and owner label, or nil
      def resolve_url(url)
        match = url.to_s.match(%r{\A/files/([A-Za-z0-9_-]{1,128})/(.+)\z})
        return nil unless match

        resolve(match[1], match[2])
      end

      # Revokes all image routes during host shutdown.
      # @return [void]
      def clear!
        @mutex.synchronize { @routes.clear }
      end

      private

      def permitted_roots(script_root)
        roots = @application_roots + @user_allowlist
        roots << resolve_directory(script_root) if script_root
        roots
      end

      def resolve_roots(roots)
        Array(roots).map { |root| resolve_directory(root) }.freeze
      end

      def resolve_directory(directory)
        root = File.realpath(directory.to_s)
        raise ArgumentError, "file root is not a directory: #{directory}" unless File.directory?(root)

        root
      rescue Errno::ENOENT, Errno::EACCES
        raise ArgumentError, "file root does not resolve: #{directory}"
      end

      # Checks resolved paths at a directory boundary, including filesystem roots.
      # @param candidate [String] canonical path to test
      # @param root [String] canonical allowed directory
      # @param allow_root [Boolean] whether the directory itself is allowed
      # @return [Boolean] whether the path is contained
      # @api private
      def within?(candidate, root, allow_root:)
        prefix = root.end_with?(File::SEPARATOR) ? root : "#{root}#{File::SEPARATOR}"
        candidate == root ? allow_root : candidate.start_with?(prefix)
      end

      def owner_label(owner)
        Diagnostics.owner_label(owner)
      end

      def log(level, message)
        Diagnostics.log(@logger, level, message)
      end
    end
  end
end
