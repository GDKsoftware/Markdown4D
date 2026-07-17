unit Markdown4D.Layout.FakeMeasurer;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Layout.Interfaces;

type
  TFakeTextMeasurer = class(TInterfacedObject, ITextMeasurer)
  private
    const
      BaseCharWidth = 10.0;
      BaseFontSize = 16.0;
      BoldWidthFactor = 1.2;
      LineHeightFactor = 1.4;
      BaselineFactor = 0.8;
    function CharWidth(const Font: TMarkdownFontStyle): Single;

  public
    function MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
    function LineHeight(const Font: TMarkdownFontStyle): Single;
    function Baseline(const Font: TMarkdownFontStyle): Single;
  end;

implementation

function TFakeTextMeasurer.MeasureText(const Text: string; const Font: TMarkdownFontStyle): TLayoutSizeF;
begin
  Result := TLayoutSizeF.Create(Length(Text) * CharWidth(Font), LineHeight(Font));
end;

function TFakeTextMeasurer.LineHeight(const Font: TMarkdownFontStyle): Single;
begin
  Result := LineHeightFactor * Font.Size;
end;

function TFakeTextMeasurer.Baseline(const Font: TMarkdownFontStyle): Single;
begin
  Result := BaselineFactor * Font.Size;
end;

function TFakeTextMeasurer.CharWidth(const Font: TMarkdownFontStyle): Single;
begin
  Result := BaseCharWidth * Font.Size / BaseFontSize;

  if Font.Bold then
    Result := Result * BoldWidthFactor;
end;

end.
