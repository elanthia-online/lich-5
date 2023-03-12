; Original script generated for Inno Setup by Doug (doug@play.net).
; Contains Ruby 3.2.1 64 bit with msys2 libraries and key gems
; to support the Lich scripting environment for Simutronics games

#define MyAppName "Ruby4Lich5"
#define MyAppVersion "5.7.0"
#define MyAppPublisher "Ruby Installer"
#define MyAppURL "https://www.rubyinstaller.org"
#define MyAppExeName "Ruby4Lich5.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId= {{15FD652E-E37B-444B-AC7C-BBDDD25713EE}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
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
;Name: "launch";               Description: "Simutronics Game Files"
;Name: "custom"; 	            Description: "Custom Installation"; 			      Flags: iscustom

[Components]
Name: "lich"; 				        Description: "Lich Files"; 				              Types: full
Name: "rubygem"; 			        Description: "Ruby 3.2.1 (64-bit) with Gems"; 	Types: full compact
; Name: "simu"; 				        Description: "Simutronics Files"; 				      Types: launch
; Name: "simu\launcher"; 		    Description: "Simu Game Launcher"; 				      Types: launch
; Name: "simu\wizardfe"; 		    Description: "Simu Wizard Front End"; 			    Flags: exclusive
; Name: "simu\stormfrontfe"; 	  Description: "Simu StormFront Front End"; 		  Flags: exclusive

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "C:\hostedtoolcache\windows\Ruby\3.2.1\x64\*";         DestDir: "{app}\";           Components: rubygem;           Flags: ignoreversion createallsubdirs recursesubdirs
Source: "C:\msys64\*";         DestDir: "{app}\msys64";           Components: rubygem;           Flags: ignoreversion createallsubdirs recursesubdirs
Source: ".\fly64.ico";            DestDir: "{app}\R4LInstall"; Components: lich; 	            Flags: ignoreversion
; Source: ".\lnchInst.exe";         DestDir: "{app}\R4LInstall"; Components: simu\launcher;     Flags: ignoreversion
; Source: ".\wzinst.exe";           DestDir: "{app}\R4LInstall"; Components: simu\wizardfe;     Flags: ignoreversion
; Source: ".\StormFront.exe";       DestDir: "{app}\R4LInstall"; Components: simu\stormfrontfe; Flags: ignoreversion
Source: ".\Lich5\*";              DestDir: "{app}\R4LInstall\Lich5";      Components: lich;              Flags: ignoreversion createallsubdirs recursesubdirs   

; NOTE: Don't use "Flags: ignoreversion" on any shared system files

;[Icons]
;Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKCU; Subkey: "SOFTWARE\Classes\.rb"; ValueType: string; ValueName: ""; ValueData: "RubyFile"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\.rbw"; ValueType: string; ValueName: ""; ValueData: "RubyWFile"; Flags: uninsdeletevalue uninsdeletekeyifempty
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile"; ValueType: string; ValueName: ""; ValueData: "RubyFile"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile"; ValueType: string; ValueName: ""; ValueData: "RubyWFile"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bin\ruby.exe,0"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bin\rubyw.exe,0"; Flags: uninsdeletekey 
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bin\ruby.exe"" ""%1"" %*"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Classes\RubyWFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bin\rubyw.exe"" ""%1"" %*"; Flags: uninsdeletekey
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"; ValueType: string; ValueName: "{app}\bin\rubyw.exe"; ValueData: "~ WIN7RTM"; Flags: uninsdeletevalue

[RUN]
;Filename: "{app}\R4LInstall\lnchInst.exe"; Parameters: "/verysilent /tasks=assocfiles"; Components: simu\launcher
;Filename: "{app}\R4LInstall\wzinst.exe"; Parameters: "/verysilent"; Components: simu\wizardfe
;Filename: "{app}\R4LInstall\stormfront.exe"; Parameters: "/verysilent"; Components: simu\stormfrontfe
Filename: "{cmd}"; Parameters: "/c""xcopy /i /e /s ""{app}\R4LInstall\Lich5"" ""{userdesktop}\Lich5"""""; Components: lich
