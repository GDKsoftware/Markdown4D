unit Markdown4D.Viewer.ImageDownloader;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markdown4D.Viewer.Lifetime;

type
  TMarkdownImageDownloadCompleted = reference to procedure(const Source: string; const Data: TBytes);

  TMarkdownImageDownloadFailed = reference to procedure(const Source: string);

  TMarkdownImageDownloader = class
  private
    const
      MaxConcurrentDownloads = 4;
      ConnectionTimeoutMilliseconds = 10000;
      ResponseTimeoutMilliseconds = 30000;
      HttpStatusOk = 200;
    type
      TPendingDownload = record
        Source: string;
        Url: string;
        MaxBytes: Integer;
      end;
    var
      FLifetime: IMarkdownViewerLifetime;
      FGeneration: Integer;
      FActiveCount: Integer;
      FQueue: TQueue<TPendingDownload>;
      FOnCompleted: TMarkdownImageDownloadCompleted;
      FOnFailed: TMarkdownImageDownloadFailed;
    procedure PumpQueue;
    procedure BeginDownload(const Pending: TPendingDownload);
    class function TryFetch(const Url: string; const MaxBytes: Integer;
      const Lifetime: IMarkdownViewerLifetime; out Data: TBytes): Boolean;
    procedure HandleDownloadResult(const Generation: Integer; const Source: string; const Data: TBytes;
      const Succeeded: Boolean);

  public
    constructor Create(const OnCompleted: TMarkdownImageDownloadCompleted;
      const OnFailed: TMarkdownImageDownloadFailed);
    destructor Destroy; override;
    procedure Download(const Source, Url: string; const MaxBytes: Integer = 0);
    procedure CancelPending;
  end;

implementation

uses
  System.Classes,
  System.Threading,
  System.Net.URLClient,
  System.Net.HttpClient;

constructor TMarkdownImageDownloader.Create(const OnCompleted: TMarkdownImageDownloadCompleted;
  const OnFailed: TMarkdownImageDownloadFailed);
begin
  inherited Create;

  FLifetime := TMarkdownViewerLifetime.Create;
  FQueue := TQueue<TPendingDownload>.Create;
  FOnCompleted := OnCompleted;
  FOnFailed := OnFailed;
end;

destructor TMarkdownImageDownloader.Destroy;
begin
  FLifetime.Shutdown;
  FQueue.Free;

  inherited Destroy;
end;

procedure TMarkdownImageDownloader.Download(const Source, Url: string; const MaxBytes: Integer);
begin
  var Pending := Default(TPendingDownload);
  Pending.Source := Source;
  Pending.Url := Url;
  Pending.MaxBytes := MaxBytes;
  FQueue.Enqueue(Pending);

  PumpQueue;
end;

procedure TMarkdownImageDownloader.CancelPending;
begin
  Inc(FGeneration);
  FQueue.Clear;
end;

procedure TMarkdownImageDownloader.PumpQueue;
begin
  while (FActiveCount < MaxConcurrentDownloads) and (FQueue.Count > 0) do
  begin
    BeginDownload(FQueue.Dequeue);
  end;
end;

procedure TMarkdownImageDownloader.BeginDownload(const Pending: TPendingDownload);
begin
  Inc(FActiveCount);

  const Lifetime = FLifetime;
  const Generation = FGeneration;
  const Source = Pending.Source;
  const Url = Pending.Url;
  const MaxBytes = Pending.MaxBytes;
  TTask.Run(
    procedure
    begin
      var Data: TBytes := nil;
      var Succeeded := False;
      try
        Succeeded := TryFetch(Url, MaxBytes, Lifetime, Data);
      finally
        // The result has to be reported even when the fetch failed in a way
        // TryFetch does not handle, otherwise the active count never drops and
        // the queue stalls for the lifetime of the viewer.
        TThread.Queue(nil,
          procedure
          begin
            if Lifetime.IsAlive then
              HandleDownloadResult(Generation, Source, Data, Succeeded);
          end);
      end;
    end);
end;

class function TMarkdownImageDownloader.TryFetch(const Url: string; const MaxBytes: Integer;
  const Lifetime: IMarkdownViewerLifetime; out Data: TBytes): Boolean;
begin
  Data := nil;
  try
    const Client = THTTPClient.Create;
    try
      Client.ConnectionTimeout := ConnectionTimeoutMilliseconds;
      Client.ResponseTimeout := ResponseTimeoutMilliseconds;
      Client.ReceiveDataCallback :=
        procedure(const Sender: TObject; ContentLength, ReadCount: Int64; var ShouldAbort: Boolean)
        begin
          // A response is free to lie about its length or to declare none at
          // all, so both the announced size and what actually arrived are held
          // against the bound.
          const ExceedsBound = (MaxBytes > 0) and ((ContentLength > MaxBytes) or (ReadCount > MaxBytes));

          ShouldAbort := ExceedsBound or (not Lifetime.IsAlive);
        end;

      const Content = TBytesStream.Create;
      try
        const Response = Client.Get(Url, Content);
        const WithinBound = (MaxBytes <= 0) or (Content.Size <= MaxBytes);
        const IsUsable = (Response.StatusCode = HttpStatusOk) and (Content.Size > 0) and WithinBound;
        if not IsUsable then
          Exit(False);

        Data := Copy(Content.Bytes, 0, Content.Size);
        Result := True;
      finally
        Content.Free;
      end;
    finally
      Client.Free;
    end;
  except
    on ENetException do
      Result := False;
  end;
end;

procedure TMarkdownImageDownloader.HandleDownloadResult(const Generation: Integer; const Source: string;
  const Data: TBytes; const Succeeded: Boolean);
begin
  Dec(FActiveCount);

  const IsCurrent = (Generation = FGeneration);
  if IsCurrent then
  begin
    if Succeeded then
      FOnCompleted(Source, Data)
    else
      FOnFailed(Source);
  end;

  PumpQueue;
end;

end.
