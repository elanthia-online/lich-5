; Ruby4Lich5 — thin installer (non-DevKit, gem-factory model)
;
; Replaces the old "bake a Ruby tree + MSYS2 and embed it" approach (R4LGTK3.iss)
; with: embed the stock RubyInstaller .exe + the precompiled gem bundle, then
;   1. run RubyInstaller silently (non-DevKit),
;   2. optionally run `ridk install` for developers (downloads MSYS2),
;   3. `gem install --local` the binary gems (offline, no compile).
; No baked tree, no prune.
;
; Build-time injected defines (workflow passes via ISCC /D...):
;   RubyVersion        e.g. 4.0.5   (resolved "latest 4.0.x")
;   RubyInstallerExe   e.g. rubyinstaller-4.0.5-1-x64.exe
;   MyAppVersion       Lich version (x-release-please-version on the gem/lich side)

#ifndef RubyVersion
  #define RubyVersion "4.0.5"
#endif
#ifndef RubyInstallerExe
  #define RubyInstallerExe "rubyinstaller-4.0.5-1-x64.exe"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Ruby4Lich5"
#define MyAppPublisher "Elanthia-Online"
#define MyAppURL "https://github.com/elanthia-online/lich-5/"
#define MyAppExeName "Ruby4Lich5.exe"

[Setup]
; AppId identifies the Lich 5 application; do NOT change it (new GUID only at Lich 6).
AppId={{edd9ccd7-33cb-4577-a470-fe8fd087eb07}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} Ruby {#RubyVersion} & Lich {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
SetupLogging=yes
ChangesAssociations=yes
ChangesEnvironment=true
DefaultDirName=C:\Ruby4Lich5
DisableStartupPrompt=Yes
DisableProgramGroupPage=Yes
DisableWelcomePage=Yes
DisableReadyPage=Yes
UsePreviousAppDir=No
PrivilegesRequired=lowest
OutputBaseFilename=Ruby4Lich5
SetupIconFile=.\fly64.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Types]
Name: "full";      Description: "Both Lich and Ruby"
Name: "lichonly";  Description: "Lich Installation Only"
Name: "rubyonly";  Description: "Ruby Installation Only"

[Components]
Name: "lich";     Description: "Lich Files";                             Types: full lichonly
Name: "rubygem";  Description: "Ruby {#RubyVersion} (64-bit) with Gems"; Types: full rubyonly

[Tasks]
Name: LichGS;  Description: "Place in Desktop ({userdesktop}\Lich5 - preferred for Gemstone IV)";  GroupDescription: "Lich5 Folder Location";  Components: lich;    Flags: unchecked exclusive
Name: LichDR;  Description: "Place in Ruby4Lich5 ({app}\Lich5 - preferred for DragonRealms)";      GroupDescription: "Lich5 Folder Location";  Components: lich;    Flags: unchecked exclusive
; Developers only: pulls the MSYS2 DevKit via `ridk install` (requires network).
Name: devkit;  Description: "Install Ruby DevKit (developers — downloads MSYS2, needs network)";  GroupDescription: "Ruby options";           Components: rubygem; Flags: unchecked

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{app}\R4LInstall"; Attribs: hidden

[Files]
; Stock RubyInstaller (non-DevKit) — run, not unpacked, by [Run] below.
Source: ".\{#RubyInstallerExe}";  DestDir: "{app}\R4LInstall";                     Components: rubygem; Flags: ignoreversion deleteafterinstall
; Precompiled gem bundle from the gem factory: *.gem + install-runtime-gems.cmd + runtime-gems-install-targets.txt
Source: ".\gems\*";               DestDir: "{app}\R4LInstall\gems";                Components: rubygem; Flags: ignoreversion createallsubdirs recursesubdirs
Source: ".\fly64.ico";            DestDir: "{app}\R4LInstall";                     Components: lich;    Flags: ignoreversion
Source: ".\Lich5\*";              DestDir: "{app}\R4LInstall\Lich{#MyAppVersion}"; Components: lich;    Flags: ignoreversion createallsubdirs recursesubdirs

; NOTE: Ruby PATH + .rb/.rbw associations are delegated to RubyInstaller's own
; `modpath,assocfiles` tasks (see [Run]), so the old [Registry] block is gone.

[Run]
; 1. Install Ruby, non-DevKit, into {app}\{RubyVersion}. RubyInstaller is itself an
;    Inno Setup app, so it honors /verysilent /dir /tasks. ridkinstall is omitted.
Filename: "{app}\R4LInstall\{#RubyInstallerExe}"; \
  Parameters: "/verysilent /norestart /dir=""{app}\{#RubyVersion}"" /tasks=""assocfiles,modpath"""; \
  StatusMsg: "Installing Ruby {#RubyVersion} (non-DevKit)..."; \
  Components: rubygem; Flags: waituntilterminated

; 2. (Optional) DevKit for developers — pulls MSYS2 base + toolchain. Needs network.
Filename: "{app}\{#RubyVersion}\bin\ridk.cmd"; Parameters: "install 2 3"; \
  StatusMsg: "Installing Ruby DevKit (MSYS2)..."; \
  Components: rubygem; Tasks: devkit; Flags: waituntilterminated runhidden

; 3. Install the precompiled binary gems against the freshly installed Ruby (offline --local).
;    install-runtime-gems.cmd lives in the bundle and runs `gem install --local` per target.
Filename: "{cmd}"; \
  Parameters: "/c ""set ""PATH={app}\{#RubyVersion}\bin;%PATH%"" && cd /d ""{app}\R4LInstall\gems"" && call install-runtime-gems.cmd"""; \
  StatusMsg: "Installing Lich runtime gems..."; \
  Components: rubygem; Flags: waituntilterminated runhidden

; 4. Place Lich where the user chose (unchanged from the legacy installer).
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{userdesktop}\Lich5"""""; Tasks: LichGS
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{app}\Lich5""""";         Tasks: LichDR
