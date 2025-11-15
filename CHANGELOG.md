# Changelog

## [5.13.0-beta.0](https://github.com/elanthia-online/lich-5/compare/v5.12.12...v5.13.0-beta.0) (2025-11-15)


### Features

* **dr:** support meta:trashcan tag for DRCI.dispose_trash ([#966](https://github.com/elanthia-online/lich-5/issues/966)) ([0443c47](https://github.com/elanthia-online/lich-5/commit/0443c476978f06858e4efb12fa95fa97581d3787))
* **gs:** Add Armaments (Weapon, Armor, and Shield) Module ([#911](https://github.com/elanthia-online/lich-5/issues/911)) ([f349b57](https://github.com/elanthia-online/lich-5/commit/f349b57f2bf4019d8889c05206e3fc913d1b7c23))
* **gs:** add creature module, including Hinterwilds creatures ([#1002](https://github.com/elanthia-online/lich-5/issues/1002)) ([e065ed5](https://github.com/elanthia-online/lich-5/commit/e065ed5e2da99acfbb65c7c8eff778cea8e60ffd))
* **gs:** Creature module combat tracking ([#1003](https://github.com/elanthia-online/lich-5/issues/1003)) ([286b3d0](https://github.com/elanthia-online/lich-5/commit/286b3d03dc3a92e2992ef1edb3385317f4a3ceed))
* **gs:** track time of last total_experience record ([#1030](https://github.com/elanthia-online/lich-5/issues/1030)) ([16bd702](https://github.com/elanthia-online/lich-5/commit/16bd702cddcb65d348e689e409fbb79a30f093cc))


### Miscellaneous Chores

* pin prerelease v5.13.0-beta.0 ([6a885d9](https://github.com/elanthia-online/lich-5/commit/6a885d99685fc3a60e15ae7aedadc96bd020738f))

## [5.12.12](https://github.com/elanthia-online/lich-5/compare/v5.12.11...v5.12.12) (2025-11-09)


### Bug Fixes

* **all:** Update module strip markdown comments ([#1056](https://github.com/elanthia-online/lich-5/issues/1056)) ([44693ba](https://github.com/elanthia-online/lich-5/commit/44693ba017a076ca65d572d86dd0fca47076c659))
* **all:** Vars/UserVars module fixes and corrections ([#1057](https://github.com/elanthia-online/lich-5/issues/1057)) ([7338ef1](https://github.com/elanthia-online/lich-5/commit/7338ef189ac03289daeb72fddb3ae7a22a2ed4ba))
* **gs:** Infomon parse fix for singular currency ([#1051](https://github.com/elanthia-online/lich-5/issues/1051)) ([eea0ea3](https://github.com/elanthia-online/lich-5/commit/eea0ea3e45dcfeb85a19721fdd39eb85862125c1))


### Documentation

* **gs:** Group API YARD additions ([#1048](https://github.com/elanthia-online/lich-5/issues/1048)) ([e4a611f](https://github.com/elanthia-online/lich-5/commit/e4a611f137eb05b4c0a8394dc07563d5141ecc04))

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
