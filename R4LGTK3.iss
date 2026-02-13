; Original script generated for Inno Setup by Doug (doug@play.net).
; Contains Ruby 64 bit with msys2 libraries and key gems
; to support the Lich scripting environment for Simutronics games

#define MyAppName "Ruby4Lich5"
#define MyAppVersion "5.14.0" ; x-release-please-version
#define RubyVersion "4.0.0"
#define MyAppPublisher "Elanthia-Online"
#define MyAppURL "https://github.com/elanthia-online/lich-5/"
#define MyAppExeName "Ruby4Lich5.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
; Release Please does not increment the AppId with every build.  So do not change this number.
; The AppId identifies the Lich 5 application.  When we move to Lich 6, we generate a new GUID.
AppId= {{edd9ccd7-33cb-4577-a470-fe8fd087eb07}
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
;
;Only need Changes Environment when setting path.
;
; Let's take this down to bare bones.
;
;DisableDirPage=Yes
DefaultDirName=C:\Ruby4Lich5
DisableStartupPrompt=Yes
DisableProgramGroupPage=Yes
DisableWelcomePage=Yes
DisableReadyPage=Yes
UsePreviousAppDir=No
;DisableFinishedPage=Yes

; Uncomment the following line to run in non administrative install mode (install for current user only.)
PrivilegesRequired=lowest
;PrivilegesRequiredOverridesAllowed=commandline dialog
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
Name: LichGS;  Description: "Place in Desktop ({userdesktop}\Lich5 - preferred for Gemstone IV)";  GroupDescription: "Lich5 Folder Location";  Components: lich; Flags: unchecked exclusive
Name: LichDR;  Description: "Place in Ruby4Lich5 ({app}\Lich5 - preferred for DragonRealms)";      GroupDescription: "Lich5 Folder Location";  Components: lich; Flags: unchecked exclusive

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{app}\R4LInstall"; Attribs: hidden

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
Source: "C:\hostedtoolcache\windows\Ruby\{#RubyVersion}\x64\*"; DestDir: "{app}\{#RubyVersion}";                 Components: rubygem; Flags: ignoreversion createallsubdirs recursesubdirs; Excludes: "msys64"
; MSYS2 installed into app tree on the runner
Source: "C:\Ruby4Lich5\msys64\*";                               DestDir: "{app}\{#RubyVersion}\msys64";          Components: rubygem; Flags: ignoreversion createallsubdirs recursesubdirs
Source: ".\fly64.ico";                                          DestDir: "{app}\R4LInstall";                     Components: lich;    Flags: ignoreversion
Source: ".\Lich5\*";                                            DestDir: "{app}\R4LInstall\Lich{#MyAppVersion}"; Components: lich;    Flags: ignoreversion createallsubdirs recursesubdirs   

[Registry]
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

[RUN]
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{userdesktop}\Lich5"""""; Tasks: LichGS
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s /y ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{app}\Lich5""""";         Tasks: LichDR
