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
      FitEpsilon = 0.01;
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
    procedure PlaceChip(const Pieces: TArray<string>; const Left, Top, ChipWidth: Single;
                        const Join: TDisplayTextJoin);
    function FittingPieces(const Text: string; const Font: TMarkdownFontStyle; const Width: Single): TArray<string>;
    function MaxCharsFitting(const Text: string; const Font: TMarkdownFontStyle; const Width: Single): Integer;
    function WidestPiece(const Pieces: TArray<string>; const Font: TMarkdownFontStyle): Single;
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

  var IsFirstRow := True;
  for var Prop in Properties do
  begin
    PlaceRow(Prop, KeyWidth, IsFirstRow);
    IsFirstRow := False;
  end;
end;

// The key column is as wide as the widest key, but never takes more than its
// share of the panel; a longer key wraps within the column, and a single word
// that is still too wide breaks between its characters.
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
// fits; a word wider than the column is broken into pieces that do fit.
// Answers the height the words took.
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

    const Pieces = FittingPieces(WordText, Font, Width);
    var PieceWidth: Single := 0;
    var IsFirstPiece := True;
    for var Piece in Pieces do
    begin
      if not IsFirstPiece then
      begin
        Cursor := Left;
        LineTop := LineTop + LineHeight;
        Join := TDisplayTextJoin.Adjacent;
      end;

      PieceWidth := TextWidth(Piece, Font);
      const Bounds = TLayoutRectF.Create(Cursor, LineTop, Cursor + PieceWidth, LineTop + LineHeight);
      EmitRun(Bounds, Piece, Font, Color, 0, Join);
      IsFirstPiece := False;
    end;

    Cursor := Cursor + PieceWidth + SpaceWidth;
    Join := TDisplayTextJoin.Space;
  end;

  Result := LineTop + LineHeight - Top;
end;

// Every item of a list value is a chip of its own; a chip that no longer fits
// on the line moves to the next one, and a chip wider than the column breaks
// its text over more lines.
function TFrontMatterLayout.PlaceChips(const Values: TArray<string>; const Left, Top, Width: Single): Single;
begin
  const Font = FTheme.BaseFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const TextWidthLimit = Max(0, Width - 2 * ChipPadding);

  var Cursor := Left;
  var LineTop := Top;
  var LineBottom := Top + LineHeight;
  var Join := TDisplayTextJoin.Tab;

  for var Value in Values do
  begin
    const Pieces = FittingPieces(Value, Font, TextWidthLimit);
    const ChipWidth = WidestPiece(Pieces, Font) + 2 * ChipPadding;
    const ChipHeight = Max(1, Length(Pieces)) * LineHeight;
    const IsLineStart = (SameValue(Cursor, Left));
    const Overflows = (not IsLineStart and (Cursor + ChipWidth > Left + Width));
    if Overflows then
    begin
      Cursor := Left;
      LineTop := LineBottom + ChipGap;
    end;

    PlaceChip(Pieces, Cursor, LineTop, ChipWidth, Join);

    Cursor := Cursor + ChipWidth + ChipGap;
    LineBottom := Max(LineBottom, LineTop + ChipHeight);
    Join := TDisplayTextJoin.Space;
  end;

  Result := LineBottom - Top;
end;

procedure TFrontMatterLayout.PlaceChip(const Pieces: TArray<string>; const Left, Top, ChipWidth: Single;
                                       const Join: TDisplayTextJoin);
begin
  const Font = FTheme.BaseFont;
  const LineHeight = FMeasurer.LineHeight(Font);
  const ChipHeight = Max(1, Length(Pieces)) * LineHeight;
  const ChipBounds = TLayoutRectF.Create(Left, Top, Left + ChipWidth, Top + ChipHeight);
  const Chip: IDisplayItem = TDisplayRectangle.Create(ChipBounds, FNode, FTheme.TableHeaderBackgroundColor, 0, 0);

  FItems.Add(Chip);

  const TextLeft = Left + ChipPadding;
  var LineTop := Top;
  var PieceJoin := Join;
  for var Piece in Pieces do
  begin
    const PieceWidth = TextWidth(Piece, Font);
    const TextBounds = TLayoutRectF.Create(TextLeft, LineTop, TextLeft + PieceWidth, LineTop + LineHeight);
    EmitRun(TextBounds, Piece, Font, FValueColor, 0, PieceJoin);

    LineTop := LineTop + LineHeight;
    PieceJoin := TDisplayTextJoin.Adjacent;
  end;
end;

// Answers Text as a single piece when it fits Width, and otherwise breaks it
// into pieces of as many characters as fit, the way a too wide table cell
// breaks. A piece holds at least one character, even when that is wider.
function TFrontMatterLayout.FittingPieces(const Text: string; const Font: TMarkdownFontStyle;
                                          const Width: Single): TArray<string>;
begin
  const Fits = (TextWidth(Text, Font) <= Width + FitEpsilon);
  if Fits then
  begin
    Result := [Text];
    Exit;
  end;

  Result := [];
  var Rest := Text;
  while not Rest.IsEmpty do
  begin
    const FitCount = MaxCharsFitting(Rest, Font, Width);
    Result := Result + [Copy(Rest, 1, FitCount)];
    Rest := Copy(Rest, FitCount + 1, Length(Rest));
  end;
end;

function TFrontMatterLayout.MaxCharsFitting(const Text: string; const Font: TMarkdownFontStyle;
                                            const Width: Single): Integer;
begin
  Result := 1;

  for var CharCount := 2 to Length(Text) do
  begin
    const Prefix = Copy(Text, 1, CharCount);
    const PrefixFits = (TextWidth(Prefix, Font) <= Width + FitEpsilon);
    if not PrefixFits then
      Exit;

    Result := CharCount;
  end;
end;

function TFrontMatterLayout.WidestPiece(const Pieces: TArray<string>; const Font: TMarkdownFontStyle): Single;
begin
  Result := 0;

  for var Piece in Pieces do
  begin
    const PieceWidth = TextWidth(Piece, Font);
    Result := Max(Result, PieceWidth);
  end;
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
