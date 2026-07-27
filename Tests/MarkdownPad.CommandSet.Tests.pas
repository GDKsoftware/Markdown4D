unit MarkdownPad.CommandSet.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  MarkdownPad.Commands,
  MarkdownPad.CommandSet;

type
  [TestFixture]
  TPadCommandSetTests = class
  private
    var
      FRegistry: TPadCommandRegistry;
      FFired: string;
      FLastFormat: TEditorCommand;
    function BuildActions: TPadCommandActions;
    procedure Invoke(const CommandName: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Register_AddsEveryCommand;

    [Test]
    procedure NewCommand_InvokesNewDocument;

    [Test]
    procedure BoldCommand_InvokesFormatWithBold;

    [Test]
    procedure TableCommand_InvokesFormatWithTable;

    [Test]
    procedure EveryCommand_HasNameAndCategory;

    [Test]
    procedure EditingCommands_AreDiscoverableFromThePalette;

    [Test]
    procedure UndoCommand_InvokesUndo;

    [Test]
    procedure IndentCommand_InvokesIndent;
  end;

implementation

uses
  MarkdownPad.Defines;

procedure TPadCommandSetTests.Setup;
begin
  FRegistry := TPadCommandRegistry.Create;
  FFired := '';
end;

procedure TPadCommandSetTests.TearDown;
begin
  FRegistry.Free;
end;

function TPadCommandSetTests.BuildActions: TPadCommandActions;
begin
  Result.NewDocument := procedure begin FFired := 'New'; end;
  Result.OpenDocument := procedure begin FFired := 'Open'; end;
  Result.Save := procedure begin FFired := 'Save'; end;
  Result.SaveAs := procedure begin FFired := 'SaveAs'; end;
  Result.CloseDocument := procedure begin FFired := 'Close'; end;
  Result.NextTab := procedure begin FFired := 'NextTab'; end;
  Result.ExportHtml := procedure begin FFired := 'Export'; end;
  Result.CopyHtml := procedure begin FFired := 'CopyHtml'; end;
  Result.ViewEditorOnly := procedure begin FFired := 'ViewEditor'; end;
  Result.ViewSplit := procedure begin FFired := 'ViewSplit'; end;
  Result.ViewPreviewOnly := procedure begin FFired := 'ViewPreview'; end;
  Result.ToggleZen := procedure begin FFired := 'Zen'; end;
  Result.ToggleTheme := procedure begin FFired := 'Theme'; end;
  Result.ToggleToc := procedure begin FFired := 'Toc'; end;
  Result.ShowFind := procedure begin FFired := 'Find'; end;
  Result.ShowReplace := procedure begin FFired := 'Replace'; end;
  Result.FindInPreview := procedure begin FFired := 'FindPreview'; end;
  Result.Undo := procedure begin FFired := 'Undo'; end;
  Result.Redo := procedure begin FFired := 'Redo'; end;
  Result.SelectAll := procedure begin FFired := 'SelectAll'; end;
  Result.Indent := procedure begin FFired := 'Indent'; end;
  Result.Outdent := procedure begin FFired := 'Outdent'; end;
  Result.DeleteWordLeft := procedure begin FFired := 'DeleteWord'; end;
  Result.ExecuteFormat :=
    procedure(const Command: TEditorCommand)
    begin
      FFired := 'Format';
      FLastFormat := Command;
    end;
end;

procedure TPadCommandSetTests.Invoke(const CommandName: string);
begin
  for var Command in FRegistry.Commands do
    if Command.Name = CommandName then
    begin
      Command.Action();
      Exit;
    end;

  Assert.Fail('Command not registered: ' + CommandName);
end;

procedure TPadCommandSetTests.Register_AddsEveryCommand;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Assert.AreEqual(35, FRegistry.Count);
end;

procedure TPadCommandSetTests.NewCommand_InvokesNewDocument;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Invoke(CmdNewName);
  Assert.AreEqual('New', FFired);
end;

procedure TPadCommandSetTests.BoldCommand_InvokesFormatWithBold;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Invoke(CmdBoldName);
  Assert.AreEqual('Format', FFired);
  Assert.IsTrue(FLastFormat = TEditorCommand.Bold, 'bold not bound');
end;

procedure TPadCommandSetTests.TableCommand_InvokesFormatWithTable;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Invoke(CmdTableName);
  Assert.AreEqual('Format', FFired);
  Assert.IsTrue(FLastFormat = TEditorCommand.Table, 'table not bound');
end;

procedure TPadCommandSetTests.EditingCommands_AreDiscoverableFromThePalette;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);

  // Anything that is only reachable through a keystroke would be invisible, so
  // the palette carries every editing command with its shortcut spelled out.
  for var Name in [CmdUndoName, CmdRedoName, CmdSelectAllName, CmdIndentName, CmdOutdentName,
    CmdDeleteWordName, CmdReplaceName, CmdZenName] do
  begin
    var Found := False;

    for var Command in FRegistry.Commands do
    begin
      if Command.Name <> Name then
        Continue;

      Found := True;
      Assert.IsTrue(Command.ShortcutText <> '', 'no shortcut shown for ' + Name);
    end;

    Assert.IsTrue(Found, 'command missing from the palette: ' + Name);
  end;
end;

procedure TPadCommandSetTests.UndoCommand_InvokesUndo;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Invoke(CmdUndoName);
  Assert.AreEqual('Undo', FFired);
end;

procedure TPadCommandSetTests.IndentCommand_InvokesIndent;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  Invoke(CmdIndentName);
  Assert.AreEqual('Indent', FFired);
end;

procedure TPadCommandSetTests.EveryCommand_HasNameAndCategory;
begin
  RegisterStaticPadCommands(FRegistry, BuildActions);
  for var Command in FRegistry.Commands do
  begin
    Assert.IsTrue(Command.Name <> '', 'empty command name');
    Assert.IsTrue(Command.Category <> '', 'empty category for ' + Command.Name);
  end;
end;

end.
