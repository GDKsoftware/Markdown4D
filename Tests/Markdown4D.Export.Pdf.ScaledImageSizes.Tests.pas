unit Markdown4D.Export.Pdf.ScaledImageSizes.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Layout.Interfaces;

type
  [TestFixture]
  TMarkdownPdfScaledImageSizesTests = class
  private
    const
      KnownSource = 'known.png';
      NaturalWidth = 100;
      NaturalHeight = 50;
    class function NaturalSizes: IMarkdownImageSizeProvider; static;

  public
    [Test]
    [TestCase('Same', '1,100,50')]
    [TestCase('Double', '2,200,100')]
    [TestCase('Triple', '3,300,150')]
    procedure TryGetImageSize_KnownSource_MultipliesByFactor(const Factor: Integer;
      const ExpectedWidth, ExpectedHeight: Integer);

    [Test]
    procedure TryGetImageSize_UnknownSource_ReturnsFalse;

    [Test]
    procedure TryGetImageSize_NilInner_ReturnsFalse;
  end;

implementation

uses
  Markdown4D.Export.Pdf.ScaledImageSizes,
  Markdown4D.Tests.FakeImageSizes;

class function TMarkdownPdfScaledImageSizesTests.NaturalSizes: IMarkdownImageSizeProvider;
begin
  Result := TFakeImageSizes.CreateForSource(KnownSource, NaturalWidth, NaturalHeight);
end;

procedure TMarkdownPdfScaledImageSizesTests.TryGetImageSize_KnownSource_MultipliesByFactor(const Factor: Integer;
  const ExpectedWidth, ExpectedHeight: Integer);
begin
  const Sizes: IMarkdownImageSizeProvider = TMarkdownPdfScaledImageSizes.Create(NaturalSizes, Factor);

  var Size: TLayoutSizeF;
  const Found = Sizes.TryGetImageSize(KnownSource, Size);

  Assert.IsTrue(Found);
  Assert.AreEqual(Single(ExpectedWidth), Size.Width, 0.001);
  Assert.AreEqual(Single(ExpectedHeight), Size.Height, 0.001);
end;

procedure TMarkdownPdfScaledImageSizesTests.TryGetImageSize_UnknownSource_ReturnsFalse;
begin
  const Sizes: IMarkdownImageSizeProvider = TMarkdownPdfScaledImageSizes.Create(NaturalSizes, 2);

  var Size: TLayoutSizeF;
  const Found = Sizes.TryGetImageSize('loading.png', Size);

  Assert.IsFalse(Found);
end;

procedure TMarkdownPdfScaledImageSizesTests.TryGetImageSize_NilInner_ReturnsFalse;
begin
  const Sizes: IMarkdownImageSizeProvider = TMarkdownPdfScaledImageSizes.Create(nil, 2);

  var Size: TLayoutSizeF;
  const Found = Sizes.TryGetImageSize(KnownSource, Size);

  Assert.IsFalse(Found);
end;

end.
