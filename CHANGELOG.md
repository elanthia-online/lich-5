# Changelog

## [5.12.0-beta.6](https://github.com/elanthia-online/lich-5/compare/v5.12.11...v5.12.0-beta.6) (2025-11-03)


### Features

* **dr:** support meta:trashcan tag for DRCI.dispose_trash ([#966](https://github.com/elanthia-online/lich-5/issues/966)) ([fd16ce2](https://github.com/elanthia-online/lich-5/commit/fd16ce2c204b0432dae17c67a88a8f82f74a65d3))
* **gs:** Add Armaments (Weapon, Armor, and Shield) Module ([#911](https://github.com/elanthia-online/lich-5/issues/911)) ([7bbf3cb](https://github.com/elanthia-online/lich-5/commit/7bbf3cb871a8ad0074b0feb3a66a2fbad278c545))
* **gs:** add creature module, including Hinterwilds creatures ([#1002](https://github.com/elanthia-online/lich-5/issues/1002)) ([eb2b89e](https://github.com/elanthia-online/lich-5/commit/eb2b89e9001364fba5e58a2b7dbde397aff11491))
* **gs:** Creature module combat tracking ([#1003](https://github.com/elanthia-online/lich-5/issues/1003)) ([836cd56](https://github.com/elanthia-online/lich-5/commit/836cd564d2d2cbb7ab889b8906b4c47d46b405df))
* **gs:** track time of last total_experience record ([#1030](https://github.com/elanthia-online/lich-5/issues/1030)) ([95ee8e9](https://github.com/elanthia-online/lich-5/commit/95ee8e9eeff0865d4177fac3ac90004e50f8824b))


### Miscellaneous Chores

* pin prerelease v5.12.0-beta.6 ([d06d418](https://github.com/elanthia-online/lich-5/commit/d06d41824964663756c5cf7d9d5f042725aaf29c))

## [5.12.11](https://github.com/elanthia-online/lich-5/compare/v5.12.10...v5.12.11) (2025-10-31)


### Bug Fixes

* **dr:** add bput match for system updates preventing actions ([#1034](https://github.com/elanthia-online/lich-5/issues/1034)) ([5df10f1](https://github.com/elanthia-online/lich-5/commit/5df10f1f8d75598bfea52caf2467e9bad92f7041))
* **dr:** drdefs.rb npc parsing ([#1038](https://github.com/elanthia-online/lich-5/issues/1038)) ([328c2b2](https://github.com/elanthia-online/lich-5/commit/328c2b29fd8f7d8efb017a55086ded77d30ac4b9))
* **dr:** Fix container reference in get_item_from_eddy_portal method ([#1039](https://github.com/elanthia-online/lich-5/issues/1039)) ([20a3f09](https://github.com/elanthia-online/lich-5/commit/20a3f093925616d8ebd133e04847ae1eea817692))
* **gs:** bounty location regex needs to match "under" ([#1037](https://github.com/elanthia-online/lich-5/issues/1037)) ([6358ba3](https://github.com/elanthia-online/lich-5/commit/6358ba305e8c9cd5acb8f0340069f2812e7cc648))

## [5.12.10](https://github.com/elanthia-online/lich-5/compare/v5.12.9...v5.12.10) (2025-10-18)


### Bug Fixes

* **all:** games.rb catch additional error for nested single/double qu… ([#1031](https://github.com/elanthia-online/lich-5/issues/1031)) ([7e572cf](https://github.com/elanthia-online/lich-5/commit/7e572cfbb8a8682d022ced5fd2ccce829be74518))
* **dr:** change keys for DR_SKILLS_DATA[:guild_skill_aliases] to be strings instead of symbols ([#1032](https://github.com/elanthia-online/lich-5/issues/1032)) ([1fc7510](https://github.com/elanthia-online/lich-5/commit/1fc75105ea378b204503dd0538bcd153ccff2f38))
* **gs:** Bounty parser for SG npcs matching ([#1027](https://github.com/elanthia-online/lich-5/issues/1027)) ([f4e993f](https://github.com/elanthia-online/lich-5/commit/f4e993f6299b595d0dd713939cc4093daa0c87a4))
* **gs:** match READY/STOW items with a/an/some inside the link ([#1026](https://github.com/elanthia-online/lich-5/issues/1026)) ([e57561a](https://github.com/elanthia-online/lich-5/commit/e57561a611d1d07c974e4255b461be60c09d98fd))

## [5.12.9](https://github.com/elanthia-online/lich-5/compare/v5.12.8...v5.12.9) (2025-10-03)


### Bug Fixes

* **gs:** StowList/ReadyList reset bug if non-default keys added ([#1019](https://github.com/elanthia-online/lich-5/issues/1019)) ([c97d86d](https://github.com/elanthia-online/lich-5/commit/c97d86d65664e5defc252f7687fe6d918c54b4c7))

## [5.12.8](https://github.com/elanthia-online/lich-5/compare/lich-5-v5.12.7...lich-5/v5.12.8) (2025-09-28)


### Bug Fixes

* **all:** script.rb show custom at script exit as well ([#993](https://github.com/elanthia-online/lich-5/issues/993)) ([dfe92dd](https://github.com/elanthia-online/lich-5/commit/dfe92ddbc8a20a4b51e98c048bdd81379ff4e425))
* **all:** Updated update.rb for single trunk and release please ([#1001](https://github.com/elanthia-online/lich-5/issues/1001)) ([7840b3d](https://github.com/elanthia-online/lich-5/commit/7840b3d7d4e3e19a1c6bb226fb614f737471a41c))
