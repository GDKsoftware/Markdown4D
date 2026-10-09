unit Markdown4D.Tests.FakeImageSizes;

interface

uses
  Markdown4D.Layout.Interfaces;

type
  TFakeImageSizes = class(TInterfacedObject, IMarkdownImageSizeProvider)
  private
    FSource: string;
    FSize: TLayoutSizeF;
    FKnowsEverySource: Boolean;

  public
    constructor Create(const Width, Height: Single);
    constructor CreateForSource(const Source: string; const Width, Height: Single);
    function TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
  end;

implementation

constructor TFakeImageSizes.Create(const Width, Height: Single);
begin
  inherited Create;

  FSize := TLayoutSizeF.Create(Width, Height);
  FKnowsEverySource := True;
end;

constructor TFakeImageSizes.CreateForSource(const Source: string; const Width, Height: Single);
begin
  inherited Create;

  FSource := Source;
  FSize := TLayoutSizeF.Create(Width, Height);
  FKnowsEverySource := False;
end;

function TFakeImageSizes.TryGetImageSize(const Source: string; out Size: TLayoutSizeF): Boolean;
begin
  Result := FKnowsEverySource or (Source = FSource);
  if Result then
    Size := FSize
  else
    Size := TLayoutSizeF.Create(0, 0);
end;

end.
