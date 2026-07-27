unit MarkdownPadFMX.Defines;

// FMX-specific constants for the Markdown4D Pad demo. Values that are shared
// verbatim with the VCL build live in MarkdownPad.Defines; only FMX-specific
// values (window chrome, custom title bar/tooltip, TAlphaColor palette,
// per-build strings) stay here.

interface

uses
  System.UITypes,
  MarkdownPad.Defines;

const
  WindowCaption = 'Markdown4D Pad (FMX)';
  InitialClientWidth = 1180;
  ToolbarHeight = 38;
  TabControlHeight = 32;
  CaptionButtonWidth = 46;
  StatusBarHeight = 26;
  ControlMargin = 6;
  IconGlyphSize = 16;
  TocHeaderHeight = 22;
  SplitterWidth = 6;
  StatusLabelWidth = 150;
  GlyphMinimize = Char($E921);
  GlyphMaximize = Char($E922);
  GlyphRestore = Char($E923);
  GlyphClose = Char($E8BB);
  HintMinimize = 'Minimize';
  HintMaximize = 'Maximize';
  HintCloseWindow = 'Close';
  ToolbarLightColor = TAlphaColor($FFF3F3F3);
  ToolbarDarkColor = TAlphaColor($FF2D2D2D);
  IconLightColor = TAlphaColor($FF404040);
  IconDarkColor = TAlphaColor($FFD6D6D6);
  SeparatorLightColor = TAlphaColor($FFD0D0D0);
  SeparatorDarkColor = TAlphaColor($FF505050);
  HoverLightColor = TAlphaColor($FFE0E0E0);
  HoverDarkColor = TAlphaColor($FF3E3E3E);
  TabActiveLightColor = TAlphaColor($FFFFFFFF);
  TabActiveDarkColor = TAlphaColor($FF3F3F3F);
  TabHoverLightColor = TAlphaColor($FFEAEAEA);
  TabHoverDarkColor = TAlphaColor($FF383838);
  CaptionCloseHoverColor = TAlphaColor($FFE81123);
  HintBackColor = TAlphaColor($FF1E1E1E);
  HintTextColor = TAlphaColor($FFF0F0F0);
  HintHeight = 24;
  HintHorizontalPadding = 8;
  HintGap = 4;
  HintCornerRadius = 4;
  MarkdownExtension = '.md';
  SessionFileName = 'MarkdownPad.Fmx.json';
  OpenErrorFormat = 'Could not open the file:'#10'%s';
  CloseUnsavedPrompt = 'This document has unsaved changes. Save before closing?';
  ReplaceButtonWidth = 90;
  ReplaceAllButtonWidth = 110;
  PaletteListHeight = PaletteRowHeight * PaletteVisibleRows;
  PaletteEditHeight = 30;
  PaletteShortcutWidth = 120;
  PaletteShortcutOpacity = 0.6;

implementation

end.
