unit Markdown4D.Viewer.Lifetime;

{$SCOPEDENUMS ON}

interface

type
  IMarkdownViewerLifetime = interface
    ['{A4E7F3D2-9C1B-4E5A-8F6D-2B3C4D5E6F70}']
    function IsAlive: Boolean;
    procedure Shutdown;
  end;

  TMarkdownViewerLifetime = class(TInterfacedObject, IMarkdownViewerLifetime)
  private
    const
      StateAlive = 0;
      StateShutdown = 1;
    var
      FShutdownState: Int64;

  public
    function IsAlive: Boolean;
    procedure Shutdown;
  end;

implementation

uses
  System.SyncObjs;

function TMarkdownViewerLifetime.IsAlive: Boolean;
begin
  Result := TInterlocked.Read(FShutdownState) = StateAlive;
end;

procedure TMarkdownViewerLifetime.Shutdown;
begin
  TInterlocked.Exchange(FShutdownState, StateShutdown);
end;

end.
