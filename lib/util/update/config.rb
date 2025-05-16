# frozen_string_literal: true

module Lich
  module Util
    module Update
      # Configuration settings for the Lich Update
      module Config
        # Minimum supported Ruby
        # Placeholder until aligned with team, not yet enabled in code
        # MINIMUM_RUBY_VERSION = '3.4.2'

        # Minimum supported version for backrev
        MINIMUM_SUPPORTED_VERSION = '5.11.0'

        # GitHub repository for Lich5
        GITHUB_REPO = 'elanthia-online/lich-5'

        # GitHub API URL for releases
        GITHUB_API_URL = "https://api.github.com/repos/#{GITHUB_REPO}/releases"

        # Release tags supported by the update
        RELEASE_TAGS = {
          latest: 'latest',
          beta: 'beta',
          dev: 'dev',
          alpha: 'alpha'
        }

        # Core script files that should be updated
        CORE_SCRIPTS = [
          "alias.lic", "autostart.lic", "dependency.lic",
          "ewaggle.lic", "foreach.lic", "go2.lic", "infomon.lic",
          "jinx.lic", "lnet.lic", "log.lic", "logxml.lic", "map.lic",
          "repository.lic", "vars.lic", "version.lic"
        ]

        # Game-specific script files
        GAME_SPECIFIC_SCRIPTS = {
          "gs" => ["ewaggle.lic", "foreach.lic"],
          "dr" => ["dependency.lic"]
        }

        # Data files that should be updated with caution
        SENSITIVE_DATA_FILES = ["effect-list.xml", "gameobj-data.xml", "spell-list.xml"]

        # Remote repositories for different file types
        REMOTE_REPOS = {
          script: {
            default: "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts",
            dependency: "https://raw.githubusercontent.com/elanthia-online/dr-scripts/main"
          },
          data: "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts",
          lib: {
            production: "https://raw.githubusercontent.com/elanthia-online/lich-5/master/lib",
            beta: "https://raw.githubusercontent.com/elanthia-online/lich-5/staging/lib"
          }
        }

        # Valid file extensions for different file types
        VALID_EXTENSIONS = {
          script: ['.lic'],
          data: ['.xml', '.json', '.yaml', '.ui'],
          lib: ['.rb']
        }

        # Default options for CLI
        DEFAULT_OPTIONS = {
          confirm: true,
          tag: 'latest',
          verbose: false
        }
      end
    end
  end
end
