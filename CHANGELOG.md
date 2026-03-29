# Changelog

## [5.17.0](https://github.com/elanthia-online/lich-5/compare/v5.16.2...v5.17.0) (2026-03-29)


### Features

* **all:** Add active sessions API ([#1274](https://github.com/elanthia-online/lich-5/issues/1274)) ([094c355](https://github.com/elanthia-online/lich-5/commit/094c355c05a29eefc1ffc23a565b6505b0c6615a))
* **all:** add core classes, ScriptSync, and login auto-sync ([#1273](https://github.com/elanthia-online/lich-5/issues/1273)) ([3ccdfb3](https://github.com/elanthia-online/lich-5/commit/3ccdfb38076c5717f9bbdb867af77c26ba0fcdd7))
* **all:** Add Genie map cross-reference fields to the DragonRealms map data model ([#1169](https://github.com/elanthia-online/lich-5/issues/1169)) ([1e7c1dd](https://github.com/elanthia-online/lich-5/commit/1e7c1dde11025e5fe8bdbdf9f562f97bb4a84a2c))
* **all:** add InstanceSettings for core Settings API access ([#1233](https://github.com/elanthia-online/lich-5/issues/1233)) ([6de17eb](https://github.com/elanthia-online/lich-5/commit/6de17eb36119f78a34b8ba3f6ee4ac16e1071b9e))
* **all:** Add session status CLI query ([#1276](https://github.com/elanthia-online/lich-5/issues/1276)) ([91e90f7](https://github.com/elanthia-online/lich-5/commit/91e90f7c4c36cb1620c0c710acf59428172cd0ba))
* **all:** add simplified DB maintenance ([#991](https://github.com/elanthia-online/lich-5/issues/991)) ([894f50d](https://github.com/elanthia-online/lich-5/commit/894f50d451683a53d3eebc059aa8b5a8be7ac4ae))
* **all:** configurable debug log retention ([#1282](https://github.com/elanthia-online/lich-5/issues/1282)) ([03d908d](https://github.com/elanthia-online/lich-5/commit/03d908d6fc433546095594fd27f955969e2803df))
* **all:** gameobj.rb - add type? method for explicit type check ([#928](https://github.com/elanthia-online/lich-5/issues/928)) ([cca16b6](https://github.com/elanthia-online/lich-5/commit/cca16b6c84987530370b7f17104e90d55df8caf5))
* **all:** Login modernization and refactor to yaml ([#1063](https://github.com/elanthia-online/lich-5/issues/1063)) ([dda2bb6](https://github.com/elanthia-online/lich-5/commit/dda2bb60eacf1b6e03ae0d6478d1d56fc4593cc1))
* **all:** messaging.rb add cmd link method ([#866](https://github.com/elanthia-online/lich-5/issues/866)) ([6b33c6e](https://github.com/elanthia-online/lich-5/commit/6b33c6ef7f369f52f1e0a5092e999f125542eeec))
* **all:** Refocus Frontend ([#960](https://github.com/elanthia-online/lich-5/issues/960)) ([72222d1](https://github.com/elanthia-online/lich-5/commit/72222d1dd954b441da05717407823dfa45563872))
* **all:** Ruby Memory Releaser module ([#1066](https://github.com/elanthia-online/lich-5/issues/1066)) ([038eef2](https://github.com/elanthia-online/lich-5/commit/038eef21485e637a954acc355a34b2f0c502778b))
* **all:** session summary store and reporting ([#1247](https://github.com/elanthia-online/lich-5/issues/1247)) ([36ec701](https://github.com/elanthia-online/lich-5/commit/36ec70170e7acb6e56c6da2e78d7fe6f08a7861a))
* **all:** settings.rb - proposal for sequel based Settings ([#591](https://github.com/elanthia-online/lich-5/issues/591)) ([49db397](https://github.com/elanthia-online/lich-5/commit/49db397bebe08994271febee3ea3d4ce5a973d21))
* **all:** socket configurator to better guard TCPSocket ([#976](https://github.com/elanthia-online/lich-5/issues/976)) ([f35034c](https://github.com/elanthia-online/lich-5/commit/f35034ca69cddf4d0268b8f19fc5b76cc53a279a))
* **all:** TextStripper module support for XML, HTML, Markdown ([#1055](https://github.com/elanthia-online/lich-5/issues/1055)) ([7dc09b3](https://github.com/elanthia-online/lich-5/commit/7dc09b3e3c3d9c3d229d68f5ea070d2a195b76ee))
* **all:** util.rb add Ruby gem install helper method ([#861](https://github.com/elanthia-online/lich-5/issues/861)) ([d8b484a](https://github.com/elanthia-online/lich-5/commit/d8b484a23eeddeddd9f5969f08754280a870d224))
* **dr:** Add GameObj.inv support for DR items ([#1080](https://github.com/elanthia-online/lich-5/issues/1080)) ([c521917](https://github.com/elanthia-online/lich-5/commit/c521917ac2a6d11296a0baa74ef4f17053e84f60))
* **dr:** common-healing.rb - add vitality parsing to HealthResult ([#1265](https://github.com/elanthia-online/lich-5/issues/1265)) ([8a65de0](https://github.com/elanthia-online/lich-5/commit/8a65de0d705a86c42b8fbbf6396f0f80232d32fc))
* **dr:** DRCS allow custom adjective for summoned weapons ([#1088](https://github.com/elanthia-online/lich-5/issues/1088)) ([2790d8c](https://github.com/elanthia-online/lich-5/commit/2790d8c2dbc1001306d0f3711af2ae5e5800feb2))
* **dr:** DRExpMonitor move into core lich ([#1154](https://github.com/elanthia-online/lich-5/issues/1154)) ([48524b9](https://github.com/elanthia-online/lich-5/commit/48524b9a1bef7089f371df5bb0073792ef287023))
* **dr:** DRParser support for new exp window xml stream elements (rested exp, tdps, favors) ([#1104](https://github.com/elanthia-online/lich-5/issues/1104)) ([ba6a1cf](https://github.com/elanthia-online/lich-5/commit/ba6a1cf7ba2d45f496232290d25df4089bfd4be8))
* **dr:** support meta:trashcan tag for DRCI.dispose_trash ([#966](https://github.com/elanthia-online/lich-5/issues/966)) ([d6a08ed](https://github.com/elanthia-online/lich-5/commit/d6a08ed730206750e9c978a5763476a842644874))
* **gs:** Add Armaments (Weapon, Armor, and Shield) Module ([#911](https://github.com/elanthia-online/lich-5/issues/911)) ([4dd3d40](https://github.com/elanthia-online/lich-5/commit/4dd3d404e94d5da1a54267dc63d900a7d225cdb6))
* **gs:** add creature module, including Hinterwilds creatures ([#1002](https://github.com/elanthia-online/lich-5/issues/1002)) ([ff65c1e](https://github.com/elanthia-online/lich-5/commit/ff65c1eb744bd4a950ad1bb741b42c7261dbcc9c))
* **gs:** add Enhancive module for enhancive item bonus tracking ([#1113](https://github.com/elanthia-online/lich-5/issues/1113)) ([61cff8f](https://github.com/elanthia-online/lich-5/commit/61cff8f7fb0155c6ebf8096186bed1cd8fc023e9))
* **gs:** add Injured class for checking ability to perform actions ([#1035](https://github.com/elanthia-online/lich-5/issues/1035)) ([e97a74d](https://github.com/elanthia-online/lich-5/commit/e97a74dac26c780b7d5fadff06e0064d79559b0d))
* **gs:** add QStrike module for optimal stamina-based RT reduction ([#1114](https://github.com/elanthia-online/lich-5/issues/1114)) ([b10af81](https://github.com/elanthia-online/lich-5/commit/b10af81f1ec8ad6143f58e1565968312d469a62e))
* **gs:** Breakout and Buildout Societes ([#919](https://github.com/elanthia-online/lich-5/issues/919)) ([0964bbf](https://github.com/elanthia-online/lich-5/commit/0964bbf0b0caf46374322bfa4b79137742942bac))
* **gs:** Creature module combat tracking ([#1003](https://github.com/elanthia-online/lich-5/issues/1003)) ([452a34a](https://github.com/elanthia-online/lich-5/commit/452a34ae90b944e993fa4fe147f3301481753529))
* **gs:** gameobj.rb allow for custom gameobj data ([#848](https://github.com/elanthia-online/lich-5/issues/848)) ([2a8b5bd](https://github.com/elanthia-online/lich-5/commit/2a8b5bdb190b911e8a81862227796ca0cf9dbed8))
* **gs:** Overwatch module into core ([#1201](https://github.com/elanthia-online/lich-5/issues/1201)) ([70dee4b](https://github.com/elanthia-online/lich-5/commit/70dee4bd617de4ee8c38ec8b585fc9a56fd100b5))
* **gs:** PSMS add support for FORCERT ([#890](https://github.com/elanthia-online/lich-5/issues/890)) ([9e8cdbc](https://github.com/elanthia-online/lich-5/commit/9e8cdbccef94bc4b526a661c1afbb954c75b2542))
* **gs:** PSMS updates, including CMan.use ([#865](https://github.com/elanthia-online/lich-5/issues/865)) ([f0ee681](https://github.com/elanthia-online/lich-5/commit/f0ee681ba75670df17239dbabc34da1ea52050d1))
* **gs:** ReadyList & StowList classes for item tracking ([#884](https://github.com/elanthia-online/lich-5/issues/884)) ([ff1faa0](https://github.com/elanthia-online/lich-5/commit/ff1faa00c194c04c7a99fdba9dc1ce18d89f9a10))
* **gs:** track time of last total_experience record ([#1030](https://github.com/elanthia-online/lich-5/issues/1030)) ([e9b31b7](https://github.com/elanthia-online/lich-5/commit/e9b31b7a5413a62a99aeaae4edcd700a6d8abe22))


### Bug Fixes

* add bundler step to Ruby install ([2f7b6e5](https://github.com/elanthia-online/lich-5/commit/2f7b6e56fb6fd807efc1cf3664de921c031c1838))
* **all:** [lib][global-defs] - move update ([#1079](https://github.com/elanthia-online/lich-5/issues/1079)) ([a5b69ae](https://github.com/elanthia-online/lich-5/commit/a5b69aeefda773d8ff745978cbe5c62feaac79b2))
* **all:** account manager sorting GUI fix ([#1123](https://github.com/elanthia-online/lich-5/issues/1123)) ([4457f4b](https://github.com/elanthia-online/lich-5/commit/4457f4b2b509751a4dd25489f957c1fb0ecfecf4))
* **all:** add --gs and --dr, refactor argv_options to helpers ([#1133](https://github.com/elanthia-online/lich-5/issues/1133)) ([a809a26](https://github.com/elanthia-online/lich-5/commit/a809a26cb9694fa699855dd91de6888aa906c514))
* **all:** add retry with exponential backoff for all login authentication ([#1205](https://github.com/elanthia-online/lich-5/issues/1205)) ([ff365ef](https://github.com/elanthia-online/lich-5/commit/ff365ef783cdd6803ce01e811b6ecf2cb5937859))
* **all:** add timeout safety to fput to prevent infinite hangs ([#1261](https://github.com/elanthia-online/lich-5/issues/1261)) ([79176c3](https://github.com/elanthia-online/lich-5/commit/79176c3b07c46fe4fed920ed70714bc23b4b3913))
* **all:** add window size / position saves to login GUI ([#1128](https://github.com/elanthia-online/lich-5/issues/1128)) ([4a22a1e](https://github.com/elanthia-online/lich-5/commit/4a22a1eb88a9a754af857711263d0174682e6ae9))
* **all:** addbacks and corrections for charsettings and gamesettings ([#889](https://github.com/elanthia-online/lich-5/issues/889)) ([98c0765](https://github.com/elanthia-online/lich-5/commit/98c076507ee17b2c2e4dfe9740b19b511b371ba6))
* **all:** allow --add-account to run without yaml and dat ([#1143](https://github.com/elanthia-online/lich-5/issues/1143)) ([ca48153](https://github.com/elanthia-online/lich-5/commit/ca48153f36c96d70728142d1e5621ed82b2e7750))
* **all:** Allow hmr to work on global_defs.rb ([#1156](https://github.com/elanthia-online/lich-5/issues/1156)) ([b077c8a](https://github.com/elanthia-online/lich-5/commit/b077c8a6fca3cd6059606a834014b3b25b6cb3a3))
* **all:** change class to is_a? checks ([#913](https://github.com/elanthia-online/lich-5/issues/913)) ([f6a441a](https://github.com/elanthia-online/lich-5/commit/f6a441af56df867d52e9df0ed749164f39e8522c))
* **all:** change encodings in main.rb to wizard FE only ([#1199](https://github.com/elanthia-online/lich-5/issues/1199)) ([fe43007](https://github.com/elanthia-online/lich-5/commit/fe4300702392b8b4c1720ac3f988cc2fa56d2bf9))
* **all:** change Hash[] pair key conversion to use to_h for Ruby 4.0 ([#1108](https://github.com/elanthia-online/lich-5/issues/1108)) ([3af9467](https://github.com/elanthia-online/lich-5/commit/3af9467d3261ee172d31f4f4b8537f00e3be01fc))
* **all:** Change server_time_offset in XMLParser to be float instead of int ([#1184](https://github.com/elanthia-online/lich-5/issues/1184)) ([2e26e8e](https://github.com/elanthia-online/lich-5/commit/2e26e8ea7af4c8ccb208af19a806a9005e8d7526))
* **all:** database_adapter.rb error handling improvement ([#956](https://github.com/elanthia-online/lich-5/issues/956)) ([52f13d8](https://github.com/elanthia-online/lich-5/commit/52f13d8f93cc9401c4df2860cde315679c486062))
* **all:** delegate .to_json properly in settings_proxy ([#927](https://github.com/elanthia-online/lich-5/issues/927)) ([fa72e1d](https://github.com/elanthia-online/lich-5/commit/fa72e1de7f50bf7dc810de096f95dff89417b742))
* **all:** enable --login for multi-variable custom launch commands ([#1144](https://github.com/elanthia-online/lich-5/issues/1144)) ([0464b2d](https://github.com/elanthia-online/lich-5/commit/0464b2d2e781a4aed1e1d8469bbd54689272ca62))
* **all:** ensure proxy path is set for non-destructive array write-th… ([#1073](https://github.com/elanthia-online/lich-5/issues/1073)) ([546fa6b](https://github.com/elanthia-online/lich-5/commit/546fa6b9f54bdb0018c32a4e3f236f3fd577a870))
* **all:** ensure updates do not target detached proxy views ([#990](https://github.com/elanthia-online/lich-5/issues/990)) ([366f1ad](https://github.com/elanthia-online/lich-5/commit/366f1ad97b8d975987631469cc88a7bedad912d7))
* **all:** Exit quickly on CLI authentication failure ([#1237](https://github.com/elanthia-online/lich-5/issues/1237)) ([f177cd0](https://github.com/elanthia-online/lich-5/commit/f177cd0f5434139767d0b3494a4640bf1d480a1d))
* **all:** fix GameObj container initialization and add clear_all_containers ([#1226](https://github.com/elanthia-online/lich-5/issues/1226)) ([2a9a6da](https://github.com/elanthia-online/lich-5/commit/2a9a6daa6a9327e903e8f1dc59d0421b290970bd))
* **all:** fix multiple custom entries, improvements to yaml save ([#1134](https://github.com/elanthia-online/lich-5/issues/1134)) ([86e69a3](https://github.com/elanthia-online/lich-5/commit/86e69a353ca323cc922fc06abddca3b61f62c0ff))
* **all:** fix three revert bugs in SnapshotManager ([#1289](https://github.com/elanthia-online/lich-5/issues/1289)) ([fa87aa0](https://github.com/elanthia-online/lich-5/commit/fa87aa0e8a804343be329145ab147d8f738b886c))
* **all:** force system gem install if RubyGems fails ([#1126](https://github.com/elanthia-online/lich-5/issues/1126)) ([4b43170](https://github.com/elanthia-online/lich-5/commit/4b431701718143f339670924dd52599f9a9dea2c))
* **all:** GameObj force new objects ID to be string ([#1087](https://github.com/elanthia-online/lich-5/issues/1087)) ([2c467b8](https://github.com/elanthia-online/lich-5/commit/2c467b8b40a98cffc5609e8c056936ef2c681bb1))
* **all:** GameObj object dedupe & GC ([#1234](https://github.com/elanthia-online/lich-5/issues/1234)) ([6a48812](https://github.com/elanthia-online/lich-5/commit/6a4881280aa7f656aee103fdd92c37e72fd5dfe2))
* **all:** gameobj.rb deeper lookup ([#885](https://github.com/elanthia-online/lich-5/issues/885)) ([190a74a](https://github.com/elanthia-online/lich-5/commit/190a74a853305db480a18dd7edc85a92d74f253f))
* **all:** games.rb catch additional error for nested single/double qu… ([#1031](https://github.com/elanthia-online/lich-5/issues/1031)) ([7e572cf](https://github.com/elanthia-online/lich-5/commit/7e572cfbb8a8682d022ced5fd2ccce829be74518))
* **all:** games.rb correct detection of invalid attributes and clean ([#924](https://github.com/elanthia-online/lich-5/issues/924)) ([27d856f](https://github.com/elanthia-online/lich-5/commit/27d856f9210dedf21eb4dcaa9326439ad00b0cf5))
* **all:** games.rb fix multiple single and double quote in XML ([#832](https://github.com/elanthia-online/lich-5/issues/832)) ([971f73f](https://github.com/elanthia-online/lich-5/commit/971f73f4d596b401a6060774d530a9d46ad2f56a))
* **all:** games.rb fixing dynamic dialogs ([#882](https://github.com/elanthia-online/lich-5/issues/882)) ([588465d](https://github.com/elanthia-online/lich-5/commit/588465d2d8b2f7842923d48a2fd8b807d37a6e68))
* **all:** games.rb proper fix for single/double nested quotes ([#836](https://github.com/elanthia-online/lich-5/issues/836)) ([6d99f2a](https://github.com/elanthia-online/lich-5/commit/6d99f2a6c3076e928c2801f747dcbbef65d814a7))
* **all:** games.rb typo in empty to empty? check ([#837](https://github.com/elanthia-online/lich-5/issues/837)) ([30a3957](https://github.com/elanthia-online/lich-5/commit/30a39572cb6bcf5c835265cb47f9ceed499fce79))
* **all:** games.rb XMLData.name wait till both not NIL and not EMPTY ([#826](https://github.com/elanthia-online/lich-5/issues/826)) ([489b5f5](https://github.com/elanthia-online/lich-5/commit/489b5f5eb5f045f033f19218393123c5dd849f8b))
* **all:** global_defs.rb bug in fput ([#864](https://github.com/elanthia-online/lich-5/issues/864)) ([ca0fb64](https://github.com/elanthia-online/lich-5/commit/ca0fb6459ee5c4b1d62076be58e6f461a9e2f2ba))
* **all:** guard against broken pipe errors in Game._puts and send_to_client ([#1260](https://github.com/elanthia-online/lich-5/issues/1260)) ([995cefd](https://github.com/elanthia-online/lich-5/commit/995cefd3ade131c5a819e3a6f649f7a2e4f95470))
* **all:** guard nil release asset and validate before deleting lib/ ([#1290](https://github.com/elanthia-online/lich-5/issues/1290)) ([b8e3002](https://github.com/elanthia-online/lich-5/commit/b8e3002e206771b1a6937ddcdb1d630e01600b84))
* **all:** guard nil stable version in beta channel resolution ([#1291](https://github.com/elanthia-online/lich-5/issues/1291)) ([c5c42c6](https://github.com/elanthia-online/lich-5/commit/c5c42c6a5e5042a97aeb250a0c8e142259cb830a))
* **all:** gui_login prevent destroying window if already destroyed ([#1127](https://github.com/elanthia-online/lich-5/issues/1127)) ([3dd8808](https://github.com/elanthia-online/lich-5/commit/3dd880865cc3d9713ffda0e2f8a1218ca5833b7b))
* **all:** handle auth exceptions in manual login to prevent hang on bad password ([#1267](https://github.com/elanthia-online/lich-5/issues/1267)) ([05dfe30](https://github.com/elanthia-online/lich-5/commit/05dfe306dd9a2d64f54d97b0dc14511e00a8be03))
* **all:** install_gem_requirements update available gems after install ([#1120](https://github.com/elanthia-online/lich-5/issues/1120)) ([782b00b](https://github.com/elanthia-online/lich-5/commit/782b00bcabb014558340fd006df16d4dea765742))
* **all:** lich.rb class variable not initialized ([#855](https://github.com/elanthia-online/lich-5/issues/855)) ([9ac3dc3](https://github.com/elanthia-online/lich-5/commit/9ac3dc36bcb996e227ef12c361c47d2a16ce510c))
* **all:** lich.rb deprecated FE message ([#852](https://github.com/elanthia-online/lich-5/issues/852)) ([1f7ae89](https://github.com/elanthia-online/lich-5/commit/1f7ae895517631cb8d387e9e61ccc405b4ff038a))
* **all:** limitedarray.rb max_size increase ([#946](https://github.com/elanthia-online/lich-5/issues/946)) ([19d585a](https://github.com/elanthia-online/lich-5/commit/19d585a013f8840a3419be4ab0ed7e7d9a698ff0))
* **all:** limitedarray.rb max_size increase [#946](https://github.com/elanthia-online/lich-5/issues/946) ([46cb3fa](https://github.com/elanthia-online/lich-5/commit/46cb3faf4b1621197e7ec48dd72491cf293e61a3))
* **all:** log and re-raise unexpected errors in saved login auth handler ([#1271](https://github.com/elanthia-online/lich-5/issues/1271)) ([5ea9501](https://github.com/elanthia-online/lich-5/commit/5ea950199d83ddc97fb5aa241d70e42a71c9d0bd))
* **all:** log.rb force msg to String for regexp comparison ([#856](https://github.com/elanthia-online/lich-5/issues/856)) ([b88f7dd](https://github.com/elanthia-online/lich-5/commit/b88f7dd50fc160767abeaeb561c4477cc1219a3c))
* **all:** login_tab_utils.rb expand helper text show Warlock ([#1135](https://github.com/elanthia-online/lich-5/issues/1135)) ([1b43e0d](https://github.com/elanthia-online/lich-5/commit/1b43e0d12b5afa88207ac017b03d790519c260d3))
* **all:** map dijkstra optimization ([#1061](https://github.com/elanthia-online/lich-5/issues/1061)) ([782df48](https://github.com/elanthia-online/lich-5/commit/782df481960e0dea30d392144f044a14a0d4c249))
* **all:** map_base.rb sort JSON better ([#1171](https://github.com/elanthia-online/lich-5/issues/1171)) ([7e60e68](https://github.com/elanthia-online/lich-5/commit/7e60e68c1dc310ebe87a10cbf25696287cf7f4bc))
* **all:** messaging debug not compared to falseclass ([#887](https://github.com/elanthia-online/lich-5/issues/887)) ([c81ce28](https://github.com/elanthia-online/lich-5/commit/c81ce28e4b54d0e506a67177df6abf1c5bded047))
* **all:** messaging.rb encoding issue ([#933](https://github.com/elanthia-online/lich-5/issues/933)) ([5069581](https://github.com/elanthia-online/lich-5/commit/5069581bd0029456b1473627c1876ec7c9ec4386))
* **all:** messaging.rb fix XML encoding for wizard and avalon ([#853](https://github.com/elanthia-online/lich-5/issues/853)) ([942570c](https://github.com/elanthia-online/lich-5/commit/942570ce4b34976db06536d8180757efa47fb8cc))
* **all:** messaging.rb return "" for xml_encode with Wizard ([#1147](https://github.com/elanthia-online/lich-5/issues/1147)) ([96a5a7f](https://github.com/elanthia-online/lich-5/commit/96a5a7f17b2f6d57ec456a2fcf798bf8c76a2a7c))
* **all:** messaging.rb xml_encode mono method msg ([#868](https://github.com/elanthia-online/lich-5/issues/868)) ([52e6aa1](https://github.com/elanthia-online/lich-5/commit/52e6aa176b9e6f2c92d4ebd3e38f9cd710fcd20a))
* **all:** move gui-login.rb to Ruby standard gui_login.rb ([#1111](https://github.com/elanthia-online/lich-5/issues/1111)) ([47abb8f](https://github.com/elanthia-online/lich-5/commit/47abb8ff8817d2e4f1528647af0b1020cfee21c3))
* **all:** Mutli-launch persistent login GUI ([#1245](https://github.com/elanthia-online/lich-5/issues/1245)) ([3e4a873](https://github.com/elanthia-online/lich-5/commit/3e4a873131311e57da32f029ccb2a9e70bc5211d))
* **all:** narrow safe_write rollback scope so cleanup failure preserves successful write ([#1287](https://github.com/elanthia-online/lich-5/issues/1287)) ([8974813](https://github.com/elanthia-online/lich-5/commit/8974813089c3fd274a62dc049336792be89e7421))
* **all:** non tabbed saved entries in reduced button / font size (not… ([#1129](https://github.com/elanthia-online/lich-5/issues/1129)) ([2ec9f0b](https://github.com/elanthia-online/lich-5/commit/2ec9f0b5b7e507df493657f98f1f1eeaf7e608cb))
* **all:** password_cipher.rb upcase account_name for key ([#1118](https://github.com/elanthia-online/lich-5/issues/1118)) ([e4d41dc](https://github.com/elanthia-online/lich-5/commit/e4d41dc9e15d4bd0effd4b520d8a3dfc0479eb0d))
* **all:** Persistent Launcher re-enable play button post launch ([#1269](https://github.com/elanthia-online/lich-5/issues/1269)) ([72d532f](https://github.com/elanthia-online/lich-5/commit/72d532f43b0f12fd925ca75e2f7d9447a72508a1))
* **all:** prevent closing connection on module reload ([#1148](https://github.com/elanthia-online/lich-5/issues/1148)) ([2540a14](https://github.com/elanthia-online/lich-5/commit/2540a1497fd301996be3e0d8466b1b065979b733))
* **all:** reduce minimum GUI window footprint for non-tabbed view ([#1138](https://github.com/elanthia-online/lich-5/issues/1138)) ([79b18ed](https://github.com/elanthia-online/lich-5/commit/79b18ed2d70d5ae56bd01477ec859acb4508e220))
* **all:** remove dead code in BranchInstaller ([#1292](https://github.com/elanthia-online/lich-5/issues/1292)) ([b3c480a](https://github.com/elanthia-online/lich-5/commit/b3c480a18245ccb37060effd6e65597758e098b3))
* **all:** remove double save in YAML to preserve yaml.bak integrity ([#1139](https://github.com/elanthia-online/lich-5/issues/1139)) ([0c26110](https://github.com/elanthia-online/lich-5/commit/0c2611081c37a4167a5a729d7da1b1b34e5aa96f))
* **all:** remove password parameter from debug logging in all cases ([#1137](https://github.com/elanthia-online/lich-5/issues/1137)) ([fe21beb](https://github.com/elanthia-online/lich-5/commit/fe21beb7bdd8ddaa8b7c7ec6254165587bbc2162))
* **all:** remove strip! from settingsInfo replacement ([#1161](https://github.com/elanthia-online/lich-5/issues/1161)) ([aef52ad](https://github.com/elanthia-online/lich-5/commit/aef52add62c47daa73579ac69e13db0352c34cdd))
* **all:** Remove Windows OS CMD prompt flash ([#1255](https://github.com/elanthia-online/lich-5/issues/1255)) ([26b7581](https://github.com/elanthia-online/lich-5/commit/26b7581394d48d821e235c33050b274bf2d246ec))
* **all:** repair regression on gui button reenable from refactor ([#1297](https://github.com/elanthia-online/lich-5/issues/1297)) ([f10b1f9](https://github.com/elanthia-online/lich-5/commit/f10b1f95f4c1f0720505d5823e43f334b3c12d62))
* **all:** restore [@theme](https://github.com/theme)_state and add to CLI capability ([#795](https://github.com/elanthia-online/lich-5/issues/795)) ([f6e1201](https://github.com/elanthia-online/lich-5/commit/f6e1201236cba8596907e6447f9ecd05da1c5e8d))
* **all:** Restore manual login behaviors to not require saved entry t… ([#1270](https://github.com/elanthia-online/lich-5/issues/1270)) ([5eb6d4f](https://github.com/elanthia-online/lich-5/commit/5eb6d4f3c492a6a9961a55a785100eed06ec965a))
* **all:** restore Wrayth / Wizard script execution ability ([#952](https://github.com/elanthia-online/lich-5/issues/952)) ([6b7149c](https://github.com/elanthia-online/lich-5/commit/6b7149c2afea112a6a1079e3440294b2e3fcb7bc))
* **all:** retire gtk2 monkey patch for gtk3 ([#823](https://github.com/elanthia-online/lich-5/issues/823)) ([498230c](https://github.com/elanthia-online/lich-5/commit/498230cd8cc50ed147c87cd100267bcaee2d25c5))
* **all:** script.rb class to is_a? checks ([#878](https://github.com/elanthia-online/lich-5/issues/878)) ([fd4e7f2](https://github.com/elanthia-online/lich-5/commit/fd4e7f28fa9ab067ba82c74d16c6c4be7e0b5847))
* **all:** script.rb show custom at script exit as well ([#993](https://github.com/elanthia-online/lich-5/issues/993)) ([dfe92dd](https://github.com/elanthia-online/lich-5/commit/dfe92ddbc8a20a4b51e98c048bdd81379ff4e425))
* **all:** script.rb show Script.kill source ([#1235](https://github.com/elanthia-online/lich-5/issues/1235)) ([fbbf04c](https://github.com/elanthia-online/lich-5/commit/fbbf04cf02cdbb3cabda3f163d6094c6bcd78d36))
* **all:** set SO_REUSEADDR before bind to allow immediate port reuse ([#1268](https://github.com/elanthia-online/lich-5/issues/1268)) ([9db4b6b](https://github.com/elanthia-online/lich-5/commit/9db4b6be4882b300bf5531e7020aa2808d9d13ab))
* **all:** settings_proxy implement to_h for appropriate behaviors ([#896](https://github.com/elanthia-online/lich-5/issues/896)) ([b24c6d1](https://github.com/elanthia-online/lich-5/commit/b24c6d1a11bacdb8209e36f76d2598a57efcbe97))
* **all:** settings.rb unwrap data from objects before Marshal ([#875](https://github.com/elanthia-online/lich-5/issues/875)) ([b98ef6b](https://github.com/elanthia-online/lich-5/commit/b98ef6b58f785064aa464b9edf3462a0a82170eb))
* **all:** settings.rb update to preserve root of derived views ([#975](https://github.com/elanthia-online/lich-5/issues/975)) ([09b3a5b](https://github.com/elanthia-online/lich-5/commit/09b3a5b88cbe85d066ed57616df93a9aff17a18e))
* **all:** show custom in various script output when custom script ([#967](https://github.com/elanthia-online/lich-5/issues/967)) ([236e202](https://github.com/elanthia-online/lich-5/commit/236e202c9413d2e2e4782418c64fc3dbf4b3b4b9))
* **all:** standardize xmlparser game instance ([#827](https://github.com/elanthia-online/lich-5/issues/827)) ([eae4e09](https://github.com/elanthia-online/lich-5/commit/eae4e090132ca0d2a2230d02245cc58ffd0f1c71))
* **all:** suppress wine detection noise and skip when unneeded ([#1244](https://github.com/elanthia-online/lich-5/issues/1244)) ([dfcd813](https://github.com/elanthia-online/lich-5/commit/dfcd81395d7a827d088654579e810924a28c283a))
* **all:** update CLI for YAML security signature, add auto-convert fo… ([#1136](https://github.com/elanthia-online/lich-5/issues/1136)) ([b1c690a](https://github.com/elanthia-online/lich-5/commit/b1c690af39b2ac045b8413a3f83b57defa264b70))
* **all:** update location for currency and move game-loader.rb to Ruby standard gameloader.rb ([#1112](https://github.com/elanthia-online/lich-5/issues/1112)) ([39bbb60](https://github.com/elanthia-online/lich-5/commit/39bbb6094f16380d1e4ecd6c080d6199faef170d))
* **all:** Update module strip markdown comments ([#1056](https://github.com/elanthia-online/lich-5/issues/1056)) ([44693ba](https://github.com/elanthia-online/lich-5/commit/44693ba017a076ca65d572d86dd0fca47076c659))
* **all:** update.rb allow for bugfix betas and branch updates ([#1211](https://github.com/elanthia-online/lich-5/issues/1211)) ([2d60245](https://github.com/elanthia-online/lich-5/commit/2d602450d38c19724b09fa9527776a49a642f907))
* **all:** update.rb keep script/data file incase of error on update ([#1070](https://github.com/elanthia-online/lich-5/issues/1070)) ([2f09881](https://github.com/elanthia-online/lich-5/commit/2f09881dd7df27c84abb07c1daff6fbdab04d087))
* **all:** update.rb pervent update if MIN_RUBY not met ([#1146](https://github.com/elanthia-online/lich-5/issues/1146)) ([24b5173](https://github.com/elanthia-online/lich-5/commit/24b5173a55400f4fff78d7f3677a85912de239cf))
* **all:** update.rb word boundary for abbreviations ([#971](https://github.com/elanthia-online/lich-5/issues/971)) ([bdd065e](https://github.com/elanthia-online/lich-5/commit/bdd065e9cc5e80d922a760f2aaa080701c8d4bb7))
* **all:** update.rb word boundary for abbreviations [#971](https://github.com/elanthia-online/lich-5/issues/971) ([cab86e8](https://github.com/elanthia-online/lich-5/commit/cab86e81fd2156faa7875d805eaf99f8bfec8ebf))
* **all:** Updated update.rb for single trunk and release please ([#1001](https://github.com/elanthia-online/lich-5/issues/1001)) ([7840b3d](https://github.com/elanthia-online/lich-5/commit/7840b3d7d4e3e19a1c6bb226fb614f737471a41c))
* **all:** uservars.rb update for vars method missing ([#940](https://github.com/elanthia-online/lich-5/issues/940)) ([5f94c07](https://github.com/elanthia-online/lich-5/commit/5f94c07bb67a1c322157b8ad43dd9f38ff1f441f))
* **all:** Util.issue_command allow single line captures ([#918](https://github.com/elanthia-online/lich-5/issues/918)) ([7e5a09f](https://github.com/elanthia-online/lich-5/commit/7e5a09fefa564dce448f9b57aac1c42ff6bfe8f8))
* **all:** util.rb - verbalize method name ([#833](https://github.com/elanthia-online/lich-5/issues/833)) ([95ad0a8](https://github.com/elanthia-online/lich-5/commit/95ad0a830be6b64f6511d33f38dde88819594530))
* **all:** util.rb only show gem installing debug messaging if gem mis… ([#1131](https://github.com/elanthia-online/lich-5/issues/1131)) ([dd55334](https://github.com/elanthia-online/lich-5/commit/dd55334351715dda9feea214ed91bf59563ef754))
* **all:** Vars/UserVars module fixes and corrections ([#1057](https://github.com/elanthia-online/lich-5/issues/1057)) ([7338ef1](https://github.com/elanthia-online/lich-5/commit/7338ef189ac03289daeb72fddb3ae7a22a2ed4ba))
* **all:** xmlparser.rb gate GSL exits sending behind [@send](https://github.com/send)_fake_tags ([#1103](https://github.com/elanthia-online/lich-5/issues/1103)) ([053319d](https://github.com/elanthia-online/lich-5/commit/053319d883c0c3dec0ccebf2978c19f9dc7ba3b1))
* correctly install REXML 3.3.1 gem for LNet ([359998e](https://github.com/elanthia-online/lich-5/commit/359998ed4b9a4b47d5a5b04543ee92e1a48ea0f2))
* **dr:** add 'You scoop' match pattern to common-items ([#900](https://github.com/elanthia-online/lich-5/issues/900)) ([3860523](https://github.com/elanthia-online/lich-5/commit/38605235d291b701e5f992c4604728bc77ae82cc))
* **dr:** add `moon_visible?(moon)` convenience method to common-moonmage ([#860](https://github.com/elanthia-online/lich-5/issues/860)) ([60d2b89](https://github.com/elanthia-online/lich-5/commit/60d2b8991f4bc1f6d2cbdc57ccd195fbd3e71820))
* **dr:** add bounded recursion depth limits to 9 methods ([#1257](https://github.com/elanthia-online/lich-5/issues/1257)) ([fea0776](https://github.com/elanthia-online/lich-5/commit/fea0776172c0aa64e8cf0bf0c47fed407478ee00))
* **dr:** add bput match for system updates preventing actions ([#1034](https://github.com/elanthia-online/lich-5/issues/1034)) ([5df10f1](https://github.com/elanthia-online/lich-5/commit/5df10f1f8d75598bfea52caf2467e9bad92f7041))
* **dr:** add buffering for multiline room players ([#1151](https://github.com/elanthia-online/lich-5/issues/1151)) ([c7c2cc7](https://github.com/elanthia-online/lich-5/commit/c7c2cc78459e01b1507f0469dbca43eb631bc0de))
* **dr:** add missing match patterns ([#901](https://github.com/elanthia-online/lich-5/issues/901)) ([dbafdda](https://github.com/elanthia-online/lich-5/commit/dbafdda5548ee152c337a02799de861e6bab2ff5))
* **dr:** Add missing matches for common-items ([#905](https://github.com/elanthia-online/lich-5/issues/905)) ([522abe2](https://github.com/elanthia-online/lich-5/commit/522abe2c7088579ed08143eaa1335c544284824a))
* **dr:** add verify_script def here instead of depending on dependency ([#1155](https://github.com/elanthia-online/lich-5/issues/1155)) ([21560de](https://github.com/elanthia-online/lich-5/commit/21560de0c7ccebb3cd1c6259c78de3eea7e801b4))
* **dr:** anchor stow success pattern to prevent fan close recovery bypass ([#1254](https://github.com/elanthia-online/lich-5/issues/1254)) ([c96933d](https://github.com/elanthia-online/lich-5/commit/c96933dee8f15be6409530592a42b021c8bcf259))
* **dr:** buffer split room obj lines and merge instead of appending closing tag to broken line ([#1149](https://github.com/elanthia-online/lich-5/issues/1149)) ([b8dd4a2](https://github.com/elanthia-online/lich-5/commit/b8dd4a2f3d25f45d89843eb58624db4e07f246d6))
* **dr:** buffer_room_objs missed split components with leading stream tags ([#1284](https://github.com/elanthia-online/lich-5/issues/1284)) ([e858d91](https://github.com/elanthia-online/lich-5/commit/e858d91746075d1c5b713826e9683ef5710c3f73))
* **dr:** change keys for DR_SKILLS_DATA[:guild_skill_aliases] to be strings instead of symbols ([#1032](https://github.com/elanthia-online/lich-5/issues/1032)) ([1fc7510](https://github.com/elanthia-online/lich-5/commit/1fc75105ea378b204503dd0538bcd153ccff2f38))
* **dr:** common-arcana.rb Regalia fix for changed game output. ([#970](https://github.com/elanthia-online/lich-5/issues/970)) ([5d1b126](https://github.com/elanthia-online/lich-5/commit/5d1b12672b961f8200969f3d29743ce2c75acd8a))
* **dr:** common-arcana.rb Regalia fix for changed game output. [#970](https://github.com/elanthia-online/lich-5/issues/970) ([cab86e8](https://github.com/elanthia-online/lich-5/commit/cab86e81fd2156faa7875d805eaf99f8bfec8ebf))
* **dr:** common-crafting.rb minor edit to add "You tuck" ([#787](https://github.com/elanthia-online/lich-5/issues/787)) ([75ffae6](https://github.com/elanthia-online/lich-5/commit/75ffae66520cee4fe1f8edc4e8950bbfaf175113))
* **dr:** common-items: add and fix match strings ([#904](https://github.com/elanthia-online/lich-5/issues/904)) ([a554c48](https://github.com/elanthia-online/lich-5/commit/a554c4861aa458e3ec87a5d3a042afcae289bd29))
* **dr:** common-items.rb - get_item_unsafe false positives via XML feed verification ([#1286](https://github.com/elanthia-online/lich-5/issues/1286)) ([b3c286f](https://github.com/elanthia-online/lich-5/commit/b3c286f38442007098ab3038dcfbf804f9fb57c0))
* **dr:** common-items.rb - move pattern from failure to success block ([#1262](https://github.com/elanthia-online/lich-5/issues/1262)) ([7209d3a](https://github.com/elanthia-online/lich-5/commit/7209d3add9a908c3f377b16fb207b49b3f783a7d))
* **dr:** common-items.rb Fix for changed inventory command output ([#973](https://github.com/elanthia-online/lich-5/issues/973)) ([fcec3c4](https://github.com/elanthia-online/lich-5/commit/fcec3c44ae21ef0afd0b26ed6b3f0408dcdd1534))
* **dr:** common-items.rb Fix for changed inventory command output [#973](https://github.com/elanthia-online/lich-5/issues/973) ([cab86e8](https://github.com/elanthia-online/lich-5/commit/cab86e81fd2156faa7875d805eaf99f8bfec8ebf))
* **dr:** common-items.rb wear/remove messaging additions ([#949](https://github.com/elanthia-online/lich-5/issues/949)) ([5b3e651](https://github.com/elanthia-online/lich-5/commit/5b3e651201c130d25582c5f16a88492f80a80e86))
* **dr:** DR modules fixes and enhancements ([#1232](https://github.com/elanthia-online/lich-5/issues/1232)) ([4c63805](https://github.com/elanthia-online/lich-5/commit/4c63805bb3f5aca6c059d9b3922ce8b85b8fe60d))
* **dr:** DRCA allow custom spell prep messaging ([#1089](https://github.com/elanthia-online/lich-5/issues/1089)) ([42f5025](https://github.com/elanthia-online/lich-5/commit/42f502575a7a45abcad76aab41b2ef133712e586))
* **dr:** drdefs.rb npc parsing ([#1038](https://github.com/elanthia-online/lich-5/issues/1038)) ([328c2b2](https://github.com/elanthia-online/lich-5/commit/328c2b29fd8f7d8efb017a55086ded77d30ac4b9))
* **dr:** drparser.rb add $last_logoff tracking ([#851](https://github.com/elanthia-online/lich-5/issues/851)) ([2fdc949](https://github.com/elanthia-online/lich-5/commit/2fdc949d26fe1f2bbe5148b7a05fde0eb2186149))
* **dr:** drparser.rb casing for Premium status check ([#842](https://github.com/elanthia-online/lich-5/issues/842)) ([a300b8d](https://github.com/elanthia-online/lich-5/commit/a300b8d3c3e40281560894cc3aa4232878905987))
* **dr:** drparser.rb Restore Premium status checking ([#834](https://github.com/elanthia-online/lich-5/issues/834)) ([5de5432](https://github.com/elanthia-online/lich-5/commit/5de5432a8c439c8e71e9dd12de49e59f742b8cb1))
* **dr:** drparser.rb to set ShowRoomID to on if turned off ([#945](https://github.com/elanthia-online/lich-5/issues/945)) ([7365317](https://github.com/elanthia-online/lich-5/commit/7365317fafc0c0aec52c16dc887694e61e826ae2))
* **dr:** drparser.rb update for Platinum account status ([#922](https://github.com/elanthia-online/lich-5/issues/922)) ([460f07f](https://github.com/elanthia-online/lich-5/commit/460f07f8f9d17f9f165a2208fd3da541aafe9df5))
* **dr:** drparser.rb update for PlayedSubscription ([#983](https://github.com/elanthia-online/lich-5/issues/983)) ([49508d7](https://github.com/elanthia-online/lich-5/commit/49508d78a5a492a78e53b722835476f7186f68b6))
* **dr:** equipmanager.rb Fix for changed game output. ([#969](https://github.com/elanthia-online/lich-5/issues/969)) ([f6d9d66](https://github.com/elanthia-online/lich-5/commit/f6d9d66f83176b791575fce836702ceddf39ad4f))
* **dr:** equipmanager.rb Fix for changed game output. [#969](https://github.com/elanthia-online/lich-5/issues/969) ([cab86e8](https://github.com/elanthia-online/lich-5/commit/cab86e81fd2156faa7875d805eaf99f8bfec8ebf))
* **dr:** equipmanager.rb support for custom messaging in forester's longbow ([#1105](https://github.com/elanthia-online/lich-5/issues/1105)) ([557fab5](https://github.com/elanthia-online/lich-5/commit/557fab5f02e49008cce3ad71b1c4bb2d2eaa169a))
* **dr:** exp mods output is not enclosed in preset xml tags anymore ([#870](https://github.com/elanthia-online/lich-5/issues/870)) ([f33aba8](https://github.com/elanthia-online/lich-5/commit/f33aba8d86ff81816b64a6e07647ef5958f0ad76))
* **dr:** Fix container reference in get_item_from_eddy_portal method ([#1039](https://github.com/elanthia-online/lich-5/issues/1039)) ([20a3f09](https://github.com/elanthia-online/lich-5/commit/20a3f093925616d8ebd133e04847ae1eea817692))
* **dr:** Fix exp mods parsing for DR ([#1102](https://github.com/elanthia-online/lich-5/issues/1102)) ([dbb50ed](https://github.com/elanthia-online/lich-5/commit/dbb50ed6bff5aa7e3f46e44ed08d660cee09591a))
* **dr:** Fix hang in equipment manager when game doesn't respond to commands ([#1110](https://github.com/elanthia-online/lich-5/issues/1110)) ([34c394a](https://github.com/elanthia-online/lich-5/commit/34c394abbe04baa8cf1546e6005d5fb81280a90f))
* **dr:** Fix race condition when clearing and repopulating XMLData.dr_active_spells ([#907](https://github.com/elanthia-online/lich-5/issues/907)) ([58b34da](https://github.com/elanthia-online/lich-5/commit/58b34dadc25eb3388f7a28d884d4db53eab71db3))
* **dr:** Fix SLS release pattern ([#908](https://github.com/elanthia-online/lich-5/issues/908)) ([746d15b](https://github.com/elanthia-online/lich-5/commit/746d15baee726d6e9afd3eb58de56d781a1a5dcf))
* **dr:** forward vitality and dead fields in perceive_health ([#1288](https://github.com/elanthia-online/lich-5/issues/1288)) ([cad008c](https://github.com/elanthia-online/lich-5/commit/cad008c24736fce9370f1807f5d1a71c5ff8e688))
* **dr:** games.rb - ignore UIDs for Frostbite mapping ([#951](https://github.com/elanthia-online/lich-5/issues/951)) ([d839d9e](https://github.com/elanthia-online/lich-5/commit/d839d9ea075634ca59205c626d6c096b91bdda4f))
* **dr:** games.rb - optional hide Room Title display of Real IDs with FLAG on ([#782](https://github.com/elanthia-online/lich-5/issues/782)) ([460a3e4](https://github.com/elanthia-online/lich-5/commit/460a3e4f688050c04e12fdaee43345a01012894c))
* **dr:** logbook_item recovery when crafted item not in hand ([#1175](https://github.com/elanthia-online/lich-5/issues/1175)) ([da18fa9](https://github.com/elanthia-online/lich-5/commit/da18fa95e602fdae0ee1cc256212fed4eaaba00d))
* **dr:** map_dr.rb Don't assign UID of zero to rooms ([#844](https://github.com/elanthia-online/lich-5/issues/844)) ([e99ac66](https://github.com/elanthia-online/lich-5/commit/e99ac66cc5291f5d4dbb2bd5cc71c1e403fc04e9))
* **dr:** map_dr.rb prevent inadvertent settings changes ([#958](https://github.com/elanthia-online/lich-5/issues/958)) ([e499253](https://github.com/elanthia-online/lich-5/commit/e499253b325d76b3d786e9c5fe51173ade0034f0))
* **dr:** Release Khri Vanish if Thief, when going visible ([#906](https://github.com/elanthia-online/lich-5/issues/906)) ([e13d21e](https://github.com/elanthia-online/lich-5/commit/e13d21eee4f82ca09dd081c4ec4776d9b662386c))
* **dr:** resolve race condition in DR crafting_magic_routine ([#914](https://github.com/elanthia-online/lich-5/issues/914)) ([722a71e](https://github.com/elanthia-online/lich-5/commit/722a71ea6b4045b6b9c036da322539b3a9297452))
* **dr:** stow_helper failure detection + unload_weapon ammo recovery ([#1259](https://github.com/elanthia-online/lich-5/issues/1259)) ([d010383](https://github.com/elanthia-online/lich-5/commit/d0103835bf18f595440ef22743ee0164254ae373))
* **dr:** Tighten checks on releasing invisibility for thieves ([#936](https://github.com/elanthia-online/lich-5/issues/936)) ([0b15ceb](https://github.com/elanthia-online/lich-5/commit/0b15cebb3f90da9e412dcd965eeb89bbe15ddaca))
* **dr:** update message patterns in common-items ([#859](https://github.com/elanthia-online/lich-5/issues/859)) ([6abef82](https://github.com/elanthia-online/lich-5/commit/6abef823789878539fd4c758c0b93f85e7208d17))
* **dr:** Update regex and parsing for active spells ([#894](https://github.com/elanthia-online/lich-5/issues/894)) ([6fe631f](https://github.com/elanthia-online/lich-5/commit/6fe631f51756be03c0e0dd559f1cd0e78933c985))
* **dr:** Update Slackbot error handling, and lnet management ([#1091](https://github.com/elanthia-online/lich-5/issues/1091)) ([f729c69](https://github.com/elanthia-online/lich-5/commit/f729c690fb1221b0e39ff6ed309a8e6c5427751a))
* **dr:** update.rb beta send validation for genie lich char ([#880](https://github.com/elanthia-online/lich-5/issues/880)) ([7999892](https://github.com/elanthia-online/lich-5/commit/799989213cd57da62bb63f28bc7cce873ba22d2e))
* **dr:** validator.rb change sleep to should_sleep named param ([#1116](https://github.com/elanthia-online/lich-5/issues/1116)) ([58e9168](https://github.com/elanthia-online/lich-5/commit/58e9168bde5c36f91f683a5e7cb305320cc7fc05))
* **dr:** xmlparser.rb - Clear out spells properly ([#916](https://github.com/elanthia-online/lich-5/issues/916)) ([8c929af](https://github.com/elanthia-online/lich-5/commit/8c929afae1f84a8c9d6541ec89c52c708d8cd59c))
* **dr:** xmlparser.rb - Fix XMLData.dr_active_spells race condition ([#915](https://github.com/elanthia-online/lich-5/issues/915)) ([617344b](https://github.com/elanthia-online/lich-5/commit/617344ba2585b30f166e3ca949392e2e712136aa))
* gate both sections to GS only ([7530074](https://github.com/elanthia-online/lich-5/commit/7530074ee4bebbb809958d949087ee2f4cc9a710))
* **gs:** activespell.rb prevent removal of RF Penalty ([#981](https://github.com/elanthia-online/lich-5/issues/981)) ([e1d5652](https://github.com/elanthia-online/lich-5/commit/e1d5652a4866fb454d7cea6f263810398b966d5c))
* **gs:** add .compact to input of Disk.find_by_name ([#982](https://github.com/elanthia-online/lich-5/issues/982)) ([f03ed8d](https://github.com/elanthia-online/lich-5/commit/f03ed8d8dff292d041a70a0fa411a62083130984))
* **gs:** add base stats capture from 'info full' command ([#1115](https://github.com/elanthia-online/lich-5/issues/1115)) ([1086093](https://github.com/elanthia-online/lich-5/commit/1086093608914555f664f0eea462c3881ab2419e))
* **gs:** add Char.che to know current character's CHE ([#791](https://github.com/elanthia-online/lich-5/issues/791)) ([d891096](https://github.com/elanthia-online/lich-5/commit/d89109605b0246c4e4995f422addb9e8ecf50ac0))
* **gs:** add class extensions to correct script modifications ([#800](https://github.com/elanthia-online/lich-5/issues/800)) ([0a25b0c](https://github.com/elanthia-online/lich-5/commit/0a25b0c741c1d1e09713b9af95471a812b594e3f))
* **gs:** add Currency.gemstone_dust and fix redsteel mark capture ([#797](https://github.com/elanthia-online/lich-5/issues/797)) ([018c48e](https://github.com/elanthia-online/lich-5/commit/018c48ede5c9ac196ca889f4ba32011a854d4741))
* **gs:** add missing Feat.use ability ([#831](https://github.com/elanthia-online/lich-5/issues/831)) ([291ec43](https://github.com/elanthia-online/lich-5/commit/291ec431fc45f1e4ddbe82e87148a8ffcee3606c))
* **gs:** allow for Group.disks to show self disk in array ([#829](https://github.com/elanthia-online/lich-5/issues/829)) ([1acf172](https://github.com/elanthia-online/lich-5/commit/1acf17210f467f61e4427bc4e5cda3e75595cc87))
* **gs:** allow spell.rb casting to take a force_stance parameter ([#902](https://github.com/elanthia-online/lich-5/issues/902)) ([f09b778](https://github.com/elanthia-online/lich-5/commit/f09b7789114fd79b3f864d77d59825c17b4a4f82))
* **gs:** Bounty heirloom return msg'ing update ([#972](https://github.com/elanthia-online/lich-5/issues/972)) ([73ac7e3](https://github.com/elanthia-online/lich-5/commit/73ac7e3b6a3cb2a637ca4dc45d09f0cbd4a257d3))
* **gs:** bounty location regex needs to match "under" ([#1037](https://github.com/elanthia-online/lich-5/issues/1037)) ([6358ba3](https://github.com/elanthia-online/lich-5/commit/6358ba305e8c9cd5acb8f0340069f2812e7cc648))
* **gs:** bounty parser and move fixes for sailor's grief ([#987](https://github.com/elanthia-online/lich-5/issues/987)) ([1faf6f4](https://github.com/elanthia-online/lich-5/commit/1faf6f45765d9ebe19d35e8acad2e94be97f0bc6))
* **gs:** Bounty parser fix regex pattern for skin retrieval task ([#1242](https://github.com/elanthia-online/lich-5/issues/1242)) ([d480143](https://github.com/elanthia-online/lich-5/commit/d4801435018b6f988ab5db4b3d74318f11668205))
* **gs:** Bounty parser for SG npcs matching ([#1027](https://github.com/elanthia-online/lich-5/issues/1027)) ([f4e993f](https://github.com/elanthia-online/lich-5/commit/f4e993f6299b595d0dd713939cc4093daa0c87a4))
* **gs:** Bounty parser.rb fix for HW & KF guard return ([#862](https://github.com/elanthia-online/lich-5/issues/862)) ([92aee8f](https://github.com/elanthia-online/lich-5/commit/92aee8fe584eb7b8617733c103bac7ea96a8abb2))
* **gs:** Bounty parser.rb FWI guard regex update ([#1096](https://github.com/elanthia-online/lich-5/issues/1096)) ([036a2c5](https://github.com/elanthia-online/lich-5/commit/036a2c5d1090e9806deb4c1181abcdfba6ed591e))
* **gs:** Bounty task.rb fix for assigned? and Ruby 2.6 ([#863](https://github.com/elanthia-online/lich-5/issues/863)) ([9fa16da](https://github.com/elanthia-online/lich-5/commit/9fa16dac6a9fad6743eb89a60079f35d8bcc2ab0))
* **gs:** change namespace accessors to Ruby 2.6 compatible ([#944](https://github.com/elanthia-online/lich-5/issues/944)) ([a7bf292](https://github.com/elanthia-online/lich-5/commit/a7bf29279384acdf53fd7ced0a8c9cd59c6de7ba))
* **gs:** cman.rb add hamstring regex for already lying down target ([#1090](https://github.com/elanthia-online/lich-5/issues/1090)) ([79e2b91](https://github.com/elanthia-online/lich-5/commit/79e2b91a9932ea10c916fca126d0d1a67ba9f6b8))
* **gs:** cman.rb hamstring regex update when can't perform on target ([#1092](https://github.com/elanthia-online/lich-5/issues/1092)) ([966aa78](https://github.com/elanthia-online/lich-5/commit/966aa78bd33ba8af9a3744e13e46fa6b113f4917))
* **gs:** cman.rb regex updates ([#874](https://github.com/elanthia-online/lich-5/issues/874)) ([61d7472](https://github.com/elanthia-online/lich-5/commit/61d7472415422dbdfa146dd66b3e18ba7c2ee4d2))
* **gs:** correct clean_key method for critranks ([#822](https://github.com/elanthia-online/lich-5/issues/822)) ([11a3a87](https://github.com/elanthia-online/lich-5/commit/11a3a8700ac0e1b38d5e865f2b5ad43a99ff00fe))
* **gs:** currency.rb track gold ([#1109](https://github.com/elanthia-online/lich-5/issues/1109)) ([f51c351](https://github.com/elanthia-online/lich-5/commit/f51c35145d7289964f437b084652ab7110222042))
* **gs:** disk.rb comparison helpers ([#828](https://github.com/elanthia-online/lich-5/issues/828)) ([1ebbe28](https://github.com/elanthia-online/lich-5/commit/1ebbe2871cb2e3e65d2ea9ef64b30c0a0bf41370))
* **gs:** escape dash in regex for HouseCHE ([#824](https://github.com/elanthia-online/lich-5/issues/824)) ([aef7f29](https://github.com/elanthia-online/lich-5/commit/aef7f2959d9828495b329b8a140b1aff7ef50b74))
* **gs:** FEAT and Infomon module parsing of new Covert Art feats. ([#796](https://github.com/elanthia-online/lich-5/issues/796)) ([2718a73](https://github.com/elanthia-online/lich-5/commit/2718a7369d9c1865efb2a4796bbf4ddcef172b24))
* **gs:** FEAT Covert Arts colon normalization and stamina costs ([#799](https://github.com/elanthia-online/lich-5/issues/799)) ([87053cd](https://github.com/elanthia-online/lich-5/commit/87053cdcb47b299f5bc28d9102e117e8fa2fd3b4))
* **gs:** Feat excoriate regex correction ([#920](https://github.com/elanthia-online/lich-5/issues/920)) ([9b994a5](https://github.com/elanthia-online/lich-5/commit/9b994a5453f2849c8353d7515e4de18951473f23))
* **gs:** feat.rb Covert Arts throw poison costs 15 stam ([#830](https://github.com/elanthia-online/lich-5/issues/830)) ([c75c051](https://github.com/elanthia-online/lich-5/commit/c75c051dadca8e86244ab62ade0dfbd325fa54a3))
* **gs:** force PROFILE FULL to sync CHE info for infomon ([#937](https://github.com/elanthia-online/lich-5/issues/937)) ([fc3982c](https://github.com/elanthia-online/lich-5/commit/fc3982c5814d1888a4deb0bfa0ceaacbfcbd15b8))
* **gs:** GameObj targets for new Sailor's Grief tentacle npc ([#948](https://github.com/elanthia-online/lich-5/issues/948)) ([dad133d](https://github.com/elanthia-online/lich-5/commit/dad133d57cbf89a9e0148b9bc94849dd0b1d53a8))
* **gs:** gameobj.rb for Sailor's Grief ghostly/boss/guild tentacles ([#989](https://github.com/elanthia-online/lich-5/issues/989)) ([38d022d](https://github.com/elanthia-online/lich-5/commit/38d022d76aa73167ac287a2caacb7e1b0b574ff9))
* **gs:** global_defs.rb move def update for Hive traps ([#980](https://github.com/elanthia-online/lich-5/issues/980)) ([036367e](https://github.com/elanthia-online/lich-5/commit/036367ed54b39b1e1b58b66d32bffe43b25b7705))
* **gs:** group.rb anchor additional regex checks ([#869](https://github.com/elanthia-online/lich-5/issues/869)) ([8a3d144](https://github.com/elanthia-online/lich-5/commit/8a3d1446ca4bc64b99d69359694ca05c3ef7d589))
* **gs:** group.rb minor corrections for XML matching \r\n characters … ([#883](https://github.com/elanthia-online/lich-5/issues/883)) ([868dca7](https://github.com/elanthia-online/lich-5/commit/868dca70ff005db6ee261c14985e279a3a67a0a0))
* **gs:** group.rb multiple corrections ([#850](https://github.com/elanthia-online/lich-5/issues/850)) ([916c7ea](https://github.com/elanthia-online/lich-5/commit/916c7ea7c168f450d7637bf5c9986119ca811f10))
* **gs:** include store location for ReadyList ([#977](https://github.com/elanthia-online/lich-5/issues/977)) ([fd8d1a9](https://github.com/elanthia-online/lich-5/commit/fd8d1a9adef01840c93ba5c7d0e94388a990a443))
* **gs:** Infomon additional CHE resign regex ([#1067](https://github.com/elanthia-online/lich-5/issues/1067)) ([94108ef](https://github.com/elanthia-online/lich-5/commit/94108ef5ecb19ea86eafd711d6fb33ef5f3f2f15))
* **gs:** Infomon parse fix for singular currency ([#1051](https://github.com/elanthia-online/lich-5/issues/1051)) ([eea0ea3](https://github.com/elanthia-online/lich-5/commit/eea0ea3e45dcfeb85a19721fdd39eb85862125c1))
* **gs:** Infomon parser.rb bug in EnhanciveEnd ([#1198](https://github.com/elanthia-online/lich-5/issues/1198)) ([fe20c7b](https://github.com/elanthia-online/lich-5/commit/fe20c7b069157f4e244f19d376a117fa0c6f11a0))
* **gs:** infomon parser.rb for profile full name matching ([#938](https://github.com/elanthia-online/lich-5/issues/938)) ([5d2735d](https://github.com/elanthia-online/lich-5/commit/5d2735d87d23bddcb88a138beab26d9425f306f5))
* **gs:** Infomon parser.rb update Account.subscription/type ([#1192](https://github.com/elanthia-online/lich-5/issues/1192)) ([698d1da](https://github.com/elanthia-online/lich-5/commit/698d1daf7da2d50fa330f84f4f60180e7ec21033))
* **gs:** infomon parser.rb update for ACCOUNT output varies ([#979](https://github.com/elanthia-online/lich-5/issues/979)) ([a741e18](https://github.com/elanthia-online/lich-5/commit/a741e18b5cb438cb846392c9c29f6106edff2a2d))
* **gs:** infomon parsing for CHE membership ([#841](https://github.com/elanthia-online/lich-5/issues/841)) ([7c56037](https://github.com/elanthia-online/lich-5/commit/7c56037ade7e7ff5df8379630659ee9ac9b26153))
* **gs:** infomon state reset on status prompt ([#943](https://github.com/elanthia-online/lich-5/issues/943)) ([d6acb8a](https://github.com/elanthia-online/lich-5/commit/d6acb8a534dca4735e593fcf2193c2cf5d6ae72f))
* **gs:** Infomon xmlparser additional npc death messaging ([#1275](https://github.com/elanthia-online/lich-5/issues/1275)) ([517f7cf](https://github.com/elanthia-online/lich-5/commit/517f7cfa77d86cc44e2bcb40cf7f6e4bf39700f3))
* **gs:** Infomon xmlparser additional npc death messaging ([#1281](https://github.com/elanthia-online/lich-5/issues/1281)) ([d66dc50](https://github.com/elanthia-online/lich-5/commit/d66dc50b76712147c7ec082c1476e64f0f46d620))
* **gs:** Infomon xmlparser.rb Ready/Stow fix for LONG before exist ([#988](https://github.com/elanthia-online/lich-5/issues/988)) ([a75df76](https://github.com/elanthia-online/lich-5/commit/a75df76ee18a03ba9580189476541ca07b5eff58))
* **gs:** infomon.rb added updated_at field to upsert_batch ([#1145](https://github.com/elanthia-online/lich-5/issues/1145)) ([ff2b4b5](https://github.com/elanthia-online/lich-5/commit/ff2b4b551e4f9438c9a28c74fd98ed1c15c6a9e2))
* **gs:** infomon.rb bug in _key transformation ([#1216](https://github.com/elanthia-online/lich-5/issues/1216)) ([46bfc81](https://github.com/elanthia-online/lich-5/commit/46bfc811d41bb3d0d80911b9e64b6fb6ca13186b))
* **gs:** map_gs.rb for no UID when hexdigest used ([#843](https://github.com/elanthia-online/lich-5/issues/843)) ([de5ec3c](https://github.com/elanthia-online/lich-5/commit/de5ec3c9bde033c24da6e67be064ac8692af039e))
* **gs:** map_gs.rb remove `delete_if` to prevent bad settings ([#957](https://github.com/elanthia-online/lich-5/issues/957)) ([56f8d53](https://github.com/elanthia-online/lich-5/commit/56f8d53afb227dc50dac67a78678775014bf8330))
* **gs:** match READY/STOW items with a/an/some inside the link ([#1026](https://github.com/elanthia-online/lich-5/issues/1026)) ([e57561a](https://github.com/elanthia-online/lich-5/commit/e57561a611d1d07c974e4255b461be60c09d98fd))
* **gs:** migrate PSMS.name_normal to Lich::Util.name_normal ([#790](https://github.com/elanthia-online/lich-5/issues/790)) ([d6c407c](https://github.com/elanthia-online/lich-5/commit/d6c407cbba03c35f27d20592fd9f0abe19347e30))
* **gs:** PSMS cost for multiple cost types & add Excoriate feat ([#912](https://github.com/elanthia-online/lich-5/issues/912)) ([231e582](https://github.com/elanthia-online/lich-5/commit/231e5820c4ebb9f715878f5b479c5274edf127e2))
* **gs:** PSMS fetch lookup use long_name after normalization ([#899](https://github.com/elanthia-online/lich-5/issues/899)) ([2ba9f26](https://github.com/elanthia-online/lich-5/commit/2ba9f26d174735e5e72f4011991efe8c85dee0ef))
* **gs:** psms.rb add additional failure matches ([#1238](https://github.com/elanthia-online/lich-5/issues/1238)) ([4ce94d2](https://github.com/elanthia-online/lich-5/commit/4ce94d247132a9c26dd4285f30e048ee3702e769))
* **gs:** readylist.rb check method fix when dead ([#1153](https://github.com/elanthia-online/lich-5/issues/1153)) ([29729f4](https://github.com/elanthia-online/lich-5/commit/29729f45fa731af2a74d21bc48daa45fd0988f48))
* **gs:** readylist.rb wait for RT when issuing check ([#965](https://github.com/elanthia-online/lich-5/issues/965)) ([48da96b](https://github.com/elanthia-online/lich-5/commit/48da96ba0e372ada253f51da6ea58c10fc6c1c22))
* **gs:** Resource tracking for sorcerer shadow essence ([#1085](https://github.com/elanthia-online/lich-5/issues/1085)) ([7730550](https://github.com/elanthia-online/lich-5/commit/7730550fd05b6e403d6fe0bf3c23dd68dc093d88))
* **gs:** Societies to check membership for various methods ([#942](https://github.com/elanthia-online/lich-5/issues/942)) ([94800fd](https://github.com/elanthia-online/lich-5/commit/94800fd866563b93883d443805591581b430d5b8))
* **gs:** spell.rb add last_cast to track last time casted ([#1193](https://github.com/elanthia-online/lich-5/issues/1193)) ([67115dd](https://github.com/elanthia-online/lich-5/commit/67115dd0b6bfbedc118de0740dc61f57603740a0))
* **gs:** standardize critranks - acid ([#801](https://github.com/elanthia-online/lich-5/issues/801)) ([6f2bc49](https://github.com/elanthia-online/lich-5/commit/6f2bc49c7d878e9584725775d1a39c01d3f825a7))
* **gs:** standardize critranks - cold ([#802](https://github.com/elanthia-online/lich-5/issues/802)) ([383247a](https://github.com/elanthia-online/lich-5/commit/383247ae10b9dd597221585e2ddf17e94a8a336f))
* **gs:** standardize critranks - crush ([#803](https://github.com/elanthia-online/lich-5/issues/803)) ([4ded463](https://github.com/elanthia-online/lich-5/commit/4ded4630715d03ac542c337722af2a4c3ded1c0c))
* **gs:** standardize critranks - disintegrate ([#804](https://github.com/elanthia-online/lich-5/issues/804)) ([a144429](https://github.com/elanthia-online/lich-5/commit/a144429c5f27ed6997e5e2ab9e4a4fd5c818e032))
* **gs:** standardize critranks - disruption ([#805](https://github.com/elanthia-online/lich-5/issues/805)) ([cf8e3e4](https://github.com/elanthia-online/lich-5/commit/cf8e3e41c94c666689f109f0fd962e746303fc05))
* **gs:** standardize critranks - fire ([#806](https://github.com/elanthia-online/lich-5/issues/806)) ([5b89778](https://github.com/elanthia-online/lich-5/commit/5b89778318abef2d75d7568f51b2dcd992c35e56))
* **gs:** standardize critranks - generic ([#821](https://github.com/elanthia-online/lich-5/issues/821)) ([e9b7f61](https://github.com/elanthia-online/lich-5/commit/e9b7f6196848ed36e82ec9a109bdd3fa30823f7e))
* **gs:** standardize critranks - grapple ([#807](https://github.com/elanthia-online/lich-5/issues/807)) ([11b610a](https://github.com/elanthia-online/lich-5/commit/11b610a49d5e6589aadceb3c82e94b1465dca5c6))
* **gs:** standardize critranks - impact ([#808](https://github.com/elanthia-online/lich-5/issues/808)) ([5ba8c7e](https://github.com/elanthia-online/lich-5/commit/5ba8c7efb5ca522ab0d720df716fc07388a73c29))
* **gs:** standardize critranks - lightning ([#809](https://github.com/elanthia-online/lich-5/issues/809)) ([bc678a6](https://github.com/elanthia-online/lich-5/commit/bc678a65d75bbb3c0021409238ecaf76b6ae7e93))
* **gs:** standardize critranks - noncorp ([#810](https://github.com/elanthia-online/lich-5/issues/810)) ([972314a](https://github.com/elanthia-online/lich-5/commit/972314a94befdb8357d823becbced7a04661d9f3))
* **gs:** standardize critranks - plasma ([#811](https://github.com/elanthia-online/lich-5/issues/811)) ([4be7566](https://github.com/elanthia-online/lich-5/commit/4be7566a19f5d3c3d20342836658c825da72fac8))
* **gs:** standardize critranks - puncture ([#812](https://github.com/elanthia-online/lich-5/issues/812)) ([cda0434](https://github.com/elanthia-online/lich-5/commit/cda043490e48de2c672faa3c6a85f77359ef3b7a))
* **gs:** standardize critranks - slash ([#813](https://github.com/elanthia-online/lich-5/issues/813)) ([2cdeac3](https://github.com/elanthia-online/lich-5/commit/2cdeac3ef2e8cc675dc17614d0e0235ab3d8dc92))
* **gs:** standardize critranks - steam ([#814](https://github.com/elanthia-online/lich-5/issues/814)) ([cb265fc](https://github.com/elanthia-online/lich-5/commit/cb265fc43b8482ee5bb7daff5cd92985fe85a32d))
* **gs:** standardize critranks - ucs grapple ([#815](https://github.com/elanthia-online/lich-5/issues/815)) ([2aa5ef6](https://github.com/elanthia-online/lich-5/commit/2aa5ef6ee3c06be4504d4927160f65822616e58d))
* **gs:** standardize critranks - ucs jab ([#816](https://github.com/elanthia-online/lich-5/issues/816)) ([fbc64c5](https://github.com/elanthia-online/lich-5/commit/fbc64c50bb513b0db80f15fb65ebf98f1bce1d06))
* **gs:** standardize critranks - ucs kick ([#817](https://github.com/elanthia-online/lich-5/issues/817)) ([eb4ec1d](https://github.com/elanthia-online/lich-5/commit/eb4ec1dcf9a1369c9d3f86b36577f7315d2b48e8))
* **gs:** standardize critranks - ucs punch ([#818](https://github.com/elanthia-online/lich-5/issues/818)) ([fd4fc43](https://github.com/elanthia-online/lich-5/commit/fd4fc43811ded1dceaad5a332b9cb156b071452b))
* **gs:** standardize critranks - unbalance ([#819](https://github.com/elanthia-online/lich-5/issues/819)) ([ad382ba](https://github.com/elanthia-online/lich-5/commit/ad382bacf998174fd8a87eb0b26b1cc9d57fd22c))
* **gs:** standardize critranks - vacuum ([#820](https://github.com/elanthia-online/lich-5/issues/820)) ([66e9ba4](https://github.com/elanthia-online/lich-5/commit/66e9ba4f14adc532666754d159bbd973dcbd3ac7))
* **gs:** standardize warcry.rb to match other PSMS ([#941](https://github.com/elanthia-online/lich-5/issues/941)) ([0758dae](https://github.com/elanthia-online/lich-5/commit/0758dae3a9439483bdb93bcd8b401355b1f13645))
* **gs:** stash.rb additional improvements ([#1132](https://github.com/elanthia-online/lich-5/issues/1132)) ([8a8d906](https://github.com/elanthia-online/lich-5/commit/8a8d906a4da56e2719789e0679e70bb88bae45b4))
* **gs:** stash.rb additional improvements with ReadyList/StowList ([#1197](https://github.com/elanthia-online/lich-5/issues/1197)) ([5ef1c85](https://github.com/elanthia-online/lich-5/commit/5ef1c859f188f506af2c7b29faa2b7b344035e21))
* **gs:** stash.rb ReadyList sheath handling and update inventory checks ([#1166](https://github.com/elanthia-online/lich-5/issues/1166)) ([7aeec90](https://github.com/elanthia-online/lich-5/commit/7aeec90f8faf8a4cef881317ab7719d6858c7b78))
* **gs:** stash.rb stale sheaths recheck ([#867](https://github.com/elanthia-online/lich-5/issues/867)) ([ad3c188](https://github.com/elanthia-online/lich-5/commit/ad3c18896e98ee1f1d28ffc3e1d604614966f238))
* **gs:** StowList missing space in capture in xmlparser.rb ([#963](https://github.com/elanthia-online/lich-5/issues/963)) ([88a880a](https://github.com/elanthia-online/lich-5/commit/88a880a193173106a99d667efdba43b7a5d8498d))
* **gs:** StowList missing space in capture in xmlparser.rb [#963](https://github.com/elanthia-online/lich-5/issues/963) ([cab86e8](https://github.com/elanthia-online/lich-5/commit/cab86e81fd2156faa7875d805eaf99f8bfec8ebf))
* **gs:** stowlist.rb check method fix when dead ([#1152](https://github.com/elanthia-online/lich-5/issues/1152)) ([ddf3a12](https://github.com/elanthia-online/lich-5/commit/ddf3a12472ab026ab8fb74e1610a3bb50f38c220))
* **gs:** stowlist.rb wait for RT when issuing check ([#964](https://github.com/elanthia-online/lich-5/issues/964)) ([ca38c70](https://github.com/elanthia-online/lich-5/commit/ca38c708ed30ba530f222fdb05ddc00b85d632ce))
* **gs:** StowList/ReadyList reset bug if non-default keys added ([#1019](https://github.com/elanthia-online/lich-5/issues/1019)) ([c97d86d](https://github.com/elanthia-online/lich-5/commit/c97d86d65664e5defc252f7687fe6d918c54b4c7))
* **gs:** update Infomon parsing for new ACCOUNT output format ([#903](https://github.com/elanthia-online/lich-5/issues/903)) ([ed25d30](https://github.com/elanthia-online/lich-5/commit/ed25d30c5053b1fbac4133229162b1726abd635b))
* **gs:** Various CMan cost corrections ([#932](https://github.com/elanthia-online/lich-5/issues/932)) ([d0f37cc](https://github.com/elanthia-online/lich-5/commit/d0f37ccd02133daa145639420869d69e462634fe))
* **gs:** various PSMs additional corrections ([#881](https://github.com/elanthia-online/lich-5/issues/881)) ([b4ebbbf](https://github.com/elanthia-online/lich-5/commit/b4ebbbf4ed22c0b8485d857be905adbf0c35c910))
* **gs:** warcry.rb yowlp :buff to string instead of regexp ([#847](https://github.com/elanthia-online/lich-5/issues/847)) ([3dd639b](https://github.com/elanthia-online/lich-5/commit/3dd639b2bca14cd76951a057699492642ae2ce02))
* **gs:** weapon PSM affordable check against Glorious Momentum ([#926](https://github.com/elanthia-online/lich-5/issues/926)) ([246d60b](https://github.com/elanthia-online/lich-5/commit/246d60bed6a1acdd1e8804729efc07605f1dd1cf))
* **gs:** weapon.rb assault break if no targets ([#962](https://github.com/elanthia-online/lich-5/issues/962)) ([fa0ee6d](https://github.com/elanthia-online/lich-5/commit/fa0ee6d2c9047128281db5445da84fb29b47e564))
* **gs:** xmlparser.rb capture additional death messaging ([#1158](https://github.com/elanthia-online/lich-5/issues/1158)) ([02293d1](https://github.com/elanthia-online/lich-5/commit/02293d1ce3b771a02b7a37176158b0ec4e09c766))
* remove unnecessary bundle install step ([70e2b37](https://github.com/elanthia-online/lich-5/commit/70e2b379adfedd5a8e7066531a383177933a639b))
* show no matches if nothing found ([2bb905b](https://github.com/elanthia-online/lich-5/commit/2bb905baca1cfa64ab6637bb762992de500ce673))
* update mikepenz/release-changelog-builder-action to v5 ([09b177c](https://github.com/elanthia-online/lich-5/commit/09b177cf51ac59b2f289285c0f664f34599de526))


### Refactoring

* **all:** Add frontend registry for capability-based configuration ([#1223](https://github.com/elanthia-online/lich-5/issues/1223)) ([c1dcc19](https://github.com/elanthia-online/lich-5/commit/c1dcc192233a02d131de19d9723e100876abb862))
* **all:** Centralize frontend capability checks in Frontend module ([#1170](https://github.com/elanthia-online/lich-5/issues/1170)) ([26e4e00](https://github.com/elanthia-online/lich-5/commit/26e4e003429a3577e4e025aed5917ceaba2bee58))
* **all:** Consolidate authentication code under lib/common/authentication ([#1240](https://github.com/elanthia-online/lich-5/issues/1240)) ([14a2ce3](https://github.com/elanthia-online/lich-5/commit/14a2ce3c59fbacdfc5e43793ea98a332b9de7430))
* **all:** Map update for robustness and maintainability ([#1163](https://github.com/elanthia-online/lich-5/issues/1163)) ([b803822](https://github.com/elanthia-online/lich-5/commit/b8038229e80b84c9d47577e8865b2970ce65e565))
* **all:** Refactor game initialization process ([#1162](https://github.com/elanthia-online/lich-5/issues/1162)) ([b90bcf9](https://github.com/elanthia-online/lich-5/commit/b90bcf97be6a404da1db6d238ad70aa7857ce958))
* **all:** reorganize specs to mirror lib/ and fix spec issues ([#1250](https://github.com/elanthia-online/lich-5/issues/1250)) ([32ed5ac](https://github.com/elanthia-online/lich-5/commit/32ed5ac4fa4c6bc425d240774bfa239957c33ee7))
* **dr:** Comprehensive DR modules refactor ([#1231](https://github.com/elanthia-online/lich-5/issues/1231)) ([9bc7914](https://github.com/elanthia-online/lich-5/commit/9bc79144d09bd27aed927044a19c0da575642eab))
* **dr:** consolidate DRCI/EquipmentManager patterns, YARD docs, bug fixes ([#1256](https://github.com/elanthia-online/lich-5/issues/1256)) ([375b9a0](https://github.com/elanthia-online/lich-5/commit/375b9a0a7640c370a0a437ce822843dbe67436df))
* **dr:** dragonrealms drinfomon audit - DRY/SOLID/robustness improvements ([#1243](https://github.com/elanthia-online/lich-5/issues/1243)) ([0478671](https://github.com/elanthia-online/lich-5/commit/04786718e8136394239193a2516f5979f83e539f))
* **dr:** DRY extraction of duplicated patterns in DRCI/EquipmentManager ([#1258](https://github.com/elanthia-online/lich-5/issues/1258)) ([82e613b](https://github.com/elanthia-online/lich-5/commit/82e613b44a8cd0ce39954299079f58b82b8178ff))
* **dr:** use yaml wire-brush-number in repair_own_tools ([#1241](https://github.com/elanthia-online/lich-5/issues/1241)) ([931a579](https://github.com/elanthia-online/lich-5/commit/931a579db0412f683577c927248db87baeb4819e))


### Documentation

* **all:** add DeepWiki auto-docs ([#1280](https://github.com/elanthia-online/lich-5/issues/1280)) ([f9cbd45](https://github.com/elanthia-online/lich-5/commit/f9cbd45bcbebe126078dde94f2518d6fc4840e51))
* **all:** add YARD documentation style guide and .yardopts ([#1252](https://github.com/elanthia-online/lich-5/issues/1252)) ([5915eda](https://github.com/elanthia-online/lich-5/commit/5915eda658141e17ce9a939d76ffeaa864c77ef2))
* **gs:** Group API YARD additions ([#1048](https://github.com/elanthia-online/lich-5/issues/1048)) ([e4a611f](https://github.com/elanthia-online/lich-5/commit/e4a611f137eb05b4c0a8394dc07563d5141ecc04))

## [5.16.2](https://github.com/elanthia-online/lich-5/compare/v5.16.1...v5.16.2) (2026-03-29)


### Bug Fixes

* **all:** repair regression on gui button reenable from refactor ([#1297](https://github.com/elanthia-online/lich-5/issues/1297)) ([f10b1f9](https://github.com/elanthia-online/lich-5/commit/f10b1f95f4c1f0720505d5823e43f334b3c12d62))

## [5.16.1](https://github.com/elanthia-online/lich-5/compare/v5.16.0...v5.16.1) (2026-03-29)


### Bug Fixes

* **all:** fix three revert bugs in SnapshotManager ([#1289](https://github.com/elanthia-online/lich-5/issues/1289)) ([fa87aa0](https://github.com/elanthia-online/lich-5/commit/fa87aa0e8a804343be329145ab147d8f738b886c))
* **all:** guard nil release asset and validate before deleting lib/ ([#1290](https://github.com/elanthia-online/lich-5/issues/1290)) ([b8e3002](https://github.com/elanthia-online/lich-5/commit/b8e3002e206771b1a6937ddcdb1d630e01600b84))
* **all:** guard nil stable version in beta channel resolution ([#1291](https://github.com/elanthia-online/lich-5/issues/1291)) ([c5c42c6](https://github.com/elanthia-online/lich-5/commit/c5c42c6a5e5042a97aeb250a0c8e142259cb830a))
* **all:** narrow safe_write rollback scope so cleanup failure preserves successful write ([#1287](https://github.com/elanthia-online/lich-5/issues/1287)) ([8974813](https://github.com/elanthia-online/lich-5/commit/8974813089c3fd274a62dc049336792be89e7421))
* **all:** remove dead code in BranchInstaller ([#1292](https://github.com/elanthia-online/lich-5/issues/1292)) ([b3c480a](https://github.com/elanthia-online/lich-5/commit/b3c480a18245ccb37060effd6e65597758e098b3))
* **dr:** forward vitality and dead fields in perceive_health ([#1288](https://github.com/elanthia-online/lich-5/issues/1288)) ([cad008c](https://github.com/elanthia-online/lich-5/commit/cad008c24736fce9370f1807f5d1a71c5ff8e688))

## [5.16.0](https://github.com/elanthia-online/lich-5/compare/v5.15.1...v5.16.0) (2026-03-28)


### Features

* **all:** Add active sessions API ([#1274](https://github.com/elanthia-online/lich-5/issues/1274)) ([094c355](https://github.com/elanthia-online/lich-5/commit/094c355c05a29eefc1ffc23a565b6505b0c6615a))
* **all:** add core classes, ScriptSync, and login auto-sync ([#1273](https://github.com/elanthia-online/lich-5/issues/1273)) ([3ccdfb3](https://github.com/elanthia-online/lich-5/commit/3ccdfb38076c5717f9bbdb867af77c26ba0fcdd7))
* **all:** Add session status CLI query ([#1276](https://github.com/elanthia-online/lich-5/issues/1276)) ([91e90f7](https://github.com/elanthia-online/lich-5/commit/91e90f7c4c36cb1620c0c710acf59428172cd0ba))
* **all:** configurable debug log retention ([#1282](https://github.com/elanthia-online/lich-5/issues/1282)) ([03d908d](https://github.com/elanthia-online/lich-5/commit/03d908d6fc433546095594fd27f955969e2803df))
* **all:** session summary store and reporting ([#1247](https://github.com/elanthia-online/lich-5/issues/1247)) ([36ec701](https://github.com/elanthia-online/lich-5/commit/36ec70170e7acb6e56c6da2e78d7fe6f08a7861a))
* **dr:** common-healing.rb - add vitality parsing to HealthResult ([#1265](https://github.com/elanthia-online/lich-5/issues/1265)) ([8a65de0](https://github.com/elanthia-online/lich-5/commit/8a65de0d705a86c42b8fbbf6396f0f80232d32fc))


### Bug Fixes

* **all:** handle auth exceptions in manual login to prevent hang on bad password ([#1267](https://github.com/elanthia-online/lich-5/issues/1267)) ([05dfe30](https://github.com/elanthia-online/lich-5/commit/05dfe306dd9a2d64f54d97b0dc14511e00a8be03))
* **all:** log and re-raise unexpected errors in saved login auth handler ([#1271](https://github.com/elanthia-online/lich-5/issues/1271)) ([5ea9501](https://github.com/elanthia-online/lich-5/commit/5ea950199d83ddc97fb5aa241d70e42a71c9d0bd))
* **all:** Persistent Launcher re-enable play button post launch ([#1269](https://github.com/elanthia-online/lich-5/issues/1269)) ([72d532f](https://github.com/elanthia-online/lich-5/commit/72d532f43b0f12fd925ca75e2f7d9447a72508a1))
* **all:** Restore manual login behaviors to not require saved entry t… ([#1270](https://github.com/elanthia-online/lich-5/issues/1270)) ([5eb6d4f](https://github.com/elanthia-online/lich-5/commit/5eb6d4f3c492a6a9961a55a785100eed06ec965a))
* **all:** set SO_REUSEADDR before bind to allow immediate port reuse ([#1268](https://github.com/elanthia-online/lich-5/issues/1268)) ([9db4b6b](https://github.com/elanthia-online/lich-5/commit/9db4b6be4882b300bf5531e7020aa2808d9d13ab))
* **dr:** buffer_room_objs missed split components with leading stream tags ([#1284](https://github.com/elanthia-online/lich-5/issues/1284)) ([e858d91](https://github.com/elanthia-online/lich-5/commit/e858d91746075d1c5b713826e9683ef5710c3f73))
* **dr:** common-items.rb - get_item_unsafe false positives via XML feed verification ([#1286](https://github.com/elanthia-online/lich-5/issues/1286)) ([b3c286f](https://github.com/elanthia-online/lich-5/commit/b3c286f38442007098ab3038dcfbf804f9fb57c0))
* **dr:** common-items.rb - move pattern from failure to success block ([#1262](https://github.com/elanthia-online/lich-5/issues/1262)) ([7209d3a](https://github.com/elanthia-online/lich-5/commit/7209d3add9a908c3f377b16fb207b49b3f783a7d))
* **gs:** Infomon xmlparser additional npc death messaging ([#1275](https://github.com/elanthia-online/lich-5/issues/1275)) ([517f7cf](https://github.com/elanthia-online/lich-5/commit/517f7cfa77d86cc44e2bcb40cf7f6e4bf39700f3))
* **gs:** Infomon xmlparser additional npc death messaging ([#1281](https://github.com/elanthia-online/lich-5/issues/1281)) ([d66dc50](https://github.com/elanthia-online/lich-5/commit/d66dc50b76712147c7ec082c1476e64f0f46d620))


### Documentation

* **all:** add DeepWiki auto-docs ([#1280](https://github.com/elanthia-online/lich-5/issues/1280)) ([f9cbd45](https://github.com/elanthia-online/lich-5/commit/f9cbd45bcbebe126078dde94f2518d6fc4840e51))

## [5.15.1](https://github.com/elanthia-online/lich-5/compare/v5.15.0...v5.15.1) (2026-03-16)


### Bug Fixes

* **all:** add timeout safety to fput to prevent infinite hangs ([#1261](https://github.com/elanthia-online/lich-5/issues/1261)) ([79176c3](https://github.com/elanthia-online/lich-5/commit/79176c3b07c46fe4fed920ed70714bc23b4b3913))
* **all:** guard against broken pipe errors in Game._puts and send_to_client ([#1260](https://github.com/elanthia-online/lich-5/issues/1260)) ([995cefd](https://github.com/elanthia-online/lich-5/commit/995cefd3ade131c5a819e3a6f649f7a2e4f95470))
* **all:** Mutli-launch persistent login GUI ([#1245](https://github.com/elanthia-online/lich-5/issues/1245)) ([3e4a873](https://github.com/elanthia-online/lich-5/commit/3e4a873131311e57da32f029ccb2a9e70bc5211d))
* **all:** Remove Windows OS CMD prompt flash ([#1255](https://github.com/elanthia-online/lich-5/issues/1255)) ([26b7581](https://github.com/elanthia-online/lich-5/commit/26b7581394d48d821e235c33050b274bf2d246ec))
* **dr:** add bounded recursion depth limits to 9 methods ([#1257](https://github.com/elanthia-online/lich-5/issues/1257)) ([fea0776](https://github.com/elanthia-online/lich-5/commit/fea0776172c0aa64e8cf0bf0c47fed407478ee00))
* **dr:** anchor stow success pattern to prevent fan close recovery bypass ([#1254](https://github.com/elanthia-online/lich-5/issues/1254)) ([c96933d](https://github.com/elanthia-online/lich-5/commit/c96933dee8f15be6409530592a42b021c8bcf259))
* **dr:** stow_helper failure detection + unload_weapon ammo recovery ([#1259](https://github.com/elanthia-online/lich-5/issues/1259)) ([d010383](https://github.com/elanthia-online/lich-5/commit/d0103835bf18f595440ef22743ee0164254ae373))


### Refactoring

* **all:** reorganize specs to mirror lib/ and fix spec issues ([#1250](https://github.com/elanthia-online/lich-5/issues/1250)) ([32ed5ac](https://github.com/elanthia-online/lich-5/commit/32ed5ac4fa4c6bc425d240774bfa239957c33ee7))
* **dr:** consolidate DRCI/EquipmentManager patterns, YARD docs, bug fixes ([#1256](https://github.com/elanthia-online/lich-5/issues/1256)) ([375b9a0](https://github.com/elanthia-online/lich-5/commit/375b9a0a7640c370a0a437ce822843dbe67436df))
* **dr:** DRY extraction of duplicated patterns in DRCI/EquipmentManager ([#1258](https://github.com/elanthia-online/lich-5/issues/1258)) ([82e613b](https://github.com/elanthia-online/lich-5/commit/82e613b44a8cd0ce39954299079f58b82b8178ff))


### Documentation

* **all:** add YARD documentation style guide and .yardopts ([#1252](https://github.com/elanthia-online/lich-5/issues/1252)) ([5915eda](https://github.com/elanthia-online/lich-5/commit/5915eda658141e17ce9a939d76ffeaa864c77ef2))

## [5.15.0](https://github.com/elanthia-online/lich-5/compare/v5.14.2...v5.15.0) (2026-03-09)


### Features

* **all:** add InstanceSettings for core Settings API access ([#1233](https://github.com/elanthia-online/lich-5/issues/1233)) ([6de17eb](https://github.com/elanthia-online/lich-5/commit/6de17eb36119f78a34b8ba3f6ee4ac16e1071b9e))
* **gs:** Overwatch module into core ([#1201](https://github.com/elanthia-online/lich-5/issues/1201)) ([70dee4b](https://github.com/elanthia-online/lich-5/commit/70dee4bd617de4ee8c38ec8b585fc9a56fd100b5))


### Bug Fixes

* **all:** Exit quickly on CLI authentication failure ([#1237](https://github.com/elanthia-online/lich-5/issues/1237)) ([f177cd0](https://github.com/elanthia-online/lich-5/commit/f177cd0f5434139767d0b3494a4640bf1d480a1d))
* **all:** fix GameObj container initialization and add clear_all_containers ([#1226](https://github.com/elanthia-online/lich-5/issues/1226)) ([2a9a6da](https://github.com/elanthia-online/lich-5/commit/2a9a6daa6a9327e903e8f1dc59d0421b290970bd))
* **all:** GameObj object dedupe & GC ([#1234](https://github.com/elanthia-online/lich-5/issues/1234)) ([6a48812](https://github.com/elanthia-online/lich-5/commit/6a4881280aa7f656aee103fdd92c37e72fd5dfe2))
* **all:** script.rb show Script.kill source ([#1235](https://github.com/elanthia-online/lich-5/issues/1235)) ([fbbf04c](https://github.com/elanthia-online/lich-5/commit/fbbf04cf02cdbb3cabda3f163d6094c6bcd78d36))
* **all:** suppress wine detection noise and skip when unneeded ([#1244](https://github.com/elanthia-online/lich-5/issues/1244)) ([dfcd813](https://github.com/elanthia-online/lich-5/commit/dfcd81395d7a827d088654579e810924a28c283a))
* **dr:** DR modules fixes and enhancements ([#1232](https://github.com/elanthia-online/lich-5/issues/1232)) ([4c63805](https://github.com/elanthia-online/lich-5/commit/4c63805bb3f5aca6c059d9b3922ce8b85b8fe60d))
* **gs:** Bounty parser fix regex pattern for skin retrieval task ([#1242](https://github.com/elanthia-online/lich-5/issues/1242)) ([d480143](https://github.com/elanthia-online/lich-5/commit/d4801435018b6f988ab5db4b3d74318f11668205))
* **gs:** psms.rb add additional failure matches ([#1238](https://github.com/elanthia-online/lich-5/issues/1238)) ([4ce94d2](https://github.com/elanthia-online/lich-5/commit/4ce94d247132a9c26dd4285f30e048ee3702e769))


### Refactoring

* **all:** Add frontend registry for capability-based configuration ([#1223](https://github.com/elanthia-online/lich-5/issues/1223)) ([c1dcc19](https://github.com/elanthia-online/lich-5/commit/c1dcc192233a02d131de19d9723e100876abb862))
* **all:** Consolidate authentication code under lib/common/authentication ([#1240](https://github.com/elanthia-online/lich-5/issues/1240)) ([14a2ce3](https://github.com/elanthia-online/lich-5/commit/14a2ce3c59fbacdfc5e43793ea98a332b9de7430))
* **dr:** Comprehensive DR modules refactor ([#1231](https://github.com/elanthia-online/lich-5/issues/1231)) ([9bc7914](https://github.com/elanthia-online/lich-5/commit/9bc79144d09bd27aed927044a19c0da575642eab))
* **dr:** dragonrealms drinfomon audit - DRY/SOLID/robustness improvements ([#1243](https://github.com/elanthia-online/lich-5/issues/1243)) ([0478671](https://github.com/elanthia-online/lich-5/commit/04786718e8136394239193a2516f5979f83e539f))
* **dr:** use yaml wire-brush-number in repair_own_tools ([#1241](https://github.com/elanthia-online/lich-5/issues/1241)) ([931a579](https://github.com/elanthia-online/lich-5/commit/931a579db0412f683577c927248db87baeb4819e))

## [5.14.2](https://github.com/elanthia-online/lich-5/compare/v5.14.1...v5.14.2) (2026-02-18)


### Bug Fixes

* **all:** add retry with exponential backoff for all login authentication ([#1205](https://github.com/elanthia-online/lich-5/issues/1205)) ([ff365ef](https://github.com/elanthia-online/lich-5/commit/ff365ef783cdd6803ce01e811b6ecf2cb5937859))
* **all:** update.rb allow for bugfix betas and branch updates ([#1211](https://github.com/elanthia-online/lich-5/issues/1211)) ([2d60245](https://github.com/elanthia-online/lich-5/commit/2d602450d38c19724b09fa9527776a49a642f907))
* **gs:** infomon.rb bug in _key transformation ([#1216](https://github.com/elanthia-online/lich-5/issues/1216)) ([46bfc81](https://github.com/elanthia-online/lich-5/commit/46bfc811d41bb3d0d80911b9e64b6fb6ca13186b))

## [5.14.1](https://github.com/elanthia-online/lich-5/compare/v5.14.0...v5.14.1) (2026-02-12)


### Bug Fixes

* **all:** change encodings in main.rb to wizard FE only ([#1199](https://github.com/elanthia-online/lich-5/issues/1199)) ([fe43007](https://github.com/elanthia-online/lich-5/commit/fe4300702392b8b4c1720ac3f988cc2fa56d2bf9))
* **all:** Change server_time_offset in XMLParser to be float instead of int ([#1184](https://github.com/elanthia-online/lich-5/issues/1184)) ([2e26e8e](https://github.com/elanthia-online/lich-5/commit/2e26e8ea7af4c8ccb208af19a806a9005e8d7526))
* **gs:** Infomon parser.rb bug in EnhanciveEnd ([#1198](https://github.com/elanthia-online/lich-5/issues/1198)) ([fe20c7b](https://github.com/elanthia-online/lich-5/commit/fe20c7b069157f4e244f19d376a117fa0c6f11a0))
* **gs:** Infomon parser.rb update Account.subscription/type ([#1192](https://github.com/elanthia-online/lich-5/issues/1192)) ([698d1da](https://github.com/elanthia-online/lich-5/commit/698d1daf7da2d50fa330f84f4f60180e7ec21033))
* **gs:** spell.rb add last_cast to track last time casted ([#1193](https://github.com/elanthia-online/lich-5/issues/1193)) ([67115dd](https://github.com/elanthia-online/lich-5/commit/67115dd0b6bfbedc118de0740dc61f57603740a0))
* **gs:** stash.rb additional improvements with ReadyList/StowList ([#1197](https://github.com/elanthia-online/lich-5/issues/1197)) ([5ef1c85](https://github.com/elanthia-online/lich-5/commit/5ef1c859f188f506af2c7b29faa2b7b344035e21))

## [5.14.0](https://github.com/elanthia-online/lich-5/compare/v5.13.6...v5.14.0) (2026-02-07)


### Features

* **all:** Add Genie map cross-reference fields to the DragonRealms map data model ([#1169](https://github.com/elanthia-online/lich-5/issues/1169)) ([1e7c1dd](https://github.com/elanthia-online/lich-5/commit/1e7c1dde11025e5fe8bdbdf9f562f97bb4a84a2c))
* **dr:** DRExpMonitor move into core lich ([#1154](https://github.com/elanthia-online/lich-5/issues/1154)) ([48524b9](https://github.com/elanthia-online/lich-5/commit/48524b9a1bef7089f371df5bb0073792ef287023))
* **gs:** add Enhancive module for enhancive item bonus tracking ([#1113](https://github.com/elanthia-online/lich-5/issues/1113)) ([61cff8f](https://github.com/elanthia-online/lich-5/commit/61cff8f7fb0155c6ebf8096186bed1cd8fc023e9))
* **gs:** add QStrike module for optimal stamina-based RT reduction ([#1114](https://github.com/elanthia-online/lich-5/issues/1114)) ([b10af81](https://github.com/elanthia-online/lich-5/commit/b10af81f1ec8ad6143f58e1565968312d469a62e))


### Bug Fixes

* **all:** map_base.rb sort JSON better ([#1171](https://github.com/elanthia-online/lich-5/issues/1171)) ([7e60e68](https://github.com/elanthia-online/lich-5/commit/7e60e68c1dc310ebe87a10cbf25696287cf7f4bc))
* **all:** remove strip! from settingsInfo replacement ([#1161](https://github.com/elanthia-online/lich-5/issues/1161)) ([aef52ad](https://github.com/elanthia-online/lich-5/commit/aef52add62c47daa73579ac69e13db0352c34cdd))
* **dr:** logbook_item recovery when crafted item not in hand ([#1175](https://github.com/elanthia-online/lich-5/issues/1175)) ([da18fa9](https://github.com/elanthia-online/lich-5/commit/da18fa95e602fdae0ee1cc256212fed4eaaba00d))
* **gs:** stash.rb ReadyList sheath handling and update inventory checks ([#1166](https://github.com/elanthia-online/lich-5/issues/1166)) ([7aeec90](https://github.com/elanthia-online/lich-5/commit/7aeec90f8faf8a4cef881317ab7719d6858c7b78))
* **gs:** xmlparser.rb capture additional death messaging ([#1158](https://github.com/elanthia-online/lich-5/issues/1158)) ([02293d1](https://github.com/elanthia-online/lich-5/commit/02293d1ce3b771a02b7a37176158b0ec4e09c766))


### Refactoring

* **all:** Centralize frontend capability checks in Frontend module ([#1170](https://github.com/elanthia-online/lich-5/issues/1170)) ([26e4e00](https://github.com/elanthia-online/lich-5/commit/26e4e003429a3577e4e025aed5917ceaba2bee58))
* **all:** Map update for robustness and maintainability ([#1163](https://github.com/elanthia-online/lich-5/issues/1163)) ([b803822](https://github.com/elanthia-online/lich-5/commit/b8038229e80b84c9d47577e8865b2970ce65e565))
* **all:** Refactor game initialization process ([#1162](https://github.com/elanthia-online/lich-5/issues/1162)) ([b90bcf9](https://github.com/elanthia-online/lich-5/commit/b90bcf97be6a404da1db6d238ad70aa7857ce958))

## [5.13.6](https://github.com/elanthia-online/lich-5/compare/v5.13.5...v5.13.6) (2026-01-26)


### Bug Fixes

* **all:** allow --add-account to run without yaml and dat ([#1143](https://github.com/elanthia-online/lich-5/issues/1143)) ([ca48153](https://github.com/elanthia-online/lich-5/commit/ca48153f36c96d70728142d1e5621ed82b2e7750))
* **all:** Allow hmr to work on global_defs.rb ([#1156](https://github.com/elanthia-online/lich-5/issues/1156)) ([b077c8a](https://github.com/elanthia-online/lich-5/commit/b077c8a6fca3cd6059606a834014b3b25b6cb3a3))
* **all:** enable --login for multi-variable custom launch commands ([#1144](https://github.com/elanthia-online/lich-5/issues/1144)) ([0464b2d](https://github.com/elanthia-online/lich-5/commit/0464b2d2e781a4aed1e1d8469bbd54689272ca62))
* **all:** messaging.rb return "" for xml_encode with Wizard ([#1147](https://github.com/elanthia-online/lich-5/issues/1147)) ([96a5a7f](https://github.com/elanthia-online/lich-5/commit/96a5a7f17b2f6d57ec456a2fcf798bf8c76a2a7c))
* **all:** prevent closing connection on module reload ([#1148](https://github.com/elanthia-online/lich-5/issues/1148)) ([2540a14](https://github.com/elanthia-online/lich-5/commit/2540a1497fd301996be3e0d8466b1b065979b733))
* **all:** update.rb pervent update if MIN_RUBY not met ([#1146](https://github.com/elanthia-online/lich-5/issues/1146)) ([24b5173](https://github.com/elanthia-online/lich-5/commit/24b5173a55400f4fff78d7f3677a85912de239cf))
* **dr:** add buffering for multiline room players ([#1151](https://github.com/elanthia-online/lich-5/issues/1151)) ([c7c2cc7](https://github.com/elanthia-online/lich-5/commit/c7c2cc78459e01b1507f0469dbca43eb631bc0de))
* **dr:** add verify_script def here instead of depending on dependency ([#1155](https://github.com/elanthia-online/lich-5/issues/1155)) ([21560de](https://github.com/elanthia-online/lich-5/commit/21560de0c7ccebb3cd1c6259c78de3eea7e801b4))
* **dr:** buffer split room obj lines and merge instead of appending closing tag to broken line ([#1149](https://github.com/elanthia-online/lich-5/issues/1149)) ([b8dd4a2](https://github.com/elanthia-online/lich-5/commit/b8dd4a2f3d25f45d89843eb58624db4e07f246d6))
* **gs:** infomon.rb added updated_at field to upsert_batch ([#1145](https://github.com/elanthia-online/lich-5/issues/1145)) ([ff2b4b5](https://github.com/elanthia-online/lich-5/commit/ff2b4b551e4f9438c9a28c74fd98ed1c15c6a9e2))
* **gs:** readylist.rb check method fix when dead ([#1153](https://github.com/elanthia-online/lich-5/issues/1153)) ([29729f4](https://github.com/elanthia-online/lich-5/commit/29729f45fa731af2a74d21bc48daa45fd0988f48))
* **gs:** stowlist.rb check method fix when dead ([#1152](https://github.com/elanthia-online/lich-5/issues/1152)) ([ddf3a12](https://github.com/elanthia-online/lich-5/commit/ddf3a12472ab026ab8fb74e1610a3bb50f38c220))

## [5.13.5](https://github.com/elanthia-online/lich-5/compare/v5.13.4...v5.13.5) (2026-01-16)


### Bug Fixes

* **all:** add --gs and --dr, refactor argv_options to helpers ([#1133](https://github.com/elanthia-online/lich-5/issues/1133)) ([a809a26](https://github.com/elanthia-online/lich-5/commit/a809a26cb9694fa699855dd91de6888aa906c514))
* **all:** fix multiple custom entries, improvements to yaml save ([#1134](https://github.com/elanthia-online/lich-5/issues/1134)) ([86e69a3](https://github.com/elanthia-online/lich-5/commit/86e69a353ca323cc922fc06abddca3b61f62c0ff))
* **all:** login_tab_utils.rb expand helper text show Warlock ([#1135](https://github.com/elanthia-online/lich-5/issues/1135)) ([1b43e0d](https://github.com/elanthia-online/lich-5/commit/1b43e0d12b5afa88207ac017b03d790519c260d3))
* **all:** reduce minimum GUI window footprint for non-tabbed view ([#1138](https://github.com/elanthia-online/lich-5/issues/1138)) ([79b18ed](https://github.com/elanthia-online/lich-5/commit/79b18ed2d70d5ae56bd01477ec859acb4508e220))
* **all:** remove double save in YAML to preserve yaml.bak integrity ([#1139](https://github.com/elanthia-online/lich-5/issues/1139)) ([0c26110](https://github.com/elanthia-online/lich-5/commit/0c2611081c37a4167a5a729d7da1b1b34e5aa96f))
* **all:** remove password parameter from debug logging in all cases ([#1137](https://github.com/elanthia-online/lich-5/issues/1137)) ([fe21beb](https://github.com/elanthia-online/lich-5/commit/fe21beb7bdd8ddaa8b7c7ec6254165587bbc2162))
* **all:** update CLI for YAML security signature, add auto-convert fo… ([#1136](https://github.com/elanthia-online/lich-5/issues/1136)) ([b1c690a](https://github.com/elanthia-online/lich-5/commit/b1c690af39b2ac045b8413a3f83b57defa264b70))
* **all:** util.rb only show gem installing debug messaging if gem mis… ([#1131](https://github.com/elanthia-online/lich-5/issues/1131)) ([dd55334](https://github.com/elanthia-online/lich-5/commit/dd55334351715dda9feea214ed91bf59563ef754))
* **gs:** stash.rb additional improvements ([#1132](https://github.com/elanthia-online/lich-5/issues/1132)) ([8a8d906](https://github.com/elanthia-online/lich-5/commit/8a8d906a4da56e2719789e0679e70bb88bae45b4))

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
