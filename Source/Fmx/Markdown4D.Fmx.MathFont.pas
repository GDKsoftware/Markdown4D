unit Markdown4D.Fmx.MathFont;

{$SCOPEDENUMS ON}

// Using this unit installs the bundled STIX Two Math font through the FMX
// font manager, so formulas render the same on every platform. Leave it out
// to fall back to the math font the platform ships with.
//
// The FMX font manager has a native service on Windows and macOS. On the
// other platforms the installation only succeeds when Skia is enabled
// (GlobalUseSkia), because the Skia font manager registers the typeface
// itself; without Skia the call reports failure and formulas fall back.

interface

implementation

uses
  System.Types,
  System.Classes,
  FMX.FontManager,
  Markdown4D.Math.Font;

{$R '..\Fonts\STIXTwoMath.res'}

const
  ResourceName = 'STIXTWOMATH';

// Runs when the first viewer or editor is created, when the platform's font
// service is up; the FMX service is not there yet while units initialize.
// On Windows the FMX font manager ends with a synchronous WM_FONTCHANGE
// broadcast, which waits for every top-level window on the desktop.
function InstallBundledMathFont: string;
begin
  const Stream = TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
  try
    const Installed = TFontManager.AddCustomFontFromStream(Stream);
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
