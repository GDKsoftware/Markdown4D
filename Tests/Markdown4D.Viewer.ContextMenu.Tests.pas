unit Markdown4D.Viewer.ContextMenu.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model,
  Markdown4D.Viewer.ContextMenu;

type
  [TestFixture]
  TMarkdownViewerContextMenuTests = class
  private
    const
      ViewportWidth = 300.0;
      ViewportHeight = 200.0;
      SampleMarkdown = 'alpha beta';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FModel: TMarkdownViewerModel;
    function ItemFor(const Command: TViewerContextCommand): TViewerContextItem;
    procedure SelectFirstWord;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Build_WithoutSelection_DisablesCopy;

    [Test]
    procedure Build_WithSelection_EnablesCopy;

    [Test]
    procedure Build_EmptyDocument_DisablesSelectAll;

    [Test]
    procedure Build_SelectAll_StartsItsOwnGroup;

    [Test]
    procedure Execute_SelectAll_SelectsEverything;

    [Test]
    procedure Execute_Copy_IsLeftToTheHost;

    [Test]
    [TestCase('Copy', 'Copy,67')]
    [TestCase('SelectAll', 'SelectAll,65')]
    procedure Build_Item_ShowsTheCtrlShortcutTheViewerHandles(const Command: TViewerContextCommand;
                                                              const KeyCode: Integer);

    [Test]
    procedure Build_WithSelection_EnablesCopyAsMarkdown;

    [Test]
    procedure Build_CopyAsMarkdown_ShowsCtrlShiftC;

    [Test]
    procedure Build_CopyAsMarkdownSwitchedOff_LeavesTheEntryOut;

    [Test]
    procedure Execute_CopyAsMarkdown_IsLeftToTheHost;
  end;

implementation

uses
  System.Classes,
  Markdown4D.Layout.FakeMeasurer;

procedure TMarkdownViewerContextMenuTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurer);
  FModel.SetViewport(ViewportWidth, ViewportHeight);
  FModel.Text := SampleMarkdown;
end;

procedure TMarkdownViewerContextMenuTests.TearDown;
begin
  FModel.Free;
  FModel := nil;

  FMeasurer := nil;

  FTheme.Free;
  FTheme := nil;
end;

function TMarkdownViewerContextMenuTests.ItemFor(const Command: TViewerContextCommand): TViewerContextItem;
begin
  for var Item in TMarkdownViewerContextMenu.Build(FModel, True) do
  begin
    if Item.Command = Command then
    begin
      Result := Item;
      Exit;
    end;
  end;

  Assert.Fail('Command missing from the context menu');
end;

procedure TMarkdownViewerContextMenuTests.SelectFirstWord;
begin
  FModel.SetSelectionAnchor(TLayoutPointF.Create(1, 10));
  FModel.SetSelectionExtent(TLayoutPointF.Create(48, 10));
end;

procedure TMarkdownViewerContextMenuTests.Build_WithoutSelection_DisablesCopy;
begin
  Assert.IsFalse(ItemFor(TViewerContextCommand.Copy).Enabled);
end;

procedure TMarkdownViewerContextMenuTests.Build_WithSelection_EnablesCopy;
begin
  SelectFirstWord;

  Assert.IsTrue(ItemFor(TViewerContextCommand.Copy).Enabled);
end;

procedure TMarkdownViewerContextMenuTests.Build_EmptyDocument_DisablesSelectAll;
begin
  FModel.Text := '';

  Assert.IsFalse(ItemFor(TViewerContextCommand.SelectAll).Enabled);
end;

procedure TMarkdownViewerContextMenuTests.Build_SelectAll_StartsItsOwnGroup;
begin
  Assert.IsTrue(ItemFor(TViewerContextCommand.SelectAll).Enabled);
  Assert.IsTrue(ItemFor(TViewerContextCommand.SelectAll).StartsGroup);
  Assert.IsFalse(ItemFor(TViewerContextCommand.Copy).StartsGroup);
end;

procedure TMarkdownViewerContextMenuTests.Execute_SelectAll_SelectsEverything;
begin
  Assert.IsTrue(TMarkdownViewerContextMenu.Execute(FModel, TViewerContextCommand.SelectAll));
  Assert.AreEqual(SampleMarkdown, FModel.SelectedText);
end;

procedure TMarkdownViewerContextMenuTests.Build_WithSelection_EnablesCopyAsMarkdown;
begin
  SelectFirstWord;

  Assert.IsTrue(ItemFor(TViewerContextCommand.CopyAsMarkdown).Enabled);
end;

procedure TMarkdownViewerContextMenuTests.Build_CopyAsMarkdown_ShowsCtrlShiftC;
begin
  const Expected = scCtrl or scShift or Ord('C');

  const Actual = ItemFor(TViewerContextCommand.CopyAsMarkdown).ShortCut;

  Assert.AreEqual(Integer(Expected), Integer(Actual));
end;

procedure TMarkdownViewerContextMenuTests.Build_CopyAsMarkdownSwitchedOff_LeavesTheEntryOut;
begin
  const Items = TMarkdownViewerContextMenu.Build(FModel, False);

  for var Item in Items do
  begin
    const IsCopyAsMarkdown = (Item.Command = TViewerContextCommand.CopyAsMarkdown);
    Assert.IsFalse(IsCopyAsMarkdown, 'Copy as Markdown must not be offered when it is switched off');
  end;
end;

procedure TMarkdownViewerContextMenuTests.Execute_CopyAsMarkdown_IsLeftToTheHost;
begin
  SelectFirstWord;

  Assert.IsFalse(TMarkdownViewerContextMenu.Execute(FModel, TViewerContextCommand.CopyAsMarkdown));
  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerContextMenuTests.Execute_Copy_IsLeftToTheHost;
begin
  SelectFirstWord;

  Assert.IsFalse(TMarkdownViewerContextMenu.Execute(FModel, TViewerContextCommand.Copy));
  Assert.AreEqual('alpha', FModel.SelectedText);
end;

procedure TMarkdownViewerContextMenuTests.Build_Item_ShowsTheCtrlShortcutTheViewerHandles(
  const Command: TViewerContextCommand; const KeyCode: Integer);
begin
  const Expected = (scCtrl or KeyCode);

  const Actual = ItemFor(Command).ShortCut;

  Assert.AreEqual(Integer(Expected), Integer(Actual));
end;

end.