unit Markdown4D.Layout.MeasureCache.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.MeasureCache;

type
  [TestFixture]
  TMarkdownMeasureCacheTests = class
  private
    const
      SampleText = 'alpha';
      SampleFamily = 'Segoe UI';
      SampleSize = 12.0;
      SamplePixelsPerInch = 96;
      SmallCapacity = 2;
    var
      FCache: TMarkdownMeasureCache;
    class function SampleFont: TMarkdownFontStyle; static;
    class function StoredSize: TLayoutSizeF; static;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TryGetSize_AfterAdd_ReturnsStoredSize;

    [Test]
    procedure TryGetSize_OtherPixelsPerInch_Misses;

    [Test]
    [TestCase('Family', 'Family')]
    [TestCase('Size', 'Size')]
    [TestCase('Bold', 'Bold')]
    [TestCase('Italic', 'Italic')]
    procedure TryGetSize_OtherFont_Misses(const Difference: string);

    [Test]
    procedure TryGetSize_OtherText_Misses;

    [Test]
    procedure Add_BeyondCapacity_StartsOver;
  end;

implementation

uses
  System.SysUtils;

procedure TMarkdownMeasureCacheTests.Setup;
begin
  FCache := TMarkdownMeasureCache.Create;
end;

procedure TMarkdownMeasureCacheTests.TearDown;
begin
  FCache.Free;
  FCache := nil;
end;

class function TMarkdownMeasureCacheTests.SampleFont: TMarkdownFontStyle;
begin
  Result := TMarkdownFontStyle.Create(SampleFamily, SampleSize);
end;

class function TMarkdownMeasureCacheTests.StoredSize: TLayoutSizeF;
begin
  Result := TLayoutSizeF.Create(42, 17);
end;

procedure TMarkdownMeasureCacheTests.TryGetSize_AfterAdd_ReturnsStoredSize;
begin
  FCache.Add(SampleText, SampleFont, SamplePixelsPerInch, StoredSize);

  var Size: TLayoutSizeF;
  const Found = FCache.TryGetSize(SampleText, SampleFont, SamplePixelsPerInch, Size);

  Assert.IsTrue(Found);
  Assert.AreEqual(Double(StoredSize.Width), Double(Size.Width));
  Assert.AreEqual(Double(StoredSize.Height), Double(Size.Height));
end;

procedure TMarkdownMeasureCacheTests.TryGetSize_OtherPixelsPerInch_Misses;
begin
  FCache.Add(SampleText, SampleFont, SamplePixelsPerInch, StoredSize);

  var Size: TLayoutSizeF;
  const Found = FCache.TryGetSize(SampleText, SampleFont, SamplePixelsPerInch * 2, Size);

  Assert.IsFalse(Found, 'A size measured at another scale must not be reused');
end;

procedure TMarkdownMeasureCacheTests.TryGetSize_OtherFont_Misses(const Difference: string);
begin
  FCache.Add(SampleText, SampleFont, SamplePixelsPerInch, StoredSize);

  var Other := SampleFont;
  if Difference = 'Family' then
    Other.FamilyName := 'Consolas'
  else if Difference = 'Size' then
    Other.Size := SampleSize + 0.01
  else if Difference = 'Bold' then
    Other.Bold := True
  else if Difference = 'Italic' then
    Other.Italic := True;

  var Size: TLayoutSizeF;
  const Found = FCache.TryGetSize(SampleText, Other, SamplePixelsPerInch, Size);

  Assert.IsFalse(Found, Format('A font with another %s must not reuse the size', [Difference]));
end;

procedure TMarkdownMeasureCacheTests.TryGetSize_OtherText_Misses;
begin
  FCache.Add(SampleText, SampleFont, SamplePixelsPerInch, StoredSize);

  var Size: TLayoutSizeF;
  const Found = FCache.TryGetSize(SampleText + 's', SampleFont, SamplePixelsPerInch, Size);

  Assert.IsFalse(Found);
end;

procedure TMarkdownMeasureCacheTests.Add_BeyondCapacity_StartsOver;
begin
  FCache.Free;
  FCache := TMarkdownMeasureCache.Create(SmallCapacity);
  FCache.Add('one', SampleFont, SamplePixelsPerInch, StoredSize);
  FCache.Add('two', SampleFont, SamplePixelsPerInch, StoredSize);

  FCache.Add('three', SampleFont, SamplePixelsPerInch, StoredSize);

  var Size: TLayoutSizeF;
  Assert.IsFalse(FCache.TryGetSize('one', SampleFont, SamplePixelsPerInch, Size), 'A full cache starts over');
  Assert.IsTrue(FCache.TryGetSize('three', SampleFont, SamplePixelsPerInch, Size));
  Assert.AreEqual(1, FCache.Count);
end;

end.
