unit Markdown4D.Fmx.Viewer.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Theme,
  Markdown4D.Fmx.Viewer;

type
  [TestFixture]
  TMarkdownFmxViewerTests = class
  private
    const
      ControlWidth = 300.0;
      ControlHeight = 200.0;
      SampleMarkdown = '# Title'#10#10'Body paragraph with enough words to wrap onto a second line.';
      ImageMarkdown = '![alt](img.png)';
    var
      FViewer: TMarkdownViewer;
      FExternalTheme: TMarkdownTheme;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewViewer_HasEmptySelectedText;

    [Test]
    procedure SetText_BuildsDocumentAtControlWidth;

    [Test]
    procedure SetText_RoundTripsThroughTextProperty;

    [Test]
    procedure AppendMarkdown_FromMainThread_AppendsToDocument;

    [Test]
    procedure ThemeSwitch_TriggersRelayout;

    [Test]
    procedure DestroyWithPendingImages_DoesNotCrash;
  end;

implementation

uses
  System.SysUtils;

procedure TMarkdownFmxViewerTests.Setup;
begin
  FViewer := TMarkdownViewer.Create(nil);
  FViewer.Width := ControlWidth;
  FViewer.Height := ControlHeight;
end;

procedure TMarkdownFmxViewerTests.TearDown;
begin
  FViewer.Free;
  FViewer := nil;

  FExternalTheme.Free;
  FExternalTheme := nil;
end;

procedure TMarkdownFmxViewerTests.NewViewer_HasEmptySelectedText;
begin
  Assert.AreEqual('', FViewer.SelectedText);
end;

procedure TMarkdownFmxViewerTests.SetText_BuildsDocumentAtControlWidth;
begin
  FViewer.Text := SampleMarkdown;

  Assert.IsTrue(FViewer.ContentHeight > 0, 'Expected the display list to build a non-empty document height');
end;

procedure TMarkdownFmxViewerTests.SetText_RoundTripsThroughTextProperty;
begin
  FViewer.Text := SampleMarkdown;

  Assert.AreEqual(SampleMarkdown, FViewer.Text);
end;

procedure TMarkdownFmxViewerTests.AppendMarkdown_FromMainThread_AppendsToDocument;
begin
  FViewer.Text := 'one';

  FViewer.AppendMarkdown(' two');

  Assert.IsTrue(FViewer.Text.Contains('two'), 'Expected appended markdown to be present after flushing');
end;

procedure TMarkdownFmxViewerTests.ThemeSwitch_TriggersRelayout;
begin
  FViewer.Text := SampleMarkdown;

  FExternalTheme := TMarkdownTheme.CreateDark;
  FViewer.Theme := FExternalTheme;

  Assert.IsTrue(FViewer.ContentHeight > 0, 'Expected the viewer to relayout after a theme switch');
end;

procedure TMarkdownFmxViewerTests.DestroyWithPendingImages_DoesNotCrash;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  try
    Viewer.Width := ControlWidth;
    Viewer.Height := ControlHeight;
    Viewer.Text := ImageMarkdown;
  finally
    Viewer.Free;
  end;

  Assert.Pass('Destroying a viewer with pending image slots must not crash');
end;

end.
