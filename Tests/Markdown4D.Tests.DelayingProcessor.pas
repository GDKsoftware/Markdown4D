unit Markdown4D.Tests.DelayingProcessor;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces;

type
  // Makes every layout take DelayMilliseconds longer, as a large document
  // does, and leaves the document as it is.
  TDelayingDocumentProcessor = class(TInterfacedObject, IMarkdownDocumentProcessor)
  private
    FDelayMilliseconds: Cardinal;

  public
    const
      ProcessorName = 'delaying-processor';
    constructor Create(const DelayMilliseconds: Cardinal);
    procedure Process(const Document: IMarkdownDocument);
  end;

implementation

uses
  System.SysUtils;

constructor TDelayingDocumentProcessor.Create(const DelayMilliseconds: Cardinal);
begin
  inherited Create;
  FDelayMilliseconds := DelayMilliseconds;
end;

procedure TDelayingDocumentProcessor.Process(const Document: IMarkdownDocument);
begin
  Sleep(FDelayMilliseconds);
end;

end.
