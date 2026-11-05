# frozen_string_literal: true

{
  id: :stormfront,
  capabilities: %i[xml streams mono room_window],
  metadata: {
    display_name: 'Wrayth',
    aliases: %w[wrayth],
    gui_selectable: true,
    gui_platforms: %i[darwin windows linux],
    launcher_adapter: :simutronics,
    discovery: {
      executables: %w[Wrayth.exe StormFront.exe],
      registry_keys: [
        'SOFTWARE\\Simutronics\\STORM32',
        'SOFTWARE\\WOW6432Node\\Simutronics\\STORM32'
      ]
    }
  }
}
