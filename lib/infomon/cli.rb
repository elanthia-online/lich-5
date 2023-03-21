# frozen_string_literal: true

module Infomon
  module CLI
    # CLI commands for Infomon
    def self.sync
      # since none of this information is 3rd party displayed, silence is golden.
      echo 'Infomon sync requested. . . '
      request = { 'info'            => /<a exist=.+#{Char.name}/,
                  'skill'           => /<a exist=.+#{Char.name}/,
                  'spell'           => %r{<output class="mono"/>},
                  'experience'      => %r{<output class="mono"/>},
                  'society'         => %r{<pushBold/>},
                  'citizenship'     => /^You don't seem|^You currently have .+ in/,
                  'armor list all'  => /<a exist=.+#{Char.name}/,
                  'cman list all'   => /<a exist=.+#{Char.name}/,
                  'feat list all'   => /<a exist=.+#{Char.name}/,
                  'shield list all' => /<a exist=.+#{Char.name}/,
                  'weapon list all' => /<a exist=.+#{Char.name}/ }

      request.each do |command, start_capture|
        echo "Retreiving character #{command}. . ." if $infomon_debug
        Lich::Util.issue_command(command.to_s, start_capture, usexml: true, quiet: true)
        echo "Did #{command}. . . " if $infomon_debug
      end
      echo 'Requested Infomon sync complete.'
    end

    def self.redo!
      # Destructive - deletes char table, recreates it, then repopulates it
      echo 'Infomon complete reset reqeusted.'
      Infomon.reset!
      Infomon.sync
      echo 'Infomon reset is now complete.'
    end

    def self.show
      response = []
      # display all stored db values
      # todo: should we extend this to accept a Char.name and pull data?
      echo "Displaying stored information for #{Char.name}"
      data_source = Infomon.table
      stored_values = data_source.all
      stored_values.each do |db_hash|
        for key in db_hash.keys
          if db_hash[key].nil?
            db_hash[key] = 'nil'
          end
          response << db_hash[:key] + " : " + db_hash[:value] + "\r\n"
        end
      end
      respond response.uniq
    end
  end
end
