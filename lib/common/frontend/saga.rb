# frozen_string_literal: true

saga_lich_launch_environment = {
  'SAGA_LICH_MODE' => '1',
  'SAGA_LICH_HOST' => '%host%',
  'SAGA_LICH_PORT' => '%port%',
  'SAGA_LICH_KEY'  => '%key%'
}.freeze

{
  id: :saga,
  capabilities: %i[xml streams mono room_window sentinel],
  metadata: {
    display_name: 'Saga',
    gui_selectable: true,
    gui_platforms: %i[darwin windows linux],
    launcher_adapter: :environment,
    launcher_status: :supported_cold_start_only,
    launch_notice: 'Saga 0.8.5 environment handoff; cold start only',
    native_launch_only: true,
    # Saga 0.8.5 consumes this environment when it owns process startup. Its
    # single-instance relay currently drops the per-launch host, port, and key.
    launch_plans: {
      darwin: {
        command: '/usr/bin/open',
        arguments: %w[-n -b com.auchand.saga],
        environment: saga_lich_launch_environment
      },
      windows: {
        command: :resolved_executable,
        arguments: [],
        environment: saga_lich_launch_environment
      },
      linux: {
        command: :resolved_executable,
        arguments: [],
        environment: saga_lich_launch_environment
      }
    },
    discovery: {
      executables: %w[Saga Saga.exe saga],
      mac_bundle_ids: %w[com.auchand.saga],
      # Do not search PATH: `saga` also names the unrelated SAGA GIS executable.
      path_lookup: false,
      paths: {
        windows: [
          '%LOCALAPPDATA%/Programs/Saga/Saga.exe',
          '%LOCALAPPDATA%/Programs/saga/Saga.exe',
          '%PROGRAMFILES%/Saga/Saga.exe',
          '%PROGRAMFILES(X86)%/Saga/Saga.exe'
        ],
        # Saga's Linux AppImage location is user-selected; /opt is one known
        # convention pending desktop/AppImage discovery.
        linux: ['/opt/Saga/saga']
      }
    }
  }
}
