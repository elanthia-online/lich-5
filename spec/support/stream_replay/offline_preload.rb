# frozen_string_literal: true

# offline_preload.rb - loaded into the replay child with `ruby -r` before
# lich.rbw. Login normally runs Game.handle_autostart, which on a fresh data
# dir updates core scripts and always syncs script repos from GitHub. A replay
# must be offline and deterministic, so once each module is defined this
# prepends no-op versions of those entry points. Nothing under lib/ changes.

module StreamReplay
  module OfflineUpdate
    def update_core_data_and_scripts(*) = nil
    def sync_all_repos(*) = nil
  end

  module CurrentCore
    def core_updated_with_lich_version = (defined?(LICH_VERSION) ? LICH_VERSION : super)
  end
end

TracePoint.new(:end) do |tp|
  mod = tp.self
  if defined?(Lich::Util::Update) && mod.equal?(Lich::Util::Update) &&
     !mod.singleton_class.include?(StreamReplay::OfflineUpdate)
    mod.singleton_class.prepend(StreamReplay::OfflineUpdate)
  elsif mod.equal?(Lich) && mod.singleton_class.method_defined?(:core_updated_with_lich_version) &&
        !mod.singleton_class.include?(StreamReplay::CurrentCore)
    mod.singleton_class.prepend(StreamReplay::CurrentCore)
  end
end.enable
