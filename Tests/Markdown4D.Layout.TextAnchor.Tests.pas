unit Markdown4D.Layout.TextAnchor.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Layout.TextAnchor;

type
  [TestFixture]
  TMarkdownTextAnchorsTests = class
  private
    const
      WideWidth = 300.0;
      WordWidth = 60.0;
      WrappingMarkdown = 'alpha beta gamma delta'#10#10'omega';
    class function LayoutMarkdown(const Source: string; const Width: Single): IMarkdownDisplayList; static;
    class function AnchorAt(const DisplayList: IMarkdownDisplayList; const Text: string): TMarkdownTextAnchor; static;
    class function RunTextAt(const DisplayList: IMarkdownDisplayList; const Position: TMarkdownTextPosition): string; static;

  public
    [Test]
    [TestCase('Narrower', '300,120')]
    [TestCase('Wider', '120,300')]
    procedure TryPositionOf_LayoutAtOtherWidth_FindsSameText(const FirstWidth, SecondWidth: Single);

    [Test]
    procedure TryPositionOf_WordWrapsOntoNextLine_FindsWordInItsOwnRun;

    [Test]
    procedure TryPositionOf_NodeBecameOtherNode_ReturnsFalse;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D,
  Markdown4D.Defines,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Theme;

procedure TMarkdownTextAnchorsTests.TryPositionOf_LayoutAtOtherWidth_FindsSameText(const FirstWidth,
  SecondWidth: Single);
begin
  const Anchor = AnchorAt(LayoutMarkdown(WrappingMarkdown, FirstWidth), 'omega');
  const Relaid = LayoutMarkdown(WrappingMarkdown, SecondWidth);
  const Anchors = TMarkdownTextAnchors.Create(Relaid);
  try
    var Position: TMarkdownTextPosition;
    const IsFound = Anchors.TryPositionOf(Anchor, Position);

    Assert.IsTrue(IsFound);
    Assert.AreEqual('omega', RunTextAt(Relaid, Position));
    Assert.AreEqual(0, Position.CharacterIndex);
  finally
    Anchors.Free;
  end;
end;

procedure TMarkdownTextAnchorsTests.TryPositionOf_WordWrapsOntoNextLine_FindsWordInItsOwnRun;
begin
  const Anchor = AnchorAt(LayoutMarkdown('alpha beta', WideWidth), 'beta');
  const Relaid = LayoutMarkdown('alpha beta', WordWidth);
  const Anchors = TMarkdownTextAnchors.Create(Relaid);
  try
    var Position: TMarkdownTextPosition;
    Anchors.TryPositionOf(Anchor, Position);

    Assert.AreEqual('beta', RunTextAt(Relaid, Position));
    Assert.AreEqual(0, Position.CharacterIndex);
  finally
    Anchors.Free;
  end;
end;

procedure TMarkdownTextAnchorsTests.TryPositionOf_NodeBecameOtherNode_ReturnsFalse;
begin
  const Anchor = AnchorAt(LayoutMarkdown('[omega] beta', WideWidth), 'omega');
  const Relaid = LayoutMarkdown('[omega] beta'#10#10'[omega]: /target', WideWidth);
  const Anchors = TMarkdownTextAnchors.Create(Relaid);
  try
    var Position: TMarkdownTextPosition;
    const IsFound = Anchors.TryPositionOf(Anchor, Position);

    Assert.IsFalse(IsFound);
  finally
    Anchors.Free;
  end;
end;

class function TMarkdownTextAnchorsTests.LayoutMarkdown(const Source: string;
  const Width: Single): IMarkdownDisplayList;
begin
  const Theme = TMarkdownTheme.CreateLight;
  try
    Theme.ContentPadding := 0;
    const Document = TMarkdown.Parse(Source, TMarkdownDialect.Gfm);
    const Measurer: ITextMeasurer = TFakeTextMeasurer.Create;

    Result := TMarkdownLayoutEngine.LayoutDocument(Document, Width, Theme, Measurer);
  finally
    Theme.Free;
  end;
end;

// The anchor of the first character of Text, in the first run that shows it.
class function TMarkdownTextAnchorsTests.AnchorAt(const DisplayList: IMarkdownDisplayList;
  const Text: string): TMarkdownTextAnchor;
begin
  Result := Default(TMarkdownTextAnchor);

  const Anchors = TMarkdownTextAnchors.Create(DisplayList);
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      if not TMarkdownTextAnchors.TrySelectableRun(DisplayList, Index, Run) then
        Continue;

      const CharacterIndex = Pos(Text, Run.Text) - 1;
      const ShowsText = (CharacterIndex >= 0);
      if not ShowsText then
        Continue;

      var Position: TMarkdownTextPosition;
      Position.ItemIndex := Index;
      Position.CharacterIndex := CharacterIndex;
      Anchors.TryAnchorOf(Position, Result);
      Exit;
    end;
  finally
    Anchors.Free;
  end;

  Assert.Fail(Format('No run shows "%s"', [Text]));
end;

class function TMarkdownTextAnchorsTests.RunTextAt(const DisplayList: IMarkdownDisplayList;
  const Position: TMarkdownTextPosition): string;
begin
  var Run: IDisplayTextRun;
  TMarkdownTextAnchors.TrySelectableRun(DisplayList, Position.ItemIndex, Run);
  Result := Run.Text.Trim;
end;

end.
