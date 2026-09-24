# frozen_string_literal: true

require 'uri'
require_relative 'errors'

module Lich
  module WebUI
    # Session-scoped, owner-attributed file roots with realpath containment.
    class FileService
      EXTENSIONS = {
        '.png' => 'image/png', '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg',
        '.gif' => 'image/gif', '.webp' => 'image/webp',
      }.freeze
      ALIAS_PATTERN = /\A[A-Za-z0-9_-]{1,128}\z/

      def initialize(application_roots:, user_allowlist: [], logger: nil)
        @application_roots = resolve_roots(application_roots)
        @user_allowlist = resolve_roots(user_allowlist)
        @logger = logger || proc { |_level, _message| }
        @routes = {}
        @mutex = Mutex.new
      end

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

      def unregister(alias_name, owner:)
        @mutex.synchronize do
          route = @routes[alias_name.to_s]
          return false unless route && route[:owner].equal?(owner)

          @routes.delete(alias_name.to_s)
          true
        end
      end

      def revoke_owner(owner)
        @mutex.synchronize { @routes.delete_if { |_name, route| route[:owner].equal?(owner) } }
      end

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

      def resolve_url(url)
        match = url.to_s.match(%r{\A/files/([A-Za-z0-9_-]{1,128})/(.+)\z})
        return nil unless match

        resolve(match[1], match[2])
      end

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
