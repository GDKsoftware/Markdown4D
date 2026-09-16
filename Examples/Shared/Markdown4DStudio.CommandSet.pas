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
  // field must be assigned before TPadCommandSet.Register is called.
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

  TPadCommandSet = class
  private
    // Binds one format command value to the shared ExecuteFormat action. Copies
    // the action into a local so the deferred closure never captures the record
    // parameter (which is gone by the time the command runs).
    class procedure RegisterFormat(const Registry: TPadCommandRegistry; const Actions: TPadCommandActions;
      const Name, ShortcutText: string; const Command: TEditorCommand); static;

  public
    // Registers the fixed Markdown4DStudio commands into Registry, wiring each
    // to the matching action.
    class procedure Register(const Registry: TPadCommandRegistry; const Actions: TPadCommandActions); static;
  end;

implementation

uses
  Markdown4DStudio.Defines;

class procedure TPadCommandSet.Register(const Registry: TPadCommandRegistry;
  const Actions: TPadCommandActions);
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

  RegisterFormat(Registry, Actions, CmdBoldName, CmdBoldShortcut, TEditorCommand.Bold);
  RegisterFormat(Registry, Actions, CmdItalicName, CmdItalicShortcut, TEditorCommand.Italic);
  RegisterFormat(Registry, Actions, CmdLinkName, CmdLinkShortcut, TEditorCommand.Link);
  RegisterFormat(Registry, Actions, CmdCodeName, CmdCodeShortcut, TEditorCommand.CodeBlock);
  RegisterFormat(Registry, Actions, CmdH1Name, CmdH1Shortcut, TEditorCommand.Heading1);
  RegisterFormat(Registry, Actions, CmdH2Name, CmdH2Shortcut, TEditorCommand.Heading2);
  RegisterFormat(Registry, Actions, CmdH3Name, CmdH3Shortcut, TEditorCommand.Heading3);
  RegisterFormat(Registry, Actions, CmdBulletName, CmdBulletShortcut, TEditorCommand.BulletList);
  RegisterFormat(Registry, Actions, CmdNumberName, CmdNumberShortcut, TEditorCommand.NumberedList);
  RegisterFormat(Registry, Actions, CmdQuoteName, CmdQuoteShortcut, TEditorCommand.Quote);
  RegisterFormat(Registry, Actions, CmdStrikeName, CmdStrikeShortcut, TEditorCommand.Strikethrough);
  RegisterFormat(Registry, Actions, CmdTableName, CmdTableShortcut, TEditorCommand.Table);
end;

class procedure TPadCommandSet.RegisterFormat(const Registry: TPadCommandRegistry;
  const Actions: TPadCommandActions; const Name, ShortcutText: string; const Command: TEditorCommand);
begin
  const Run: TPadFormatAction = Actions.ExecuteFormat;

  Registry.Register(Name, CatFormat, ShortcutText,
    procedure
    begin
      Run(Command);
    end);
end;

end.
