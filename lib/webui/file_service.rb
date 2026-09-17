# frozen_string_literal: true

require 'uri'
require_relative 'errors'

module Lich
  module WebUI
    # Session-scoped, owner-attributed file roots with realpath containment.
    #
    # An owner registers a directory under an alias and gets a URL prefix
    # back; the server resolves `/files/<alias>/<path>` requests through
    # {#resolve_url}. A root is accepted only inside the application roots,
    # the player's allowlist, or the owner's own script directory, and every
    # resolved file must stay inside its root after symlinks are followed.
    class FileService
      # The file types that may be served, by extension.
      EXTENSIONS = {
        '.png' => 'image/png', '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif', '.webp' => 'image/webp',
      }.freeze
      # The syntax an alias must have.
      ALIAS_PATTERN = /\A[A-Za-z0-9_-]{1,128}\z/

      # Builds a service with no routes.
      #
      # @param application_roots [Array<String>] directories any owner may serve from
      # @param user_allowlist [Array<String>] extra directories the player permits
      # @param logger [#call, nil] receives `(level, message)`; silent when nil
      # @return [FileService] the service
      # @raise [ArgumentError] when a root is not an existing directory
      def initialize(application_roots:, user_allowlist: [], logger: nil)
        @application_roots = resolve_roots(application_roots)
        @user_allowlist = resolve_roots(user_allowlist)
        @logger = logger || proc { |_level, _message| }
        @routes = {}
        @mutex = Mutex.new
      end

      # Registers a directory an owner may serve files from.
      #
      # @param alias_name [String, Symbol] the URL alias, matching {ALIAS_PATTERN}
      # @param directory [String] the directory to serve
      # @param owner [Object] the registering owner
      # @param script_root [String, nil] the owner's own directory, permitted in addition to the allowlists
      # @return [String] the URL prefix, `/files/<alias>/`
      # @raise [ArgumentError] when the alias syntax is invalid, the owner is missing, or the directory does
      #   not resolve
      # @raise [Error] when the directory is outside every permitted root
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
          @routes[alias_string] = { root: root, owner: owner, owner_id: owner.object_id }
        end
        "/files/#{alias_string}/"
      end

      # Removes an alias, but only for the owner that registered it.
      #
      # @param alias_name [String, Symbol] the alias
      # @param owner [Object] the owner claiming it
      # @return [Boolean] whether a route was removed
      def unregister(alias_name, owner:)
        @mutex.synchronize do
          route = @routes[alias_name.to_s]
          return false unless route && route[:owner].equal?(owner)

          @routes.delete(alias_name.to_s)
          true
        end
      end

      # Removes every alias an owner registered.
      #
      # @param owner [Object] the owner
      # @return [Hash] the remaining routes
      def revoke_owner(owner)
        @mutex.synchronize { @routes.delete_if { |_name, route| route[:owner].equal?(owner) } }
      end

      # Resolves an alias and a URL-encoded relative path to a servable file.
      #
      # @param alias_name [String, Symbol] the alias
      # @param encoded_relative_path [String] the percent-encoded path under the alias
      # @return [Array(String, String, String), nil] the real path, content type and owner label, or nil
      #   when the alias is unknown, the type is not servable, or the path escapes or is not a file
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

      # Resolves a `/files/<alias>/<path>` request path; see {#resolve}.
      #
      # @param url [String, #to_s] the request path
      # @return [Array(String, String, String), nil] as {#resolve}, or nil when the path has another shape
      def resolve_url(url)
        match = url.to_s.match(%r{\A/files/([A-Za-z0-9_-]{1,128})/(.+)\z})
        return nil unless match

        resolve(match[1], match[2])
      end

      # Removes every route.
      #
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

      def within?(candidate, root, allow_root:)
        candidate == root ? allow_root : candidate.start_with?("#{root}#{File::SEPARATOR}")
      end

      def owner_label(owner)
        return owner.webui_owner_id if owner.respond_to?(:webui_owner_id)
        return owner.name if owner.respond_to?(:name) && owner.name

        "#{owner.class}:#{owner.object_id}"
      end

      def log(level, message)
        @logger.call(level, message)
      rescue StandardError
        nil
      end
    end
  end
end
