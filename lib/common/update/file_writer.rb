# frozen_string_literal: true

module Lich
  module Util
    module Update
      module FileWriter
        def self.safe_write(path, content)
          tmp = "#{path}.tmp"
          old = "#{path}.old"
          File.rename(path, old) if File.exist?(path)
          begin
            File.binwrite(tmp, content)
            File.rename(tmp, path)
            File.delete(old) if File.exist?(old)
          rescue StandardError
            File.rename(old, path) if File.exist?(old)
            File.delete(tmp) if File.exist?(tmp)
            raise
          end
        end

        def self.build_local_sha_map(dir, pattern = '*.lic')
          Dir[File.join(dir, pattern)].each_with_object({}) do |path, map|
            body = File.binread(path)
            map[File.basename(path)] = Digest::SHA1.hexdigest("blob #{body.size}\0#{body}")
          end
        end
      end
    end
  end
end
