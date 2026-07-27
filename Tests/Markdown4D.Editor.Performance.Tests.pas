unit Markdown4D.Editor.Performance.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Vcl.Forms,
  Markdown4D.Editor.Model,
  Markdown4D.Vcl.Editor;

type
  [TestFixture]
  TEditorTypingPerformanceTests = class
  private
    const
      LargeLineCount = 5000;
      TypedCharacterCount = 100;
      HostWidth = 900;
      HostHeight = 600;
      // Measured around 15 ms and 70 ms on a debug build; the budgets leave room
      // for slower machines while still catching a return to per-keystroke work
      // that scales with the document (which cost 2500 ms here).
      ModelBudgetMilliseconds = 60.0;
      EditorBudgetMilliseconds = 250.0;
    var
      FHostForm: TForm;
      FDocument: string;
    class function BuildDocument(const Lines: Integer): string; static;
    function NewHostedEditor: TMarkdownEditor;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Model_TypingInLargeDocument_StaysUnderBudget;

    [Test]
    procedure Editor_TypingInLargeDocument_StaysUnderBudget;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  Markdown4D.Defines;

class function TEditorTypingPerformanceTests.BuildDocument(const Lines: Integer): string;
begin
  var Builder := TStringBuilder.Create;
  try
    for var Index := 1 to Lines do
    begin
      case Index mod 8 of
        0:
          Builder.Append('## Section ').Append(Index);
        3:
          Builder.Append('- list item ').Append(Index).Append(' with some **bold** text');
        5:
          Builder.Append('> quoted line ').Append(Index);
      else
        Builder.Append('Paragraph line ').Append(Index).Append(' with a little more text to measure.');
      end;

      Builder.Append(LineFeed);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TEditorTypingPerformanceTests.NewHostedEditor: TMarkdownEditor;
begin
  FHostForm := TForm.CreateNew(nil);
  FHostForm.ClientWidth := HostWidth;
  FHostForm.ClientHeight := HostHeight;

  Result := TMarkdownEditor.Create(FHostForm);
  Result.Visible := False;
  Result.Parent := FHostForm;
  Result.SetBounds(0, 0, HostWidth, HostHeight);
  Result.HandleNeeded;
end;

procedure TEditorTypingPerformanceTests.Setup;
begin
  FDocument := BuildDocument(LargeLineCount);
end;

procedure TEditorTypingPerformanceTests.TearDown;
begin
  FHostForm.Free;
  FHostForm := nil;
end;

procedure TEditorTypingPerformanceTests.Model_TypingInLargeDocument_StaysUnderBudget;
begin
  const Model = TMarkdownEditorModel.Create;
  try
    Model.LoadText(FDocument);
    Model.CaretPosition := Length(FDocument) div 2;

    const Watch = TStopwatch.StartNew;
    for var Index := 1 to TypedCharacterCount do
      Model.Insert('x');
    const Elapsed = Watch.Elapsed.TotalMilliseconds;

    Assert.IsTrue(Elapsed < ModelBudgetMilliseconds,
      Format('Typing %d characters in a %d line document took %.1f ms (budget %.1f ms)',
        [TypedCharacterCount, LargeLineCount, Elapsed, ModelBudgetMilliseconds]));
  finally
    Model.Free;
  end;
end;

procedure TEditorTypingPerformanceTests.Editor_TypingInLargeDocument_StaysUnderBudget;
begin
  const Editor = NewHostedEditor;

  Editor.Text := FDocument;
  Editor.CaretPosition := Length(FDocument) div 2;

  const Watch = TStopwatch.StartNew;
  for var Index := 1 to TypedCharacterCount do
    Editor.InsertText('x');
  const Elapsed = Watch.Elapsed.TotalMilliseconds;

  Assert.IsTrue(Elapsed < EditorBudgetMilliseconds,
    Format('Typing %d characters in a %d line document took %.1f ms (budget %.1f ms)',
      [TypedCharacterCount, LargeLineCount, Elapsed, EditorBudgetMilliseconds]));
end;

end.
