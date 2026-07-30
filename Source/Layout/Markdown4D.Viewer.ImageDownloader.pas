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

  // Decides whether one address may be fetched. Every hop of a redirect chain
  // is offered here, so a destination reached through a redirect faces the same
  // judgement as the one written in the document.
  TMarkdownImageAddressAllowed = reference to function(const Url: string): Boolean;

  TMarkdownImageDownloader = class
  private
    const
      MaxConcurrentDownloads = 4;
      MaxRedirects = 5;
      ConnectionTimeoutMilliseconds = 10000;
      ResponseTimeoutMilliseconds = 30000;
      HttpStatusOk = 200;
      RedirectStatusCodes: array[0..4] of Integer = (301, 302, 303, 307, 308);
      LocationHeaderName = 'Location';
      SchemeSeparator = '://';
      SchemeRelativePrefix = '//';
      PathSeparator = '/';
    type
      TFetchStatus = (Succeeded, Failed, Redirected);
      TFetchResult = record
        Status: TFetchStatus;
        Data: TBytes;
        Location: string;
      end;
      TPendingDownload = record
        Source: string;
        Url: string;
        MaxBytes: Integer;
        HopsLeft: Integer;
      end;
    var
      FLifetime: IMarkdownViewerLifetime;
      FGeneration: Integer;
      FActiveCount: Integer;
      FQueue: TQueue<TPendingDownload>;
      FOnCompleted: TMarkdownImageDownloadCompleted;
      FOnFailed: TMarkdownImageDownloadFailed;
      FOnAddressAllowed: TMarkdownImageAddressAllowed;
    procedure PumpQueue;
    procedure BeginDownload(const Pending: TPendingDownload);
    class function TryFetch(const Url: string; const MaxBytes: Integer;
      const Lifetime: IMarkdownViewerLifetime): TFetchResult;
    class function IsRedirect(const StatusCode: Integer): Boolean;
    class function IsHttpAddress(const Url: string): Boolean;
    class function ResolvedLocation(const BaseUrl, Location: string): string;
    procedure HandleDownloadResult(const Generation: Integer; const Pending: TPendingDownload;
      const Fetch: TFetchResult);
    procedure FollowRedirect(const Pending: TPendingDownload; const Location: string);

  public
    constructor Create(const OnCompleted: TMarkdownImageDownloadCompleted;
      const OnFailed: TMarkdownImageDownloadFailed);
    destructor Destroy; override;
    procedure Download(const Source, Url: string; const MaxBytes: Integer = 0);
    procedure CancelPending;
    // Left unassigned, a redirect is followed as long as it stays on http or
    // https. Assign it to keep the host's own judgement in charge of every hop.
    property OnAddressAllowed: TMarkdownImageAddressAllowed read FOnAddressAllowed write FOnAddressAllowed;
  end;

implementation

uses
  System.Classes,
  System.Threading,
  System.Net.URLClient,
  System.Net.HttpClient,
  Markdown4D.Defines;

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
  Pending.HopsLeft := MaxRedirects;
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
  const Request = Pending;
  TTask.Run(
    procedure
    begin
      var Fetch := Default(TFetchResult);
      Fetch.Status := TFetchStatus.Failed;
      try
        Fetch := TryFetch(Request.Url, Request.MaxBytes, Lifetime);
      finally
        // The result has to be reported even when the fetch failed in a way
        // TryFetch does not handle, otherwise the active count never drops and
        // the queue stalls for the lifetime of the viewer.
        TThread.Queue(nil,
          procedure
          begin
            if Lifetime.IsAlive then
              HandleDownloadResult(Generation, Request, Fetch);
          end);
      end;
    end);
end;

class function TMarkdownImageDownloader.TryFetch(const Url: string; const MaxBytes: Integer;
  const Lifetime: IMarkdownViewerLifetime): TFetchResult;
