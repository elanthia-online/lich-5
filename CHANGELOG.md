# Changelog

## [5.13.4](https://github.com/elanthia-online/lich-5/compare/v5.13.3...v5.13.4) (2026-01-14)


### Bug Fixes

* **all:** add window size / position saves to login GUI ([#1128](https://github.com/elanthia-online/lich-5/issues/1128)) ([4a22a1e](https://github.com/elanthia-online/lich-5/commit/4a22a1eb88a9a754af857711263d0174682e6ae9))
* **all:** force system gem install if RubyGems fails ([#1126](https://github.com/elanthia-online/lich-5/issues/1126)) ([4b43170](https://github.com/elanthia-online/lich-5/commit/4b431701718143f339670924dd52599f9a9dea2c))
* **all:** gui_login prevent destroying window if already destroyed ([#1127](https://github.com/elanthia-online/lich-5/issues/1127)) ([3dd8808](https://github.com/elanthia-online/lich-5/commit/3dd880865cc3d9713ffda0e2f8a1218ca5833b7b))
* **all:** non tabbed saved entries in reduced button / font size (not… ([#1129](https://github.com/elanthia-online/lich-5/issues/1129)) ([2ec9f0b](https://github.com/elanthia-online/lich-5/commit/2ec9f0b5b7e507df493657f98f1f1eeaf7e608cb))

## [5.13.3](https://github.com/elanthia-online/lich-5/compare/v5.13.2...v5.13.3) (2026-01-14)


### Bug Fixes

* **all:** account manager sorting GUI fix ([#1123](https://github.com/elanthia-online/lich-5/issues/1123)) ([4457f4b](https://github.com/elanthia-online/lich-5/commit/4457f4b2b509751a4dd25489f957c1fb0ecfecf4))

## [5.13.2](https://github.com/elanthia-online/lich-5/compare/v5.13.1...v5.13.2) (2026-01-14)


### Bug Fixes

* **all:** install_gem_requirements update available gems after install ([#1120](https://github.com/elanthia-online/lich-5/issues/1120)) ([782b00b](https://github.com/elanthia-online/lich-5/commit/782b00bcabb014558340fd006df16d4dea765742))

## [5.13.1](https://github.com/elanthia-online/lich-5/compare/v5.13.0...v5.13.1) (2026-01-14)


### Bug Fixes

* **all:** password_cipher.rb upcase account_name for key ([#1118](https://github.com/elanthia-online/lich-5/issues/1118)) ([e4d41dc](https://github.com/elanthia-online/lich-5/commit/e4d41dc9e15d4bd0effd4b520d8a3dfc0479eb0d))
* **dr:** validator.rb change sleep to should_sleep named param ([#1116](https://github.com/elanthia-online/lich-5/issues/1116)) ([58e9168](https://github.com/elanthia-online/lich-5/commit/58e9168bde5c36f91f683a5e7cb305320cc7fc05))
* **gs:** add base stats capture from 'info full' command ([#1115](https://github.com/elanthia-online/lich-5/issues/1115)) ([1086093](https://github.com/elanthia-online/lich-5/commit/1086093608914555f664f0eea462c3881ab2419e))

## [5.13.0](https://github.com/elanthia-online/lich-5/compare/v5.12.12...v5.13.0) (2026-01-13)


### Features

* **all:** add simplified DB maintenance ([#991](https://github.com/elanthia-online/lich-5/issues/991)) ([894f50d](https://github.com/elanthia-online/lich-5/commit/894f50d451683a53d3eebc059aa8b5a8be7ac4ae))
* **all:** Login modernization and refactor to yaml ([#1063](https://github.com/elanthia-online/lich-5/issues/1063)) ([dda2bb6](https://github.com/elanthia-online/lich-5/commit/dda2bb60eacf1b6e03ae0d6478d1d56fc4593cc1))
* **all:** Refocus Frontend ([#960](https://github.com/elanthia-online/lich-5/issues/960)) ([72222d1](https://github.com/elanthia-online/lich-5/commit/72222d1dd954b441da05717407823dfa45563872))
* **all:** Ruby Memory Releaser module ([#1066](https://github.com/elanthia-online/lich-5/issues/1066)) ([038eef2](https://github.com/elanthia-online/lich-5/commit/038eef21485e637a954acc355a34b2f0c502778b))
* **all:** socket configurator to better guard TCPSocket ([#976](https://github.com/elanthia-online/lich-5/issues/976)) ([f35034c](https://github.com/elanthia-online/lich-5/commit/f35034ca69cddf4d0268b8f19fc5b76cc53a279a))
* **all:** TextStripper module support for XML, HTML, Markdown ([#1055](https://github.com/elanthia-online/lich-5/issues/1055)) ([7dc09b3](https://github.com/elanthia-online/lich-5/commit/7dc09b3e3c3d9c3d229d68f5ea070d2a195b76ee))
* **dr:** Add GameObj.inv support for DR items ([#1080](https://github.com/elanthia-online/lich-5/issues/1080)) ([c521917](https://github.com/elanthia-online/lich-5/commit/c521917ac2a6d11296a0baa74ef4f17053e84f60))
* **dr:** DRCS allow custom adjective for summoned weapons ([#1088](https://github.com/elanthia-online/lich-5/issues/1088)) ([2790d8c](https://github.com/elanthia-online/lich-5/commit/2790d8c2dbc1001306d0f3711af2ae5e5800feb2))
* **dr:** DRParser support for new exp window xml stream elements (rested exp, tdps, favors) ([#1104](https://github.com/elanthia-online/lich-5/issues/1104)) ([ba6a1cf](https://github.com/elanthia-online/lich-5/commit/ba6a1cf7ba2d45f496232290d25df4089bfd4be8))
* **dr:** support meta:trashcan tag for DRCI.dispose_trash ([#966](https://github.com/elanthia-online/lich-5/issues/966)) ([d6a08ed](https://github.com/elanthia-online/lich-5/commit/d6a08ed730206750e9c978a5763476a842644874))
* **gs:** Add Armaments (Weapon, Armor, and Shield) Module ([#911](https://github.com/elanthia-online/lich-5/issues/911)) ([4dd3d40](https://github.com/elanthia-online/lich-5/commit/4dd3d404e94d5da1a54267dc63d900a7d225cdb6))
* **gs:** add creature module, including Hinterwilds creatures ([#1002](https://github.com/elanthia-online/lich-5/issues/1002)) ([ff65c1e](https://github.com/elanthia-online/lich-5/commit/ff65c1eb744bd4a950ad1bb741b42c7261dbcc9c))
* **gs:** add Injured class for checking ability to perform actions ([#1035](https://github.com/elanthia-online/lich-5/issues/1035)) ([e97a74d](https://github.com/elanthia-online/lich-5/commit/e97a74dac26c780b7d5fadff06e0064d79559b0d))
* **gs:** Creature module combat tracking ([#1003](https://github.com/elanthia-online/lich-5/issues/1003)) ([452a34a](https://github.com/elanthia-online/lich-5/commit/452a34ae90b944e993fa4fe147f3301481753529))
* **gs:** track time of last total_experience record ([#1030](https://github.com/elanthia-online/lich-5/issues/1030)) ([e9b31b7](https://github.com/elanthia-online/lich-5/commit/e9b31b7a5413a62a99aeaae4edcd700a6d8abe22))


### Bug Fixes

* **all:** [lib][global-defs] - move update ([#1079](https://github.com/elanthia-online/lich-5/issues/1079)) ([a5b69ae](https://github.com/elanthia-online/lich-5/commit/a5b69aeefda773d8ff745978cbe5c62feaac79b2))
* **all:** change Hash[] pair key conversion to use to_h for Ruby 4.0 ([#1108](https://github.com/elanthia-online/lich-5/issues/1108)) ([3af9467](https://github.com/elanthia-online/lich-5/commit/3af9467d3261ee172d31f4f4b8537f00e3be01fc))
* **all:** ensure proxy path is set for non-destructive array write-th… ([#1073](https://github.com/elanthia-online/lich-5/issues/1073)) ([546fa6b](https://github.com/elanthia-online/lich-5/commit/546fa6b9f54bdb0018c32a4e3f236f3fd577a870))
* **all:** GameObj force new objects ID to be string ([#1087](https://github.com/elanthia-online/lich-5/issues/1087)) ([2c467b8](https://github.com/elanthia-online/lich-5/commit/2c467b8b40a98cffc5609e8c056936ef2c681bb1))
* **all:** map dijkstra optimization ([#1061](https://github.com/elanthia-online/lich-5/issues/1061)) ([782df48](https://github.com/elanthia-online/lich-5/commit/782df481960e0dea30d392144f044a14a0d4c249))
* **all:** move gui-login.rb to Ruby standard gui_login.rb ([#1111](https://github.com/elanthia-online/lich-5/issues/1111)) ([47abb8f](https://github.com/elanthia-online/lich-5/commit/47abb8ff8817d2e4f1528647af0b1020cfee21c3))
* **all:** update location for currency and move game-loader.rb to Ruby standard gameloader.rb ([#1112](https://github.com/elanthia-online/lich-5/issues/1112)) ([39bbb60](https://github.com/elanthia-online/lich-5/commit/39bbb6094f16380d1e4ecd6c080d6199faef170d))
* **all:** update.rb keep script/data file incase of error on update ([#1070](https://github.com/elanthia-online/lich-5/issues/1070)) ([2f09881](https://github.com/elanthia-online/lich-5/commit/2f09881dd7df27c84abb07c1daff6fbdab04d087))
* **all:** xmlparser.rb gate GSL exits sending behind [@send](https://github.com/send)_fake_tags ([#1103](https://github.com/elanthia-online/lich-5/issues/1103)) ([053319d](https://github.com/elanthia-online/lich-5/commit/053319d883c0c3dec0ccebf2978c19f9dc7ba3b1))
* **dr:** DRCA allow custom spell prep messaging ([#1089](https://github.com/elanthia-online/lich-5/issues/1089)) ([42f5025](https://github.com/elanthia-online/lich-5/commit/42f502575a7a45abcad76aab41b2ef133712e586))
* **dr:** equipmanager.rb support for custom messaging in forester's longbow ([#1105](https://github.com/elanthia-online/lich-5/issues/1105)) ([557fab5](https://github.com/elanthia-online/lich-5/commit/557fab5f02e49008cce3ad71b1c4bb2d2eaa169a))
* **dr:** Fix exp mods parsing for DR ([#1102](https://github.com/elanthia-online/lich-5/issues/1102)) ([dbb50ed](https://github.com/elanthia-online/lich-5/commit/dbb50ed6bff5aa7e3f46e44ed08d660cee09591a))
* **dr:** Fix hang in equipment manager when game doesn't respond to commands ([#1110](https://github.com/elanthia-online/lich-5/issues/1110)) ([34c394a](https://github.com/elanthia-online/lich-5/commit/34c394abbe04baa8cf1546e6005d5fb81280a90f))
* **dr:** Update Slackbot error handling, and lnet management ([#1091](https://github.com/elanthia-online/lich-5/issues/1091)) ([f729c69](https://github.com/elanthia-online/lich-5/commit/f729c690fb1221b0e39ff6ed309a8e6c5427751a))
* **gs:** Bounty parser.rb FWI guard regex update ([#1096](https://github.com/elanthia-online/lich-5/issues/1096)) ([036a2c5](https://github.com/elanthia-online/lich-5/commit/036a2c5d1090e9806deb4c1181abcdfba6ed591e))
* **gs:** cman.rb add hamstring regex for already lying down target ([#1090](https://github.com/elanthia-online/lich-5/issues/1090)) ([79e2b91](https://github.com/elanthia-online/lich-5/commit/79e2b91a9932ea10c916fca126d0d1a67ba9f6b8))
* **gs:** cman.rb hamstring regex update when can't perform on target ([#1092](https://github.com/elanthia-online/lich-5/issues/1092)) ([966aa78](https://github.com/elanthia-online/lich-5/commit/966aa78bd33ba8af9a3744e13e46fa6b113f4917))
* **gs:** currency.rb track gold ([#1109](https://github.com/elanthia-online/lich-5/issues/1109)) ([f51c351](https://github.com/elanthia-online/lich-5/commit/f51c35145d7289964f437b084652ab7110222042))
* **gs:** Infomon additional CHE resign regex ([#1067](https://github.com/elanthia-online/lich-5/issues/1067)) ([94108ef](https://github.com/elanthia-online/lich-5/commit/94108ef5ecb19ea86eafd711d6fb33ef5f3f2f15))
* **gs:** Resource tracking for sorcerer shadow essence ([#1085](https://github.com/elanthia-online/lich-5/issues/1085)) ([7730550](https://github.com/elanthia-online/lich-5/commit/7730550fd05b6e403d6fe0bf3c23dd68dc093d88))

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
