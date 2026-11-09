unit Markdown4D.Viewer.ExtensionContext.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model;

type
  [TestFixture]
  TViewerExtensionContextTests = class
  private
    const
      ViewportWidth = 480.0;
      ViewportHeight = 360.0;
      Following = 'after';
      BoxThenText = '```box'#10'```'#10#10 + Following;
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
    function NewModel(const Text: string): TMarkdownViewerModel;
    class function RunShowing(const Model: TMarkdownViewerModel; const Text: string): IDisplayTextRun; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ExtensionData_SetInOneViewer_ChangesOnlyThatViewersLayout;

    [Test]
    procedure LayoutNested_ImageTheViewerLoaded_HasItsSize;

    [Test]
    procedure AppendNested_PlacesTheNestedLayoutWhereAsked;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Layout.Engine,
  Markdown4D.Layout.FakeMeasurer,
  Markdown4D.Tests.BoxOverride;

procedure TViewerExtensionContextTests.Setup;
begin
  FTheme := TMarkdownTheme.CreateLight;
  FTheme.ContentPadding := 0;
  FMeasurer := TFakeTextMeasurer.Create;
  TMarkdownLayoutEngine.RegisterBlockOverride(TBoxBlockOverride.Create, TBoxBlockOverride.Priority);
end;

procedure TViewerExtensionContextTests.TearDown;
begin
  TMarkdownLayoutEngine.ClearBlockOverrides;
  FMeasurer := nil;
  FTheme.Free;
end;

function TViewerExtensionContextTests.NewModel(const Text: string): TMarkdownViewerModel;
begin
  Result := TMarkdownViewerModel.Create(FTheme, FMeasurer);
  Result.SetViewport(ViewportWidth, ViewportHeight);
  Result.Text := Text;
end;

class function TViewerExtensionContextTests.RunShowing(const Model: TMarkdownViewerModel;
  const Text: string): IDisplayTextRun;
begin
  for var Index := 0 to Model.DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsShowing = (Supports(Model.DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text = Text));
    if IsShowing then
      Exit(Run);
  end;

  raise EAssertionFailed.CreateFmt('No run shows "%s"', [Text]);
end;

// Two viewers can show the same text, and what the reader did in one of them
// stays in that one.
procedure TViewerExtensionContextTests.ExtensionData_SetInOneViewer_ChangesOnlyThatViewersLayout;
begin
  const Changed = NewModel(BoxThenText);
  const Untouched = NewModel(BoxThenText);
  try
    const Grown = 50.0;
    Changed.ExtensionData.SetValue(TBoxBlockOverride.OverrideName, TBoxHeight.Create(Grown));
    Changed.RefreshLayout;

    const Moved = RunShowing(Changed, Following).Bounds.Top - RunShowing(Untouched, Following).Bounds.Top;
    Assert.AreEqual(Grown - TBoxBlockOverride.DefaultBarHeight, Moved, 0.01);
  finally
    Untouched.Free;
    Changed.Free;
  end;
end;

// The viewer only fetches the images of its own document, so this image is
// also outside the box.
procedure TViewerExtensionContextTests.LayoutNested_ImageTheViewerLoaded_HasItsSize;
begin
  const Model = NewModel('![picture](picture.png)'#10#10'```box'#10'![picture](picture.png)'#10'```');
  try
    const Loaded = TLayoutSizeF.Create(200, 100);
    Model.NotifyImageArrived('picture.png', Loaded);

    var SizedImages := 0;
    for var Index := 0 to Model.DisplayList.ItemCount - 1 do
    begin
      var Image: IDisplayImage;
      const IsSized = (Supports(Model.DisplayList.Items[Index], IDisplayImage, Image) and
                       SameValue(Image.Bounds.Width, Loaded.Width, 0.01));
      if IsSized then
        Inc(SizedImages);
    end;

    Assert.AreEqual(2, SizedImages, 'the image outside and the one inside the box');
  finally
    Model.Free;
  end;
end;

procedure TViewerExtensionContextTests.AppendNested_PlacesTheNestedLayoutWhereAsked;
begin
  const Model = NewModel('```box'#10'inside'#10'```');
  try
    const Bounds = RunShowing(Model, 'inside').Bounds;

    Assert.AreEqual(TBoxBlockOverride.NestedLeft, Bounds.Left, 0.01);
    Assert.IsTrue(Bounds.Top >= TBoxBlockOverride.DefaultBarHeight, 'below the bar');
  finally
    Model.Free;
  end;
end;

end.
