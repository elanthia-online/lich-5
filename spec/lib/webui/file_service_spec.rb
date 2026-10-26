# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tmpdir'
require 'webui/file_service'

RSpec.describe Lich::WebUI::FileService do
  let(:owner) { Object.new }
  let(:logs) { [] }

  it 'serves allowlisted files, refuses traversal/symlink/extensions/directories, and revokes' do
    Dir.mktmpdir('webui-app') do |application_root|
      Dir.mktmpdir('webui-outside') do |outside_root|
        File.binwrite(File.join(application_root, 'inside.png'), 'png')
        File.binwrite(File.join(application_root, 'inside.BMP'), 'bmp')
        File.binwrite(File.join(application_root, 'inside.txt'), 'text')
        File.binwrite(File.join(outside_root, 'outside.png'), 'outside')
        File.symlink(File.join(outside_root, 'outside.png'), File.join(application_root, 'escape.png'))
        service = described_class.new(application_roots: [application_root])

        expect(service.register('images', application_root, owner: owner)).to eq('/files/images/')
        expect(service.resolve('images', 'inside.BMP')[1]).to eq('image/bmp')
        expect(service.resolve('images', 'inside.png')&.first).to eq(File.realpath(File.join(application_root, 'inside.png')))
        expect(service.resolve_url('/files/images/inside.png')&.first).to eq(File.realpath(File.join(application_root, 'inside.png')))
        File.binwrite(File.join(application_root, 'plus+name.png'), 'plus')
        expect(service.resolve_url('/files/images/plus+name.png')&.first)
          .to eq(File.realpath(File.join(application_root, 'plus+name.png')))
        expect(service.resolve_url('https://example.com/inside.png')).to be_nil
        expect(service.resolve('images', '../outside.png')).to be_nil
        expect(service.resolve('images', 'escape.png')).to be_nil
        expect(service.resolve('images', 'inside.txt')).to be_nil
        expect(service.resolve('images', '')).to be_nil
        expect(service.unregister('images', owner: owner)).to be true
        expect(service.resolve('images', 'inside.png')).to be_nil
      end
    end
  end

  it 'allows script and explicit user roots while refusing unrelated roots with attribution' do
    Dir.mktmpdir('webui-app') do |application_root|
      Dir.mktmpdir('webui-script') do |script_root|
        Dir.mktmpdir('webui-user') do |user_root|
          Dir.mktmpdir('webui-refused') do |refused_root|
            service = described_class.new(
              application_roots: [application_root], user_allowlist: [user_root],
              logger: ->(level, message) { logs << [level, message] }
            )

            expect { service.register('script', script_root, owner: owner, script_root: script_root) }.not_to raise_error
            expect { service.register('user', user_root, owner: owner) }.not_to raise_error
            expect { service.register('bad', refused_root, owner: owner) }
              .to raise_error(Lich::WebUI::Error, /outside registered/)
            expect(logs.last.join(' ')).to include('owner=Object:', 'reason=outside_allowlist')
          end
        end
      end
    end
  end

  it 'refuses another owner replacing a live alias without losing the original route' do
    Dir.mktmpdir('webui-alias') do |root|
      first, second = %w[first second].map { |name| File.join(root, name).tap { |path| Dir.mkdir(path) } }
      File.binwrite(File.join(first, 'image.png'), 'first')
      File.binwrite(File.join(second, 'image.png'), 'second')
      service = described_class.new(application_roots: [root])
      other = Object.new
      service.register('images', first, owner: owner)
      expect { service.register('images', second, owner: other) }.to raise_error(Lich::WebUI::Error, /already registered/)
      service.revoke_owner(other)
      expect(service.resolve('images', 'image.png').first).to eq(File.realpath(File.join(first, 'image.png')))
      service.register('images', second, owner: owner)
      expect(service.resolve('images', 'image.png').first).to eq(File.realpath(File.join(second, 'image.png')))
      service.revoke_owner(owner)
      expect { service.register('images', first, owner: other) }.not_to raise_error
    end
  end

  it 'recognizes a filesystem root without accepting a sibling directory prefix' do
    Dir.mktmpdir('webui-root') do |root|
      root = File.realpath(root)
      filesystem_root = root
      filesystem_root = File.dirname(filesystem_root) until File.dirname(filesystem_root) == filesystem_root
      service = described_class.new(application_roots: [filesystem_root])
      expect { service.register('images', root, owner: owner) }.not_to raise_error
      File.binwrite(File.join(root, 'image.png'), 'png')
      service.register('filesystem', filesystem_root, owner: owner)
      relative = File.join(root, 'image.png').delete_prefix(filesystem_root).delete_prefix(File::SEPARATOR)
      expect(service.resolve('filesystem', relative).first).to eq(File.join(root, 'image.png'))
      expect(service.send(:within?, "#{root}-sibling/image.png", root, allow_root: false)).to be(false)
    end
  end

  it 'removes every route owned by a terminating owner' do
    Dir.mktmpdir('webui-app') do |root|
      File.binwrite(File.join(root, 'image.png'), 'png')
      service = described_class.new(application_roots: [root])
      service.register('one', root, owner: owner)
      service.register('two', root, owner: Object.new)

      service.revoke_owner(owner)

      expect(service.resolve('one', 'image.png')).to be_nil
      expect(service.resolve('two', 'image.png')).not_to be_nil
    end
  end
end
