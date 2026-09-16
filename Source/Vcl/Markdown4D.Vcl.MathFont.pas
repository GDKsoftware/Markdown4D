unit Markdown4D.Vcl.MathFont;

{$SCOPEDENUMS ON}

// Using this unit installs the bundled STIX Two Math font for the process,
// privately and without touching the system font folder, so formulas render
// the same on every machine. Leave it out to fall back to Cambria Math,
// the math font Windows ships with.

interface

implementation

uses
  Winapi.Windows,
  System.Classes,
  Markdown4D.Math.Font;

{$R '..\Fonts\STIXTwoMath.res'}

const
  ResourceName = 'STIXTWOMATH';

function InstallBundledMathFont: string;
begin
  const Stream = TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    var FontCount: DWORD := 0;
    const Handle = AddFontMemResourceEx(Stream.Memory, Stream.Size, nil, @FontCount);

    const Installed = (Handle <> 0);
    Result := '';
    if Installed then
      Result := TMarkdownMathFont.BundledFamilyName;
  finally
    Stream.Free;
  end;
end;

initialization
  TMarkdownMathFont.RegisterInstaller(InstallBundledMathFont);

end.
