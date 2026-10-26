# frozen_string_literal: true

# Explicit source-repair candidates for acceptance only. Product code and the
# digest-checked upstream fixtures never receive these substitutions. A changed
# source must fail the exact-match check rather than silently broadening a repair.
module WebUIBuilderSourceRepairs
  def self.replace_once(source, before, after)
    raise 'source repair no longer matches exactly once' unless source.split(before, -1).length == 2
    source.sub(before, after)
  end

  def self.apply(name, source)
    source = source.gsub("\r\n", "\n")
    case name
    when 'eloot'
      before = '<object class="GtkLabel"><property name="visible">True</property><property name="can-focus">False</property><property name="label" translatable="yes">Exclusions (?)</property>'
      replace_once(source, before, before.sub('<object class="GtkLabel">', '<object class="GtkLabel" id="exclusions_label">'))
    when 'bigshot'
      source = replace_once(source, "      # Flee from boon/boss/glamour creatures\n      self['boon_flee_from'].tooltip_text = ''\n", '')
      before = "          # Handle legacy boon_flee_from toggle\n" \
               "          if @settings[:boon_flee_from] && value =~ /flee/\n" \
               "            self[\"all:flee\"].active = true\n" \
               "            @settings[key] << value\n" \
               "          end\n\n"
      source = replace_once(source, before, '')
      migration = <<~'RUBY'
        # Older profiles may predate the per-boon settings.
        (@groups.keys + [:boons_all, :boons_ignore, :boons_flee]).each do |key|
          @settings[key] = [] if @settings[key].nil?
        end

        # Consume the retired flag once per loaded profile. Its true value means
        # Flee for every known boon, replacing conflicting Common/Ignore choices.
        if @settings.delete(:boon_flee_from)
          @settings[:boons_all] = ['flee']
          @settings[:boons_ignore] = []
          @settings[:boons_flee] = @groups.values.flatten
          @groups.each do |group, items|
            @settings[group] = ['flee'] + items.map { |item| "#{item}_flee" }
          end
        end

      RUBY
      migration = migration.lines.map { |line| line.strip.empty? ? line : "        #{line}" }.join
      before = "    def load_settings(connect = true)\n      Gtk.queue do\n"
      replace_once(source, before, before + migration)
    else
      raise "no reviewed source repair for #{name}"
    end
  end
end
