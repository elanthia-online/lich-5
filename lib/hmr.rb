## hot module reloading
module HMR
  def self.clear_cache
    Gem.clear_paths
  end

  def self.loaded
    $LOADED_FEATURES.select { |path| path.end_with?(".rb") }
  end

  def self.reload(pattern)
    self.clear_cache
    self.loaded.grep(pattern).each { |file|
      begin
        load(file)
        _respond "<b>[lich.hmr] reloaded %s</b>" % file
      rescue => exception
        respond exception
        respond exception.backtrace.join("\n")
      end
    }
  end
end
