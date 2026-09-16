unit Markdown4D.Editor.Rows.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Rows;

type
  [TestFixture]
  TMarkdownEditorRowsTests = class
  private
    const
      CharWidth = 10.0;
    var
      FModel: TMarkdownEditorModel;
      FRows: TMarkdownEditorRows;
    class function MeasureText(const Text: string): Single; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Rebuild_ShortLine_ProducesSingleRow;

    [Test]
    procedure Rebuild_LineWithoutSpaces_WrapsAtFixedWidth;

    [Test]
    procedure IndexOfOffset_OffsetAtWrapBoundary_ReturnsNextRow;

    [Test]
    procedure LineTextAt_SecondLine_ReturnsThatLineOnly;
  end;

implementation

class function TMarkdownEditorRowsTests.MeasureText(const Text: string): Single;
begin
  Result := Length(Text) * CharWidth;
end;

procedure TMarkdownEditorRowsTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
  FRows := TMarkdownEditorRows.Create(FModel, MeasureText);
end;

procedure TMarkdownEditorRowsTests.TearDown;
begin
  FRows.Free;
  FModel.Free;
end;

procedure TMarkdownEditorRowsTests.Rebuild_ShortLine_ProducesSingleRow;
begin
  FModel.LoadText('hello');
  FRows.Rebuild(1000);

  Assert.AreEqual(1, FRows.Count);
  Assert.AreEqual('hello', FRows.TextOf(FRows.Items[0]));
end;

procedure TMarkdownEditorRowsTests.Rebuild_LineWithoutSpaces_WrapsAtFixedWidth;
begin
  FModel.LoadText('abcdefghij');
  FRows.Rebuild(55);

  Assert.AreEqual(2, FRows.Count);
  Assert.AreEqual('abcde', FRows.TextOf(FRows.Items[0]));
  Assert.AreEqual('fghij', FRows.TextOf(FRows.Items[1]));
end;

procedure TMarkdownEditorRowsTests.IndexOfOffset_OffsetAtWrapBoundary_ReturnsNextRow;
begin
  FModel.LoadText('abcdefghij');
  FRows.Rebuild(55);

  Assert.AreEqual(0, FRows.IndexOfOffset(2));
  Assert.AreEqual(1, FRows.IndexOfOffset(5));
end;

procedure TMarkdownEditorRowsTests.LineTextAt_SecondLine_ReturnsThatLineOnly;
begin
  FModel.LoadText('first'#10'second line');
  FRows.Rebuild(1000);

  Assert.AreEqual('second line', FRows.LineTextAt(1));
end;

end.