begin
  Result := Default(TFetchResult);
  Result.Status := TFetchStatus.Failed;

  try
    const Client = THTTPClient.Create;
    try
      Client.ConnectionTimeout := ConnectionTimeoutMilliseconds;
      Client.ResponseTimeout := ResponseTimeoutMilliseconds;
      // Redirects are followed by the caller instead, so the address policy
      // gets to judge every hop rather than only the first.
      Client.HandleRedirects := False;
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

        if IsRedirect(Response.StatusCode) then
        begin
          Result.Location := Response.HeaderValue[LocationHeaderName];
          if Result.Location <> '' then
            Result.Status := TFetchStatus.Redirected;
          Exit;
        end;

        const WithinBound = (MaxBytes <= 0) or (Content.Size <= MaxBytes);
        const IsUsable = (Response.StatusCode = HttpStatusOk) and (Content.Size > 0) and WithinBound;
        if not IsUsable then
          Exit;

        Result.Data := Copy(Content.Bytes, 0, Content.Size);
        Result.Status := TFetchStatus.Succeeded;
      finally
        Content.Free;
      end;
    finally
      Client.Free;
    end;
  except
    // An address out of a document is an outside boundary: whatever the network
    // stack, the stream or the decoder raises here is one failed image, never a
    // lost background task.
    on Exception do
    begin
      Result.Data := nil;
      Result.Status := TFetchStatus.Failed;
    end;
  end;
end;

class function TMarkdownImageDownloader.IsRedirect(const StatusCode: Integer): Boolean;
begin
  for var Code in RedirectStatusCodes do
  begin
    if Code = StatusCode then
      Exit(True);
  end;

  Result := False;
end;

class function TMarkdownImageDownloader.IsHttpAddress(const Url: string): Boolean;
begin
  Result := Url.StartsWith(HttpSchemePrefix, True) or Url.StartsWith(HttpsSchemePrefix, True);
end;

// Resolves what a Location header may abbreviate: a full address, one that
// borrows the scheme, one rooted at the host, or one relative to the folder of
// the address just requested.
class function TMarkdownImageDownloader.ResolvedLocation(const BaseUrl, Location: string): string;
begin
  if Location.Contains(SchemeSeparator) then
    Exit(Location);

  const SchemeEnd = BaseUrl.IndexOf(SchemeSeparator);
  if SchemeEnd < 0 then
    Exit('');

  if Location.StartsWith(SchemeRelativePrefix) then
    Exit(BaseUrl.Substring(0, SchemeEnd + 1) + Location);

  const HostStart = SchemeEnd + Length(SchemeSeparator);
  var HostEnd := BaseUrl.IndexOf(PathSeparator, HostStart);
  if HostEnd < 0 then
    HostEnd := BaseUrl.Length;

  if Location.StartsWith(PathSeparator) then
    Exit(BaseUrl.Substring(0, HostEnd) + Location);

  const LastSeparator = BaseUrl.LastIndexOf(PathSeparator);
  if LastSeparator < HostEnd then
    Exit(BaseUrl.Substring(0, HostEnd) + PathSeparator + Location);

  Result := BaseUrl.Substring(0, LastSeparator + 1) + Location;
end;

procedure TMarkdownImageDownloader.HandleDownloadResult(const Generation: Integer;
  const Pending: TPendingDownload; const Fetch: TFetchResult);
begin
  Dec(FActiveCount);

  const IsCurrent = (Generation = FGeneration);
  if IsCurrent then
  begin
    case Fetch.Status of
      TFetchStatus.Succeeded:
        FOnCompleted(Pending.Source, Fetch.Data);
      TFetchStatus.Redirected:
        FollowRedirect(Pending, Fetch.Location);
    else
      FOnFailed(Pending.Source);
    end;
  end;

  PumpQueue;
end;

// Runs on the thread that started the download, so the host's own judgement is
// asked where it expects to be asked.
procedure TMarkdownImageDownloader.FollowRedirect(const Pending: TPendingDownload; const Location: string);
begin
  const Target = ResolvedLocation(Pending.Url, Location);

  const Refused = (Pending.HopsLeft <= 0) or (not IsHttpAddress(Target)) or
    (Assigned(FOnAddressAllowed) and not FOnAddressAllowed(Target));
  if Refused then
  begin
    FOnFailed(Pending.Source);
    Exit;
  end;

  var Next := Pending;
  Next.Url := Target;
  Next.HopsLeft := Pending.HopsLeft - 1;
  FQueue.Enqueue(Next);
end;

end.
