unit Markdown4D.Math.Font;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  // Installs a font for the process and returns its family name, or an
  // empty string when nothing was installed.
  TMarkdownMathFontInstaller = reference to function: string;

  // Where the formula font comes from. The theme names the generic family
  // "math"; each painter resolves that through here. A framework loader
  // (Markdown4D.Vcl.MathFont, Markdown4D.Fmx.MathFont) registers an installer
  // for the font it bundles. The installer runs when the first viewer is
  // created rather than at unit initialization, because FMX's font service
  // does not exist yet while units initialize.
  TMarkdownMathFont = class
  private
    class var
      FRegisteredFamily: string;
      FInstaller: TMarkdownMathFontInstaller;
      FInstallAttempted: Boolean;
    class procedure RunInstallerOnce;

  public
    const
      BundledFamilyName = 'STIX Two Math';
      // The math font the platform ships with: Cambria Math comes with
      // Windows, STIX Two Math with macOS 13 and later. The other platforms
      // have none, so the name only steers font substitution there.
      SystemFamilyName = {$IFDEF MACOS}'STIX Two Math'{$ELSE}'Cambria Math'{$ENDIF};
    class procedure RegisterInstaller(const Installer: TMarkdownMathFontInstaller);
    // Runs the registered installer once. The viewers call this when they are
    // created, on the main thread and outside any measuring or painting,
    // which is where a font service is safe to change.
    class procedure EnsureInstalled;
    class procedure RegisterFamily(const FamilyName: string);
    class function IsRegistered: Boolean;
    // The family a painter should ask its platform for: the registered one
    // when a loader installed a font, otherwise the math font the platform ships with.
    class function ResolvedFamily: string;
    class procedure Clear;
  end;

implementation

class procedure TMarkdownMathFont.RegisterInstaller(const Installer: TMarkdownMathFontInstaller);
begin
  FInstaller := Installer;
  FInstallAttempted := False;
end;

class procedure TMarkdownMathFont.EnsureInstalled;
begin
  RunInstallerOnce;
end;

class procedure TMarkdownMathFont.RegisterFamily(const FamilyName: string);
begin
  FRegisteredFamily := FamilyName;
end;

class function TMarkdownMathFont.IsRegistered: Boolean;
begin
  Result := (FRegisteredFamily <> '');
end;

class function TMarkdownMathFont.ResolvedFamily: string;
begin
  RunInstallerOnce;

  if IsRegistered then
  begin
    Result := FRegisteredFamily;
    Exit;
  end;

  Result := SystemFamilyName;
end;

class procedure TMarkdownMathFont.RunInstallerOnce;
begin
  const ShouldInstall = (not IsRegistered) and Assigned(FInstaller) and (not FInstallAttempted);
  if not ShouldInstall then
    Exit;

  FInstallAttempted := True;
  FRegisteredFamily := FInstaller();
end;

class procedure TMarkdownMathFont.Clear;
begin
  FRegisteredFamily := '';
  FInstaller := nil;
  FInstallAttempted := False;
end;

end.
