; Ruby4Lich5 — baked installer (non-DevKit, binary-gem factory model)
;
; The Ruby tree is built on the CI runner: stock RubyInstaller (.7z) extracted,
; then the precompiled binary gems are `gem install --local`'d straight into it.
; No MSYS2, no compilation, no prune — the binary gems are self-contained
; (they vendor their own DLLs). This installer just lays that finished tree down:
; one app, file-copy fast, responsive. DevKit stays optional via ridk.
;
; Build-time injected defines (workflow passes via ISCC /D...):
;   RubyVersion    e.g. 4.0.5   (resolved "latest 4.0.x")
;   MyAppVersion   Lich version

#ifndef RubyVersion
  #define RubyVersion "4.0.5"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Ruby4Lich5"
#define MyAppPublisher "Elanthia-Online"
#define MyAppURL "https://github.com/elanthia-online/lich-5/"

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
; The pre-baked Ruby tree: RubyInstaller + binary gems already installed in, staged by CI at .\ruby.
Source: ".\ruby\*";    DestDir: "{app}\{#RubyVersion}";                 Components: rubygem; Flags: ignoreversion createallsubdirs recursesubdirs
Source: ".\fly64.ico"; DestDir: "{app}\R4LInstall";                     Components: lich;    Flags: ignoreversion
Source: ".\Lich5\*";   DestDir: "{app}\R4LInstall\Lich{#MyAppVersion}"; Components: lich;    Flags: ignoreversion createallsubdirs recursesubdirs

[Registry]
; We lay down a tree (no RubyInstaller run), so we set associations + PATH ourselves.
; Restored verbatim from the legacy R4LGTK3.iss — proven for months.
Root: HKCU; Subkey: "SOFTWARE\Classes\.rb";                          ValueType: string; ValueName: ""; ValueData: "RubyFile";                                         Components: rubygem; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\.rbw";                         ValueType: string; ValueName: ""; ValueData: "RubyWFile";                                        Components: rubygem; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile";                     ValueType: string; ValueName: ""; ValueData: "RubyFile";                                         Components: rubygem; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile";                    ValueType: string; ValueName: ""; ValueData: "RubyWFile";                                        Components: rubygem; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\DefaultIcon";         ValueType: string; ValueName: ""; ValueData: "{app}\{#RubyVersion}\bin\ruby.exe,0";              Components: rubygem; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\DefaultIcon";        ValueType: string; ValueName: ""; ValueData: "{app}\{#RubyVersion}\bin\rubyw.exe,0";             Components: rubygem; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\shell\open\command";  ValueType: string; ValueName: ""; ValueData: """{app}\{#RubyVersion}\bin\ruby.exe"" ""%1"" %*";  Components: rubygem; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#RubyVersion}\bin\rubyw.exe"" ""%1"" %*"; Components: rubygem; Flags: uninsdeletekey
; Put Ruby bin, then the old PATH
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{app}\{#RubyVersion}\bin;{olddata}"; Flags: preservestringtype

[Run]
; Optional DevKit for developers — ridk ships in the baked tree; pulls MSYS2 (network).
Filename: "{app}\{#RubyVersion}\bin\ridk.cmd"; Parameters: "install 2 3"; \
  StatusMsg: "Installing Ruby DevKit (MSYS2)..."; \
  Components: rubygem; Tasks: devkit; Flags: waituntilterminated runhidden

; Place Lich where the user chose (unchanged from the legacy installer).
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{userdesktop}\Lich5"""""; Tasks: LichGS
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{app}\Lich5""""";         Tasks: LichDR
