class Bounty
  class Task
    def initialize(options={})
      @description    = options[:description]
      @requirements   = options[:requirements] || {}
      @task           = options[:task]
      @town           = options[:town] || @requirements[:town]
    end
    attr_accessor :task, :requirements, :description, :town

    def type; task; end
    def kind; task; end
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
      task.to_s.start_with?("bandit")
    end

    def creature?
      [
        :creature_assignment, :cull, :dangerous, :dangerous_spawned, :rescue, :heirloom
      ].include?(task)
    end

    def cull?
      task.to_s.start_with?("cull")
    end

    def dangerous?
      task.to_s.start_with?("dangerous")
    end

    def escort?
      task.to_s.start_with?("escort")
    end

    def gem?
      task.to_s.start_with?("gem")
    end

    def heirloom?
      task.to_s.start_with?("heirloom")
    end

    def herb?
      task.to_s.start_with?("herb")
    end

    def rescue?
      task.to_s.start_with?("rescue")
    end

    def skin?
      task.to_s.start_with?("skin")
    end

    def search_heirloom?
      heirloom &&
        requirements[:action] == "search"
    end

    def loot_heirloom?
      heirloom &&
        requirements[:action] == "loot"
    end

    def done?
      [
        :failed, :guard, :taskmaster
      ].include?(task)
    end

    def spawned?
      [
        :dangerous_spawned, :escort, :rescue_spawned
      ].include?(task)
    end

    def triggered?; spawned?; end

    def any?
      !none?
    end

    def none?
      [:none, nil].include?(task)
    end

    def guard?
      [
        :guard,
        :bandit_assignment, :creature_assignment, :heirloom_assignment, :rescue_assignment
      ].include?(task)
    end

    def help?
      description.start_with?("You have been tasked to help")
    end

    def method_missing(symbol, *args, &blk)
      if requirements&.keys.include?(symbol)
        requirements[symbol]
      else
        super
      end
    end

    def respond_to_missing?(symbol, include_private=false)
      requirements&.keys.include?(symbol) || super
    end
  end
end
