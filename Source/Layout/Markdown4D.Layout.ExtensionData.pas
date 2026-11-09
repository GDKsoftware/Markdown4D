unit Markdown4D.Layout.ExtensionData;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  Markdown4D.Layout.BlockOverride;

type
  TMarkdownExtensionData = class(TInterfacedObject, IMarkdownExtensionData)
  private
    FValues: TDictionary<string, IInterface>;

  public
    constructor Create;
    destructor Destroy; override;
    function TryGetValue(const Name: string; out Value: IInterface): Boolean;
    procedure SetValue(const Name: string; const Value: IInterface);
  end;

implementation

constructor TMarkdownExtensionData.Create;
begin
  inherited Create;

  FValues := TDictionary<string, IInterface>.Create;
end;

destructor TMarkdownExtensionData.Destroy;
begin
  FValues.Free;

  inherited Destroy;
end;

function TMarkdownExtensionData.TryGetValue(const Name: string; out Value: IInterface): Boolean;
begin
  Result := FValues.TryGetValue(Name, Value);
end;

procedure TMarkdownExtensionData.SetValue(const Name: string; const Value: IInterface);
begin
  FValues.AddOrSetValue(Name, Value);
end;

end.
