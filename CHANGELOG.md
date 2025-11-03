# Changelog

## [5.12.0-beta.6](https://github.com/elanthia-online/lich-5/compare/v5.12.11...v5.12.0-beta.6) (2025-11-03)


### Features

* **dr:** support meta:trashcan tag for DRCI.dispose_trash ([#966](https://github.com/elanthia-online/lich-5/issues/966)) ([97e1540](https://github.com/elanthia-online/lich-5/commit/97e1540c2332a045f69878ba07e9f8971d35c799))
* **gs:** Add Armaments (Weapon, Armor, and Shield) Module ([#911](https://github.com/elanthia-online/lich-5/issues/911)) ([89263ee](https://github.com/elanthia-online/lich-5/commit/89263ee066c2db77341eb3f603bd966b189dd75a))
* **gs:** add creature module, including Hinterwilds creatures ([#1002](https://github.com/elanthia-online/lich-5/issues/1002)) ([46ef960](https://github.com/elanthia-online/lich-5/commit/46ef960f656c6fa07c1e67fc3172f1ec127706cd))
* **gs:** Creature module combat tracking ([#1003](https://github.com/elanthia-online/lich-5/issues/1003)) ([38b63ef](https://github.com/elanthia-online/lich-5/commit/38b63ef79b98b9d202e73e60bab01e894c2b8eae))
* **gs:** track time of last total_experience record ([#1030](https://github.com/elanthia-online/lich-5/issues/1030)) ([5708674](https://github.com/elanthia-online/lich-5/commit/5708674aa3dce43deb73c2bd134da741dd7f74cd))


### Miscellaneous Chores

* pin prerelease v5.12.0-beta.6 ([55cf228](https://github.com/elanthia-online/lich-5/commit/55cf22831620a047efee0700c7f848ad4421ac24))

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
