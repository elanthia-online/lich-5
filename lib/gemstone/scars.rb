# frozen_string_literal: true

module Lich
  module Gemstone
    # Scars class for tracking character scars
    class Scars < Gemstone::CharacterStatus # GameBase::CharacterStatus
      class << self
        def leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end
        def leye;      fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end
        def rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end
        def reye;      fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end
        def head;      fix_injury_mode; XMLData.injuries['head']['scar'];      end
        def neck;      fix_injury_mode; XMLData.injuries['neck']['scar'];      end
        def back;      fix_injury_mode; XMLData.injuries['back']['scar'];      end
        def chest;     fix_injury_mode; XMLData.injuries['chest']['scar'];     end
        def abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end
        def abs;       fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end
        def leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end
        def larm;      fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end
        def rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end
        def rarm;      fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end
        def rightHand; fix_injury_mode; XMLData.injuries['rightHand']['scar']; end
        def rhand;     fix_injury_mode; XMLData.injuries['rightHand']['scar']; end
        def leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end
        def lhand;     fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end
        def leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end
        def lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end
        def rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end
        def rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end
        def leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['scar'];  end
        def rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['scar']; end
        def nsys;      fix_injury_mode; XMLData.injuries['nsys']['scar'];      end
        def nerves;    fix_injury_mode; XMLData.injuries['nsys']['scar'];      end

        def arms
          fix_injury_mode
          [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'],
           XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar']].max
        end

        def limbs
          fix_injury_mode
          [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'],
           XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar'],
           XMLData.injuries['leftLeg']['scar'], XMLData.injuries['rightLeg']['scar']].max
        end

        def torso
          fix_injury_mode
          [XMLData.injuries['rightEye']['scar'], XMLData.injuries['leftEye']['scar'],
           XMLData.injuries['chest']['scar'], XMLData.injuries['abdomen']['scar'],
           XMLData.injuries['back']['scar']].max
        end
      end
    end
  end
end
