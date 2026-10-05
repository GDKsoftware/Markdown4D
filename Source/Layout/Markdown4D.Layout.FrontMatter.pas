unit Markdown4D.Layout.FrontMatter;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.FrontMatter,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme;

type
  // Lays out a front matter block as a properties panel, the way Obsidian
  // shows it: a row per property with the key on the left and the value on
  // the right, and every item of a list value as a chip of its own. Front
  // matter the strict reader does not understand is shown as its raw lines,
  // the way a code block without a highlighter is.
  TFrontMatterLayout = class
  private
    const
      KeyColumnShare = 0.4;
      RowLineThickness = 1.0;
      WordSeparator = ' ';
    var
      FTheme: TMarkdownTheme;
      FMeasurer: ITextMeasurer;
      FItems: TList<IDisplayItem>;
      FNode: IMarkdownNode;
      FValueColor: TLayoutColor;
      FLeft: Single;
      FRight: Single;
      FCurrentY: Single;
    procedure LayoutProperties(const Properties: TArray<TFrontMatterProperty>);
    function KeyColumnWidth(const Properties: TArray<TFrontMatterProperty>): Single;
    procedure PlaceRow(const Prop: TFrontMatterProperty; const KeyWidth: Single; const IsFirstRow: Boolean);
    function PlaceWords(const Text: string; const Left, Top, Width: Single; const Color: TLayoutColor;
                        const FirstJoin: TDisplayTextJoin): Single;
    function PlaceChips(const Values: TArray<string>; const Left, Top, Width: Single): Single;
    procedure PlaceChip(const Value: string; const Left, Top: Single; const Join: TDisplayTextJoin);
    procedure EmitRowLine(const Y: Single);
    procedure LayoutRawLines(const Literal: string);
    procedure EmitRun(const Bounds: TLayoutRectF; const Text: string; const Font: TMarkdownFontStyle;
                      const Color: TLayoutColor; const StartOffset: Integer; const Join: TDisplayTextJoin);
    function TextWidth(const Text: string; const Font: TMarkdownFontStyle): Single;
    function ChipPadding: Single;
    function ChipGap: Single;

  public
    constructor Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer; const Items: TList<IDisplayItem>);
    function Layout(const Node: IMarkdownNode; const Left, Top, Right: Single; const ValueColor: TLayoutColor): Single;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  Markdown4D.Defines,
  Markdown4D.Layout.Primitives;

constructor TFrontMatterLayout.Create(const Theme: TMarkdownTheme; const Measurer: ITextMeasurer;
                                      const Items: TList<IDisplayItem>);
begin
  inherited Create;

  FTheme := Theme;
  FMeasurer := Measurer;
  FItems := Items;
end;

function TFrontMatterLayout.Layout(const Node: IMarkdownNode; const Left, Top, Right: Single;
                                   const ValueColor: TLayoutColor): Single;
begin
  FNode := Node;
  FValueColor := ValueColor;
  FLeft := Left;
  FRight := Right;
  FCurrentY := Top;

  const BackgroundIndex = FItems.Count;
  const Literal = (Node as IMarkdownFrontMatter).Literal;

  var Properties: TArray<TFrontMatterProperty>;
  if TFrontMatterProperties.TryParse(Literal, Properties) then
    LayoutProperties(Properties)
  else
    LayoutRawLines(Literal);

  const BackgroundBounds = TLayoutRectF.Create(FLeft, Top, FRight, FCurrentY);
  const Background: IDisplayItem = TDisplayRectangle.Create(BackgroundBounds, FNode, FTheme.CodeBackgroundColor, 0, 0);
  FItems.Insert(BackgroundIndex, Background);

  Result := FCurrentY - Top;
end;

procedure TFrontMatterLayout.LayoutProperties(const Properties: TArray<TFrontMatterProperty>);
begin
  const HasProperties = (Length(Properties) > 0);
  if not HasProperties then
  begin
    const LineHeight = FMeasurer.LineHeight(FTheme.BaseFont);
    FCurrentY := FCurrentY + LineHeight + 2 * FTheme.TableCellPadding;
    Exit;
  end;

  const KeyWidth = KeyColumnWidth(Properties);

  for var Index := 0 to High(Properties) do
  begin
    const IsFirstRow = (Index = 0);
    PlaceRow(Properties[Index], KeyWidth, IsFirstRow);
  end;
