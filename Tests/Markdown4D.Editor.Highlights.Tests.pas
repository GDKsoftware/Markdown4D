unit Markdown4D.Editor.Highlights.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Editor.Model,
  Markdown4D.Editor.Highlights;

type
  [TestFixture]
  TMarkdownEditorHighlightsTests = class
  private
    const
      SampleText = 'one two one two one';
    var
      FModel: TMarkdownEditorModel;
      FHighlights: TMarkdownEditorHighlights;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetNeedle_MarksEveryOccurrence;

    [Test]
    procedure SetNeedle_EmptyNeedle_MarksNothing;

    [Test]
    procedure SetNeedle_CaseInsensitiveByDefault;

    [Test]
    procedure SetNeedle_MatchCase_SkipsOtherCasing;

    [Test]
    procedure Refresh_AfterEdit_FollowsTheNewText;

    [Test]
    procedure Clear_DropsMarksAndDeactivates;

    [Test]
    procedure SpansWithin_ClipsToTheRequestedRange;

    [Test]
    procedure SpansWithin_OutsideRange_ReturnsNothing;
  end;

implementation

procedure TMarkdownEditorHighlightsTests.Setup;
begin
  FModel := TMarkdownEditorModel.Create;
  FModel.LoadText(SampleText);
  FHighlights := TMarkdownEditorHighlights.Create;
end;

procedure TMarkdownEditorHighlightsTests.TearDown;
begin
  FHighlights.Free;
  FModel.Free;
end;

procedure TMarkdownEditorHighlightsTests.SetNeedle_MarksEveryOccurrence;
begin
  FHighlights.SetNeedle(FModel, 'one', Default(TMarkdownFindOptions));

  Assert.IsTrue(FHighlights.IsActive);
  Assert.AreEqual(3, FHighlights.Count);
  Assert.AreEqual(0, FHighlights.Spans[0].StartOffset);
  Assert.AreEqual(3, FHighlights.Spans[0].EndOffset);
  Assert.AreEqual(8, FHighlights.Spans[1].StartOffset);
end;

procedure TMarkdownEditorHighlightsTests.SetNeedle_EmptyNeedle_MarksNothing;
begin
  FHighlights.SetNeedle(FModel, '', Default(TMarkdownFindOptions));

  Assert.IsFalse(FHighlights.IsActive);
  Assert.AreEqual(0, FHighlights.Count);
end;

procedure TMarkdownEditorHighlightsTests.SetNeedle_CaseInsensitiveByDefault;
begin
  FModel.LoadText('One one ONE');
  FHighlights.SetNeedle(FModel, 'one', Default(TMarkdownFindOptions));

  Assert.AreEqual(3, FHighlights.Count);
end;

procedure TMarkdownEditorHighlightsTests.SetNeedle_MatchCase_SkipsOtherCasing;
begin
  FModel.LoadText('One one ONE');
  FHighlights.SetNeedle(FModel, 'one', TMarkdownFindOptions.Create(True, False));

  Assert.AreEqual(1, FHighlights.Count);
  Assert.AreEqual(4, FHighlights.Spans[0].StartOffset);
end;

procedure TMarkdownEditorHighlightsTests.Refresh_AfterEdit_FollowsTheNewText;
begin
  FHighlights.SetNeedle(FModel, 'one', Default(TMarkdownFindOptions));
  Assert.AreEqual(3, FHighlights.Count);

  FModel.SetSelection(0, 3);
  FModel.Insert('xxx');
  FHighlights.Refresh(FModel);

  Assert.AreEqual(2, FHighlights.Count);
end;

procedure TMarkdownEditorHighlightsTests.Clear_DropsMarksAndDeactivates;
begin
  FHighlights.SetNeedle(FModel, 'one', Default(TMarkdownFindOptions));
  FHighlights.Clear;

  Assert.IsFalse(FHighlights.IsActive);
  Assert.AreEqual(0, FHighlights.Count);
end;

procedure TMarkdownEditorHighlightsTests.SpansWithin_ClipsToTheRequestedRange;
begin
  FHighlights.SetNeedle(FModel, 'one', Default(TMarkdownFindOptions));

  const Clipped = FHighlights.SpansWithin(1, 10);

  Assert.AreEqual(2, Integer(Length(Clipped)));
  Assert.AreEqual(1, Clipped[0].StartOffset);
  Assert.AreEqual(3, Clipped[0].EndOffset);
  Assert.AreEqual(8, Clipped[1].StartOffset);
  Assert.AreEqual(10, Clipped[1].EndOffset);
end;

procedure TMarkdownEditorHighlightsTests.SpansWithin_OutsideRange_ReturnsNothing;
begin
  FHighlights.SetNeedle(FModel, 'two', Default(TMarkdownFindOptions));

  Assert.AreEqual(0, Integer(Length(FHighlights.SpansWithin(0, 3))));
end;

end.
