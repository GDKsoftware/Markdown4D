unit Markdown4D.Viewer.Lifetime;

{$SCOPEDENUMS ON}

interface

type
  IMarkdownViewerLifetime = interface
    ['{A4E7F3D2-9C1B-4E5A-8F6D-2B3C4D5E6F70}']
    function IsAlive: Boolean;
    procedure Kill;
  end;

  TMarkdownViewerLifetime = class(TInterfacedObject, IMarkdownViewerLifetime)
  private
    FAlive: Boolean;

  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Kill;
  end;

implementation

constructor TMarkdownViewerLifetime.Create;
begin
  inherited Create;

  FAlive := True;
end;

function TMarkdownViewerLifetime.IsAlive: Boolean;
begin
  Result := FAlive;
end;

procedure TMarkdownViewerLifetime.Kill;
begin
  FAlive := False;
end;

end.
