module Lich
  module DragonRealms
    module DRInfomon
      $DRINFOMON_VERSION = '3.0'

      DRINFOMON_CORE_LICH_DEFINES = %W(drinfomon common common-arcana common-crafting common-healing common-healing-data common-items common-money common-moonmage common-summoning common-theurgy common-travel common-validation events slackbot equipmanager spellmonitor)

      DRINFOMON_IN_CORE_LICH = true
      require_relative 'drinfomon/drdefs'
      require_relative 'drinfomon/drvariables'
      require_relative 'drinfomon/drparser'
      require_relative 'drinfomon/drskill'
      require_relative 'drinfomon/drstats'
      require_relative 'drinfomon/drroom'
      require_relative 'drinfomon/drspells'
      require_relative 'drinfomon/events'
      require_relative 'drinfomon/drexpmonitor'
      require_relative 'drinfomon/startup'

      # Auto-start DRExpMonitor based on Lich.display_expgains setting
      # - Defaults to ON for non-Genie frontends (Genie has built-in exp tracking)
      # - Persisted: if user toggles it off, stays off across sessions
      # Use ";display expgains" command to toggle on/off manually
      # Use ";display inlineexp" to toggle inline gains in EXP window (off by default)
      DRExpMonitor.start if Lich.display_expgains
    end
  end
end
