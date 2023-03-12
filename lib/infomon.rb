# frozen_string_literal: true

# Replacement for the veneable infomon.lic script used in Lich4 and Lich5 (03/01/23)
# Supports Ruby 3.X builds
#
#     maintainer: elanthia-online
#   contributers: Tillmen, Shaelun, Athias
#           game: Gemstone
#           tags: core
#       required: Lich > 5.6.2
#        version: 2.0
#         Source: https://github.com/elanthia-online/scripts


require 'English'
require 'sequel'
require 'tmpdir'

module Infomon
  $infomon_debug = false
  # use temp dir in ci context
  @root = defined?(DATA_DIR) ? DATA_DIR : Dir.tmpdir
  @file = File.join(@root, "infomon.db")
  @db   = Sequel.sqlite(@file)
  
  def self.file
    @file
  end

  def self.db
    @db
  end

  def self.state
    @_table ||= self.setup!
  end

  def self.setup!
    @db.create_table?(:state) do
      primary_key :key
      String  :key
      Integer :value
    end
  end

  def self.get(key)
  end

  def self.set(key, value)
  end

  
  
=begin

  class Monitor
    require "#{LIB_DIR}/stats-info.rb"
    sleep(0.1) until Char.name && !Char.name.empty?
    # Need to confirm if this approach disrupts DR start-up
    if XMLData.game =~ /^(?:GSF|GSIV|GSPlat|GST|Test)$/
      _respond 'Moving forward ho!' if $infomon_debug
    else
      respond "This script is meant for Gemstone Prime, Platinum, or Shattered.  It will likely cause problems on whatever game you're trying to run it on..."
      exit # probably should unload rather than exit, or DR will never get a connection
    end

    sleep(0.1) until Char.name && !Char.name.empty?

    # This section will require specific calls to Lich.db rather than relying on CharSettings,
    # unless we overload the CharSettings section to take a specific script name (infomon)

    @save_value = {}
    $infomon_values = DB_Store.read('infomon')
    respond $infomon_values if $infomon_debug
    # sleep 0.5
    respond 'starting sequence' if $infomon_debug
    respond $infomon_values if $infomon_debug
    respond $infomon_values['active_spells'] if $infomon_debug
    respond $infomon_values['need_psm_update'] if $infomon_debug
    respond $infomon_values['Stats'] if $infomon_debug

    respond 'Calling active spells' if $infomon_debug
    $infomon_values['active_spells'] = {} unless $infomon_values['active_spells'].instance_of?(Hash)

    respond 'Calling need psm update' if $infomon_debug
    $infomon_values['need_psm_update'] = true if $infomon_values['need_psm_update'].nil?

    #
    # Load spell info
    #
    unless Spell.load
      respond 'error: failed to load spell list'
      exit
    end

    #
    # Load or get character information
    #

    psm_abilities = if Gem::Version.new(LICH_VERSION) < Gem::Version.new('5.0.16')
                      ['CMan']
                    else
                      %w[Feat Armor Weapon Shield CMan]
                    end
    need_psm = []
    if $infomon_values['need_psm_update']
      need_psm = psm_abilities.dup
      $infomon_values['need_psm_update'] = false
    else
      psm_abilities.each do |ability|
        if !defined?(eval(ability.to_s))
          respond 'Encountered fatal error'
          exit
        elsif $infomon_values[ability.to_s.downcase].nil?
          $infomon_values[ability.to_s.downcase] = {}
          need_psm << ability
        else
          begin
            unless $infomon_values[ability.to_s.downcase].empty?
              $infomon_values[ability.to_s.downcase].each_pair { |psm, rank| eval(ability.to_s).send("#{psm}=", rank) }
            end
          rescue StandardError
            respond 'Bad juju happened here.'
            nil
          end
        end
      end
    end

              
    respond 'checking psms...' unless need_psm.empty?
    need_psm.each do |get_ability|
      Lich::Statsinfo.request('psms', get_ability)
    end
              

    respond 'calling Stats, Skills, Spells, Society, Citizenship' if $infomon_debug
    if $infomon_values['Stats'] &&
       $infomon_values['Skills'] &&
       $infomon_values['Spells'] &&
       $infomon_values['Society'] &&
       $infomon_values['citizenship']

      begin
        respond 'Now LOADING Stats, Skills, Spells, Society, Citizenship' if $infomon_debug
        Stats.load_serialized   = $infomon_values['Stats']
        Skills.load_serialized  = $infomon_values['Skills']
        Spells.load_serialized  = $infomon_values['Spells']
        Society.load_serialized = $infomon_values['Society']
        Char.citizenship        = $infomon_values['citizenship']
      rescue StandardError
        respond $ERROR_INFO
        respond $ERROR_INFO.backtrace[0..1]
        exit
      end
    else
                
      hide_lines = done = false

      # FIXME: - update to use Lich silent commands

      action = proc { |server_string|
        if hide_lines
          if server_string =~ /^\s*Mana:|<prompt/
            DownstreamHook.remove('infomon_info')
            done = true
          end
          nil
        elsif server_string =~ /^\s*Name:/
          hide_lines = true
          nil
        else
          server_string
        end
      }
      DownstreamHook.add('infomon_info', action)
      respond 'checking stats...'
      put 'info'
      wait_until { done }

      hide_lines = done = false
      action = proc { |server_string|
        if hide_lines
          if server_string =~ %r{<output class=""/>|<prompt}
            DownstreamHook.remove('infomon_skills')
            done = true
          end
          nil
        elsif server_string =~ %r{^\s*(?:<.*?>)?#{Char.name}(?:</a>)? \(at level}o
          hide_lines = true
          nil
        else
          server_string
        end
      }
      DownstreamHook.add('infomon_skills', action)
      respond 'checking skills...'
      put 'skills'
      wait_until { done }

      hide_lines = done = false
      action = proc { |server_string|
        if hide_lines
          if server_string =~ /<prompt/
            DownstreamHook.remove('infomon_society')
            done = true
          end
          nil
        elsif server_string == "<pushBold/>\r\n"
          hide_lines = true
          nil
        else
          server_string
        end
      }
      DownstreamHook.add('infomon_society', action)
      respond 'checking society...'
      put 'society'
      wait_until { done }

      done = false
      action = proc { |server_string|
        if server_string =~ /You currently have .*? citizenship in|You don't seem to have citizenship\./
          DownstreamHook.remove('infomon_citizenship')
          done = true
          nil
        else
          server_string
        end
      }
      DownstreamHook.add('infomon_citizenship', action)
      respond 'checking citizenship...'
      put 'citizenship'
      wait_until { done }

                

    end

    if $infomon_values['active_spells'].empty?
      respond 'checking active spells...'
      $process_legacy_spell_durations = true
    end
    respond 'Infomon library loading done.'

    #
    # Load spell timers
    #
    $infomon_values['active_spells'].each_pair do |spell_num, timeleft|
      if (spell = Spell[spell_num.to_i])
        if defined?(spell.real_time) && spell.real_time
          timeleft = (timeleft - Time.now.to_f) / 60.0
          if timeleft.positive?
            spell.timeleft = timeleft
            spell.active = true
          end
        else
          spell.timeleft = timeleft
          spell.active = true
        end
      else
        respond "spell not loaded: #{spell_num}"
      end
    end
    Spellsong.load_serialized = $infomon_values['Spellsong'] if $infomon_values['Spellsong']

    #
    # Register ;magic and ;banks commands moved
    #

    $infomon_sleeping = false
    $infomon_bound = false
    $infomon_silenced = false
    $infomon_calmed = true
    $infomon_cutthroat = false
    #
    # Save function
    #
    def self.save_proc
      @save_value = $infomon_values
      respond @save_value if $infomon_debug
      @save_value['active_spells'] = {}
      Spell.active.each do |spell|
        @save_value['active_spells'][spell.num.to_s] = if defined?(spell.real_time) && spell.real_time
                                                         Time.now.to_f + (spell.timeleft * 60)
                                                       else
                                                         spell.timeleft
                                                       end
      end
      @save_value['Spellsong'] = Spellsong.serialize
      DB_Store.save('infomon', @save_value)
    end

    #
    # Save current status every five minutes in case of crash
    #
    Thread.new do
      loop do
        sleep 300
        Infomon::Monitor.save_proc
      end
    rescue StandardError
      respond $ERROR_INFO
      respond $ERROR_INFO.backtrace[0..1]
    end
    #
    # Save current status on exit
    #
    #before_dying do
    #  Infomon::Monitor.save_proc
    #  # UpstreamHook.remove('infomon')
    #end
    #
    # Death
    #
    Thread.new do
      loop do
        wait_until { dead? }
        Spell.list.each do |killit|
          if defined?(killit.clear_on_death)
            killit.putdown if killit.clear_on_death
          else
            killit.putdown unless [6666, 9009, 920, 9516, 9003, 9011].include?(killit.num)
          end
        end
        Spellsong.renewed
        wait_while { dead? }
        Spell[6666].putdown
      end
    rescue StandardError
      respond $ERROR_INFO
      respond $ERROR_INFO.backtrace[0..1]
      sleep 0.3
    end
    #
    # Spell timing true-up (Invoker and SK item spells do not have proper durations)
    # this needs to be addressed in class Spell rewrite
    # in the meantime, this should mean no spell is more than 1 second off from
    # Simu's time calculations
    #
    unless Gem::Version.new(LICH_VERSION) < Gem::Version.new('5.0.16')
      Thread.new do
        loop do
          begin
            sleep 0.01 until $process_legacy_spell_durations
            update_spell_durations = ::XMLData.active_spells
            update_spell_names = []
            @makeychange = []
            update_spell_durations.each do |k, _v|
              case k
              when /(?:Mage Armor|520) - /
                @makeychange << k
                update_spell_names.push('Mage Armor')
                next
              when /(?:CoS|712) - /
                @makeychange << k
                update_spell_names.push('Cloak of Shadows')
                next
              when /Enh\./
                @makeychange << k
                case k
                when /Enh\. Strength/
                  update_spell_names.push('Surge of Strength')
                when /Enh\. (?:Dexterity|Agility)/
                  update_spell_names.push('Burst of Swiftness')
                end
                next
              when /Empowered/
                @makeychange << k
                update_spell_names.push('Shout')
                next
              when /Multi-Strike/
                @makeychange << k
                update_spell_names.push('MStrike Cooldown')
                next
              when /Next Bounty Cooldown/
                @makeychange << k
                update_spell_names.push('Next Bounty')
                next
              end
              update_spell_names << k
            end
            @makeychange.each do |changekey|
              next unless update_spell_durations.key?(changekey)

              case changekey
              when /(?:Mage Armor|520) - /
                update_spell_durations['Mage Armor'] = update_spell_durations.delete changekey
              when /(?:CoS|712) - /
                update_spell_durations['Cloak of Shadows'] = update_spell_durations.delete changekey
              when /Enh\. Strength/
                update_spell_durations['Surge of Strength'] = update_spell_durations.delete changekey
              when /Enh\. (?:Dexterity|Agility)/
                update_spell_durations['Burst of Swiftness'] = update_spell_durations.delete changekey
              when /Empowered/
                update_spell_durations['Shout'] = update_spell_durations.delete changekey
              when /Multi-Strike/
                update_spell_durations['MStrike Cooldown'] = update_spell_durations.delete changekey
              when /Next Bounty Cooldown/
                update_spell_durations['Next Bounty'] = update_spell_durations.delete changekey
              when /Next Group Bounty Cooldown/
                update_spell_durations['Next Group Bounty'] = update_spell_durations.delete changekey
              end
            end

            existing_spell_names = []
            ignore_spells = ['Berserk']
            Spell.active.each { |s| existing_spell_names << s.name }
            inactive_spells = existing_spell_names - ignore_spells - update_spell_names
            inactive_spells.each do |s|
              badspell = Spell[s].num
              Spell[badspell].putdown if Spell[s].active?
            end

            update_spell_durations.uniq.each do |k, v|
              if (spell = Spell.list.find { |s| (s.name.downcase == k.strip.downcase) || (s.num.to_s == k.strip) })
                spell.active = true
                spell.timeleft = if v - Time.now > 300 * 60
                                   600.01
                                 else
                                   ((v - Time.now) / 60)
                                 end
              elsif $infomon_debug
                respond "no spell matches #{k}"
              end
            end
          rescue StandardError
            respond 'Error in spell durations thread' if $infomon_debug
          end
          $process_legacy_spell_durations = false
        end
      end
    end

    def self.main
      # loop {
      while (line = get)
        begin
          case line
          when /^Your mind goes completely blank\.$|^You close your eyes and slowly drift off to sleep\.$|^You slump to the ground and immediately fall asleep\.  You must have been exhausted!$/
            $infomon_sleeping = true
          when /^Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$|^You are awoken|^You awake/
            $infomon_sleeping = false
          when 'An unseen force envelops you, restricting all movement.'
            $infomon_bound = true
          when /^The restricting force that envelops you dissolves away\.|^You shake off the immobilization that was restricting your movements!/
            $infomon_bound = false
          when /^A pall of silence settles over you\.|^The pall of silence settles more heavily over you\./
            $infomon_silenced = true
          when 'The pall of silence leaves you.'
            $infomon_silenced = false
          when 'A calm washes over you.'
            $infomon_calmed = true
          when /^You are enraged by .*? attack!|^The feeling of calm leaves you\./
            $infomon_calmed = false
          when /slices deep into your vocal cords!$|^All you manage to do is cough up some blood\.$/
            $infomon_cutthroat = true
          when /^\s*The horrible pain in your vocal cords subsides as you spit out the last of the blood clogging your throat\.$/
            $infomon_cutthroat = false
          ## Test line to see if we can detect and flag attacks from hidden creatures for hunting scripts to action.
          when /flies (?:from|out of) the shadows (?:at|toward)|A .+ slips into hiding|A faint silvery light flickers from the shadows/
            $infomon_hidingcreatures = true
          ## Test line to see if we can capture bandit creatures that were hidden and populate them to GameObj for hunting scripts.
          when /You reveal a .+ from hiding|who was hidden|leaps from hiding|leaps out of .+ hiding|revealed from hiding|springs upon|discover the hiding place|knocked from hiding|forced from hiding/
            $infomon_unhidingcreatures = true

          when /^\s#{Char.name} \(at level/o
            _buffer_skills = ''
            _buffer_skills = "#{line}\r\n"
            until (line = get) =~ /\(Use |[0-9]+ days? remain|You started this migration period|Further information can be found in the FAQs./
              _buffer_skills += "#{line}\r\n"
            end
            Lich::Statsinfo.request('skills', _buffer_skills)
          when /^Name:\s+[-A-z\s']+Race:\s+([-A-z\s]+)\s+Profession:\s+([-A-z\s]+)/
            _buffer_stats = ''
            _buffer_stats += "#{line}\r\n"
            until (line = get) =~ /Mana/
              _buffer_stats += "#{line}\r\n"
            end
            _buffer_stats += "#{line}\r\n"
            Lich::Statsinfo.request('info', _buffer_stats)
          when /^You are now level ([0-9]+)!$/
            _buffer_levelup = ''
            _buffer_levelup += "#{line}\r\n"
            get
            until (line = get) =~ /^Physical|\s+Mental|No statistic/
              _buffer_levelup += "#{line}\r\n"
            end
            _buffer_levelup += "#{line}\r\n"
            Lich::Statsinfo.request('levelup', _buffer_levelup)
          when /#{Char.name}, your (Combat|Armor|Feat|Shield|Weapon).*? are as follows:/
            type_request = ::Regexp.last_match(1).dup.downcase
            type_request = 'cman' if type_request == 'combat'
            Lich::Statsinfo.request('psms', type_request)
          when /^\s+You are a (Master|member) (?:in|of) the (Order of Voln|Council of Light|Guardians of Sunfist)( at rank [0-9]+| at step [0-9]+)?\.$/
            Society.status = ::Regexp.last_match(2).dup
            Society.rank = if ::Regexp.last_match(1) == 'Master'
                             if ::Regexp.last_match(2) == 'Order of Voln'
                               '26'
                             else
                               '20'
                             end
                           else
                             ::Regexp.last_match(3).dup
                           end
            $infomon_values['Society'] = Society.serialize
          when '   You are not a member of any society at this time.'
            Society.status = 'None'
            Society.rank = '0'
            $infomon_values['Society'] = Society.serialize
          when /^You currently have .*? citizenship in (.*)\.$/
            Char.citizenship = ::Regexp.last_match(1)
            $infomon_values['citizenship'] = Char.citizenship
          when /^\s*You don't seem to have citizenship\.$/
            Char.citizenship = 'None'
            $infomon_values['citizenship'] = Char.citizenship
          when /^You sign your name into the citizenship/
            done = false
            action = proc { |server_string|
              if server_string =~ /You currently have .*? citizenship in|You don't seem to have citizenship\./
                DownstreamHook.remove('infomon_citizenship')
                done = true
                nil
              else
                server_string
              end
            }
            DownstreamHook.add('infomon_citizenship', action)
            # respond 'checking citizenship...'
            save_silent = script.silent
            script.silent = true
            put 'citizenship'
            script.silent = save_silent
            wait_until { done }
          end
        rescue ThreadError
          respond $ERROR_INFO
          respond $ERROR_INFO.backtrace.first
          sleep 1
        rescue StandardError
          respond $ERROR_INFO
          respond $ERROR_INFO.backtrace.first
          sleep 1
        end
      end
      sleep 0.01
    end

    # ExecScript.start("no_kill_all; hide_me; no_pause_all; Infomon::Monitor.main", { quiet: true })
    Monitor.main
  end
=end
end
