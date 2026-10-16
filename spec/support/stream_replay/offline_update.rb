# frozen_string_literal: true

# offline_update.rb - the no-op entry points offline_preload.rb prepends in the
# replay child, plus the self-check the probe reports in its ready marker.
# Kept apart from offline_preload.rb so specs can load it without enabling
# that file's process-wide TracePoint.
# The self-check catches renames of the three entry points handle_autostart
# calls today (lib/games.rb), not new network calls added there later: it is
# not a general "the replay is offline" guarantee.

module StreamReplay
  # Prepended onto Lich::Util::Update's singleton class: no core update, no
  # repo sync (both reach GitHub).
  module OfflineUpdate
    def update_core_data_and_scripts(*) = nil
    def sync_all_repos(*) = nil
  end

  # Prepended onto Lich's singleton class: the core always counts as updated
  # for the running version, so handle_autostart never starts a core update.
  module CurrentCore
    def core_updated_with_lich_version = (defined?(LICH_VERSION) ? LICH_VERSION : super)
  end

  # Why the replay child may not be offline. The preload matches lib/ by name,
  # so a rename there would make it stub nothing and let a replay reach the
  # network while its golden still passes. This turns that into an error.
  #
  # @param update [Module, nil] Lich::Util::Update (nil when not defined)
  # @param lich [Module, nil] Lich
  # @return [Array<String>] one message per problem; empty when every stub is
  #   prepended and shadows a real method
  def self.offline_problems(update, lich)
    [[OfflineUpdate, update, 'Lich::Util::Update'], [CurrentCore, lich, 'Lich']].flat_map do |stub, target, label|
      next ["#{label} is not defined"] if target.nil?
      next ["#{label} was never prepended with #{stub}"] unless target.singleton_class.include?(stub)

      stub.instance_methods(false).sort.filter_map do |name|
        next if target.singleton_class.instance_method(name).super_method

        "#{label}.#{name} does not exist, so its no-op stubs nothing"
      end
    end
  end
end
