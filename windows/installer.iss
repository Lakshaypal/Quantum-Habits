; Inno Setup script — produces QuantumHabits-windows-setup.exe.
; Installs per-user (no admin prompt), creates Start menu + search entry and
; an Add/Remove Programs record, launches the app after install, and supports
; silent self-updates (/SILENT) from inside the app.
;
; Built in CI (release.yml) with:
;   iscc /DAppVersion=X.Y.Z /DSourceDir=..\build\windows\x64\runner\Release windows\installer.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8F4A9C51-2B7E-4D31-9A64-3C61A2B7E905}
AppName=Quantum Habits
AppVersion={#AppVersion}
AppPublisher=Quantum Habits
DefaultDirName={localappdata}\QuantumHabits
DefaultGroupName=Quantum Habits
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputBaseFilename=QuantumHabits-windows-setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\quantum_habits.exe
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
; Start menu (this is what makes it show up in Start + Windows search)
Name: "{autoprograms}\Quantum Habits"; Filename: "{app}\quantum_habits.exe"
; Optional desktop shortcut
Name: "{autodesktop}\Quantum Habits"; Filename: "{app}\quantum_habits.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
; Relaunch after both interactive installs and silent in-app updates
Filename: "{app}\quantum_habits.exe"; Flags: nowait
