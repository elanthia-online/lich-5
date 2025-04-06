# frozen_string_literal: true

module Lich
  module Gemstone
    # Scars class for tracking character scars
    class Scars < Gemstone::CharacterStatus # GameBase::CharacterStatus
      class << self
        # Body part accessor methods
        # XML from Simutronics drives the structure of the scar naming (eg. leftEye)
        # The following is a hash of the body parts and shorthand aliases created for more idiomatic Ruby
        BODY_PARTS = {
          leftEye: ['leye'],
          rightEye: ['reye'],
          head: [],
          neck: [],
          back: [],
          chest: [],
          abdomen: ['abs'],
          leftArm: ['larm'],
          rightArm: ['rarm'],
          rightHand: ['rhand'],
          leftHand: ['lhand'],
          leftLeg: ['lleg'],
          rightLeg: ['rleg'],
          leftFoot: ['lfoot'],
          rightFoot: ['rfoot'],
          nsys: ['nerves']
        }.freeze

        # Define methods for each body part and its aliases
        BODY_PARTS.each do |part, aliases|
          # Define the primary method
          define_method(part) do
            fix_injury_mode('both') # continue to use 'both' (_injury2) for now

            XMLData.injuries[part.to_s] && XMLData.injuries[part.to_s]['scar']
          end

          # Define shorthand alias methods
          aliases.each do |ali|
            alias_method ali, part
          end
        end

        # Alias snake_case methods for overachievers
        def left_eye; leftEye; end
        def right_eye; rightEye; end
        def left_arm; leftArm; end
        def right_arm; rightArm; end
        def left_hand; leftHand; end
        def right_hand; rightHand; end
        def left_leg; leftLeg; end
        def right_leg; rightLeg; end
        def left_foot; leftFoot; end
        def right_foot; rightFoot; end

        # Composite scar methods
        def arms
          fix_injury_mode('both')
          [
            XMLData.injuries['leftArm']['scar'],
            XMLData.injuries['rightArm']['scar'],
            XMLData.injuries['leftHand']['scar'],
            XMLData.injuries['rightHand']['scar']
          ].max
        end

        def limbs
          fix_injury_mode('both')
          [
            XMLData.injuries['leftArm']['scar'],
            XMLData.injuries['rightArm']['scar'],
            XMLData.injuries['leftHand']['scar'],
            XMLData.injuries['rightHand']['scar'],
            XMLData.injuries['leftLeg']['scar'],
            XMLData.injuries['rightLeg']['scar']
          ].max
        end

        def torso
          fix_injury_mode('both')
          [
            XMLData.injuries['rightEye']['scar'],
            XMLData.injuries['leftEye']['scar'],
            XMLData.injuries['chest']['scar'],
            XMLData.injuries['abdomen']['scar'],
            XMLData.injuries['back']['scar']
          ].max
        end

        # Helper method to get scar level for any body part
        def scar_level(part)
          fix_injury_mode('both')
          XMLData.injuries[part.to_s] && XMLData.injuries[part.to_s]['scar']
        end

        # Helper method to get all scar levels
        def all_scars
          begin
            fix_injury_mode('scar') # for this one call, we want to get actual scar level data
            result = XMLData.injuries.transform_values { |v| v['scar'] }
          ensure
            fix_injury_mode('both') # reset to both
          end
          return result
        end
      end
    end
  end
end
