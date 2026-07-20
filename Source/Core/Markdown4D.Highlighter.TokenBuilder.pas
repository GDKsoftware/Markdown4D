unit Markdown4D.Highlighter.TokenBuilder;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Highlighter.Interfaces;

type
  TSyntaxTokenBuilder = class
  private
    FTokens: TList<TSyntaxToken>;

  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Kind: TSyntaxTokenKind; const StartIndex, TokenLength: Integer);
    function ToLine(const NextState: Integer): TSyntaxLine;
  end;

implementation

constructor TSyntaxTokenBuilder.Create;
begin
  inherited Create;

  FTokens := TList<TSyntaxToken>.Create;
end;

destructor TSyntaxTokenBuilder.Destroy;
begin
  FTokens.Free;

  inherited Destroy;
end;

procedure TSyntaxTokenBuilder.Add(const Kind: TSyntaxTokenKind; const StartIndex, TokenLength: Integer);
begin
  const HasContent = (TokenLength > 0);
  if not HasContent then
    Exit;

  const LastIndex = FTokens.Count - 1;
  if LastIndex >= 0 then
  begin
    var Last := FTokens[LastIndex];
    const CanMerge = (Kind = TSyntaxTokenKind.PlainText) and (Last.Kind = TSyntaxTokenKind.PlainText) and
      (Last.Start + Last.Length = StartIndex);
    if CanMerge then
    begin
      Last.Length := Last.Length + TokenLength;
      FTokens[LastIndex] := Last;
      Exit;
    end;
  end;

  FTokens.Add(TSyntaxToken.Create(Kind, StartIndex, TokenLength));
end;

function TSyntaxTokenBuilder.ToLine(const NextState: Integer): TSyntaxLine;
begin
  Result := TSyntaxLine.Create(FTokens.ToArray, NextState);
end;

end.
