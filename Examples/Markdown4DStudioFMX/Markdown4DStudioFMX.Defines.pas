unit Markdown4DStudioFMX.Defines;

// FMX-specific constants for the Markdown4D Studio demo. Values that are shared
// verbatim with the VCL build live in Markdown4DStudio.Defines; only FMX-specific
// values (window chrome, custom title bar/tooltip, TAlphaColor palette,
// per-build strings) stay here.

interface

uses
  System.UITypes,
  Markdown4DStudio.Defines;

const
  WindowCaption = 'Markdown4D Studio (FMX)';
  InitialClientWidth = 1180;
  ToolbarHeight = 38;
  CaptionButtonWidth = 46;
  StatusBarHeight = 26;
  ControlMargin = 6;
  IconGlyphSize = 16;
  SplitterWidth = 6;
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
  // A pressed toolbar button sits one step beyond hover, so the active view mode
  // stays readable while the pointer rests on one of its neighbours.
  ActiveLightColor = TAlphaColor($FFCBCBCB);
  ActiveDarkColor = TAlphaColor($FF525252);
  InputDarkColor = TAlphaColor($FF3C3C3C);
  // Style name of the rectangle that replaces an edit's bitmap background in the dark theme.
  InputBackingStyleName = 'studioinputbacking';
  TabActiveLightColor = TAlphaColor($FFFFFFFF);
  TabActiveDarkColor = TAlphaColor($FF3F3F3F);
  TabHoverLightColor = TAlphaColor($FFEAEAEA);
  TabHoverDarkColor = TAlphaColor($FF383838);
  CaptionCloseHoverColor = TAlphaColor($FFE81123);
  HintHorizontalPadding = 8;
  HintGap = 4;
  MarkdownExtension = '.md';
  SessionFileName = 'Markdown4DStudio.Fmx.json';
  OpenErrorFormat = 'Could not open the file:'#10'%s';
  CloseUnsavedPrompt = 'This document has unsaved changes. Save before closing?';
  PaletteShortcutWidth = 120;
  PaletteShortcutOpacity = 0.6;

implementation

end.
