unit Markdown4D.Vcl.Design.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.TypInfo,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Markdown4D.Theme,
  Markdown4D.Vcl.Viewer,
  Markdown4D.Vcl.Editor;

type
  [TestFixture]
  TMarkdownVclDesignTests = class
  private
    const
      PreviewWidth = 360;
      PreviewHeight = 260;
      SampleStep = 4;
      MinimumDistinctColors = 3;
      SampleText = '## Streamed'#10#10'Body **bold** text.';
      SampleBaseUrl = 'https://cdn.example.com/assets/';
    var
      FHostForm: TForm;
    class function DistinctColorCount(const Bitmap: TBitmap): Integer; static;
    function RenderDesigning(const Control: TWinControl): TBitmap;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Viewer_DesignerPath_RendersNonBlankPreview;

    [Test]
    procedure Editor_DesignerPath_RendersNonBlankPreview;

    [Test]
    procedure Viewer_PublishedProperties_StreamThroughDfmRoundTrip;

    [Test]
    procedure Editor_PublishedProperties_StreamThroughDfmRoundTrip;

    [Test]
    procedure Viewer_ExposesPublishedPropertiesAndEvents;

    [Test]
    procedure Editor_ExposesPublishedPropertiesAndEvents;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TComponentDesignCrack = class(TComponent);

procedure TMarkdownVclDesignTests.Setup;
begin
  FHostForm := TForm.CreateNew(nil);
  FHostForm.SetBounds(0, 0, PreviewWidth + 40, PreviewHeight + 40);
end;

procedure TMarkdownVclDesignTests.TearDown;
begin
  FHostForm.Free;
  FHostForm := nil;
end;

class function TMarkdownVclDesignTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  const Seen = TDictionary<TColor, Boolean>.Create;
  try
    var YIndex := 0;
    while YIndex < Bitmap.Height do
    begin
      var XIndex := 0;
      while XIndex < Bitmap.Width do
      begin
        Seen.AddOrSetValue(Bitmap.Canvas.Pixels[XIndex, YIndex], True);
        Inc(XIndex, SampleStep);
      end;

      Inc(YIndex, SampleStep);
    end;

    Result := Seen.Count;
  finally
    Seen.Free;
  end;
end;

function TMarkdownVclDesignTests.RenderDesigning(const Control: TWinControl): TBitmap;
begin
  Control.Parent := FHostForm;
  Control.SetBounds(0, 0, PreviewWidth, PreviewHeight);

  TComponentDesignCrack(Control).SetDesigning(True);

  FHostForm.HandleNeeded;
  Control.HandleNeeded;

  Result := TBitmap.Create;
  Result.PixelFormat := TPixelFormat.pf24bit;
  Result.SetSize(PreviewWidth, PreviewHeight);
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(Result.Canvas.ClipRect);

  Control.PaintTo(Result.Canvas.Handle, 0, 0);
end;

procedure TMarkdownVclDesignTests.Viewer_DesignerPath_RendersNonBlankPreview;
begin
  const Viewer = TMarkdownViewer.Create(FHostForm);

  const Bitmap = RenderDesigning(Viewer);
  try
    Assert.IsTrue(Viewer.ContentHeight > 0,
      'Designer sample should populate the viewer display list');

    const Colors = DistinctColorCount(Bitmap);
    Assert.IsTrue(Colors >= MinimumDistinctColors,
      Format('Expected at least %d distinct preview colors but found %d', [MinimumDistinctColors, Colors]));
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDesignTests.Editor_DesignerPath_RendersNonBlankPreview;
begin
  const Editor = TMarkdownEditor.Create(FHostForm);

  const Bitmap = RenderDesigning(Editor);
  try
    const Colors = DistinctColorCount(Bitmap);
    Assert.IsTrue(Colors >= MinimumDistinctColors,
      Format('Expected at least %d distinct preview colors but found %d', [MinimumDistinctColors, Colors]));
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownVclDesignTests.Viewer_PublishedProperties_StreamThroughDfmRoundTrip;
begin
  const Source = TMarkdownViewer.Create(nil);
  try
    Source.Name := 'SourceViewer';
    Source.Text := SampleText;
    Source.ThemePreset := TMarkdownThemePreset.Dark;
    Source.Images.BaseUrl := SampleBaseUrl;

    const Stream = TMemoryStream.Create;
    try
      Stream.WriteComponent(Source);
      Stream.Position := 0;

      const Target = TMarkdownViewer.Create(nil);
      try
        Stream.ReadComponent(Target);

        Assert.AreEqual(SampleText, Target.Text, 'Text should round-trip through streaming');
        Assert.AreEqual(Ord(TMarkdownThemePreset.Dark), Ord(Target.ThemePreset),
          'ThemePreset should round-trip through streaming');
        Assert.AreEqual(SampleBaseUrl, Target.Images.BaseUrl,
          'Images.BaseUrl should round-trip through streaming');
      finally
        Target.Free;
      end;
    finally
      Stream.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMarkdownVclDesignTests.Editor_PublishedProperties_StreamThroughDfmRoundTrip;
begin
  const Source = TMarkdownEditor.Create(nil);
  try
    Source.Name := 'SourceEditor';
    Source.Text := SampleText;
    Source.ThemePreset := TMarkdownThemePreset.Dark;
    Source.ShowLineNumbers := True;

    const Stream = TMemoryStream.Create;
    try
      Stream.WriteComponent(Source);
      Stream.Position := 0;

      const Target = TMarkdownEditor.Create(nil);
      try
        Stream.ReadComponent(Target);

        Assert.AreEqual(SampleText, Target.Text, 'Text should round-trip through streaming');
        Assert.AreEqual(Ord(TMarkdownThemePreset.Dark), Ord(Target.ThemePreset),
          'ThemePreset should round-trip through streaming');
        Assert.IsTrue(Target.ShowLineNumbers, 'ShowLineNumbers should round-trip through streaming');
      finally
        Target.Free;
      end;
    finally
      Stream.Free;
    end;
  finally
    Source.Free;
  end;
end;

procedure TMarkdownVclDesignTests.Viewer_ExposesPublishedPropertiesAndEvents;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  try
    for var PropertyName in TArray<string>.Create('Text', 'ThemePreset', 'Images', 'OnLinkClick',
      'OnLinkHover', 'OnResolveImage', 'OnScroll') do
    begin
      Assert.IsNotNull(GetPropInfo(Viewer, PropertyName),
        Format('Property %s should be published on TMarkdownViewer', [PropertyName]));
    end;
  finally
    Viewer.Free;
  end;
end;

procedure TMarkdownVclDesignTests.Editor_ExposesPublishedPropertiesAndEvents;
begin
  const Editor = TMarkdownEditor.Create(nil);
  try
    for var PropertyName in TArray<string>.Create('Text', 'ThemePreset', 'ShowLineNumbers',
      'OnChange', 'OnScroll') do
    begin
      Assert.IsNotNull(GetPropInfo(Editor, PropertyName),
        Format('Property %s should be published on TMarkdownEditor', [PropertyName]));
    end;
  finally
    Editor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMarkdownVclDesignTests);

end.