end;

// The key column is as wide as the widest key, but never takes more than its
// share of the panel; a longer key wraps within the column.
function TFrontMatterLayout.KeyColumnWidth(const Properties: TArray<TFrontMatterProperty>): Single;
begin
  Result := 0;

  for var Prop in Properties do
  begin
    const KeyWidth = TextWidth(Prop.Key, FTheme.BaseFont);
    Result := Max(Result, KeyWidth);
  end;

  const InnerWidth = FRight - FLeft - 3 * FTheme.TableCellPadding;
  const MaxKeyWidth = Max(0, InnerWidth * KeyColumnShare);
  Result := Min(Result, MaxKeyWidth);
end;

procedure TFrontMatterLayout.PlaceRow(const Prop: TFrontMatterProperty; const KeyWidth: Single;
                                      const IsFirstRow: Boolean);
begin
  const Padding = FTheme.TableCellPadding;
  const RowTop = FCurrentY;
  const ContentTop = RowTop + Padding;
  const KeyLeft = FLeft + Padding;
  const ValueLeft = KeyLeft + KeyWidth + Padding;
  const ValueWidth = Max(0, FRight - Padding - ValueLeft);

  if not IsFirstRow then
    EmitRowLine(RowTop);

  var KeyJoin := TDisplayTextJoin.LineBreak;
  if IsFirstRow then
    KeyJoin := TDisplayTextJoin.None;

  const KeyHeight = PlaceWords(Prop.Key, KeyLeft, ContentTop, KeyWidth, FTheme.BlockQuoteTextColor, KeyJoin);

  var ValueHeight: Single;
  if Prop.IsList then
  begin
    ValueHeight := PlaceChips(Prop.Values, ValueLeft, ContentTop, ValueWidth);
  end
  else
  begin
    const ValueText = string.Join(WordSeparator, Prop.Values);
    ValueHeight := PlaceWords(ValueText, ValueLeft, ContentTop, ValueWidth, FValueColor, TDisplayTextJoin.Tab);
  end;

  const LineHeight = FMeasurer.LineHeight(FTheme.BaseFont);
  const ContentHeight = Max(KeyHeight, ValueHeight);
  const RowHeight = Max(LineHeight, ContentHeight) + 2 * Padding;

  FCurrentY := RowTop + RowHeight;
end;

// Places Text word by word and starts a new line when the next word no longer
// fits. Answers the height the words took.
function TFrontMatterLayout.PlaceWords(const Text: string; const Left, Top, Width: Single; const Color: TLayoutColor;
                                       const FirstJoin: TDisplayTextJoin): Single;
begin
  const Font = FTheme.BaseFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const SpaceWidth = TextWidth(WordSeparator, Font);
  const Words = Text.Split([WordSeparator], TStringSplitOptions.ExcludeEmpty);

  var Cursor := Left;
  var LineTop := Top;
  var Join := FirstJoin;

  for var WordText in Words do
  begin
    const WordWidth = TextWidth(WordText, Font);
    const IsLineStart = (SameValue(Cursor, Left));
    const Overflows = (not IsLineStart and (Cursor + WordWidth > Left + Width));
    if Overflows then
    begin
      Cursor := Left;
      LineTop := LineTop + LineHeight;
    end;

    const Bounds = TLayoutRectF.Create(Cursor, LineTop, Cursor + WordWidth, LineTop + LineHeight);
    EmitRun(Bounds, WordText, Font, Color, 0, Join);

    Cursor := Cursor + WordWidth + SpaceWidth;
    Join := TDisplayTextJoin.Space;
  end;

  Result := LineTop + LineHeight - Top;
end;

// Every item of a list value is a chip of its own; a chip that no longer fits
// on the line moves to the next one.
function TFrontMatterLayout.PlaceChips(const Values: TArray<string>; const Left, Top, Width: Single): Single;
begin
  const Font = FTheme.BaseFont;
  const ChipHeight = FMeasurer.LineHeight(Font);
  const LineAdvance = ChipHeight + ChipGap;

  var Cursor := Left;
  var LineTop := Top;
  var Join := TDisplayTextJoin.Tab;

  for var Value in Values do
  begin
    const ChipWidth = TextWidth(Value, Font) + 2 * ChipPadding;
    const IsLineStart = (SameValue(Cursor, Left));
    const Overflows = (not IsLineStart and (Cursor + ChipWidth > Left + Width));
    if Overflows then
    begin
      Cursor := Left;
      LineTop := LineTop + LineAdvance;
    end;

    PlaceChip(Value, Cursor, LineTop, Join);

    Cursor := Cursor + ChipWidth + ChipGap;
    Join := TDisplayTextJoin.Space;
  end;

  Result := LineTop + ChipHeight - Top;
