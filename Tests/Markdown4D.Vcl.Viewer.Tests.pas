unit Markdown4D.Vcl.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  Vcl.Forms,
  DUnitX.TestFramework,
  Markdown4D.Vcl.Viewer;

type
  TTestableVclViewer = class(TMarkdownViewer)
  public
    function SimulateWheel(const WheelDelta: Integer): Boolean;
    procedure SimulateKeyDown(const Key: Word; const Shift: TShiftState);
  end;

  [TestFixture]
  TMarkdownVclViewerTests = class
  private
    const
      HostWidth = 400;
      HostHeight = 120;
      ShortMarkdown = 'one line';
      ParagraphCount = 40;
    var
      FHostForm: TForm;
    function NewHostedViewer: TTestableVclViewer;

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Wheel_ContentFitsViewport_LeavesWheelUnhandled;

    [Test]
    procedure Wheel_ContentOverflowsViewport_ScrollsAndHandles;

    [Test]
    procedure Keyboard_CtrlA_SelectsWholeDocument;

    [Test]
    procedure Keyboard_ArrowDown_ScrollsOverflowingContent;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Markdown4D.Tests.Pipeline.Helpers;

function TTestableVclViewer.SimulateWheel(const WheelDelta: Integer): Boolean;
begin
  Result := DoMouseWheel([], WheelDelta, TPoint.Create(0, 0));
end;

procedure TTestableVclViewer.SimulateKeyDown(const Key: Word; const Shift: TShiftState);
begin
  var PressedKey := Key;
  KeyDown(PressedKey, Shift);
end;

procedure TMarkdownVclViewerTests.TearDown;
begin
  FHostForm.Free;
  FHostForm := nil;
end;

function TMarkdownVclViewerTests.NewHostedViewer: TTestableVclViewer;
begin
  FHostForm := TForm.CreateNew(nil);
  FHostForm.ClientWidth := HostWidth;
  FHostForm.ClientHeight := HostHeight;

  Result := TTestableVclViewer.Create(FHostForm);
  Result.Visible := False;
  Result.Parent := FHostForm;
  Result.SetBounds(0, 0, HostWidth, HostHeight);
  Result.HandleNeeded;
end;

procedure TMarkdownVclViewerTests.Wheel_ContentFitsViewport_LeavesWheelUnhandled;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := ShortMarkdown;

  Assert.IsFalse(Viewer.SimulateWheel(-WHEEL_DELTA),
    'A viewer whose content fits should pass the wheel to its parent');
end;

procedure TMarkdownVclViewerTests.Wheel_ContentOverflowsViewport_ScrollsAndHandles;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Assert.IsTrue(Viewer.SimulateWheel(-WHEEL_DELTA), 'A scrollable viewer should claim the wheel');
  Assert.IsTrue(Viewer.ScrollOffset > 0, 'The wheel should have scrolled the content down');
end;

procedure TMarkdownVclViewerTests.Keyboard_CtrlA_SelectsWholeDocument;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := ShortMarkdown;

  Viewer.SimulateKeyDown(Ord('A'), [ssCtrl]);

  Assert.AreEqual(ShortMarkdown, Viewer.SelectedText);
end;

procedure TMarkdownVclViewerTests.Keyboard_ArrowDown_ScrollsOverflowingContent;
begin
  const Viewer = NewHostedViewer;
  Viewer.Text := TMarkdownTestPipelineHelpers.ManyParagraphs(ParagraphCount);

  Viewer.SimulateKeyDown(VK_DOWN, []);

  Assert.IsTrue(Viewer.ScrollOffset > 0, 'The down arrow should scroll a viewer whose content overflows');
end;

end.
