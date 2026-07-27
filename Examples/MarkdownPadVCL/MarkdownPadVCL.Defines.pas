unit MarkdownPadVCL.Defines;

// VCL-specific constants for the Markdown4D Pad demo. Values that are shared
// verbatim with the FMX build live in MarkdownPad.Defines; only VCL-specific
// values (custom title bar, DWM caption, TColor palette, per-build strings)
// stay here.

interface

uses
  System.UITypes;

const
  WindowCaption = 'Markdown4D Pad';
  InitialClientWidth = 1200;
  ToolbarHeight = 36;
  TabsHeight = 30;
  CaptionButtonsReserve = 160;
  DwmCaptionColorAttribute = 35;
  StatusBarHeight = 22;
  StatusLabelWidth = 160;
  StatusLabelLeftMargin = 8;
  ButtonSpacing = 4;
  IconGlyphSize = 14;
  ToolbarLightColor = TColor($00F3F3F3);
  ToolbarDarkColor = TColor($002D2D2D);
  IconLightColor = TColor($00404040);
  IconDarkColor = TColor($00D6D6D6);
  SeparatorLightColor = TColor($00D0D0D0);
  SeparatorDarkColor = TColor($00505050);
  TabAccentColor = TColor($00C0742C);
  TabActiveDarkColor = TColor($003F3F3F);
  TabHoverLightColor = TColor($00EAEAEA);
  TabHoverDarkColor = TColor($00383838);
  ZenPadDarkColor = TColor($0017110D); // matches the dark theme editor/preview background ($0D1117)
  SessionFileName = 'MarkdownPad.Vcl.json';
  CloseUnsavedPrompt = 'Save changes before closing this document?';
  PaletteTextMargin = 8;
  ReplaceButtonWidth = 90;
  ReplaceAllButtonWidth = 110;

implementation

end.
