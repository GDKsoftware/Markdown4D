unit Markdown4D.Editor.Sync;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  TMarkdownEditorSync = class
  strict private
    type
      TMappingPoint = record
        SourceLine: Integer;
        PreviewOffset: Single;
      end;
    var
      FPoints: TArray<TMappingPoint>;
      FAverageLineHeight: Single;
    procedure AddPoint(const SourceLine: Integer; const PreviewOffset: Single);
    function FindBySourceLine(const SourceLine: Integer): Integer;
    function FindByPreviewOffset(const Offset: Single): Integer;

  public
    procedure Update(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList);
    procedure ShiftAfter(const SourceLine, LineDelta: Integer);
    function SourceLineToPreviewOffset(const SourceLine: Integer): Single;
    function PreviewOffsetToSourceLine(const Offset: Single): Integer;
    function MappedLineCount: Integer;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

procedure TMarkdownEditorSync.Update(const Document: IMarkdownDocument; const DisplayList: IMarkdownDisplayList);
begin
  FPoints := nil;
  FAverageLineHeight := 0;

  const HasInput = (Document <> nil) and (DisplayList <> nil);
  if not HasInput then
    Exit;

  const BlockCount = DisplayList.BlockCount;
  var MaxSourceLine := 0;
  for var Index := 0 to Document.ChildCount - 1 do
  begin
    if Index >= BlockCount then
      Break;

    const Node = Document.Children[Index];
    const Top = DisplayList.BlockInfos[Index].Top;

    var Heading: IMarkdownHeading;
    if Supports(Node, IMarkdownHeading, Heading) then
    begin
      const ZeroBasedLine = Max(0, Heading.SourceLine - 1);
      AddPoint(ZeroBasedLine, Top);
      MaxSourceLine := Max(MaxSourceLine, ZeroBasedLine);
    end
    else if Index = 0 then
      AddPoint(0, Top);
  end;

  if Length(FPoints) = 0 then
    AddPoint(0, 0);

  if DisplayList.Height > 0 then
    FAverageLineHeight := DisplayList.Height / (MaxSourceLine + 1);
end;

procedure TMarkdownEditorSync.ShiftAfter(const SourceLine, LineDelta: Integer);
begin
  for var Index := 0 to High(FPoints) do
  begin
    if FPoints[Index].SourceLine > SourceLine then
    begin
      FPoints[Index].SourceLine := FPoints[Index].SourceLine + LineDelta;
      FPoints[Index].PreviewOffset := FPoints[Index].PreviewOffset + LineDelta * FAverageLineHeight;
    end;
  end;
end;

function TMarkdownEditorSync.SourceLineToPreviewOffset(const SourceLine: Integer): Single;
begin
  if Length(FPoints) = 0 then
    Exit(0);

  const Index = FindBySourceLine(SourceLine);
  Result := FPoints[Index].PreviewOffset;
end;

function TMarkdownEditorSync.PreviewOffsetToSourceLine(const Offset: Single): Integer;
begin
  if Length(FPoints) = 0 then
    Exit(0);

  const Index = FindByPreviewOffset(Offset);
  Result := FPoints[Index].SourceLine;
end;

function TMarkdownEditorSync.MappedLineCount: Integer;
begin
  Result := Length(FPoints);
end;

procedure TMarkdownEditorSync.AddPoint(const SourceLine: Integer; const PreviewOffset: Single);
begin
  var Point := Default(TMappingPoint);
  Point.SourceLine := SourceLine;
  Point.PreviewOffset := PreviewOffset;
  FPoints := FPoints + [Point];
end;

function TMarkdownEditorSync.FindBySourceLine(const SourceLine: Integer): Integer;
begin
  Result := 0;
  var Lo := 0;
  var Hi := High(FPoints);
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if FPoints[Mid].SourceLine <= SourceLine then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

function TMarkdownEditorSync.FindByPreviewOffset(const Offset: Single): Integer;
begin
  Result := 0;
  var Lo := 0;
  var Hi := High(FPoints);
  while Lo <= Hi do
  begin
    const Mid = (Lo + Hi) div 2;
    if FPoints[Mid].PreviewOffset <= Offset then
    begin
      Result := Mid;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

end.
