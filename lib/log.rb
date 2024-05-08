##
## contextual logging
##
module Log
  def self.out(msg, label: :debug)
    if msg.is_a?(Exception)
      ## pretty-print exception
      _write _view(msg.message, label)
      msg.backtrace.to_a.slice(0..5).each do |frame| _write _view(frame, label) end
    else
      self._write _view(msg, label) #if Script.current.vars.include?("--debug")
    end
  end

  def self._write(line)
    if Script.current.vars.include?("--headless") or not defined?(:_respond)
      $stdout.write(line + "\n")
    elsif line.include?("<") and line.include?(">")
      respond(line)
    else
      _respond Preset.as(:debug, line)
    end
  end

  def self._view(msg, label)
    label = [Script.current.name, label].flatten.compact.join(".")
    safe = msg.inspect
    #safe = safe.gsub("<", "&lt;").gsub(">", "&gt;") if safe.include?("<") and safe.include?(">")
    "[#{label}] #{safe}"
  end

  def self.pp(msg, label = :debug)
    respond _view(msg, label)
  end

  def self.dump(*args)
    pp(*args)
  end

  module Preset
    def self.as(kind, body)
      %[<preset id="#{kind}">#{body}</preset>]
    end
  end
end
