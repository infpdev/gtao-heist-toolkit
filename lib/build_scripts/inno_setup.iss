
; Inno Setup script for vaultOps
#define MyAppName "vaultOps"
#define MyAppVersion "3.4.0"
#define MyAppPublisher "infpdev"
#define MyAppURL "https://github.com/infpdev/gtao-heist-toolkit"
#define MyAppExeName "vaultOps.exe"


[Setup]
AppId={{E0CFA883-C448-4117-99EF-F35801970A1F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={code:GetMyCurrentDir}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputDir=..\..\dist
OutputBaseFilename="vaultOps-Setup"
SetupIconFile=gta.ico
; SolidCompression=yes
; Compression=lzma2

WizardStyle=modern


[Code]
function GetMyCurrentDir(Param: String): String;
begin
	Result := ExpandConstant('{pf}');
	try
		Result := GetCurrentDir();
	except
	end;
end;


[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"


[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"


[Files]
Source: "..\..\vaultOps.exe"; DestDir: "{app}"; Flags: ignoreversion 
Source: "gta.ico"; DestDir: "{app}\lib\static"; Flags: ignoreversion
Source: "..\..\1366x768\*"; DestDir: "{app}\1366x768"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\1600x900\*"; DestDir: "{app}\1600x900"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\1920x1080\*"; DestDir: "{app}\1920x1080"; Flags: ignoreversion recursesubdirs createallsubdirs
; Source: "settings_template.ini"; DestDir: "{app}"; DestName: "zSettings.ini"; Flags: ignoreversion
Source: "..\static\*"; DestDir: "{app}\lib\static"; Flags: ignoreversion recursesubdirs createallsubdirs


[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\lib\static\gta.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\lib\static\gta.ico"; Tasks: desktopicon


[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

