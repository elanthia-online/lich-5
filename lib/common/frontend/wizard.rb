# frozen_string_literal: true

{
  id: :wizard,
  capabilities: %i[gsl],
  metadata: {
    display_name: 'Wizard',
    gui_selectable: true,
    gui_platforms: %i[darwin windows linux],
    launcher_adapter: :simutronics,
    discovery: {
      executables: %w[Wizard.exe],
      registry_keys: [
        'SOFTWARE\\Simutronics\\WIZ32',
        'SOFTWARE\\WOW6432Node\\Simutronics\\WIZ32'
      ]
    }
  }
}
