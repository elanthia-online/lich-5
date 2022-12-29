require_relative "./bounty/parser"
require_relative "./bounty/task"

class Bounty
  KNOWN_TASKS = Parser::TASK_MATCHERS.keys

  def self.current
    Task.new(Parser.parse(checkbounty))
  end

  def self.task
    current
  end

  def self.lnet(person)
    if target_info = LNet.get_data(person.dup, 'bounty')
      Task.new(Parser.parse(target_info))
    else
      if target_info == false
        text = "No one on LNet with a name like #{person}"
      else
        text = "Empty response from LNet for bounty from #{person}\n"
      end
      Lich::Messaging.msg("warn", text)
      nil
    end
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
