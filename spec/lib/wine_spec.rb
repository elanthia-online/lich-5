# frozen_string_literal: true

require 'rspec'
require 'fileutils'

# These tests verify wine.rb behavior using file content analysis
# and targeted load tests where stubbing works reliably.
RSpec.describe 'wine.rb' do
  let(:wine_file_path) { File.expand_path('../../lib/wine.rb', __dir__) }
  let(:wine_file_content) { File.read(wine_file_path) }

  describe 'file content verification' do
    it 'uses PATH scanning instead of shelling out with which/backticks' do
      expect(wine_file_content).to include('ENV.fetch(\'PATH\', \'\').split(File::PATH_SEPARATOR)')
      expect(wine_file_content).to include('File.executable?(candidate)')
      expect(wine_file_content).not_to include('which wine')
    end

    it 'skips wine detection when --without-frontend is passed' do
      expect(wine_file_content).to include("ARGV.include?('--without-frontend')")
    end

    it 'skips wine detection when --no-wine is passed' do
      expect(wine_file_content).to include('--no-wine')
    end

    it 'checks for --wine= argument to explicitly set wine path' do
      expect(wine_file_content).to include('--wine=')
    end

    it 'checks for --wine-prefix argument' do
      expect(wine_file_content).to include('--wine-prefix=')
    end

    it 'falls back to WINEPREFIX environment variable' do
      expect(wine_file_content).to include("ENV['WINEPREFIX']")
    end

    it 'falls back to $HOME/.wine' do
      expect(wine_file_content).to include("ENV['HOME'] + '/.wine'")
    end

    it 'defines Wine module only when binary and prefix exist' do
      expect(wine_file_content).to include('File.exist?($wine_bin)')
      expect(wine_file_content).to include('File.file?($wine_bin)')
      expect(wine_file_content).to include('File.exist?($wine_prefix)')
      expect(wine_file_content).to include('File.directory?($wine_prefix)')
    end

    it 'defines Wine.registry_gets method' do
      expect(wine_file_content).to include('def Wine.registry_gets')
    end

    it 'defines Wine.registry_puts method' do
      expect(wine_file_content).to include('def Wine.registry_puts')
    end
  end

  describe 'ARGV parsing with controlled load' do
    let(:temp_wine_bin) { '/tmp/wine_spec_bin' }
    let(:temp_wine_prefix) { '/tmp/wine_spec_prefix' }

    before(:each) do
      $wine_bin = nil
      $wine_prefix = nil
      Object.send(:remove_const, :Wine) if defined?(Wine)
      FileUtils.touch(temp_wine_bin)
      FileUtils.mkdir_p(temp_wine_prefix)
    end

    after(:each) do
      FileUtils.rm_f(temp_wine_bin)
      FileUtils.rm_rf(temp_wine_prefix)
      $wine_bin = nil
      $wine_prefix = nil
      Object.send(:remove_const, :Wine) if defined?(Wine)
    end

    context 'with --no-wine argument' do
      it 'sets $wine_bin to nil' do
        stub_const('ARGV', ['--no-wine'])
        load wine_file_path
        expect($wine_bin).to be_nil
      end
    end

    context 'with --without-frontend argument' do
      it 'sets $wine_bin to nil' do
        stub_const('ARGV', ['--without-frontend'])
        load wine_file_path
        expect($wine_bin).to be_nil
      end
    end

    context 'with explicit --wine= argument' do
      it 'sets $wine_bin to specified path' do
        stub_const('ARGV', ["--wine=#{temp_wine_bin}", "--wine-prefix=#{temp_wine_prefix}"])
        load wine_file_path
        expect($wine_bin).to eq(temp_wine_bin)
      end

      it 'defines Wine module when paths are valid' do
        stub_const('ARGV', ["--wine=#{temp_wine_bin}", "--wine-prefix=#{temp_wine_prefix}"])
        load wine_file_path
        expect(defined?(Wine)).to eq('constant')
        expect(Wine::BIN).to eq(temp_wine_bin)
        expect(Wine::PREFIX).to eq(temp_wine_prefix)
      end
    end

    context 'with explicit --wine-prefix argument' do
      it 'sets $wine_prefix to specified path' do
        stub_const('ARGV', ["--wine=#{temp_wine_bin}", "--wine-prefix=#{temp_wine_prefix}"])
        load wine_file_path
        expect($wine_prefix).to eq(temp_wine_prefix)
      end
    end

    context 'with both --no-wine and other arguments' do
      it 'respects --no-wine and ignores wine detection' do
        stub_const('ARGV', ['--no-wine', '--some-other-arg'])
        load wine_file_path
        expect($wine_bin).to be_nil
        expect(defined?(Wine)).to be_nil
      end
    end

    context 'with no explicit wine flags' do
      it 'finds a wine executable from PATH without shelling out' do
        path_dir = Dir.mktmpdir('wine-path')
        wine_bin = File.join(path_dir, 'wine')
        begin
          FileUtils.touch(wine_bin)
          FileUtils.chmod(0o755, wine_bin)

          original_path = ENV['PATH']
          ENV['PATH'] = path_dir
          stub_const('ARGV', [])

          load wine_file_path
          expect($wine_bin).to eq(wine_bin)
        ensure
          ENV['PATH'] = original_path
          FileUtils.rm_rf(path_dir)
        end
      end
    end
  end

  describe 'Wine module functionality' do
    let(:temp_wine_bin) { '/tmp/wine_spec_bin' }
    let(:temp_wine_prefix) { '/tmp/wine_spec_prefix' }

    before(:each) do
      $wine_bin = nil
      $wine_prefix = nil
      Object.send(:remove_const, :Wine) if defined?(Wine)
      FileUtils.touch(temp_wine_bin)
      FileUtils.mkdir_p(temp_wine_prefix)
      stub_const('ARGV', ["--wine=#{temp_wine_bin}", "--wine-prefix=#{temp_wine_prefix}"])
      load wine_file_path
    end

    after(:each) do
      FileUtils.rm_f(temp_wine_bin)
      FileUtils.rm_rf(temp_wine_prefix)
      $wine_bin = nil
      $wine_prefix = nil
      Object.send(:remove_const, :Wine) if defined?(Wine)
    end

    describe 'Wine.registry_gets' do
      let(:system_reg_content) do
        <<~REG
          WINE REGISTRY Version 2
          ;; All keys relative to \\\\Machine

          [Software\\\\Simutronics\\\\Launcher]
          "Directory"="C:\\\\Program Files\\\\Launcher"

          [Software\\\\Classes\\\\Test]
          @="default value"
        REG
      end

      it 'reads named registry values from system.reg' do
        File.write("#{temp_wine_prefix}/system.reg", system_reg_content)
        result = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\Simutronics\\Launcher\\Directory')
        expect(result).to eq('C:\\Program Files\\Launcher')
      end

      it 'reads default (@) registry values' do
        File.write("#{temp_wine_prefix}/system.reg", system_reg_content)
        result = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\Classes\\Test\\')
        expect(result).to eq('default value')
      end

      it 'returns false when key does not exist' do
        File.write("#{temp_wine_prefix}/system.reg", system_reg_content)
        result = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\NonExistent\\Key\\')
        expect(result).to eq(false)
      end

      it 'returns false for HKEY_CURRENT_USER (not implemented)' do
        File.write("#{temp_wine_prefix}/system.reg", system_reg_content)
        result = Wine.registry_gets('HKEY_CURRENT_USER\\Software\\Test\\Value')
        expect(result).to eq(false)
      end

      it 'returns false when system.reg does not exist' do
        result = Wine.registry_gets('HKEY_LOCAL_MACHINE\\Software\\Test\\Value')
        expect(result).to eq(false)
      end

      it 'raises ArgumentError for malformed registry keys' do
        expect { Wine.registry_gets('not-a-registry-key') }
          .to raise_error(ArgumentError, /Invalid registry key format/)
      end
    end

    describe 'Wine.registry_puts' do
      before do
        stub_const('TEMP_DIR', '/tmp')
      end

      it 'returns false when prefix does not exist' do
        FileUtils.rm_rf(temp_wine_prefix)
        # Re-stub PREFIX constant to force missing-prefix branch in registry_puts.
        stub_const('Wine::PREFIX', '/nonexistent/path')
        result = Wine.registry_puts('HKEY_LOCAL_MACHINE\\Software\\Test\\Value', 'test')
        expect(result).to eq(false)
      end

      it 'raises ArgumentError for malformed registry keys' do
        expect { Wine.registry_puts('bad-key', 'test') }
          .to raise_error(ArgumentError, /Invalid registry key format/)
      end

      it 'returns false when regedit command returns non-zero' do
        allow(Wine).to receive(:system).and_return(false)
        result = Wine.registry_puts('HKEY_LOCAL_MACHINE\\Software\\Test\\Value', 'test')
        expect(result).to eq(false)
      end
    end
  end
end
