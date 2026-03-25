# frozen_string_literal: true

module Lich
  module Util
    module Update
      class ScriptSync
        def initialize(client)
          @client = client
        end

        def sync_all_repos
          SCRIPT_REPOS.each_key { |repo_key| sync_repo(repo_key) }
        end

        def sync_repo(repo_key, force: false)
          config = SCRIPT_REPOS[repo_key]
          unless config
            respond "[lich5-update: Unknown repository '#{repo_key}'. Known: #{SCRIPT_REPOS.keys.join(', ')}]"
            return
          end

          if config[:game_filter] && XMLData.game !~ config[:game_filter]
            return
          end

          tree_data = @client.fetch_github_json(config[:api_url])
          unless tree_data && tree_data['tree']
            respond "[lich5-update: Failed to fetch tree for #{repo_key}.]"
            return
          end
          tree = tree_data['tree']

          name = config[:display_name] || repo_key
          syncable = filter_syncable_scripts(tree, config)
          StatusReporter.respond_mono("[lich5-update: Syncing #{name} (#{syncable.length} scripts)...]")

          local_shas = FileWriter.build_local_sha_map(SCRIPT_DIR)
          downloaded_scripts = []
          failed_scripts = []
          syncable.each do |entry|
            filename = File.basename(entry['path'])
            next if !force && local_shas[filename] == entry['sha']

            content = @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed_scripts << filename
              next
            end

            begin
              FileWriter.safe_write(File.join(SCRIPT_DIR, filename), content)
              downloaded_scripts << filename
            rescue StandardError => e
              respond "[lich5-update: write failed for #{filename}: #{e.message}]"
              failed_scripts << filename
            end
          end

          downloaded_other = {}
          failed_other = {}
          (config[:subdirs] || {}).each do |subdir_name, subconfig|
            files, failures = sync_subdir(tree, config, subdir_name, subconfig)
            downloaded_other[subdir_name] = files unless files.empty?
            failed_other[subdir_name] = failures unless failures.empty?
          end

          StatusReporter.render_sync_summary(name, syncable.length, downloaded_scripts, downloaded_other, config[:subdirs]&.keys || [], failed_scripts, failed_other)
        end

        def sync_subdir(tree, config, _subdir_name, subconfig)
          pattern = subconfig[:pattern]
          dest = subconfig[:dest]
          return [[], []] unless pattern && dest

          FileUtils.mkdir_p(dest)
          entries = tree.select { |e| e['path'] =~ pattern && e['type'] == 'blob' }
          return [[], []] if entries.empty?

          local_shas = FileWriter.build_local_sha_map(dest, subconfig[:glob] || '*.yaml')
          downloaded = []
          failed = []
          entries.each do |entry|
            filename = File.basename(entry['path'])
            next if local_shas[filename] == entry['sha']

            content = @client.http_get("#{config[:raw_base_url]}/#{entry['path']}", auth: false)
            unless content
              failed << filename
              next
            end

            begin
              FileWriter.safe_write(File.join(dest, filename), content)
              downloaded << filename
            rescue StandardError => e
              respond "[lich5-update: write failed for #{filename}: #{e.message}]"
              failed << filename
            end
          end
          [downloaded, failed]
        end

        def filter_syncable_scripts(tree, config)
          candidates = tree.select { |e| e['path'] =~ config[:script_pattern] && e['type'] == 'blob' }

          case config[:tracking_mode]
          when :all
            candidates.reject { |e| File.basename(e['path']).include?('-setup') }
          when :explicit
            tracked = TrackedScripts.new.tracked_scripts(config)
            candidates.select { |e| tracked.include?(File.basename(e['path'])) }
          else
            candidates
          end
        end
      end
    end
  end
end
