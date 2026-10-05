unit Markdown4D.Tests.FailingExtensions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.BlockOverride;

type
  EFailingExtension = class(Exception);

  TFailingCodeBlockOverride = class(TInterfacedObject, ILayoutBlockOverride)
  public
    const
      OverrideName = 'failing-override';
      FailureMessage = 'Failure inside a block override';
      PartialFillColor = TLayoutColor($FF654321);
    function GetName: string;
    function Handles(const Node: IMarkdownNode): Boolean;
    function LayoutBlock(const Node: IMarkdownNode; const Top: Single; const Context: ILayoutBlockContext): Single;
  end;

  TFailingDocumentProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  public
    const
      ProcessorName = 'failing-processor';
      FailureMessage = 'Failure inside a document processor';
    procedure Process(const Document: IMarkdownDocument);
  end;

implementation

function TFailingCodeBlockOverride.GetName: string;
begin
  Result := OverrideName;
end;

function TFailingCodeBlockOverride.Handles(const Node: IMarkdownNode): Boolean;
begin
  Result := (Node.Kind = TMarkdownNodeKind.CodeBlock);
end;

function TFailingCodeBlockOverride.LayoutBlock(const Node: IMarkdownNode; const Top: Single;
  const Context: ILayoutBlockContext): Single;
begin
  Context.Canvas.FillRectangle(TLayoutRectF.Create(0, Top, Context.Width, Top + 10), PartialFillColor);
  raise EFailingExtension.Create(FailureMessage);
end;

procedure TFailingDocumentProcessor.Process(const Document: IMarkdownDocument);
begin
  raise EFailingExtension.Create(FailureMessage);
end;

end.
