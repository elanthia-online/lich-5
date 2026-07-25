# frozen_string_literal: true

require_relative '../../spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe 'Lich::Gemstone::Group loading' do
  it 'does not execute the repository benchmark command' do
    repo_root = File.expand_path('../../..', __dir__)
    group_file = File.join(repo_root, 'lib', 'gemstone', 'group.rb')
    script = <<~RUBY
      $LOAD_PATH.unshift(#{repo_root.inspect})
      ARGV.replace(['--no-gui'])
      require #{group_file.inspect}
      puts 'loaded'
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-e', script)

    expect(status).to be_success, stderr
    expect(stdout).to eq("loaded\n")
  end
end
