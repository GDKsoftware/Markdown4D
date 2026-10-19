unit Markdown4D.FrontMatter.RecordingVisitor;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  // A visitor that only remembers the front matter it was shown, so a test can
  // check that Accept dispatches a front matter node to VisitFrontMatter.
  TFrontMatterRecordingVisitor = class(TInterfacedObject, IMarkdownVisitor)
  private
    FVisitedRawText: string;
    FVisitCount: Integer;

  public
    procedure VisitDocument(const Node: IMarkdownDocument);
    procedure VisitParagraph(const Node: IMarkdownNode);
    procedure VisitHeading(const Node: IMarkdownHeading);
    procedure VisitThematicBreak(const Node: IMarkdownNode);
    procedure VisitCodeBlock(const Node: IMarkdownCodeBlock);
    procedure VisitBlockQuote(const Node: IMarkdownNode);
    procedure VisitList(const Node: IMarkdownList);
    procedure VisitListItem(const Node: IMarkdownNode);
    procedure VisitHtmlBlock(const Node: IMarkdownText);
    procedure VisitText(const Node: IMarkdownText);
    procedure VisitEmphasis(const Node: IMarkdownNode);
    procedure VisitStrong(const Node: IMarkdownNode);
    procedure VisitCodeSpan(const Node: IMarkdownText);
    procedure VisitLink(const Node: IMarkdownLink);
    procedure VisitImage(const Node: IMarkdownLink);
    procedure VisitAutolink(const Node: IMarkdownLink);
    procedure VisitSoftLineBreak(const Node: IMarkdownNode);
    procedure VisitHardLineBreak(const Node: IMarkdownNode);
    procedure VisitInlineHtml(const Node: IMarkdownText);
    procedure VisitCustomInline(const Node: IMarkdownCustomInline);
    procedure VisitTable(const Node: IMarkdownNode);
    procedure VisitTableRow(const Node: IMarkdownTableRow);
    procedure VisitTableCell(const Node: IMarkdownTableCell);
    procedure VisitMath(const Node: IMarkdownMath);
    procedure VisitFrontMatter(const Node: IMarkdownFrontMatter);
    property VisitedRawText: string read FVisitedRawText;
    property VisitCount: Integer read FVisitCount;
  end;

implementation

procedure TFrontMatterRecordingVisitor.VisitDocument(const Node: IMarkdownDocument);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitParagraph(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitHeading(const Node: IMarkdownHeading);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitThematicBreak(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitCodeBlock(const Node: IMarkdownCodeBlock);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitBlockQuote(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitList(const Node: IMarkdownList);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitListItem(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitHtmlBlock(const Node: IMarkdownText);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitText(const Node: IMarkdownText);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitEmphasis(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitStrong(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitCodeSpan(const Node: IMarkdownText);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitLink(const Node: IMarkdownLink);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitImage(const Node: IMarkdownLink);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitAutolink(const Node: IMarkdownLink);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitSoftLineBreak(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitHardLineBreak(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitInlineHtml(const Node: IMarkdownText);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitCustomInline(const Node: IMarkdownCustomInline);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitTable(const Node: IMarkdownNode);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitTableRow(const Node: IMarkdownTableRow);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitTableCell(const Node: IMarkdownTableCell);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitMath(const Node: IMarkdownMath);
begin
end;

procedure TFrontMatterRecordingVisitor.VisitFrontMatter(const Node: IMarkdownFrontMatter);
begin
  FVisitedRawText := Node.RawText;
  Inc(FVisitCount);
end;

end.
