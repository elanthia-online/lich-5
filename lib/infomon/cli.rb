# frozen_string_literal: true

module Infomon
  # CLI commands for Infomon
  def self.sync
    # since none of this information is 3rd party displayed, silence is golden.
    shroud_detected = false
    respond 'Infomon sync requested.'
    if Effects::Spells.active?(1212)
      respond 'ATTENTION:  SHROUD DETECTED - disabling Shroud of Deception to sync character\'s infomon setting'
      while Effects::Spells.active?(1212)
        dothistimeout('STOP 1212', 3, /^With a moment's concentration, you terminate the Shroud of Deception spell\.$|^Stop what\?$/)
        sleep(0.5)
      end
      shroud_detected = true
    end
    request = { 'info'               => /<a exist=.+#{XMLData.name}/,
                'skill'              => /<a exist=.+#{XMLData.name}/,
                'spell'              => %r{<output class="mono"/>},
                'experience'         => %r{<output class="mono"/>},
                'society'            => %r{<pushBold/>},
                'citizenship'        => /^You don't seem|^You currently have .+ in/,
                'armor list all'     => /<a exist=.+#{XMLData.name}/,
                'cman list all'      => /<a exist=.+#{XMLData.name}/,
                'feat list all'      => /<a exist=.+#{XMLData.name}/,
                'shield list all'    => /<a exist=.+#{XMLData.name}/,
                'weapon list all'    => /<a exist=.+#{XMLData.name}/,
                'ascension list all' => /<a exist=.+#{XMLData.name}/,
                'resource'           => /^Health: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Mana: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Stamina: \d+\/(?:<pushBold\/>)?\d+(?:<popBold\/>)?\s+Spirit: \d+\/(?:<pushBold\/>)?\d+/,
                'warcry'             => /^You have learned the following War Cries:|^You must be an active member of the Warrior Guild to use this skill/ }

    request.each do |command, start_capture|
      respond "Retrieving character #{command}." if $infomon_debug
      Lich::Util.issue_command(command.to_s, start_capture, /<prompt/, include_end: true, timeout: 5, silent: false, usexml: true, quiet: true)
      respond "Did #{command}." if $infomon_debug
    end
    respond 'Requested Infomon sync complete.'
    respond 'ATTENTION:  TEND TO YOUR SHROUD!' if shroud_detected
    Infomon.set('infomon.last_sync', Time.now.to_i)
  end

  def self.redo!
    # Destructive - deletes char table, recreates it, then repopulates it
    respond 'Infomon complete reset reqeusted.'
    Infomon.reset!
    Infomon.sync
    respond 'Infomon reset is now complete.'
  end

  def self.show(full = false)
    response = []
    # display all stored db values
    respond "Displaying stored information for #{XMLData.name}"
    Infomon.table.map([:key, :value]).each { |k, v|
      response << "#{k} : #{v.inspect}\n"
    }
    unless full
      response.each { |_line|
        response.reject! do |line|
          line.match?(/\s:\s0$/)
        end
      }
    end
    respond response
  end
end
