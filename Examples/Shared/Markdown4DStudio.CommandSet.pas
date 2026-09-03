unit Markdown4DStudio.CommandSet;

{$SCOPEDENUMS ON}

// Framework-neutral registration of the Markdown4DStudio command palette. The
// command names, categories, shortcuts and registration order live here once;
// each form only supplies the action bodies (which call its own editor and
// form methods) through TPadCommandActions.

interface

uses
  Markdown4D.Editor.Model,
  Markdown4DStudio.Commands;

type
  TPadFormatAction = reference to procedure(const Command: TEditorCommand);

  // Action bodies the host form plugs into the shared registration. Every
  // field must be assigned before RegisterStaticPadCommands is called.
  TPadCommandActions = record
    NewDocument: TPadCommandAction;
    OpenDocument: TPadCommandAction;
    Save: TPadCommandAction;
    SaveAs: TPadCommandAction;
    CloseDocument: TPadCommandAction;
    NextTab: TPadCommandAction;
    ExportHtml: TPadCommandAction;
    CopyHtml: TPadCommandAction;
    ViewEditorOnly: TPadCommandAction;
    ViewSplit: TPadCommandAction;
    ViewPreviewOnly: TPadCommandAction;
    ToggleZen: TPadCommandAction;
    ToggleTheme: TPadCommandAction;
    ToggleToc: TPadCommandAction;
    ShowFind: TPadCommandAction;
    ShowReplace: TPadCommandAction;
    FindInPreview: TPadCommandAction;
    Undo: TPadCommandAction;
    Redo: TPadCommandAction;
    SelectAll: TPadCommandAction;
    Indent: TPadCommandAction;
    Outdent: TPadCommandAction;
    DeleteWordLeft: TPadCommandAction;
    ExecuteFormat: TPadFormatAction;
  end;

// Registers the fixed Markdown4DStudio commands into Registry, wiring each to the
// matching action.
procedure RegisterStaticPadCommands(const Registry: TPadCommandRegistry;
  const Actions: TPadCommandActions);

implementation

uses
  Markdown4DStudio.Defines;

procedure RegisterStaticPadCommands(const Registry: TPadCommandRegistry;
  const Actions: TPadCommandActions);

  // Binds one format command value to the shared ExecuteFormat action. Copies
  // the action into a local so the deferred closure never captures the record
  // parameter (which is gone by the time the command runs).
  procedure RegisterFormat(const Name, ShortcutText: string; const Command: TEditorCommand);
  var
    Run: TPadFormatAction;
  begin
    Run := Actions.ExecuteFormat;
    Registry.Register(Name, CatFormat, ShortcutText,
      procedure
      begin
        Run(Command);
      end);
  end;

begin
  Registry.Register(CmdNewName, CatFile, CmdNewShortcut, Actions.NewDocument);
  Registry.Register(CmdOpenName, CatFile, CmdOpenShortcut, Actions.OpenDocument);
  Registry.Register(CmdSaveName, CatFile, CmdSaveShortcut, Actions.Save);
  Registry.Register(CmdSaveAsName, CatFile, CmdSaveAsShortcut, Actions.SaveAs);
  Registry.Register(CmdCloseName, CatFile, CmdCloseShortcut, Actions.CloseDocument);
  Registry.Register(CmdNextTabName, CatFile, CmdNextTabShortcut, Actions.NextTab);
  Registry.Register(CmdExportName, CatFile, CmdExportShortcut, Actions.ExportHtml);
  Registry.Register(CmdCopyHtmlName, CatFile, CmdCopyHtmlShortcut, Actions.CopyHtml);

  Registry.Register(CmdViewEditorName, CatView, CmdViewEditorShortcut, Actions.ViewEditorOnly);
  Registry.Register(CmdViewSplitName, CatView, CmdViewSplitShortcut, Actions.ViewSplit);
  Registry.Register(CmdViewPreviewName, CatView, CmdViewPreviewShortcut, Actions.ViewPreviewOnly);
  Registry.Register(CmdZenName, CatView, CmdZenShortcut, Actions.ToggleZen);
  Registry.Register(CmdThemeName, CatView, CmdThemeShortcut, Actions.ToggleTheme);
  Registry.Register(CmdTocName, CatView, CmdTocShortcut, Actions.ToggleToc);

  Registry.Register(CmdFindName, CatEdit, CmdFindShortcut, Actions.ShowFind);
  Registry.Register(CmdReplaceName, CatEdit, CmdReplaceShortcut, Actions.ShowReplace);
  Registry.Register(CmdFindPreviewName, CatEdit, CmdFindPreviewShortcut, Actions.FindInPreview);
  Registry.Register(CmdUndoName, CatEdit, CmdUndoShortcut, Actions.Undo);
  Registry.Register(CmdRedoName, CatEdit, CmdRedoShortcut, Actions.Redo);
  Registry.Register(CmdSelectAllName, CatEdit, CmdSelectAllShortcut, Actions.SelectAll);
  Registry.Register(CmdIndentName, CatEdit, CmdIndentShortcut, Actions.Indent);
  Registry.Register(CmdOutdentName, CatEdit, CmdOutdentShortcut, Actions.Outdent);
  Registry.Register(CmdDeleteWordName, CatEdit, CmdDeleteWordShortcut, Actions.DeleteWordLeft);

  RegisterFormat(CmdBoldName, CmdBoldShortcut, TEditorCommand.Bold);
  RegisterFormat(CmdItalicName, CmdItalicShortcut, TEditorCommand.Italic);
  RegisterFormat(CmdLinkName, CmdLinkShortcut, TEditorCommand.Link);
  RegisterFormat(CmdCodeName, CmdCodeShortcut, TEditorCommand.CodeBlock);
  RegisterFormat(CmdH1Name, CmdH1Shortcut, TEditorCommand.Heading1);
  RegisterFormat(CmdH2Name, CmdH2Shortcut, TEditorCommand.Heading2);
  RegisterFormat(CmdH3Name, CmdH3Shortcut, TEditorCommand.Heading3);
  RegisterFormat(CmdBulletName, CmdBulletShortcut, TEditorCommand.BulletList);
  RegisterFormat(CmdNumberName, CmdNumberShortcut, TEditorCommand.NumberedList);
  RegisterFormat(CmdQuoteName, CmdQuoteShortcut, TEditorCommand.Quote);
  RegisterFormat(CmdStrikeName, CmdStrikeShortcut, TEditorCommand.Strikethrough);
  RegisterFormat(CmdTableName, CmdTableShortcut, TEditorCommand.Table);
end;

end.
