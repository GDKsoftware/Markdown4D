unit Markdown4D.Layout.MeasureCache;

{$SCOPEDENUMS ON}

// Most measurements during a layout repeat the same words in the same fonts,
// and every relayout (resize, new text, arriving images) repeats them again.
// Measuring through the platform is the slow part, so the sizes are kept,
// keyed by everything that decides them, the scale included.

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.Interfaces;

type
  TMarkdownMeasureCache = class
  private
    type
      TKey = record
        Text: string;
        Font: TMarkdownFontStyle;
        PixelsPerInch: Integer;
      end;
    var
      FCapacity: Integer;
      FSizes: TDictionary<TKey, TLayoutSizeF>;
    class function KeyOf(const Text: string; const Font: TMarkdownFontStyle;
      const PixelsPerInch: Integer): TKey; static;
    class function KeysEqual(const Left, Right: TKey): Boolean; static;
    class function KeyHash(const Key: TKey): Integer; static;

  public
    const
      DefaultCapacity = 65536;
    constructor Create(const Capacity: Integer = DefaultCapacity);
    destructor Destroy; override;
    function TryGetSize(const Text: string; const Font: TMarkdownFontStyle; const PixelsPerInch: Integer;
      out Size: TLayoutSizeF): Boolean;
    // A full cache starts over rather than tracking which entries are old: the
    // words of the document in view come back on the next layout.
    procedure Add(const Text: string; const Font: TMarkdownFontStyle; const PixelsPerInch: Integer;
      const Size: TLayoutSizeF);
    function Count: Integer;
  end;

implementation

uses
  System.Generics.Defaults,
  System.Hash;

class function TMarkdownMeasureCache.KeyOf(const Text: string; const Font: TMarkdownFontStyle;
  const PixelsPerInch: Integer): TKey;
begin
  Result.Text := Text;
  Result.Font := Font;
  Result.PixelsPerInch := PixelsPerInch;
end;

class function TMarkdownMeasureCache.KeysEqual(const Left, Right: TKey): Boolean;
begin
  Result := (Left.Text = Right.Text) and
            Left.Font.SameAs(Right.Font) and
            (Left.PixelsPerInch = Right.PixelsPerInch);
end;

// Each part feeds the next as its initial value, so no arithmetic can overflow
// in a host that compiles with overflow checks.
class function TMarkdownMeasureCache.KeyHash(const Key: TKey): Integer;
begin
  const TextHash = THashBobJenkins.GetHashValue(Key.Text);
  const FamilyHash = THashBobJenkins.GetHashValue(Key.Font.FamilyName);

  Result := THashBobJenkins.GetHashValue(FamilyHash, SizeOf(FamilyHash), TextHash);
  Result := THashBobJenkins.GetHashValue(Key.Font.Size, SizeOf(Key.Font.Size), Result);
  Result := THashBobJenkins.GetHashValue(Key.PixelsPerInch, SizeOf(Key.PixelsPerInch), Result);
end;

constructor TMarkdownMeasureCache.Create(const Capacity: Integer);
begin
  inherited Create;

  FCapacity := Capacity;
  const Comparer = TEqualityComparer<TKey>.Construct(KeysEqual, KeyHash);
  FSizes := TDictionary<TKey, TLayoutSizeF>.Create(Comparer);
end;

destructor TMarkdownMeasureCache.Destroy;
begin
  FSizes.Free;

  inherited Destroy;
end;

function TMarkdownMeasureCache.TryGetSize(const Text: string; const Font: TMarkdownFontStyle;
  const PixelsPerInch: Integer; out Size: TLayoutSizeF): Boolean;
begin
  const Key = KeyOf(Text, Font, PixelsPerInch);
  Result := FSizes.TryGetValue(Key, Size);
end;

procedure TMarkdownMeasureCache.Add(const Text: string; const Font: TMarkdownFontStyle; const PixelsPerInch: Integer;
  const Size: TLayoutSizeF);
begin
  const IsFull = (FSizes.Count >= FCapacity);
  if IsFull then
    FSizes.Clear;

  const Key = KeyOf(Text, Font, PixelsPerInch);
  FSizes.AddOrSetValue(Key, Size);
end;

function TMarkdownMeasureCache.Count: Integer;
begin
  Result := FSizes.Count;
end;

end.
