; Original script generated for Inno Setup by Doug (doug@play.net).
; Contains Ruby 64 bit with msys2 libraries and key gems
; to support the Lich scripting environment for Simutronics games

#define MyAppName "Ruby4Lich5"
#define MyAppVersion "5.7.0-rc.3"
#define RubyVersion "3.2.2"
#define MyAppPublisher "Elanthia-Online"
#define MyAppURL "https://github.com/elanthia-online/lich-5/"
#define MyAppExeName "Ruby4Lich5.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId= {{edd9ccd7-33cb-4577-a470-fe8fd087ead1}
; AppId History
; Ruby 3.2.2 Lich 5.7.0-rc.3 - edd9ccd7-33cb-4577-a470-fe8fd087ead1
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} Ruby {#RubyVersion} & Lich {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
SetupLogging=yes
ChangesAssociations=yes
;ChangesEnvironment=true
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
Name: "full"; 		            Description: "Ruby and Lich Files"
Name: "compact"; 	            Description: "Ruby Installation Only"

[Components]
Name: "lich"; 				        Description: "Lich Files"; 				              Types: full
Name: "rubygem"; 			        Description: "Ruby {#RubyVersion} (64-bit) with Gems"; 	Types: full compact

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
Source: "C:\hostedtoolcache\windows\Ruby\{#RubyVersion}\x64\*";         DestDir: "{app}\{#RubyVersion}";           Components: rubygem;           Flags: ignoreversion createallsubdirs recursesubdirs
Source: "C:\msys64\*";         DestDir: "{app}\{#RubyVersion}\msys64";           Components: rubygem;           Flags: ignoreversion createallsubdirs recursesubdirs
Source: ".\fly64.ico";            DestDir: "{app}\R4LInstall"; Components: lich; 	            Flags: ignoreversion
Source: ".\Lich5\*";              DestDir: "{app}\R4LInstall\Lich{#MyAppVersion}";      Components: lich;              Flags: ignoreversion createallsubdirs recursesubdirs   

[Registry]
Root: HKCU; Subkey: "SOFTWARE\Classes\.rb"; ValueType: string; ValueName: ""; ValueData: "RubyFile"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\.rbw"; ValueType: string; ValueName: ""; ValueData: "RubyWFile"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile"; ValueType: string; ValueName: ""; ValueData: "RubyFile"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile"; ValueType: string; ValueName: ""; ValueData: "RubyWFile"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#RubyVersion}\bin\ruby.exe,0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#RubyVersion}\bin\rubyw.exe,0"; Flags: uninsdeletekey 
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#RubyVersion}\bin\ruby.exe"" ""%1"" %*"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#RubyVersion}\bin\rubyw.exe"" ""%1"" %*"; Flags: uninsdeletekey
;Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"; ValueType: string; ValueName: "{app}\{#RubyVersion}\bin\rubyw.exe"; ValueData: "~ WIN7RTM"; Flags: uninsdeletevalue

[RUN]
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s ""{app}\R4LInstall\Lich{#MyAppVersion}"" ""{userdesktop}\Lich5"""""; Components: lich
