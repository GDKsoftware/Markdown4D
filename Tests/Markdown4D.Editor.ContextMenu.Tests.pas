unit Markdown4D.Editor.ContextMenu.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.ContextMenu;

type
  [TestFixture]
  TMarkdownEditorContextMenuTests = class
  private
    const
      SampleText = 'Hello world';
    var
      FModel: TMarkdownEditorModel;
    function ItemFor(const Command: TEditorContextCommand;
      const ClipboardHasText: Boolean): TEditorContextItem;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Build_WithoutSelection_DisablesCutCopyAndDelete;

    [Test]
    procedure Build_WithSelection_EnablesCutCopyAndDelete;

    [Test]
    procedure Build_EmptyClipboard_DisablesPaste;

    [Test]
    procedure Build_FreshDocument_DisablesUndoAndRedo;

    [Test]
    procedure Build_AfterEdit_EnablesUndo;

    [Test]
    procedure Build_EmptyDocument_DisablesSelectAll;

    [Test]
    procedure Execute_SelectAll_SelectsEverything;

    [Test]
    procedure Execute_Delete_RemovesSelection;

    [Test]
    procedure Execute_ClipboardCommand_IsLeftToTheHost;
  end;

implementation

procedure TMarkdownEditorContextMenuTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
  FModel.LoadText(SampleText);
end;

procedure TMarkdownEditorContextMenuTests.TearDown;
begin
  FModel.Free;
end;

function TMarkdownEditorContextMenuTests.ItemFor(const Command: TEditorContextCommand;
  const ClipboardHasText: Boolean): TEditorContextItem;
begin
  for var Item in TMarkdownEditorContextMenu.Build(FModel, ClipboardHasText) do
  begin
    if Item.Command = Command then
      Exit(Item);
  end;

  Assert.Fail('Command missing from the context menu');
end;

procedure TMarkdownEditorContextMenuTests.Build_WithoutSelection_DisablesCutCopyAndDelete;
begin
  Assert.IsFalse(ItemFor(TEditorContextCommand.Cut, True).Enabled);
  Assert.IsFalse(ItemFor(TEditorContextCommand.Copy, True).Enabled);
  Assert.IsFalse(ItemFor(TEditorContextCommand.DeleteSelection, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Build_WithSelection_EnablesCutCopyAndDelete;
begin
  FModel.SetSelection(0, 5);

  Assert.IsTrue(ItemFor(TEditorContextCommand.Cut, True).Enabled);
  Assert.IsTrue(ItemFor(TEditorContextCommand.Copy, True).Enabled);
  Assert.IsTrue(ItemFor(TEditorContextCommand.DeleteSelection, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Build_EmptyClipboard_DisablesPaste;
begin
  Assert.IsFalse(ItemFor(TEditorContextCommand.Paste, False).Enabled);
  Assert.IsTrue(ItemFor(TEditorContextCommand.Paste, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Build_FreshDocument_DisablesUndoAndRedo;
begin
  Assert.IsFalse(ItemFor(TEditorContextCommand.Undo, True).Enabled);
  Assert.IsFalse(ItemFor(TEditorContextCommand.Redo, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Build_AfterEdit_EnablesUndo;
begin
  FModel.CaretPosition := 0;
  FModel.Insert('X');

  Assert.IsTrue(ItemFor(TEditorContextCommand.Undo, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Build_EmptyDocument_DisablesSelectAll;
begin
  FModel.LoadText('');

  Assert.IsFalse(ItemFor(TEditorContextCommand.SelectAll, True).Enabled);
end;

procedure TMarkdownEditorContextMenuTests.Execute_SelectAll_SelectsEverything;
begin
  Assert.IsTrue(TMarkdownEditorContextMenu.Execute(FModel, TEditorContextCommand.SelectAll));
  Assert.AreEqual(SampleText, FModel.SelectedText);
end;

procedure TMarkdownEditorContextMenuTests.Execute_Delete_RemovesSelection;
begin
  FModel.SetSelection(0, 6);

  Assert.IsTrue(TMarkdownEditorContextMenu.Execute(FModel, TEditorContextCommand.DeleteSelection));
  Assert.AreEqual('world', FModel.Text);
end;

procedure TMarkdownEditorContextMenuTests.Execute_ClipboardCommand_IsLeftToTheHost;
begin
  Assert.IsFalse(TMarkdownEditorContextMenu.Execute(FModel, TEditorContextCommand.Copy));
  Assert.IsFalse(TMarkdownEditorContextMenu.Execute(FModel, TEditorContextCommand.Cut));
  Assert.IsFalse(TMarkdownEditorContextMenu.Execute(FModel, TEditorContextCommand.Paste));
end;

end.
