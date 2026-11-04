#define AppName "Wholesale Manager Owner"
#define AppVersion "1.0.0"
#define ReleaseDir AddBackslash(SourcePath) + "..\build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + "..\build\installer\vc_redist.x64.exe"

[Setup]
AppId={{A8D9A886-25A1-4B57-B41A-9F9F78B6CB91}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\Wholesale Manager Owner
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\owner_desktop.exe
OutputBaseFilename=owner-desktop-Setup
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
DisableProgramGroupPage=yes
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VCRedistPath}"; DestDir: "{tmp}"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\owner_desktop.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\owner_desktop.exe"

[Code]
function IsRequiredVCRedistInstalled: Boolean;
var
  Installed, Major, Minor: Cardinal;
begin
  Result :=
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed) and
    (Installed = 1) and
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Major', Major) and
    RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Minor', Minor) and
    ((Major > 14) or ((Major = 14) and (Minor >= 20)));
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  if IsRequiredVCRedistInstalled then
    Exit;

  ExtractTemporaryFile('vc_redist.x64.exe');
  if not Exec(
    ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  ) then
  begin
    Result := 'The Microsoft Visual C++ x64 Redistributable could not be started. ' +
      'Close other installers and choose Retry, or cancel setup.';
    Exit;
  end;

  if (ResultCode = 3010) or (ResultCode = 1641) then
  begin
    NeedsRestart := True;
    Exit;
  end;

  if IsRequiredVCRedistInstalled then
    Exit;

  if ResultCode = 0 then
    Result := 'The Microsoft Visual C++ x64 Redistributable reported success, ' +
      'but its required runtime was not detected. Close other installers and ' +
      'choose Retry, or cancel setup.'
  else
    Result := Format(
      'The Microsoft Visual C++ x64 Redistributable installation failed (code %d). ' +
        'Close other installers and choose Retry, or cancel setup.',
      [ResultCode]
    );
end;
