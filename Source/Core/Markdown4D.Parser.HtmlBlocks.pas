unit Markdown4D.Parser.HtmlBlocks;

{$SCOPEDENUMS ON}

interface

uses
  System.RegularExpressions;

type
  THtmlBlockScanner = class
  private
    const
      FirstKind = 1;
      LastKind = 7;
      LastLineTerminatedKind = 5;
      InterruptingKindLimit = 7;
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
    function TryMatchStart(const LineRest: string; const AllowInterruptingKind: Boolean; out Kind: Integer): Boolean;
    function EndsOnSameLine(const Kind: Integer; const LineRest: string): Boolean;
    class function EndsAtBlankLine(const Kind: Integer): Boolean;
  end;

implementation

constructor THtmlBlockScanner.Create;
begin
  inherited Create;

  FOpenPatterns[1] := TRegEx.Create('^<(?:script|pre|textarea|style)(?:\s|>|$)', [roIgnoreCase]);
  FOpenPatterns[2] := TRegEx.Create('^<!--');
  FOpenPatterns[3] := TRegEx.Create('^<\?');
  FOpenPatterns[4] := TRegEx.Create('^<![A-Za-z]');
  FOpenPatterns[5] := TRegEx.Create('^<!\[CDATA\[');
  FOpenPatterns[6] := TRegEx.Create('^</?(?:' + BlockTagNames + ')(?:\s|/?>|$)', [roIgnoreCase]);
  FOpenPatterns[7] := TRegEx.Create('^(?:' + OpenTag + '|' + CloseTag + ')\s*$', [roIgnoreCase]);

  FClosePatterns[1] := TRegEx.Create('</(?:script|pre|textarea|style)>', [roIgnoreCase]);
  FClosePatterns[2] := TRegEx.Create('-->');
  FClosePatterns[3] := TRegEx.Create('\?>');
  FClosePatterns[4] := TRegEx.Create('>');
  FClosePatterns[5] := TRegEx.Create('\]\]>');
end;

function THtmlBlockScanner.TryMatchStart(const LineRest: string; const AllowInterruptingKind: Boolean;
                                         out Kind: Integer): Boolean;
begin
  Kind := 0;

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

function THtmlBlockScanner.EndsOnSameLine(const Kind: Integer; const LineRest: string): Boolean;
begin
  const IsLineTerminated = (Kind >= FirstKind) and (Kind <= LastLineTerminatedKind);
  if not IsLineTerminated then
    Exit(False);

  Result := FClosePatterns[Kind].IsMatch(LineRest);
end;

class function THtmlBlockScanner.EndsAtBlankLine(const Kind: Integer): Boolean;
begin
  Result := (Kind > LastLineTerminatedKind);
end;

end.
