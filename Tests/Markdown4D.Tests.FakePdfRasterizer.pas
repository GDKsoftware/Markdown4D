unit Markdown4D.Tests.FakePdfRasterizer;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Export.Pdf.Interfaces,
  Markdown4D.Tests.RecordingPainter;

type
  TFakePdfRasterizer = class(TInterfacedObject, IMarkdownImageSizeProvider, IMarkdownPdfPageRasterizer)
  private
    const
      WhiteChannel = $FF;
    var
      FMeasurer: ITextMeasurer;
      FPageLifetimes: TList<IPainter>;
      FPages: TList<TRecordingPainter>;
      FBackgrounds: TList<TLayoutColor>;
      FImageSizes: TDictionary<string, TLayoutSizeF>;
      FEndPageCount: Integer;

  public
    constructor Create;
    destructor Destroy; override;
    procedure AddImage(const Source: string; const Size: TLayoutSizeF);
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
    function Measurer: ITextMeasurer;
    function BeginPage(const Background: TLayoutColor): IPainter;
    function EndPage: TMarkdownPdfPageImage;
    function Pages: TArray<TRecordingPainter>;
    function Backgrounds: TArray<TLayoutColor>;
    property EndPageCount: Integer read FEndPageCount;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Layout.FakeMeasurer;

constructor TFakePdfRasterizer.Create;
begin
  inherited Create;

  FMeasurer := TFakeTextMeasurer.Create;
  FPageLifetimes := TList<IPainter>.Create;
  FPages := TList<TRecordingPainter>.Create;
  FBackgrounds := TList<TLayoutColor>.Create;
  FImageSizes := TDictionary<string, TLayoutSizeF>.Create;
end;

destructor TFakePdfRasterizer.Destroy;
begin
  FImageSizes.Free;
  FBackgrounds.Free;
  FPages.Free;
  FPageLifetimes.Free;

  inherited Destroy;
end;

procedure TFakePdfRasterizer.AddImage(const Source: string; const Size: TLayoutSizeF);
begin
  FImageSizes.AddOrSetValue(Source, Size);
end;

function TFakePdfRasterizer.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Result := FImageSizes.TryGetValue(Source, Size);
end;

function TFakePdfRasterizer.Measurer: ITextMeasurer;
begin
  Result := FMeasurer;
end;

function TFakePdfRasterizer.BeginPage(const Background: TLayoutColor): IPainter;
begin
  const Page = TRecordingPainter.Create;
  Result := Page;

  FPageLifetimes.Add(Result);
  FPages.Add(Page);
  FBackgrounds.Add(Background);
end;

function TFakePdfRasterizer.EndPage: TMarkdownPdfPageImage;
begin
  Inc(FEndPageCount);
  Result := TMarkdownPdfPageImage.Create(1, 1, [WhiteChannel, WhiteChannel, WhiteChannel]);
end;

function TFakePdfRasterizer.Pages: TArray<TRecordingPainter>;
begin
  Result := FPages.ToArray;
end;

function TFakePdfRasterizer.Backgrounds: TArray<TLayoutColor>;
begin
  Result := FBackgrounds.ToArray;
end;

end.
