# frozen_string_literal: true

require 'stringio'

require_relative '../../../spec_helper'
require_relative '../../../login_spec_helper'
require_relative '../../../../lib/common/cli/cli_orchestration'

RSpec.describe Lich::Common::CLI::CLIOrchestration do
  around do |example|
    original_stdout = $stdout
    $stdout = StringIO.new
    example.run
    $stdout = original_stdout
  end

  before do
    stub_const('LICH_DIR', '/tmp/lich')
  end

  describe '.handle_add_account' do
    let(:cli_password) { Lich::Common::Authentication::CLIPassword }

    # Stands in for a terminal: io/console's IO#getpass reads one line with
    # echo off and returns it without the line ending, or nil at end-of-input.
    let(:terminal) do
      Class.new do
        attr_reader :prompts

        def initialize(line)
          @line = line
          @prompts = []
        end

        def tty? = true

        # A prompt passed here would go to $stderr, which Lich points at
        # the debug log, so callers must print their own and pass none.
        def getpass(prompt = nil)
          @prompts << prompt
          @line
        end

        def gets
          raise 'a terminal password must be read with getpass, not gets'
        end
      end
    end

    around do |example|
      original_stdin = $stdin
      example.run
    ensure
      $stdin = original_stdin
    end

    before do
      allow(Lich::Common::Authentication::EntryStore).to receive(:yaml_file_path).and_return('/nonexistent/entry.yaml')
      allow(Lich::Common::CLI::CLIConversion).to receive(:conversion_needed?).and_return(false)
      allow(Lich::Common::CLI::CLIConversion).to receive(:convert).and_return(true)
      allow(cli_password).to receive(:add_account).and_return(0)
    end

    def run_add_account(argv, stdin:)
      stub_const('ARGV', argv)
      $stdin = stdin
      status = nil
      expect { described_class.handle_add_account }.to raise_error(SystemExit) { |e| status = e.status }
      status
    end

    def expect_deprecation_warning
      expect($stdout.string).to include('Passing PASSWORD on the command line is deprecated')
      expect($stdout.string).to include("error starting with Lich #{described_class::POSITIONAL_PASSWORD_REMOVAL}")
    end

    context 'with the password on the command line (deprecated)' do
      # A pipe that would fail the example if anything read the password from it.
      let(:untouched_stdin) { StringIO.new("should-not-be-read\n") }

      it 'passes an explicit valid --frontend through and warns' do
        expect(run_add_account(['--add-account', 'DOUG', 'secret', '--frontend', 'wizard'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'secret', 'wizard', prompt_frontend: true)
        expect_deprecation_warning
        expect(untouched_stdin.pos).to eq(0)
      end

      it 'passes nil when --frontend is omitted' do
        expect(run_add_account(['-aa', 'DOUG', 'secret'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'secret', nil, prompt_frontend: true)
        expect_deprecation_warning
      end

      it 'never echoes the password in the warning or on stdout' do
        run_add_account(['-aa', 'DOUG', 'hunter2-unique'], stdin: untouched_stdin)

        expect($stdout.string).not_to include('hunter2-unique')
      end

      it 'accepts a PASSWORD that starts with a dash' do
        expect(run_add_account(['--add-account', 'DOUG', '-secret'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '-secret', nil, prompt_frontend: true)
        expect_deprecation_warning
      end

      it 'accepts a PASSWORD that is literally --frontend' do
        expect(run_add_account(['--add-account', 'DOUG', '--frontend'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '--frontend', nil, prompt_frontend: true)
        expect_deprecation_warning
      end

      it 'reads --frontend after a PASSWORD that is literally --frontend' do
        expect(run_add_account(['--add-account', 'DOUG', '--frontend', '--frontend', 'wizard'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '--frontend', 'wizard', prompt_frontend: true)
      end

      it 'keeps --frontend as the PASSWORD when a later --frontend supplies the frontend' do
        expect(run_add_account(['-aa', 'DOUG', '--frontend', 'wizard', '--frontend', 'avalon'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '--frontend', 'avalon', prompt_frontend: true)
      end

      it 'reads a PASSWORD of literally --frontend when the next word is a flag' do
        expect(run_add_account(['-aa', 'DOUG', '--frontend', '-x'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '--frontend', nil, prompt_frontend: true)
      end

      it 'reads --frontend given before the command' do
        expect(run_add_account(['--frontend', 'wizard', '--add-account', 'DOUG', 'secret'], stdin: untouched_stdin)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'secret', 'wizard', prompt_frontend: true)
      end

      it 'exits 1 without reading stdin or adding the account when --password-stdin is also given' do
        expect(run_add_account(['-aa', 'DOUG', 'secret', '--password-stdin'], stdin: untouched_stdin)).to eq(1)
        expect($stdout.string).to include('not both')
        expect(untouched_stdin.pos).to eq(0)
        expect(cli_password).not_to have_received(:add_account)
      end

      it 'treats --frontend followed by --password-stdin as a password plus the flag, and rejects the pair' do
        expect(run_add_account(['-aa', 'DOUG', '--frontend', '--password-stdin'], stdin: untouched_stdin)).to eq(1)
        expect(cli_password).not_to have_received(:add_account)
      end
    end

    context 'with a terminal prompt' do
      it 'prompts without echo and passes the typed password through, whitespace intact' do
        tty = terminal.new('  pass word ')

        expect(run_add_account(['-aa', 'DOUG'], stdin: tty)).to eq(0)
        expect(tty.prompts).to eq([nil])
        expect($stdout.string).to start_with("Password: \n")
        expect(cli_password).to have_received(:add_account).with('DOUG', '  pass word ', nil, prompt_frontend: true)
        expect($stdout.string).not_to include('deprecated')
      end

      it 'reads -aa DOUG --frontend wizard as the flag and prompts for the password' do
        tty = terminal.new('typed')

        expect(run_add_account(['-aa', 'DOUG', '--frontend', 'wizard'], stdin: tty)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'typed', 'wizard', prompt_frontend: true)
        expect($stdout.string).not_to include('deprecated')
      end

      it 'exits 1 without prompting when --frontend is invalid' do
        tty = terminal.new('typed')

        expect(run_add_account(['-aa', 'DOUG', '--frontend', 'bogus'], stdin: tty)).to eq(1)
        expect(tty.prompts).to be_empty
        expect(cli_password).not_to have_received(:add_account)
      end

      it 'exits 1 without converting legacy entries when the prompt hits end-of-input' do
        allow(Lich::Common::CLI::CLIConversion).to receive(:conversion_needed?).and_return(true)

        expect(run_add_account(['-aa', 'DOUG'], stdin: terminal.new(nil))).to eq(1)
        expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
        expect(cli_password).not_to have_received(:add_account)
      end

      it 'exits 1 without adding the account when the typed password is empty' do
        expect(run_add_account(['-aa', 'DOUG'], stdin: terminal.new(''))).to eq(1)
        expect($stdout.string).to include('Password cannot be empty')
        expect(cli_password).not_to have_received(:add_account)
      end
    end

    context 'with --password-stdin' do
      it 'reads one line, keeps surrounding spaces, and skips the frontend prompt' do
        pipe = StringIO.new("  pass word \nsecond line\n")

        expect(run_add_account(['-aa', 'DOUG', '--password-stdin'], stdin: pipe)).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', '  pass word ', nil, prompt_frontend: false)
        expect(pipe.gets).to eq("second line\n")
        expect($stdout.string).not_to include('deprecated')
      end

      it 'removes a Windows line ending' do
        expect(run_add_account(['-aa', 'DOUG', '--password-stdin'], stdin: StringIO.new("secret\r\n"))).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'secret', nil, prompt_frontend: false)
      end

      it 'reads --frontend given after the flag' do
        expect(run_add_account(['-aa', 'DOUG', '--password-stdin', '--frontend', 'avalon'], stdin: StringIO.new("pw\n"))).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'pw', 'avalon', prompt_frontend: false)
      end

      it 'reads --frontend given before the flag' do
        expect(run_add_account(['-aa', 'DOUG', '--frontend', 'avalon', '--password-stdin'], stdin: StringIO.new("pw\n"))).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'pw', 'avalon', prompt_frontend: false)
      end

      it 'accepts a password with no trailing newline' do
        expect(run_add_account(['-aa', 'DOUG', '--password-stdin'], stdin: StringIO.new('pw'))).to eq(0)
        expect(cli_password).to have_received(:add_account).with('DOUG', 'pw', nil, prompt_frontend: false)
      end

      it 'exits 1 without converting legacy entries at end-of-input' do
        allow(Lich::Common::CLI::CLIConversion).to receive(:conversion_needed?).and_return(true)

        expect(run_add_account(['-aa', 'DOUG', '--password-stdin'], stdin: StringIO.new(''))).to eq(1)
        expect($stdout.string).to include('Unable to read password')
        expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
        expect(cli_password).not_to have_received(:add_account)
      end
    end

    context 'with no terminal and no --password-stdin' do
      it 'exits 1 without reading the pipe and points at --password-stdin' do
        pipe = StringIO.new("unrelated bytes\n")

        expect(run_add_account(['-aa', 'DOUG'], stdin: pipe)).to eq(1)
        expect(pipe.pos).to eq(0)
        expect($stdout.string).to include('--password-stdin')
        expect(cli_password).not_to have_received(:add_account)
      end
    end

    it 'exits 1 without converting legacy entries or adding the account when --frontend is invalid' do
      allow(Lich::Common::CLI::CLIConversion).to receive(:conversion_needed?).and_return(true)

      expect(run_add_account(['--add-account', 'DOUG', 'secret', '--frontend', 'bogus'], stdin: StringIO.new)).to eq(1)
      expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
      expect(cli_password).not_to have_received(:add_account)
    end

    it 'exits 1 without adding the account when ACCOUNT is missing and a flag takes its place' do
      expect(run_add_account(['--add-account', '--frontend', 'wizard'], stdin: StringIO.new)).to eq(1)
      expect(cli_password).not_to have_received(:add_account)
    end

    it 'exits 1 when ACCOUNT is missing' do
      expect(run_add_account(['-aa'], stdin: StringIO.new)).to eq(1)
      expect(cli_password).not_to have_received(:add_account)
    end
  end

  describe '.handle_refresh_characters' do
    before do
      allow(Lich::Common::Authentication::CLIPassword).to receive(:refresh_characters).and_return(0)
    end

    it 'passes an explicit valid --frontend through' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', '--frontend', 'wizard'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:refresh_characters)
        .with('DOUG', 'wizard')
    end

    it 'passes nil when --frontend is omitted' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:refresh_characters)
        .with('DOUG', nil)
    end

    it 'exits 1 without authenticating when --frontend has no value' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', '--frontend'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when --frontend is followed by another flag' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', '--frontend', '--other-flag'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when --frontend is not a recognized frontend' do
      stub_const('ARGV', ['--refresh-characters', 'DOUG', '--frontend', 'bogus'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when ACCOUNT is missing' do
      stub_const('ARGV', ['--refresh-characters'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end

    it 'exits 1 without authenticating when ACCOUNT is missing and a flag takes its place' do
      stub_const('ARGV', ['--refresh-characters', '--frontend', 'wizard'])

      expect { described_class.handle_refresh_characters }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:refresh_characters)
    end
  end

  describe '.handle_add_character' do
    before do
      allow(Lich::Common::Authentication::CLIPassword).to receive(:add_character).and_return(0)
    end

    it 'passes explicit valid --game-code and --frontend through' do
      stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar', '--game-code', 'GS3', '--frontend', 'avalon'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:add_character)
        .with('DOUG', 'Newchar', game_code: 'GS3', frontend: 'avalon')
    end

    it 'exits 1 without adding a character when --game-code is omitted' do
      stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end

    it 'exits 1 without adding a character when --game-code is not a recognized code' do
      stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar', '--game-code', 'ZZ'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end

    it 'exits 1 without adding a character when --frontend is not a recognized frontend' do
      stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar', '--game-code', 'DR', '--frontend', 'bogus'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end

    # GSX is a retired Simutronics instance kept only for normalizing entries stored
    # before its retirement; LoginHelpers.valid_game_code? rejects it, and persisting
    # it would yield a record whose game_name is 'Unknown'.
    it 'exits 1 without adding a character for a retired game code' do
      stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar', '--game-code', 'GSX'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end

    it 'accepts every game code the login validator accepts' do
      Lich::Common::Authentication::LoginHelpers::VALID_GAME_CODES.each do |code|
        stub_const('ARGV', ['--add-character', 'DOUG', 'Newchar', '--game-code', code])

        expect { described_class.handle_add_character }.to raise_error(SystemExit)
        expect(Lich::Common::Authentication::CLIPassword).to have_received(:add_character)
          .with('DOUG', 'Newchar', game_code: code, frontend: nil)
      end
    end

    it 'exits 1 without adding a character when CHAR_NAME is missing and a flag takes its place' do
      stub_const('ARGV', ['--add-character', 'DOUG', '--game-code', 'DR'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end

    it 'exits 1 without adding a character when ACCOUNT is missing and a flag takes its place' do
      stub_const('ARGV', ['--add-character', '--game-code', 'DR', 'Newchar'])

      expect { described_class.handle_add_character }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:add_character)
    end
  end

  describe '.handle_web_login_test' do
    let(:saved_entries) do
      [{ user_id: 'DOUG', password: 'secret', char_name: 'Raiyen', game_code: 'DRT' }]
    end

    before do
      allow(Lich::Common::Authentication::EntryStore).to receive(:load_saved_entries).and_return(saved_entries)
    end

    it 'authenticates via Web using the password from the saved entry, not ARGV' do
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_return('gamehost' => 'h', 'gameport' => 'p', 'key' => 'k')
      stub_const('ARGV', ['--web-login-test', 'DOUG', 'Raiyen', '--game-code', 'DRT'])

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      expect(Lich::Common::Authentication::WebLogin).to have_received(:auth_with_timeout)
        .with(account: 'DOUG', password: 'secret', character: 'Raiyen', game_code: 'DRT')
    end

    it 'never prints the live one-time KEY (a real usable credential) to stdout' do
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout)
        .and_return('gamehost' => 'h', 'gameport' => 'p', 'key' => 'super-secret-key-value')
      stub_const('ARGV', ['--web-login-test', 'DOUG', 'Raiyen', '--game-code', 'DRT'])

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      expect($stdout.string).not_to include('super-secret-key-value')
      expect($stdout.string).to include('KEY=[scrubbed]')
      expect($stdout.string).to include('GAMEHOST=h') # non-secret fields still shown
    end

    it 'exits 1 and reports the error code on authentication failure' do
      error = Lich::Common::Authentication::WebLogin::AuthenticationError.new('LOGIN_FAILED')
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout).and_raise(error)
      stub_const('ARGV', ['--web-login-test', 'DOUG', 'Raiyen', '--game-code', 'DRT'])

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect($stdout.string).to include('LOGIN_FAILED')
    end

    it 'exits 1 without authenticating when the account is not in the saved entries' do
      stub_const('ARGV', ['--web-login-test', 'NOBODY', 'Raiyen', '--game-code', 'DRT'])
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout)

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(Lich::Common::Authentication::WebLogin).not_to have_received(:auth_with_timeout)
    end

    it 'exits 1 without authenticating when --game-code is missing' do
      stub_const('ARGV', ['--web-login-test', 'DOUG', 'Raiyen'])
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout)

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(Lich::Common::Authentication::WebLogin).not_to have_received(:auth_with_timeout)
    end

    it 'exits 1 without authenticating when --game-code is not a recognized code' do
      stub_const('ARGV', ['--web-login-test', 'DOUG', 'Raiyen', '--game-code', 'ZZ'])
      allow(Lich::Common::Authentication::WebLogin).to receive(:auth_with_timeout)

      expect { described_class.handle_web_login_test }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      expect(Lich::Common::Authentication::WebLogin).not_to have_received(:auth_with_timeout)
    end
  end

  describe '.handle_change_master_password' do
    before do
      allow(Lich::Common::Authentication::CLIPassword).to receive(:change_master_password).and_return(0)
    end

    it 'passes both OLDPASSWORD and NEWPASSWORD through when provided' do
      stub_const('ARGV', ['--change-master-password', 'oldpass', 'newpass'])

      expect { described_class.handle_change_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:change_master_password)
        .with('oldpass', 'newpass')
    end

    it 'passes nil for NEWPASSWORD when omitted' do
      stub_const('ARGV', ['--change-master-password', 'oldpass'])

      expect { described_class.handle_change_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:change_master_password)
        .with('oldpass', nil)
    end

    it 'accepts the -cmp short flag' do
      stub_const('ARGV', ['-cmp', 'oldpass', 'newpass'])

      expect { described_class.handle_change_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:change_master_password)
        .with('oldpass', 'newpass')
    end

    it 'exits 1 without authenticating when OLDPASSWORD is missing' do
      stub_const('ARGV', ['--change-master-password'])

      expect { described_class.handle_change_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).not_to have_received(:change_master_password)
    end
  end

  describe '.handle_recover_master_password' do
    before do
      allow(Lich::Common::Authentication::CLIPassword).to receive(:recover_master_password).and_return(0)
    end

    it 'passes NEWPASSWORD through when provided' do
      stub_const('ARGV', ['--recover-master-password', 'recoveredpass'])

      expect { described_class.handle_recover_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:recover_master_password)
        .with('recoveredpass')
    end

    it 'passes nil when NEWPASSWORD is omitted, deferring to interactive prompt' do
      stub_const('ARGV', ['--recover-master-password'])

      expect { described_class.handle_recover_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:recover_master_password)
        .with(nil)
    end

    it 'accepts the -rmp short flag' do
      stub_const('ARGV', ['-rmp', 'recoveredpass'])

      expect { described_class.handle_recover_master_password }.to raise_error(SystemExit)
      expect(Lich::Common::Authentication::CLIPassword).to have_received(:recover_master_password)
        .with('recoveredpass')
    end
  end

  describe '.handle_convert_entries' do
    before do
      allow(Lich::Common::CLI::CLIConversion).to receive(:convert).and_return(true)
    end

    %w[plaintext standard].each do |mode|
      it "converts to #{mode} mode without prompting for a master password" do
        stub_const('ARGV', ['--convert-entries', mode])

        expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
        expect(Lich::Common::CLI::CLIConversion).to have_received(:convert).with(DATA_DIR, mode)
      end
    end

    it 'exits 1 without converting when the mode is missing' do
      stub_const('ARGV', ['--convert-entries'])

      expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
    end

    it 'exits 1 without converting when the mode is not recognized' do
      stub_const('ARGV', ['--convert-entries', 'bogus'])

      expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
    end

    context 'when converting to enhanced mode' do
      before do
        allow(Lich::Common::Authentication::CLIPassword).to receive(:prompt_and_confirm_password)
          .and_return('newmasterpass')
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(true)
      end

      it 'prompts for and stores a master password before converting' do
        stub_const('ARGV', ['--convert-entries', 'enhanced'])

        expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
        expect(Lich::Common::Authentication::CLIPassword).to have_received(:prompt_and_confirm_password)
        expect(Lich::Common::GUI::MasterPasswordManager).to have_received(:store_master_password)
          .with('newmasterpass')
        expect(Lich::Common::CLI::CLIConversion).to have_received(:convert).with(DATA_DIR, 'enhanced')
      end

      it 'exits 1 without converting when password confirmation is cancelled' do
        allow(Lich::Common::Authentication::CLIPassword).to receive(:prompt_and_confirm_password).and_return(nil)
        stub_const('ARGV', ['--convert-entries', 'enhanced'])

        expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
        expect(Lich::Common::GUI::MasterPasswordManager).not_to have_received(:store_master_password)
        expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
      end

      it 'exits 1 without converting when storing the password in the keychain fails' do
        allow(Lich::Common::GUI::MasterPasswordManager).to receive(:store_master_password).and_return(false)
        stub_const('ARGV', ['--convert-entries', 'enhanced'])

        expect { described_class.handle_convert_entries }.to raise_error(SystemExit)
        expect(Lich::Common::CLI::CLIConversion).not_to have_received(:convert)
      end
    end

    it 'exits 1 when the underlying conversion fails' do
      allow(Lich::Common::CLI::CLIConversion).to receive(:convert).and_return(false)
      stub_const('ARGV', ['--convert-entries', 'plaintext'])

      expect { described_class.handle_convert_entries }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end
  end

  describe '.handle_change_encryption_mode' do
    before do
      allow(Lich::Common::CLI::EncryptionModeChange).to receive(:change_mode).and_return(0)
    end

    it 'passes the mode as a symbol through' do
      stub_const('ARGV', ['--change-encryption-mode', 'enhanced'])

      expect { described_class.handle_change_encryption_mode }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::EncryptionModeChange).to have_received(:change_mode).with(:enhanced, nil)
    end

    it 'passes an explicit --master-password through' do
      stub_const('ARGV', ['--change-encryption-mode', 'enhanced', '--master-password', 'secret'])

      expect { described_class.handle_change_encryption_mode }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::EncryptionModeChange).to have_received(:change_mode).with(:enhanced, 'secret')
    end

    it 'accepts the -mp short flag for the master password' do
      stub_const('ARGV', ['--change-encryption-mode', 'enhanced', '-mp', 'secret'])

      expect { described_class.handle_change_encryption_mode }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::EncryptionModeChange).to have_received(:change_mode).with(:enhanced, 'secret')
    end

    it 'accepts the -cem short flag' do
      stub_const('ARGV', ['-cem', 'standard'])

      expect { described_class.handle_change_encryption_mode }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::EncryptionModeChange).to have_received(:change_mode).with(:standard, nil)
    end

    it 'exits 1 without changing mode when MODE is missing' do
      stub_const('ARGV', ['--change-encryption-mode'])

      expect { described_class.handle_change_encryption_mode }.to raise_error(SystemExit)
      expect(Lich::Common::CLI::EncryptionModeChange).not_to have_received(:change_mode)
    end
  end
end
