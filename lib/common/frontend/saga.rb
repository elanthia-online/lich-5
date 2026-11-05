# frozen_string_literal: true

saga_lich_launch_environment = {
  'SAGA_LICH_MODE' => '1',
  'SAGA_LICH_HOST' => '%host%',
  'SAGA_LICH_PORT' => '%port%',
  'SAGA_LICH_KEY'  => '%key%'
}.freeze

{
  id: :saga,
  capabilities: %i[xml streams mono room_window sentinel room_element game_links double_bold],
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
      # Saga's electron-builder NSIS installer records $INSTDIR as
      # InstallLocation under Software\<APP_GUID> in HKCU (per-user install)
      # or HKLM (elevated all-users install), so a custom directory is still
      # found. APP_GUID is uuid5 of the com.auchand.saga appId, stable across
      # releases. Per-user wins when both installs are present.
      registry_keys: %i[current_user local_machine].map do |hive|
        {
          hive: hive,
          key: 'Software\\3f78e0da-1d8f-570d-9cef-2ff34b0efe1a',
          value: 'InstallLocation',
          view: 64
        }
      end,
      paths: {
        windows: [
          '%LOCALAPPDATA%/Programs/Saga/Saga.exe',
          '%LOCALAPPDATA%/Programs/saga/Saga.exe',
          '%PROGRAMFILES%/Saga/Saga.exe',
          '%PROGRAMFILES(X86)%/Saga/Saga.exe'
        ],
        # electron-builder's deb/rpm install path. Saga has only ever shipped
        # an AppImage on Linux (see appimage below); kept for manual installs.
        linux: ['/opt/Saga/saga']
      },
      # Linux releases are a single versioned AppImage with no installer.
      # Integrator desktop entries are matched by the embedded desktop file's
      # StartupWMClass, then these case-sensitive names (SAGA GIS also uses
      # `saga`) are searched in those and the usual AppImage directories.
      appimage: {
        startup_wm_class: 'Saga',
        names: %w[Saga-[0-9]*.AppImage Saga.AppImage],
        directories: %w[
          %HOME%/Applications
          %HOME%/AppImages
          %HOME%/.local/bin
          %HOME%/Downloads
        ]
      }
    }
  }
}
