# frozen_string_literal: true

require_relative '../../spec_helper'
require 'securerandom'

# Load production code
require "common/hmr"

module HMR
  module Helpers
    # Use unique filenames per test to avoid $LOADED_FEATURES pollution
    def self.unique_filename(suffix)
      File.join(Dir.tmpdir, "hmr-test-#{suffix}-#{::SecureRandom.hex(4)}.rb")
    end

    First = <<~RUBY
      module HMR
        Test = 1
      end
    RUBY

    Second = <<~RUBY
      module HMR
        Test = 2
      end
    RUBY
  end
end

RSpec.describe HMR, "#loaded" do
  context "can tell what has been loaded" do
    it "can find itself loaded" do
      expect(Lich::Common::HMR.loaded.any?(%r{/lib/common/hmr\.rb$})).to be_truthy
    end

    it "can tell something has been freshly loaded" do
      filename = HMR::Helpers.unique_filename("freshly-loaded")
      expect(Lich::Common::HMR.loaded.any?(filename)).to be_falsy

      File.write(filename, HMR::Helpers::First)
      require(filename)

      expect(Lich::Common::HMR.loaded.any?(filename)).to be_truthy
    end
  end
end

RSpec.describe HMR, "#reload" do
  context "can reload a module" do
    it "can find itself loaded" do
      filename = HMR::Helpers.unique_filename("reload")
      File.write(filename, HMR::Helpers::First)
      require(filename)
      expect(Lich::Common::HMR.loaded.any?(filename)).to be_truthy
      expect(HMR::Test).to eq(1)
      File.write(filename, HMR::Helpers::Second)
      Lich::Common::HMR.reload(filename)
      expect(HMR::Test).to eq(2)
    end
  end
end

