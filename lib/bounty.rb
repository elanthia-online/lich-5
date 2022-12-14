require_relative "./bounty/parser"
require_relative "./bounty/task"

class Bounty
  def self.current
    Task.new(Parser.parse(checkbounty))
  end

  # Delegate class methods to a new instance of the current bounty task
  [:status, :type, :requirements, :town, :any?, :none?, :done?].each do |attr|
    self.class.instance_eval do
      define_method(attr) do |*args, &blk|
        current&.send(attr, *args, &blk)
      end
    end
  end
end
