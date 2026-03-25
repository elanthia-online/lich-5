# frozen_string_literal: true

module Lich
  module Util
    module Update
      module StatusReporter
        def self.respond_mono(text)
          if defined?(Lich::Messaging) && Lich::Messaging.respond_to?(:mono)
            Lich::Messaging.mono(text)
          else
            respond text
          end
        end

        def self.render_sync_summary(repo_name, script_count, downloaded_scripts, downloaded_other, subdir_names, failed_scripts = [], failed_other = {})
          total_downloaded = downloaded_scripts.length + downloaded_other.values.flatten.length
          total_failed = failed_scripts.length + failed_other.values.flatten.length

          if total_downloaded == 0 && total_failed == 0
            table = Terminal::Table.new(
              title: "#{repo_name} Sync",
              rows: [
                ['Scripts', "#{script_count} checked, all up to date"],
                *subdir_names.map { |s| [s.capitalize, 'up to date'] }
              ]
            )
            respond_mono(table.to_s)
            return
          end

          table_rows = []
          table_rows << ['Category', 'File', 'Status']
          table_rows << :separator

          downloaded_scripts.each { |f| table_rows << ['script', f, 'downloaded'] }
          failed_scripts.each { |f| table_rows << ['script', f, 'FAILED (will retry next login)'] }

          downloaded_other.each do |subdir, files|
            files.each { |f| table_rows << [subdir, f, 'downloaded'] }
          end

          failed_other.each do |subdir, files|
            files.each { |f| table_rows << [subdir, f, 'FAILED (will retry next login)'] }
          end

          subdir_names.each do |s|
            next if downloaded_other.key?(s) || failed_other.key?(s)

            table_rows << [s, '--', 'up to date']
          end

          if downloaded_scripts.empty? && failed_scripts.empty?
            table_rows << ['scripts', '--', "#{script_count} checked, all up to date"]
          end

          table_rows << :separator
          summary = "Total: #{total_downloaded} updated"
          summary += ", #{total_failed} failed" if total_failed > 0
          table_rows << [{ value: summary, colspan: 3 }]

          table = Terminal::Table.new(title: "#{repo_name} Sync", rows: table_rows)
          respond_mono(table.to_s)
        end
      end
    end
  end
end