RSpec.describe HMR, "#reload error handling" do
  let(:messages) { [] }

  before do
    allow(Lich::Common::HMR).to receive(:msg) { |m| messages << m }
  end

  def loaded_file(suffix, body)
    filename = HMR::Helpers.unique_filename(suffix)
    File.write(filename, body)
    require(filename)
    filename
  end

  # A typo in the file being edited is the most common reload failure.
  # SyntaxError is a ScriptError, not a StandardError, so a bare rescue
  # let it escape into the client thread.
  it "reports a SyntaxError in the reloaded file instead of raising it" do
    filename = loaded_file("syntax", HMR::Helpers::First)
    File.write(filename, "module HMR\n  def broken(\nend\n")

    expect { Lich::Common::HMR.reload(filename) }.not_to raise_error
    expect(messages.join("\n")).to match(/syntax/i)
    expect(messages).not_to include(a_string_matching(/reloaded #{Regexp.escape(filename)}/))
  end

  it "reports a SystemStackError raised while reloading instead of raising it" do
    filename = loaded_file("stack", HMR::Helpers::First)
    File.write(filename, <<~RUBY)
      module HMR
        def self.hmr_spec_recurse(depth) = hmr_spec_recurse(depth + 1)
        hmr_spec_recurse(0)
      end
    RUBY

    expect { Lich::Common::HMR.reload(filename) }.not_to raise_error
    expect(messages.join("\n")).to include("stack level too deep")
  end

  # A stack overflow's backtrace repeats the recursing frame ~10,000 times.
  # Printing all of it floods the frontend with hundreds of KB of one line.
  it "caps the backtrace it prints for a SystemStackError" do
    filename = loaded_file("stack-cap", HMR::Helpers::First)
    File.write(filename, <<~RUBY)
      module HMR
        def self.hmr_spec_recurse_cap(depth) = hmr_spec_recurse_cap(depth + 1)
        hmr_spec_recurse_cap(0)
      end
    RUBY

    Lich::Common::HMR.reload(filename)

    printed = messages.join("\n").lines
    expect(printed.size).to be < 50
    expect(printed.last).to match(/\d+ more backtrace lines/)
  end

  it "still prints the failing file's own frame first" do
    filename = loaded_file("short-trace", HMR::Helpers::First)
    File.write(filename, "module HMR\n  raise ArgumentError, 'hmr spec boom'\nend\n")

    Lich::Common::HMR.reload(filename)

    expect(messages).to include("hmr spec boom")
    expect(messages[messages.index("hmr spec boom") + 1].lines.first).to start_with("#{filename}:2")
  end

  it "prints a backtrace within the cap in full" do
    trace = Array.new(Lich::Common::HMR::BACKTRACE_LINES) { |i| "frame#{i}.rb:1" }

    expect(Lich::Common::HMR.format_backtrace(trace)).to eq(trace.join("\n"))
    expect(Lich::Common::HMR.format_backtrace(nil)).to eq("")
  end

  it "keeps reloading the remaining files after one fails" do
    bad = loaded_file("bad-first", HMR::Helpers::First)
    good = loaded_file("good-second", "module HMR\n  TestAfterFailure = 1\nend\n")
    File.write(bad, "module HMR\n  def broken(\nend\n")
    File.write(good, "module HMR\n  remove_const(:TestAfterFailure)\n  TestAfterFailure = 2\nend\n")

    Lich::Common::HMR.reload(Regexp.union(bad, good))

    expect(HMR::TestAfterFailure).to eq(2)
  end
end

RSpec.describe HMR, "#reload candidate selection" do
  let(:messages) { [] }

  before do
    require 'rexml/document'
    allow(Lich::Common::HMR).to receive(:msg) { |m| messages << m }
    # Never let a regression really re-run a gem or stdlib file in a shared
    # rspec worker; record the attempt instead.
    allow(Lich::Common::HMR).to receive(:load)
  end

  # rexml is a gem Lich loads at boot (lich.rbw, gameobj.rb). Re-running its
  # files overflows the stack in REXML::XMLDecl#encoding= and leaves REXML
  # unusable for the rest of the process, so `;hmr xml` must not touch them.
  it "does not reload files that belong to an installed gem" do
    rexml = $LOADED_FEATURES.find { |f| f.end_with?('/rexml/document.rb') }
    expect(rexml).not_to be_nil

    Lich::Common::HMR.reload(%r{/rexml/document\.rb\z})

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  it "does not reload files from Ruby's own library directory" do
    stdlib = Lich::Common::HMR.loaded.find { |f| f.start_with?(File.join(RbConfig::CONFIG['rubylibdir'], '')) }
    expect(stdlib).not_to be_nil

    Lich::Common::HMR.reload(/\A#{Regexp.escape(stdlib)}\z/)

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  it "does not reload Ruby's built-in features recorded without a path" do
    builtin = Lich::Common::HMR.loaded.find { |f| !File.absolute_path?(f) }
    skip "no path-less feature in this Ruby" if builtin.nil?

    Lich::Common::HMR.reload(/\A#{Regexp.escape(builtin)}\z/)

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  it "still reloads Lich's own files when the pattern also matches gem files" do
    Lich::Common::HMR.reload(%r{/lib/common/hmr\.rb\z|/rexml/document\.rb\z})

    expect(Lich::Common::HMR).to have_received(:load).once
    expect(Lich::Common::HMR).to have_received(:load).with(a_string_ending_with('/lib/common/hmr.rb'))
  end

  it "says why nothing was reloaded when every match is a gem or Ruby file" do
    Lich::Common::HMR.reload(%r{/rexml/document\.rb\z})

    expect(messages.join("\n")).to match(%r{skipped 1 file.*Ruby or an installed gem}i)
    expect(messages.join("\n")).not_to include("nothing matching")
  end
end

RSpec.describe HMR, "#reload path comparison" do
  let(:messages) { [] }
  let(:tmp) { File.realpath(Dir.mktmpdir("hmr-roots-")) }

  before do
    allow(Lich::Common::HMR).to receive(:msg) { |m| messages << m }
    allow(Lich::Common::HMR).to receive(:load)
  end

  after { FileUtils.rm_rf(tmp) }

  def required_file(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "# hmr path spec\n")
    require(path)
    $LOADED_FEATURES.find { |f| f.end_with?(File.basename(path)) }
  end

  def reload_basename(path)
    Lich::Common::HMR.reload(/#{Regexp.escape(File.basename(path))}\z/)
  end

  # Homebrew's Gem.path holds /opt/homebrew/lib/... while the gem files are
  # recorded under Cellar/. Both sides must resolve symlinks.
  it "skips a gem file when Gem.path names the gem dir through a symlink" do
    File.symlink(FileUtils.mkdir_p(File.join(tmp, "realgems")).first, File.join(tmp, "linkgems"))
    file = required_file(File.join(tmp, "realgems", "gems", "g-1.0", "lib", "hmr-link-root-#{SecureRandom.hex(4)}.rb"))
    allow(Gem).to receive(:path).and_return([File.join(tmp, "linkgems")])

    reload_basename(file)

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  it "skips a gem file that was required through a symlinked path" do
    real = FileUtils.mkdir_p(File.join(tmp, "realgems", "gems", "g-1.0", "lib")).first
    File.symlink(File.join(tmp, "realgems"), File.join(tmp, "linkgems"))
    name = "hmr-link-file-#{SecureRandom.hex(4)}.rb"
    File.write(File.join(real, name), "# hmr path spec\n")
    require(File.join(tmp, "linkgems", "gems", "g-1.0", "lib", name))
    allow(Gem).to receive(:path).and_return([File.join(tmp, "realgems")])

    Lich::Common::HMR.reload(/#{Regexp.escape(name)}\z/)

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  it "reloads a file in a sibling directory whose name starts with a gem dir's name" do
    file = required_file(File.join(tmp, "gemstone", "hmr-sibling-#{SecureRandom.hex(4)}.rb"))
    FileUtils.mkdir_p(File.join(tmp, "gem"))
    allow(Gem).to receive(:path).and_return([File.join(tmp, "gem")])

    reload_basename(file)

    expect(Lich::Common::HMR).to have_received(:load).with(file)
  end

  # Bundler path:/git: gems live outside Gem.path; only the activated spec
  # knows where.
  it "skips a file of an activated gem that lives outside Gem.path" do
    file = required_file(File.join(tmp, "pathgem", "lib", "hmr-pathgem-#{SecureRandom.hex(4)}.rb"))
    spec = instance_double(Gem::Specification, full_gem_path: File.join(tmp, "pathgem"))
    allow(Gem).to receive(:loaded_specs).and_return({ "pathgem" => spec })

    reload_basename(file)

    expect(Lich::Common::HMR).not_to have_received(:load)
  end

  # RbConfig's strings are BINARY. Under a home directory with a non-ASCII
  # name (rbenv/asdf/rvm keep Ruby there), comparing such a root with a
  # UTF-8 feature path that is non-ASCII too raised
  # Encoding::CompatibilityError out of reload, so no ;hmr worked at all.
  context "when Ruby and the loaded file live under a non-ASCII directory" do
    let(:home) { File.join(tmp, "jos#{0xE9.chr(Encoding::UTF_8)}") }

    before do
      rubylib = FileUtils.mkdir_p(File.join(home, "ruby", "lib")).first.b
      allow(RbConfig::CONFIG).to receive(:[]).and_call_original
      allow(RbConfig::CONFIG).to receive(:[]).with("rubylibdir").and_return(rubylib)
    end

    it "reloads a file outside Ruby's directories" do
      file = required_file(File.join(home, "lich", "hmr-nonascii-#{SecureRandom.hex(4)}.rb"))

      expect { reload_basename(file) }.not_to raise_error
      expect(Lich::Common::HMR).to have_received(:load).with(file)
    end

    it "skips a file inside Ruby's library directory" do
      file = required_file(File.join(home, "ruby", "lib", "hmr-nonascii-lib-#{SecureRandom.hex(4)}.rb"))

      expect { reload_basename(file) }.not_to raise_error
      expect(Lich::Common::HMR).not_to have_received(:load)
    end
  end

  # A loaded file deleted since has no realpath. It is not a gem file, so it
  # goes to load, whose LoadError the per-file rescue reports.
  it "does not raise for a loaded file that has since been deleted" do
    file = required_file(File.join(tmp, "gone", "hmr-deleted-#{SecureRandom.hex(4)}.rb"))
    File.delete(file)

    expect { reload_basename(file) }.not_to raise_error
    expect(Lich::Common::HMR).to have_received(:load).with(file)
  end
end
