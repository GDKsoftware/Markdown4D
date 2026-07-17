unit Markdown4D.Fmx.Design.Tests;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Types,
  System.TypInfo,
  System.UITypes,
  FMX.Graphics,
  FMX.Controls,
  DUnitX.TestFramework,
  Markdown4D.Theme,
  Markdown4D.Fmx.Viewer,
  Markdown4D.Fmx.Editor;

type
  [TestFixture]
  TMarkdownFmxDesignTests = class
  private
    const
      PreviewWidth = 360;
      PreviewHeight = 260;
      SampleStep = 4;
      MinimumDistinctColors = 3;
      SampleText = '## Streamed'#10#10'Body **bold** text.';
      SampleBaseUrl = 'https://cdn.example.com/assets/';
    class function DistinctColorCount(const Bitmap: TBitmap): Integer; static;
    class function RenderDesigning(const Control: TControl): TBitmap; static;

  public
    [Test]
    procedure Viewer_DesignerPath_RendersNonBlankPreview;

    [Test]
    procedure Editor_DesignerPath_RendersNonBlankPreview;

    [Test]
    procedure Viewer_PublishedProperties_StreamThroughFmxRoundTrip;

    [Test]
    procedure Editor_PublishedProperties_StreamThroughFmxRoundTrip;

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

class function TMarkdownFmxDesignTests.DistinctColorCount(const Bitmap: TBitmap): Integer;
begin
  var Data: TBitmapData;
  if not Bitmap.Map(TMapAccess.Read, Data) then
    Exit(0);

  try
    const Seen = TDictionary<TAlphaColor, Boolean>.Create;
    try
      var YIndex := 0;
      while YIndex < Bitmap.Height do
      begin
        var XIndex := 0;
        while XIndex < Bitmap.Width do
        begin
          Seen.AddOrSetValue(Data.GetPixel(XIndex, YIndex), True);
          Inc(XIndex, SampleStep);
        end;

        Inc(YIndex, SampleStep);
      end;

      Result := Seen.Count;
    finally
      Seen.Free;
    end;
  finally
    Bitmap.Unmap(Data);
  end;
end;

class function TMarkdownFmxDesignTests.RenderDesigning(const Control: TControl): TBitmap;
begin
  Control.SetBounds(0, 0, PreviewWidth, PreviewHeight);

  TComponentDesignCrack(Control).SetDesigning(True);

  Result := TBitmap.Create(PreviewWidth, PreviewHeight);
  Result.Clear(TAlphaColorRec.White);

  if Result.Canvas.BeginScene then
  try
    Control.PaintTo(Result.Canvas, TRectF.Create(0, 0, PreviewWidth, PreviewHeight));
  finally
    Result.Canvas.EndScene;
  end;
end;

procedure TMarkdownFmxDesignTests.Viewer_DesignerPath_RendersNonBlankPreview;
begin
  const Viewer = TMarkdownViewer.Create(nil);
  try
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
  finally
    Viewer.Free;
  end;
end;

procedure TMarkdownFmxDesignTests.Editor_DesignerPath_RendersNonBlankPreview;
begin
  const Editor = TMarkdownEditor.Create(nil);
  try
    const Bitmap = RenderDesigning(Editor);
    try
      const Colors = DistinctColorCount(Bitmap);
      Assert.IsTrue(Colors >= MinimumDistinctColors,
        Format('Expected at least %d distinct preview colors but found %d', [MinimumDistinctColors, Colors]));
    finally
      Bitmap.Free;
    end;
  finally
    Editor.Free;
  end;
end;

procedure TMarkdownFmxDesignTests.Viewer_PublishedProperties_StreamThroughFmxRoundTrip;
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

procedure TMarkdownFmxDesignTests.Editor_PublishedProperties_StreamThroughFmxRoundTrip;
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

procedure TMarkdownFmxDesignTests.Viewer_ExposesPublishedPropertiesAndEvents;
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

procedure TMarkdownFmxDesignTests.Editor_ExposesPublishedPropertiesAndEvents;
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
  TDUnitX.RegisterTestFixture(TMarkdownFmxDesignTests);

end.
