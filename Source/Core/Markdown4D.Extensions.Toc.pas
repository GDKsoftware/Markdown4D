unit Markdown4D.Extensions.Toc;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces;

type
  TMarkdownTocMarkers = class
  public
    const
      ExtensionDataKey = 'markdown4d.toc';
    // The list of links to the headings that stands in for a [[_TOC_]] or
    // [TOC] paragraph. The paragraph itself stays, so the source keeps the
    // marker.
    class function TryGetContents(const Node: IMarkdownNode; out Contents: IMarkdownNode): Boolean; static;
  end;

  // A table of contents: a paragraph that holds nothing but [[_TOC_]] or [TOC]
  // shows a nested list of links to every heading of the document.
  TTocExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Ast.Builder,
  Markdown4D.Toc;

type
  TTocMarkerProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    const
      // [[_TOC_]] reads as [[ and an emphasised TOC and ]], so its plain text
      // has lost the underscores.
      Markers: array[0..1] of string = ('[TOC]', '[[TOC]]');
      AnchorMark = '#';
    class function IsMarker(const Node: IMarkdownNode): Boolean; static;
    class function TryAppendPlainText(const Node: IMarkdownNode; const Text: TStringBuilder): Boolean; static;
    class function ContentsOf(const Toc: IMarkdownToc): IMarkdownNode; static;
    class procedure AddEntry(const Builder: IMarkdownDocumentBuilder; const Entry: IMarkdownTocEntry); static;

  public
    procedure Process(const Document: IMarkdownDocument);
  end;

class function TMarkdownTocMarkers.TryGetContents(const Node: IMarkdownNode; out Contents: IMarkdownNode): Boolean;
begin
  Contents := nil;

  var Data: IInterface;
  Result := Node.TryGetExtensionData(ExtensionDataKey, Data) and Supports(Data, IMarkdownNode, Contents);
end;

procedure TTocExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  const Processor: IMarkdownDocumentProcessor = TTocMarkerProcessor.Create;
  Pipeline.RegisterDocumentProcessor(Processor, TMarkdownPriorities.ExtensionProcessor);
end;

// GitLab honours the marker only on a line of its own, so only a paragraph of
// the document itself is looked at.
procedure TTocMarkerProcessor.Process(const Document: IMarkdownDocument);
begin
  var Contents: IMarkdownNode := nil;

  for var Index := 0 to Document.ChildCount - 1 do
  begin
    const Child = Document.Children[Index];
    if not IsMarker(Child) then
      Continue;

    if Contents = nil then
    begin
      const Toc = TMarkdownToc.FromDocument(Document);
      Contents := ContentsOf(Toc);
    end;

    Child.SetExtensionData(TMarkdownTocMarkers.ExtensionDataKey, Contents);
  end;
end;

class function TTocMarkerProcessor.IsMarker(const Node: IMarkdownNode): Boolean;
begin
  Result := False;
  if Node.Kind <> TMarkdownNodeKind.Paragraph then
    Exit;

  const Text = TStringBuilder.Create;
  try
    if not TryAppendPlainText(Node, Text) then
      Exit;

    const PlainText = Text.ToString;
    for var Marker in Markers do
    begin
      if PlainText = Marker then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    Text.Free;
  end;
end;

// False for anything but text and emphasis, so a link or an image never reads
// as a marker.
class function TTocMarkerProcessor.TryAppendPlainText(const Node: IMarkdownNode; const Text: TStringBuilder): Boolean;
begin
  Result := True;

  for var Index := 0 to Node.ChildCount - 1 do
  begin
    const Child = Node.Children[Index];

    case Child.Kind of
      TMarkdownNodeKind.Text:
        Text.Append((Child as IMarkdownText).Literal);
      TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
        Result := TryAppendPlainText(Child, Text);
    else
      Result := False;
    end;

    if not Result then
      Exit;
  end;
end;

class function TTocMarkerProcessor.ContentsOf(const Toc: IMarkdownToc): IMarkdownNode;
begin
  const Builder = TMarkdownDocumentBuilder.Create;
  Builder.BeginBulletList;

  for var Entry in Toc do
  begin
    AddEntry(Builder, Entry);
  end;

  Builder.EndList;
  Result := Builder.Build.Children[0];
end;

class procedure TTocMarkerProcessor.AddEntry(const Builder: IMarkdownDocumentBuilder; const Entry: IMarkdownTocEntry);
begin
  Builder.BeginListItem;
  Builder.BeginParagraph;
  Builder.Link(Entry.Caption, AnchorMark + Entry.Anchor);
  Builder.EndParagraph;

  const HasChildren = (Entry.ChildCount > 0);
  if HasChildren then
  begin
    Builder.BeginBulletList;
    for var Index := 0 to Entry.ChildCount - 1 do
    begin
      AddEntry(Builder, Entry.Children[Index]);
    end;
    Builder.EndList;
  end;

  Builder.EndListItem;
end;

end.
