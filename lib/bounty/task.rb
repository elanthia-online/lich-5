class Bounty
  class Task
    TYPES = [
      :cull, :heirloom, :skins,
      :gem, :escort, :herb,
      :rescue, :dangerous, :bandit,
    ].freeze

    STATUSES = [
      :assigned,
      :triggered,
      :done,
      :failed,
      :unfinished,
    ].freeze

    def initialize(options={})
      @description    = options[:description]
      @requirements   = options[:requirements] || {}
      @task           = options[:task]
      @status         = options[:status]
      @town           = options[:town] || @requirements[:town]
    end
    attr_accessor :task, :status, :requirements, :description, :town

    def type; task; end
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

    def search_heirloom?
      task == :heirloom &&
        requirements[:action] == "search"
    end

    def loot_heirloom?
      task == :heirloom &&
        requirements[:action] == "loot"
    end

    def done?
      [:done, :failed].include?(status)
    end

    def triggered?
      :triggered == status
    end

    def any?
      !!status
    end

    def none?
      !any?
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
