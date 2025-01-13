module Lich
  module DragonRealms
    module DRInfomon
      $DRINFOMON_VERSION = '3.0'

      DRINFOMON_IN_CORE_LICH = true

      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drdefs.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drvariables.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drparser.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drskill.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drstats.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drroom.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'drspells.rb')
      require File.join(LIB_DIR, 'DragonRealms', 'drinfomon', 'events.rb')
    end
  end
end
