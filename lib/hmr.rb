## hot module reloading
module HMR
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

  def self.reload(pattern)
    self.clear_cache
    self.loaded.grep(pattern).each { |file|
      begin
        load(file)
        self.msg "<b>[lich.hmr] reloaded %s</b>" % file
      rescue => exception
        self.msg exception
        self.msg exception.backtrace.join("\n")
      end
    }
  end
end
