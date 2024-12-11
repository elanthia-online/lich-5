module Lich
  module DragonRealms
    $DRINFOMON_VERSION = '3.0'

    DRINFOMON_IN_CORE_LICH = true

    DRINFOMON_CORE_LICH_DEFINES = %W(drinfomon common common-arcana common-crafting common-healing common-healing-data common-items common-money common-moonmage common-summoning common-theurgy common-travel common-validation events slackbot equipmanager spellmonitor)

    require_relative "./drdefs"
    require_relative "./drvariables"
    require_relative "./drparser"
    require_relative "./drskill"
    require_relative "./drstats"
    require_relative "./drroom"
    require_relative "./drspells"
    require_relative "./events"
  end
end
