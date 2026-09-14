# frozen_string_literal: true

{
  id: :avalon,
  capabilities: %i[gsl],
  metadata: {
    display_name: 'Avalon',
    gui_selectable: true,
    gui_platforms: %i[darwin],
    launcher_adapter: :avalon,
    native_launch_only: true,
    discovery: {
      executables: %w[Avalon avalon],
      mac_bundle_ids: %w[Avalon SimutronicsAvalon],
      path_lookup: false
    }
  }
}
