unit Markdown4D.Editor.Highlights;

{$SCOPEDENUMS ON}

// Search hits as offset ranges, kept in step with the text and clipped to the
// line a host is about to paint. The ranges are framework-neutral; only turning
// them into rectangles belongs to a concrete editor control.

interface

uses
  Markdown4D.Editor.Model;

type
  TEditorHighlightSpan = record
    StartOffset: Integer;
    EndOffset: Integer;
    class function Create(const StartOffset, EndOffset: Integer): TEditorHighlightSpan; static;
    function Length: Integer;
  end;

  TMarkdownEditorHighlights = class
  strict private
    FNeedle: string;
    FOptions: TMarkdownFindOptions;
    FSpans: TArray<TEditorHighlightSpan>;
  public
    procedure SetNeedle(const Model: TMarkdownEditorModel; const Needle: string;
      const Options: TMarkdownFindOptions);
    procedure Clear;
    // Call after the text changed so the ranges follow the new content.
    procedure Refresh(const Model: TMarkdownEditorModel);
    function IsActive: Boolean;
    function Count: Integer;
    function Spans: TArray<TEditorHighlightSpan>;
    // The parts of the ranges that fall inside one visual row, already clipped.
    function SpansWithin(const RangeStart, RangeEnd: Integer): TArray<TEditorHighlightSpan>;
  end;

implementation

uses
  System.Math;

class function TEditorHighlightSpan.Create(const StartOffset, EndOffset: Integer): TEditorHighlightSpan;
begin
  Result.StartOffset := StartOffset;
  Result.EndOffset := EndOffset;
end;

function TEditorHighlightSpan.Length: Integer;
begin
  Result := EndOffset - StartOffset;
end;

procedure TMarkdownEditorHighlights.SetNeedle(const Model: TMarkdownEditorModel; const Needle: string;
  const Options: TMarkdownFindOptions);
begin
  FNeedle := Needle;
  FOptions := Options;

  Refresh(Model);
end;

procedure TMarkdownEditorHighlights.Clear;
begin
  FNeedle := '';
  FSpans := [];
end;

procedure TMarkdownEditorHighlights.Refresh(const Model: TMarkdownEditorModel);
begin
  FSpans := [];

  if (FNeedle = '') or (Model = nil) then
    Exit;

  const NeedleLength = System.Length(FNeedle);
  for var Start in Model.FindAllMatches(FNeedle, FOptions) do
    FSpans := FSpans + [TEditorHighlightSpan.Create(Start, Start + NeedleLength)];
end;

function TMarkdownEditorHighlights.IsActive: Boolean;
begin
  Result := FNeedle <> '';
end;

function TMarkdownEditorHighlights.Count: Integer;
begin
  Result := System.Length(FSpans);
end;

function TMarkdownEditorHighlights.Spans: TArray<TEditorHighlightSpan>;
begin
  Result := FSpans;
end;

function TMarkdownEditorHighlights.SpansWithin(const RangeStart, RangeEnd: Integer): TArray<TEditorHighlightSpan>;
begin
  Result := [];

  for var Span in FSpans do
  begin
    const Outside = (Span.EndOffset <= RangeStart) or (Span.StartOffset >= RangeEnd);
    if Outside then
      Continue;

    Result := Result + [TEditorHighlightSpan.Create(Max(Span.StartOffset, RangeStart),
      Min(Span.EndOffset, RangeEnd))];
  end;
end;

end.
