
require 'tempfile'
require 'json'
require 'fileutils'

module Frontend
  @session_file = nil
  @tmp_session_dir = File.join Dir.tmpdir, "simutronics", "sessions"

  def self.create_session_file(name, host, port)
    FileUtils.mkdir_p @tmp_session_dir
    @session_file = File.join(@tmp_session_dir, "%s.session" % name.downcase.capitalize)
    session_descriptor = {name: name, host: host, port: port}.to_json
    puts "writing session descriptor to %s\n%s" % [@session_file, session_descriptor]
    File.open(@session_file, "w") do |fd|
      fd << session_descriptor
    end
  end

  def self.cleanup_session_file()
    return if @session_file.nil?
    File.delete(@session_file) if File.exist? @session_file
  end
end
