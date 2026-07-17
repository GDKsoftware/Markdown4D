unit Markdown4D.Layout.HitTest;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList;

type
  TMarkdownTextHit = record
    Run: IDisplayTextRun;
    CharacterIndex: Integer;
  end;

  TMarkdownHitTester = class
  private
    class function NearestCharacterIndex(const Run: IDisplayTextRun; const Point: TLayoutPointF;
      const Measurer: ITextMeasurer): Integer;

  public
    class function TryFindLink(const DisplayList: IMarkdownDisplayList; const Point: TLayoutPointF;
      out Link: IMarkdownLink): Boolean;
    class function TryFindTextPosition(const DisplayList: IMarkdownDisplayList; const Point: TLayoutPointF;
      const Measurer: ITextMeasurer; out Hit: TMarkdownTextHit): Boolean;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownHitTester.TryFindLink(const DisplayList: IMarkdownDisplayList; const Point: TLayoutPointF;
  out Link: IMarkdownLink): Boolean;
begin
  Link := nil;

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    const Item = DisplayList.Items[Index];
    const IsHit = Item.Bounds.Contains(Point);
    if not IsHit then
      Continue;

    const Node = Item.Node;
    if Node = nil then
      Continue;

    const IsLinkNode = (Node.Kind = TMarkdownNodeKind.Link) or (Node.Kind = TMarkdownNodeKind.Autolink);
    const FoundLink = IsLinkNode and Supports(Node, IMarkdownLink, Link);
    if FoundLink then
      Exit(True);
  end;

  Result := False;
end;

class function TMarkdownHitTester.TryFindTextPosition(const DisplayList: IMarkdownDisplayList;
  const Point: TLayoutPointF; const Measurer: ITextMeasurer; out Hit: TMarkdownTextHit): Boolean;
begin
  Hit := Default(TMarkdownTextHit);

  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsTextRunHit = Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and Run.Bounds.Contains(Point);
    if not IsTextRunHit then
      Continue;

    Hit.Run := Run;
    Hit.CharacterIndex := NearestCharacterIndex(Run, Point, Measurer);
    Exit(True);
  end;

  Result := False;
end;

class function TMarkdownHitTester.NearestCharacterIndex(const Run: IDisplayTextRun; const Point: TLayoutPointF;
  const Measurer: ITextMeasurer): Integer;
begin
  const LocalX = Point.X - Run.Bounds.Left;

  Result := 0;
  var BestDistance := Abs(LocalX);

  for var Count := 1 to Length(Run.Text) do
  begin
    const BoundaryX = Measurer.MeasureText(Copy(Run.Text, 1, Count), Run.Font).Width;
    const Distance = Abs(LocalX - BoundaryX);

    if Distance < BestDistance then
    begin
      BestDistance := Distance;
      Result := Count;
    end;
  end;
end;

end.
