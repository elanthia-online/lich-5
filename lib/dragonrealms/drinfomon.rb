module Lich
  module DragonRealms
    module DRInfomon
      $DRINFOMON_VERSION = '3.0'

      DRINFOMON_IN_CORE_LICH = true
      require_relative 'drinfomon/drdefs'
      require_relative 'drinfomon/drvariables'
      require_relative 'drinfomon/drparser'
      require_relative 'drinfomon/drskill'
      require_relative 'drinfomon/drstats'
      require_relative 'drinfomon/drroom'
      require_relative 'drinfomon/drspells'
      require_relative 'drinfomon/events'
    end
  end
end
