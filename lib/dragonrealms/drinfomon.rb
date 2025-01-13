module Lich
  module DragonRealms
    module DRInfomon
      $DRINFOMON_VERSION = '3.0'

      DRINFOMON_IN_CORE_LICH = true

      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drdefs.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drvariables.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drparser.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drskill.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drstats.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drroom.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'drspells.rb')
      require File.join(LIB_DIR, 'dragonrealms', 'drinfomon', 'events.rb')
    end
  end
end