end;

procedure TFrontMatterLayout.PlaceChip(const Value: string; const Left, Top: Single; const Join: TDisplayTextJoin);
begin
  const Font = FTheme.BaseFont;
  const ValueWidth = TextWidth(Value, Font);
  const Height = FMeasurer.LineHeight(Font);
  const ChipBounds = TLayoutRectF.Create(Left, Top, Left + ValueWidth + 2 * ChipPadding, Top + Height);
  const TextLeft = Left + ChipPadding;
  const TextBounds = TLayoutRectF.Create(TextLeft, Top, TextLeft + ValueWidth, Top + Height);
  const Chip: IDisplayItem = TDisplayRectangle.Create(ChipBounds, FNode, FTheme.TableHeaderBackgroundColor, 0, 0);

  FItems.Add(Chip);
  EmitRun(TextBounds, Value, Font, FValueColor, 0, Join);
end;

procedure TFrontMatterLayout.EmitRowLine(const Y: Single);
begin
  const StartPoint = TLayoutPointF.Create(FLeft, Y);
  const EndPoint = TLayoutPointF.Create(FRight, Y);
  const Bounds = TLayoutRectF.Create(FLeft, Y, FRight, Y + RowLineThickness);
  const Line: IDisplayItem = TDisplayLine.Create(Bounds, FNode, StartPoint, EndPoint, FTheme.TableBorderColor,
                                                 RowLineThickness);

  FItems.Add(Line);
end;

procedure TFrontMatterLayout.LayoutRawLines(const Literal: string);
begin
  const Font = FTheme.CodeFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const Padding = FTheme.CodePadding;
  const Lines = Literal.Split([LineFeed]);

  var LineStart := 0;
  var Join := TDisplayTextJoin.None;

  for var Index := 0 to High(Lines) do
  begin
    const LineText = Lines[Index];
    const Top = FCurrentY + Padding + Index * LineHeight;

    const HasText = (not LineText.IsEmpty);
    const IsBlankAfterFirst = (not HasText and (Index > 0));
    if HasText then
    begin
      const LineWidth = TextWidth(LineText, Font);
      const Bounds = TLayoutRectF.Create(FLeft + Padding, Top, FLeft + Padding + LineWidth, Top + LineHeight);
      EmitRun(Bounds, LineText, Font, FTheme.CodeTextColor, LineStart, Join);
      Join := TDisplayTextJoin.LineBreak;
    end
    else if IsBlankAfterFirst then
    begin
      Join := TDisplayTextJoin.BlankLine;
    end;

    LineStart := LineStart + Length(LineText) + 1;
  end;

  const LineCount = Max(1, Length(Lines));
  FCurrentY := FCurrentY + LineCount * LineHeight + 2 * Padding;
end;

procedure TFrontMatterLayout.EmitRun(const Bounds: TLayoutRectF; const Text: string; const Font: TMarkdownFontStyle;
                                     const Color: TLayoutColor; const StartOffset: Integer;
                                     const Join: TDisplayTextJoin);
begin
  const Baseline = FMeasurer.Baseline(Font);
  const Run: IDisplayTextRun = TDisplayTextRun.Create(Bounds, FNode, Text, Font, Color, Baseline, StartOffset);

  const HasJoin = (Join <> TDisplayTextJoin.None);
  if HasJoin then
    FItems.Add(Run.Joined(Join, 0))
  else
    FItems.Add(Run);
end;

function TFrontMatterLayout.TextWidth(const Text: string; const Font: TMarkdownFontStyle): Single;
begin
  const Size = FMeasurer.MeasureText(Text, Font);
  Result := Size.Width;
end;

function TFrontMatterLayout.ChipPadding: Single;
begin
  Result := FTheme.TableCellPadding / 2;
end;

function TFrontMatterLayout.ChipGap: Single;
begin
  Result := FTheme.TableCellPadding / 2;
end;

end.
