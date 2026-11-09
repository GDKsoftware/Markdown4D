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
    class function EdgesOf(const Text: string): TArray<Single>; static;
    class function RowTexts(const Rows: TMarkdownEditorRows): string; static;

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

    [Test]
    [TestCase('Words', 'the quick brown fox jumps over the lazy dog,75')]
    [TestCase('NoSpaces', 'abcdefghijklmnopqrstuvwxyz,55')]
    [TestCase('FitsWhole', 'short line,1000')]
    procedure Rebuild_WithCharacterEdges_WrapsLikeMeasuring(const Line: string; const WrapWidth: Integer);

    [Test]
    procedure Rebuild_WithCharacterEdges_MeasuresEachLineOnce;

    [Test]
    procedure Rebuild_ClusterAcrossWrapWidth_MovesToNextRow;
  end;

implementation

class function TMarkdownEditorRowsTests.MeasureText(const Text: string): Single;
begin
  Result := Length(Text) * CharWidth;
end;

class function TMarkdownEditorRowsTests.EdgesOf(const Text: string): TArray<Single>;
begin
  SetLength(Result, Length(Text));
  for var CharIndex := 0 to High(Result) do
  begin
    Result[CharIndex] := (CharIndex + 1) * CharWidth;
  end;
end;

class function TMarkdownEditorRowsTests.RowTexts(const Rows: TMarkdownEditorRows): string;
begin
  Result := '';
  for var Row in Rows.Items do
  begin
    Result := Result + '|' + Rows.TextOf(Row);
  end;
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

procedure TMarkdownEditorRowsTests.Rebuild_WithCharacterEdges_WrapsLikeMeasuring(const Line: string;
                                                                              const WrapWidth: Integer);
begin
  FModel.LoadText(Line);
  FRows.Rebuild(WrapWidth);
  const EdgeRows = TMarkdownEditorRows.Create(FModel, MeasureText, EdgesOf);
  try
    EdgeRows.Rebuild(WrapWidth);

    Assert.AreEqual(RowTexts(FRows), RowTexts(EdgeRows));
  finally
    EdgeRows.Free;
  end;
end;

procedure TMarkdownEditorRowsTests.Rebuild_WithCharacterEdges_MeasuresEachLineOnce;
begin
  var EdgeCalls := 0;
  var MeasureCalls := 0;
  FModel.LoadText('the quick brown fox jumps over the lazy dog'#10'and runs away again');
  const EdgeRows = TMarkdownEditorRows.Create(FModel,
    function(const Text: string): Single
    begin
      Inc(MeasureCalls);
      Result := MeasureText(Text);
    end,
    function(const Text: string): TArray<Single>
    begin
      Inc(EdgeCalls);
      Result := EdgesOf(Text);
    end);
  try
    EdgeRows.Rebuild(75);

    Assert.AreEqual(2, EdgeCalls);
    Assert.AreEqual(0, MeasureCalls);
  finally
    EdgeRows.Free;
  end;
end;

procedure TMarkdownEditorRowsTests.Rebuild_ClusterAcrossWrapWidth_MovesToNextRow;
begin
  FModel.LoadText('abcdef');
  const EdgeRows = TMarkdownEditorRows.Create(FModel, MeasureText,
    function(const Text: string): TArray<Single>
    begin
      Result := [10, 20, 30, 50, 50, 60];
    end);
  try
    EdgeRows.Rebuild(45);

    Assert.AreEqual('|abc|def', RowTexts(EdgeRows), 'the fourth and fifth character form one cluster');
  finally
    EdgeRows.Free;
  end;
end;

end.
