unit MarkdownPad.Defines;

// Constants shared verbatim between the VCL (MarkdownPadVCL) and FMX
// (MarkdownPadFMX) builds of the pad. Platform-specific values (colours,
// differing metrics, framework-only chrome) stay in each form unit.

interface

const
  // Icon fonts
  FluentIconFontName = 'Segoe Fluent Icons';
  Mdl2IconFontName = 'Segoe MDL2 Assets';

  // Toolbar glyphs (Segoe Fluent / MDL2 code points)
  GlyphNew = Char($E7C3);
  GlyphOpen = Char($E8E5);
  GlyphSave = Char($E74E);
  GlyphSaveAs = Char($E792);
  GlyphRecent = Char($E81C);
  GlyphExport = Char($E896);
  GlyphCopyHtml = Char($E8C8);
  GlyphBold = Char($E8DD);
  GlyphItalic = Char($E8DB);
  GlyphLink = Char($E71B);
  GlyphCode = Char($E943);
  GlyphTheme = Char($E793);
  GlyphToc = Char($E8FD);
  GlyphFind = Char($E721);

  // Toolbar hints
  HintNew = 'New (Ctrl+N)';
  HintOpen = 'Open (Ctrl+O)';
  HintSave = 'Save (Ctrl+S)';
  HintSaveAs = 'Save As (Ctrl+Shift+S)';
  HintRecent = 'Recent files';
  HintExport = 'Export HTML (Ctrl+Shift+E)';
  HintCopyHtml = 'Copy HTML (Ctrl+Shift+C)';
  HintBold = 'Bold (Ctrl+B)';
  HintItalic = 'Italic (Ctrl+I)';
  HintLink = 'Link (Ctrl+K)';
  HintCode = 'Code block';
  HintTheme = 'Toggle theme';
  HintToc = 'Toggle contents';
  HintFind = 'Find in preview';

  // Layout metrics identical to both frameworks
  InitialClientHeight = 760;
  TitleBarHeight = 40;
  TitleBarLeftInset = 8;
  IconButtonSize = 32;
  SeparatorWidth = 1;
  FindEditWidth = 160;
  TocPanelWidth = 240;
  TickIntervalMilliseconds = 100;
  FindBarHeight = 32;
  FindBarEditWidth = 240;
  PaletteWidth = 560;
  PaletteTop = 80;
  PaletteRowHeight = 22;
  PaletteVisibleRows = 10;
  ZenMaxTextWidth = 820;

  // Captions, filters and format strings
  TocHeaderCaption = 'Contents';
  FindButtonCaption = 'Find';
  MarkdownFilter = 'Markdown files (*.md)|*.md|All files (*.*)|*.*';
  DefaultExtension = 'md';
  ModifiedMarker = ' *';
  StatusPositionFormat = 'Ln %d, Col %d';
  StatusWordsFormat = '%d words';
  TitleFormat = '%s - %s';
  UntitledName = 'Untitled';
  RecentNoneCaption = '(none)';
  CloseDocumentPromptFormat = 'Save changes to %s before closing?';
  MatchCountFormat = '%d matches';
  SingleMatchCaption = '1 match';
  NoMatchCaption = 'No matches';
  EmptyFindCaption = '';
  FindHintCaption = 'Find in editor';
  PaletteHintCaption = 'Type a command';
  ExportButtonCaption = 'Export';
  CopyHtmlButtonCaption = 'Copy HTML';
  HtmlFilter = 'HTML files (*.html)|*.html|All files (*.*)|*.*';
  HtmlExtension = 'html';

  // Command palette entries: display name + shortcut label
  CmdNewName = 'New tab';
  CmdNewShortcut = 'Ctrl+N';
  CmdOpenName = 'Open...';
  CmdOpenShortcut = 'Ctrl+O';
  CmdSaveName = 'Save';
  CmdSaveShortcut = 'Ctrl+S';
  CmdSaveAsName = 'Save As...';
  CmdSaveAsShortcut = 'Ctrl+Shift+S';
  CmdCloseName = 'Close tab';
  CmdCloseShortcut = 'Ctrl+W';
  CmdNextTabName = 'Next tab';
  CmdNextTabShortcut = 'Ctrl+Tab';
  CmdThemeName = 'Toggle theme';
  CmdThemeShortcut = '';
  CmdTocName = 'Toggle contents';
  CmdTocShortcut = '';
  CmdViewEditorName = 'Editor only';
  CmdViewEditorShortcut = 'Ctrl+1';
  CmdViewSplitName = 'Split view';
  CmdViewSplitShortcut = 'Ctrl+2';
  CmdViewPreviewName = 'Preview only';
  CmdViewPreviewShortcut = 'Ctrl+3';
  CmdZenName = 'Zen mode';
  CmdZenShortcut = 'F11';
  CmdFindName = 'Find in editor';
  CmdFindShortcut = 'Ctrl+F';
  CmdFindPreviewName = 'Find in preview';
  CmdFindPreviewShortcut = '';
  CmdBoldName = 'Bold';
  CmdBoldShortcut = 'Ctrl+B';
  CmdItalicName = 'Italic';
  CmdItalicShortcut = 'Ctrl+I';
  CmdLinkName = 'Link';
  CmdLinkShortcut = '';
  CmdCodeName = 'Code block';
  CmdCodeShortcut = '';
  CmdH1Name = 'Heading 1';
  CmdH1Shortcut = 'Ctrl+Shift+1';
  CmdH2Name = 'Heading 2';
  CmdH2Shortcut = 'Ctrl+Shift+2';
  CmdH3Name = 'Heading 3';
  CmdH3Shortcut = 'Ctrl+Shift+3';
  CmdBulletName = 'Bullet list';
  CmdBulletShortcut = 'Ctrl+Shift+U';
  CmdNumberName = 'Numbered list';
  CmdNumberShortcut = 'Ctrl+Shift+O';
  CmdQuoteName = 'Quote';
  CmdQuoteShortcut = 'Ctrl+Shift+Q';
  CmdStrikeName = 'Strikethrough';
  CmdStrikeShortcut = 'Ctrl+Shift+X';
  CmdTableName = 'Insert table';
  CmdTableShortcut = 'Ctrl+Shift+T';
  CmdExportName = 'Export HTML...';
  CmdExportShortcut = 'Ctrl+Shift+E';
  CmdCopyHtmlName = 'Copy HTML';
  CmdCopyHtmlShortcut = 'Ctrl+Shift+C';

  // Command palette categories
  CatFile = 'File';
  CatView = 'View';
  CatEdit = 'Edit';
  CatFormat = 'Format';
  CatRecent = 'Recent';

implementation

end.
