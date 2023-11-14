class Bounty
  class Task
    def initialize(options = {})
      @description    = options[:description]
      @type           = options[:type]
      @requirements   = options[:requirements] || {}
      @town           = options[:town] || @requirements[:town]
    end
    attr_accessor :type, :requirements, :description, :town

    def task; type; end
    def kind; type; end
    def count; number; end

    def creature
      requirements[:creature]
    end

    def critter
      requirements[:creature]
    end

    def critter?
      !!requirements[:creature]
    end

    def location
      requirements[:area] || town
    end

    def bandit?
      type.to_s.start_with?("bandit")
    end

    def creature?
      [
        :creature_assignment, :cull, :dangerous, :dangerous_spawned, :rescue, :heirloom
      ].include?(type)
    end

    def cull?
      type.to_s.start_with?("cull")
    end

    def dangerous?
      type.to_s.start_with?("dangerous")
    end

    def escort?
      type.to_s.start_with?("escort")
    end

    def gem?
      type.to_s.start_with?("gem")
    end

    def heirloom?
      type.to_s.start_with?("heirloom")
    end

    def herb?
      type.to_s.start_with?("herb")
    end

    def rescue?
      type.to_s.start_with?("rescue")
    end

    def skin?
      type.to_s.start_with?("skin")
    end

    def search_heirloom?
      [:heirloom].include?(type) &&
        requirements[:action] == "search"
    end

    def loot_heirloom?
      [:heirloom].include?(type) &&
        requirements[:action] == "loot"
    end

    def heirloom_found?
      [
        :heirloom_found
      ].include?(type)
    end

    def done?
      [
        :failed, :guard, :taskmaster, :heirloom_found
      ].include?(type)
    end

    def spawned?
      [
        :dangerous_spawned, :escort, :rescue_spawned
      ].include?(type)
    end

    def triggered?; spawned?; end

    def any?
      !none?
    end

    def none?
      [:none, nil].include?(type)
    end

    def guard?
      [
        :guard,
        :bandit_assignment, :creature_assignment, :heirloom_assignment, :heirloom_found, :rescue_assignment
      ].include?(type)
    end

    def assigned?
      type.end_with?("assignment")
    end

    def ready?
      [
        :bandit_assignment, :escort_assignment,
        :bandit, :cull, :dangerous, :escort, :gem, :heirloom, :herb, :rescue, :skin
      ].include?(type)
    end

    def help?
      description.start_with?("You have been tasked to help")
    end

    def assist?
      help?
    end

    def group?
      help?
    end

    def method_missing(symbol, *args, &blk)
      if requirements&.keys&.include?(symbol)
        requirements[symbol]
      else
        super
      end
    end

    def respond_to_missing?(symbol, include_private = false)
      requirements&.keys&.include?(symbol) || super
    end
  end
end
