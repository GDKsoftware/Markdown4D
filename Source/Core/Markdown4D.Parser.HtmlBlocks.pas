unit Markdown4D.Parser.HtmlBlocks;

{$SCOPEDENUMS ON}

interface

uses
  System.RegularExpressions;

type
  THtmlBlockKind = (
    RawTextElement,
    Comment,
    ProcessingInstruction,
    Declaration,
    CData,
    BlockElement,
    CompleteTag
  );

  THtmlBlockScanner = class
  private
    const
      FirstKind = THtmlBlockKind.RawTextElement;
      LastKind = THtmlBlockKind.CompleteTag;
      LastLineTerminatedKind = THtmlBlockKind.CData;
      InterruptingKindLimit = THtmlBlockKind.CompleteTag;
      BlockTagNames = 'address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|'
        + 'dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h[123456]|head|header|hr|'
        + 'html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|'
        + 'summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul';
    var
      FOpenPatterns: array[FirstKind..LastKind] of TRegEx;
      FClosePatterns: array[FirstKind..LastLineTerminatedKind] of TRegEx;

  public
    const
      TagName = '[A-Za-z][A-Za-z0-9-]*';
      AttributeName = '[a-zA-Z_:][a-zA-Z0-9:._-]*';
      AttributeValue = '(?:[^"''=<>`\x00-\x20]+|''[^'']*''|"[^"]*")';
      AttributeValueSpec = '\s*=\s*' + AttributeValue;
      Attribute = '\s+' + AttributeName + '(?:' + AttributeValueSpec + ')?';
      OpenTag = '<' + TagName + '(?:' + Attribute + ')*\s*/?>';
      CloseTag = '</' + TagName + '\s*>';
    constructor Create;
    function TryMatchStart(const LineRest: string; const AllowInterruptingKind: Boolean; out Kind: THtmlBlockKind): Boolean;
    function EndsOnSameLine(const Kind: THtmlBlockKind; const LineRest: string): Boolean;
    class function EndsAtBlankLine(const Kind: THtmlBlockKind): Boolean;
  end;

implementation

constructor THtmlBlockScanner.Create;
begin
  inherited Create;

  FOpenPatterns[THtmlBlockKind.RawTextElement] := TRegEx.Create('^<(?:script|pre|textarea|style)(?:\s|>|$)', [roIgnoreCase]);
  FOpenPatterns[THtmlBlockKind.Comment] := TRegEx.Create('^<!--');
  FOpenPatterns[THtmlBlockKind.ProcessingInstruction] := TRegEx.Create('^<\?');
  FOpenPatterns[THtmlBlockKind.Declaration] := TRegEx.Create('^<![A-Za-z]');
  FOpenPatterns[THtmlBlockKind.CData] := TRegEx.Create('^<!\[CDATA\[');
  FOpenPatterns[THtmlBlockKind.BlockElement] := TRegEx.Create('^</?(?:' + BlockTagNames + ')(?:\s|/?>|$)', [roIgnoreCase]);
  FOpenPatterns[THtmlBlockKind.CompleteTag] := TRegEx.Create('^(?:' + OpenTag + '|' + CloseTag + ')\s*$', [roIgnoreCase]);

  FClosePatterns[THtmlBlockKind.RawTextElement] := TRegEx.Create('</(?:script|pre|textarea|style)>', [roIgnoreCase]);
  FClosePatterns[THtmlBlockKind.Comment] := TRegEx.Create('-->');
  FClosePatterns[THtmlBlockKind.ProcessingInstruction] := TRegEx.Create('\?>');
  FClosePatterns[THtmlBlockKind.Declaration] := TRegEx.Create('>');
  FClosePatterns[THtmlBlockKind.CData] := TRegEx.Create('\]\]>');
end;

function THtmlBlockScanner.TryMatchStart(const LineRest: string; const AllowInterruptingKind: Boolean;
                                         out Kind: THtmlBlockKind): Boolean;
begin
  Kind := FirstKind;

  for var Candidate := FirstKind to LastKind do
  begin
    const RequiresNonInterrupting = (Candidate = InterruptingKindLimit) and (not AllowInterruptingKind);
    if RequiresNonInterrupting then
      Continue;

    if FOpenPatterns[Candidate].IsMatch(LineRest) then
    begin
      Kind := Candidate;
      Exit(True);
    end;
  end;

  Result := False;
end;

function THtmlBlockScanner.EndsOnSameLine(const Kind: THtmlBlockKind; const LineRest: string): Boolean;
begin
  const IsLineTerminated = (Kind >= FirstKind) and (Kind <= LastLineTerminatedKind);
  if not IsLineTerminated then
    Exit(False);

  Result := FClosePatterns[Kind].IsMatch(LineRest);
end;

class function THtmlBlockScanner.EndsAtBlankLine(const Kind: THtmlBlockKind): Boolean;
begin
  Result := (Kind > LastLineTerminatedKind);
end;

end.
