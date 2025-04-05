# frozen_string_literal: true

module Lich
  module Gemstone
    # Wounds class for tracking character wounds
    class Wounds < Gemstone::CharacterStatus # GameBase::CharacterStatus
      class << self
        def leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end
        def leye;      fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end
        def rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end
        def reye;      fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end
        def head;      fix_injury_mode; XMLData.injuries['head']['wound'];      end
        def neck;      fix_injury_mode; XMLData.injuries['neck']['wound'];      end
        def back;      fix_injury_mode; XMLData.injuries['back']['wound'];      end
        def chest;     fix_injury_mode; XMLData.injuries['chest']['wound'];     end
        def abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end
        def abs;       fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end
        def leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end
        def larm;      fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end
        def rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end
        def rarm;      fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end
        def rightHand; fix_injury_mode; XMLData.injuries['rightHand']['wound']; end
        def rhand;     fix_injury_mode; XMLData.injuries['rightHand']['wound']; end
        def leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end
        def lhand;     fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end
        def leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end
        def lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end
        def rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end
        def rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end
        def leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['wound'];  end
        def rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['wound']; end
        def nsys;      fix_injury_mode; XMLData.injuries['nsys']['wound'];      end
        def nerves;    fix_injury_mode; XMLData.injuries['nsys']['wound'];      end

        def arms
          fix_injury_mode
          [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'],
           XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound']].max
        end

        def limbs
          fix_injury_mode
          [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'],
           XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound'],
           XMLData.injuries['leftLeg']['wound'], XMLData.injuries['rightLeg']['wound']].max
        end

        def torso
          fix_injury_mode
          [XMLData.injuries['rightEye']['wound'], XMLData.injuries['leftEye']['wound'],
           XMLData.injuries['chest']['wound'], XMLData.injuries['abdomen']['wound'],
           XMLData.injuries['back']['wound']].max
        end
      end
    end
  end
end
