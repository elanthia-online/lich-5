class Bounty
  class Task
    def initialize(options={})
      @description    = options[:description]
      @requirements   = options[:requirements] || {}
      @task           = options[:task]
      @status         = options[:status]
      @town           = options[:town] || @requirements[:town]
    end
    attr_accessor :task, :status, :requirements, :description, :town

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

    def heirloom?
      task == :heirloom
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
      [:done, :failed].include?(status)
    end

    def spawned?
      task.end_with?("spawned")
    end

    def triggered?; spawned?; end

    def any?
      !none?
    end

    def none?
      [:none, nil].include?(task)
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
