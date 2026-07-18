unit Markdown4D.Fmx.Viewer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model,
  Markdown4D.Viewer.ImageDownloader,
  Markdown4D.Viewer.Lifetime,
  Markdown4D.Fmx.Painter;

type
  TMarkdownLinkClickEvent = procedure(const Sender: TObject; const Url: string) of object;

  TMarkdownLinkHoverEvent = procedure(const Sender: TObject; const Url: string) of object;

  TMarkdownResolveImageEvent = procedure(const Sender: TObject; const Url: string; const Bitmap: TBitmap;
    var Handled: Boolean) of object;

  TMarkdownViewerImageSettings = class(TPersistent)
  private
    FBaseUrl: string;

  public
    procedure Assign(Source: TPersistent); override;

  published
    property BaseUrl: string read FBaseUrl write FBaseUrl;
  end;

  TMarkdownViewer = class(TControl)
  private
    const
      DefaultControlWidth = 300;
      DefaultControlHeight = 200;
      SelectionFillColor = TLayoutColor($402F81F7);
    var
      FLifetime: IMarkdownViewerLifetime;
      FImages: TMarkdownViewerImageSettings;
      FDocumentFolder: string;
      FImageDownloader: TMarkdownImageDownloader;
      FRequestedImageSources: TDictionary<string, Boolean>;
      FTheme: TMarkdownTheme;
      FOwnsTheme: Boolean;
      FThemePreset: TMarkdownThemePreset;
      FDesignSampleActive: Boolean;
      FModel: TMarkdownViewerModel;
      FMeasureBitmap: TBitmap;
      FMeasurePainter: TMarkdownFmxPainter;
      FMeasurePainterLifetime: IPainter;
      FLoadedImages: TObjectDictionary<string, TBitmap>;
      FFlushTimer: TTimer;
      FSelecting: Boolean;
      FPressedLinkUrl: string;
      FHoveredLinkUrl: string;
      FOnLinkClick: TMarkdownLinkClickEvent;
      FOnLinkHover: TMarkdownLinkHoverEvent;
      FOnResolveImage: TMarkdownResolveImageEvent;
      FOnScroll: TNotifyEvent;
    procedure RegisterDefaultHighlighters;
    procedure CreateFlushTimer;
    function InvokeOnMainThread(const Action: TThreadProcedure): Boolean;
    procedure HandleFlushTimer(Sender: TObject);
    procedure FlushImmediately;
    procedure RedrawContent;
    procedure ApplyViewport;
    procedure ScrollToBottom;
    procedure SetScrollPosition(const Value: Single);
    function LineScrollAmount: Single;
    function ContentPointOf(const X, Y: Single): TLayoutPointF;
    procedure UpdateHoverCursor(const Point: TLayoutPointF);
    procedure SetHoveredLinkUrl(const Value: string);
    function TryFindLinkUrl(const Point: TLayoutPointF; out Url: string): Boolean;
    procedure ResolvePendingImages;
    procedure ResolvePendingImage(const Source: string);
    function TryResolveImageThroughEvent(const Source, Url: string): Boolean;
    procedure LoadLocalImage(const Source, FilePath: string);
    procedure HandleImageDataArrived(const Source: string; const Data: TBytes);
    procedure HandleImageDownloadFailed(const Source: string);
    procedure ApplyLoadedBitmap(const Source: string; const Bitmap: TBitmap);
    procedure ApplyFailedImage(const Source: string);
    procedure StoreLoadedImage(const Source: string; const Bitmap: TBitmap);
    function TryResolveImageUrl(const Source: string; out Url: string): Boolean;
    class function IsHttpUrl(const Url: string): Boolean;
    function ResolveLoadedImage(const Source: string): TBitmap;
    function IsImageBroken(const Source: string): Boolean;
    function GetContentHeight: Integer;
    function GetScrollOffset: Single;
    function GetDisplayList: IMarkdownDisplayList;
    function GetText: string;
    procedure SetText(const Value: string);
    procedure SetImages(const Value: TMarkdownViewerImageSettings);
    function IsTextStored: Boolean;
    procedure SetThemePreset(const Value: TMarkdownThemePreset);
    procedure EnsureDesignSample;
    procedure SetTheme(const Value: TMarkdownTheme);
    function GetSelectedText: string;

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure DoMouseLeave; override;

  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(const Stream: TStream);
    procedure AppendMarkdown(const Markdown: string);
    function FindText(const Needle: string): Boolean;
    procedure CopySelectionToClipboard;
    property Theme: TMarkdownTheme read FTheme write SetTheme;
    property ContentHeight: Integer read GetContentHeight;
    property ScrollOffset: Single read GetScrollOffset write SetScrollPosition;
    property DisplayList: IMarkdownDisplayList read GetDisplayList;
    property SelectedText: string read GetSelectedText;

  published
    property Text: string read GetText write SetText stored IsTextStored;
    property ThemePreset: TMarkdownThemePreset read FThemePreset write SetThemePreset
      default TMarkdownThemePreset.Light;
    property Images: TMarkdownViewerImageSettings read FImages write SetImages;
    property Align;
    property Anchors;
    property Cursor;
    property Enabled;
    property Height;
    property HitTest;
    property Margins;
    property Opacity;
    property Padding;
    property PopupMenu;
    property Position;
    property Size;
    property TabOrder;
    property Visible;
    property Width;
    property OnLinkClick: TMarkdownLinkClickEvent read FOnLinkClick write FOnLinkClick;
    property OnLinkHover: TMarkdownLinkHoverEvent read FOnLinkHover write FOnLinkHover;
    property OnResolveImage: TMarkdownResolveImageEvent read FOnResolveImage write FOnResolveImage;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
  end;

implementation

uses
  Markdown4D.DesignSample,
  System.Math,
  System.Rtti,
  System.IOUtils,
  System.Math.Vectors,
  FMX.Platform,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Defines,
  Markdown4D.Highlighter.Interfaces,
  Markdown4D.Highlighter.Pascal,
  Markdown4D.Highlighter.Sql,
  Markdown4D.Highlighter.Json,
  Markdown4D.Highlighter.Xml,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.Renderer;

procedure TMarkdownViewerImageSettings.Assign(Source: TPersistent);
begin
  if Source is TMarkdownViewerImageSettings then
    FBaseUrl := TMarkdownViewerImageSettings(Source).FBaseUrl
  else
    inherited Assign(Source);
end;

constructor TMarkdownViewer.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FLifetime := TMarkdownViewerLifetime.Create;

  Width := DefaultControlWidth;
  Height := DefaultControlHeight;
  HitTest := True;
  CanFocus := True;
  AutoCapture := True;

  FImages := TMarkdownViewerImageSettings.Create;
  FTheme := TMarkdownTheme.CreateLight;
  FOwnsTheme := True;
  FLoadedImages := TObjectDictionary<string, TBitmap>.Create([doOwnsValues]);
  FRequestedImageSources := TDictionary<string, Boolean>.Create;
  FImageDownloader := TMarkdownImageDownloader.Create(HandleImageDataArrived, HandleImageDownloadFailed);

  FMeasureBitmap := TBitmap.Create(1, 1);
  FMeasurePainter := TMarkdownFmxPainter.Create(FMeasureBitmap.Canvas);
  FMeasurePainterLifetime := FMeasurePainter;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurePainterLifetime);

  CreateFlushTimer;

  RegisterDefaultHighlighters;
  ApplyViewport;
end;

procedure TMarkdownViewer.CreateFlushTimer;
begin
  var TimerService: IFMXTimerService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, TimerService) then
    Exit;

  FFlushTimer := TTimer.Create(Self);
  FFlushTimer.Enabled := False;
  FFlushTimer.Interval := FlushTimerIntervalMilliseconds;
  FFlushTimer.OnTimer := HandleFlushTimer;
end;

destructor TMarkdownViewer.Destroy;
begin
  FLifetime.Kill;
  FImageDownloader.Free;
  FRequestedImageSources.Free;
  FModel.Free;
  FMeasurePainter := nil;
  FMeasurePainterLifetime := nil;
  FMeasureBitmap.Free;
  FLoadedImages.Free;
  if FOwnsTheme then
    FTheme.Free;
  FImages.Free;

  inherited Destroy;
end;

procedure TMarkdownViewer.RegisterDefaultHighlighters;
begin
  var Existing: IMarkdownSyntaxHighlighter;

  if not THighlighterRegistry.TryGet(PascalLanguageName, Existing) then
    THighlighterRegistry.Register(PascalLanguageName, TPascalSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(SqlLanguageName, Existing) then
    THighlighterRegistry.Register(SqlLanguageName, TSqlSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(JsonLanguageName, Existing) then
    THighlighterRegistry.Register(JsonLanguageName, TJsonSyntaxHighlighter.Create);

  if not THighlighterRegistry.TryGet(XmlLanguageName, Existing) then
    THighlighterRegistry.Register(XmlLanguageName, TXmlSyntaxHighlighter.Create);
end;

function TMarkdownViewer.InvokeOnMainThread(const Action: TThreadProcedure): Boolean;
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    Exit(False);

  const Lifetime = FLifetime;
  TThread.Queue(nil,
    procedure
    begin
      if Lifetime.IsAlive then
        Action();
    end);
  Result := True;
end;

procedure TMarkdownViewer.LoadFromFile(const FileName: string);
begin
  FDocumentFolder := TPath.GetDirectoryName(TPath.GetFullPath(FileName));

  const Reader = TStreamReader.Create(FileName, True);
  try
    Text := Reader.ReadToEnd;
  finally
    Reader.Free;
  end;
end;

procedure TMarkdownViewer.LoadFromStream(const Stream: TStream);
begin
  const Reader = TStreamReader.Create(Stream, True);
  try
    Text := Reader.ReadToEnd;
  finally
    Reader.Free;
  end;
end;

procedure TMarkdownViewer.AppendMarkdown(const Markdown: string);
begin
  if InvokeOnMainThread(
    procedure
    begin
      AppendMarkdown(Markdown);
    end) then
    Exit;

  FModel.AppendMarkdown(Markdown, Int64(TThread.GetTickCount64));
  if Assigned(FFlushTimer) then
    FFlushTimer.Enabled := True
  else
    FlushImmediately;
end;

procedure TMarkdownViewer.HandleFlushTimer(Sender: TObject);
begin
  const Flushed = FModel.TryFlush(Int64(TThread.GetTickCount64));
  if Flushed then
  begin
    if FModel.ShouldAutoFollow then
      ScrollToBottom;
    ResolvePendingImages;
    RedrawContent;
  end;

  if not FModel.IsDirty and Assigned(FFlushTimer) then
    FFlushTimer.Enabled := False;
end;

procedure TMarkdownViewer.FlushImmediately;
begin
  const Deadline = Int64(TThread.GetTickCount64) + FModel.FlushIntervalMilliseconds;
  if not FModel.TryFlush(Deadline) then
    Exit;

  if FModel.ShouldAutoFollow then
    ScrollToBottom;
  ResolvePendingImages;
  RedrawContent;
end;

function TMarkdownViewer.FindText(const Needle: string): Boolean;
begin
  const Ranges = FModel.FindText(Needle);
  Result := Length(Ranges) > 0;
  if not Result then
    Exit;

  const FirstMatch = FModel.DisplayList.Items[Ranges[0].ItemIndex];
  SetScrollPosition(FirstMatch.Bounds.Top);
end;

procedure TMarkdownViewer.CopySelectionToClipboard;
begin
  const Selected = FModel.SelectedText;
  if Selected = '' then
    Exit;

  var Clipboard: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Clipboard.SetClipboard(Selected);
end;

procedure TMarkdownViewer.Paint;
begin
  EnsureDesignSample;

  const Background = FTheme.BackgroundColor;

  const Painter = TMarkdownFmxPainter.Create(Canvas);
  const PainterLifetime: IPainter = Painter;
  Painter.ImageResolver := ResolveLoadedImage;
  Painter.BrokenImageQuery := IsImageBroken;

  const ScrollY = FModel.ScrollOffset;
  const SavedMatrix = Canvas.Matrix;
  Canvas.SetMatrix(TMatrix.CreateTranslation(0, -ScrollY) * SavedMatrix);
  try
    const Viewport = TLayoutRectF.Create(0, ScrollY, Width, ScrollY + Height);
    TMarkdownDisplayListRenderer.Render(FModel.DisplayList, PainterLifetime, Viewport, Background);

    for var SelectionRect in FModel.SelectionRects do
    begin
      PainterLifetime.FillRect(SelectionRect, SelectionFillColor);
    end;
  finally
    Canvas.SetMatrix(SavedMatrix);
  end;
end;

procedure TMarkdownViewer.EnsureDesignSample;
begin
  if not (csDesigning in ComponentState) then
    Exit;

  if FDesignSampleActive then
    Exit;

  if FModel.FullText <> '' then
    Exit;

  FDesignSampleActive := True;
  FModel.Text := TMarkdownDesignSample.Markdown;
end;

procedure TMarkdownViewer.Resize;
begin
  inherited Resize;

  if FModel = nil then
    Exit;

  ApplyViewport;
  ResolvePendingImages;
  RedrawContent;
end;

procedure TMarkdownViewer.ApplyViewport;
begin
  FModel.SetViewport(Width, Height);
end;

procedure TMarkdownViewer.RedrawContent;
begin
  if Scene <> nil then
    Repaint;
end;

procedure TMarkdownViewer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  if CanFocus then
    SetFocus;

  const Point = ContentPointOf(X, Y);
  if TryFindLinkUrl(Point, FPressedLinkUrl) then
    Exit;

  FPressedLinkUrl := '';
  FSelecting := True;
  FModel.SetSelectionAnchor(Point);
  RedrawContent;
end;

procedure TMarkdownViewer.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited MouseMove(Shift, X, Y);

  const Point = ContentPointOf(X, Y);
  if FSelecting then
  begin
    FModel.SetSelectionExtent(Point);
    RedrawContent;
    Exit;
  end;

  UpdateHoverCursor(Point);
end;

procedure TMarkdownViewer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited MouseUp(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  if FSelecting then
  begin
    FSelecting := False;
    Exit;
  end;

  if FPressedLinkUrl = '' then
    Exit;

  const PressedUrl = FPressedLinkUrl;
  FPressedLinkUrl := '';

  var ReleasedUrl: string;
  const IsSameLink = TryFindLinkUrl(ContentPointOf(X, Y), ReleasedUrl) and (ReleasedUrl = PressedUrl);
  if IsSameLink and Assigned(FOnLinkClick) then
    FOnLinkClick(Self, PressedUrl);
end;

procedure TMarkdownViewer.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  if Handled then
    Exit;

  const Notches = WheelDelta / 120;
  SetScrollPosition(FModel.ScrollOffset - (Notches * WheelLinesPerNotch * LineScrollAmount));
  Handled := True;
end;

procedure TMarkdownViewer.DoMouseLeave;
begin
  inherited DoMouseLeave;

  Cursor := crDefault;
  SetHoveredLinkUrl('');
end;

procedure TMarkdownViewer.ScrollToBottom;
begin
  if FModel.DisplayList = nil then
    Exit;

  SetScrollPosition(FModel.DisplayList.Height);
end;

procedure TMarkdownViewer.SetScrollPosition(const Value: Single);
begin
  FModel.ScrollOffset := Value;
  RedrawContent;

  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

function TMarkdownViewer.LineScrollAmount: Single;
begin
  Result := ScrollLineDips;
end;

function TMarkdownViewer.ContentPointOf(const X, Y: Single): TLayoutPointF;
begin
  Result := TLayoutPointF.Create(X, Y + FModel.ScrollOffset);
end;

procedure TMarkdownViewer.UpdateHoverCursor(const Point: TLayoutPointF);
begin
  var Url: string;
  if TryFindLinkUrl(Point, Url) then
    Cursor := crHandPoint
  else
    Cursor := crDefault;

  SetHoveredLinkUrl(Url);
end;

procedure TMarkdownViewer.SetHoveredLinkUrl(const Value: string);
begin
  if Value = FHoveredLinkUrl then
    Exit;

  FHoveredLinkUrl := Value;
  if Assigned(FOnLinkHover) then
    FOnLinkHover(Self, FHoveredLinkUrl);
end;

function TMarkdownViewer.TryFindLinkUrl(const Point: TLayoutPointF; out Url: string): Boolean;
begin
  Url := '';
  if FModel.DisplayList = nil then
    Exit(False);

  var Link: IMarkdownLink;
  Result := TMarkdownHitTester.TryFindLink(FModel.DisplayList, Point, Link);
  if Result then
    Url := Link.Destination;
end;

procedure TMarkdownViewer.ResolvePendingImages;
begin
  for var Source in FModel.PendingImageSources do
  begin
    ResolvePendingImage(Source);
  end;
end;

procedure TMarkdownViewer.ResolvePendingImage(const Source: string);
begin
  if FRequestedImageSources.ContainsKey(Source) then
    Exit;

  var Url: string;
  if not TryResolveImageUrl(Source, Url) then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  if TryResolveImageThroughEvent(Source, Url) then
    Exit;

  if IsHttpUrl(Url) then
  begin
    FRequestedImageSources.Add(Source, True);
    FImageDownloader.Download(Source, Url);
    Exit;
  end;

  LoadLocalImage(Source, Url);
end;

function TMarkdownViewer.TryResolveImageThroughEvent(const Source, Url: string): Boolean;
begin
  if not Assigned(FOnResolveImage) then
    Exit(False);

  const Bitmap = TBitmap.Create;
  try
    var Handled := False;
    FOnResolveImage(Self, Url, Bitmap, Handled);
    if not Handled then
      Exit(False);

    ApplyLoadedBitmap(Source, Bitmap);
    Result := True;
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownViewer.LoadLocalImage(const Source, FilePath: string);
begin
  if not TFile.Exists(FilePath) then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  const Bitmap = TBitmap.Create;
  try
    try
      Bitmap.LoadFromFile(FilePath);
    except
      on Exception do
      begin
        ApplyFailedImage(Source);
        Exit;
      end;
    end;

    ApplyLoadedBitmap(Source, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownViewer.HandleImageDataArrived(const Source: string; const Data: TBytes);
begin
  FRequestedImageSources.Remove(Source);

  const Bitmap = TBitmap.Create;
  try
    const Stream = TBytesStream.Create(Data);
    try
      try
        Bitmap.LoadFromStream(Stream);
      except
        on Exception do
        begin
          ApplyFailedImage(Source);
          Exit;
        end;
      end;
    finally
      Stream.Free;
    end;

    ApplyLoadedBitmap(Source, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMarkdownViewer.HandleImageDownloadFailed(const Source: string);
begin
  FRequestedImageSources.Remove(Source);
  ApplyFailedImage(Source);
end;

procedure TMarkdownViewer.ApplyLoadedBitmap(const Source: string; const Bitmap: TBitmap);
begin
  const HasBitmap = (Bitmap <> nil) and not Bitmap.IsEmpty;
  if not HasBitmap then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  StoreLoadedImage(Source, Bitmap);
  FModel.NotifyImageArrived(Source, TLayoutSizeF.Create(Bitmap.Width, Bitmap.Height));
  RedrawContent;
end;

procedure TMarkdownViewer.ApplyFailedImage(const Source: string);
begin
  FModel.NotifyImageFailed(Source);
  RedrawContent;
end;

procedure TMarkdownViewer.StoreLoadedImage(const Source: string; const Bitmap: TBitmap);
begin
  const Clone = TBitmap.Create;
  try
    Clone.Assign(Bitmap);
  except
    Clone.Free;
    raise;
  end;

  FLoadedImages.AddOrSetValue(Source, Clone);
end;

function TMarkdownViewer.TryResolveImageUrl(const Source: string; out Url: string): Boolean;
begin
  Url := Source;
  try
    if Source.Contains(UrlSchemeSeparator) then
      Exit(True);

    if FImages.BaseUrl <> '' then
    begin
      if FImages.BaseUrl.Contains(UrlSchemeSeparator) then
        Url := FImages.BaseUrl + Source
      else
        Url := TPath.Combine(FImages.BaseUrl, Source);
      Exit(True);
    end;

    const UsesDocumentFolder = (FDocumentFolder <> '') and not TPath.IsPathRooted(Source);
    if UsesDocumentFolder then
      Url := TPath.Combine(FDocumentFolder, Source);

    Result := True;
  except
    on Exception do
      Result := False;
  end;
end;

class function TMarkdownViewer.IsHttpUrl(const Url: string): Boolean;
begin
  Result := Url.StartsWith(HttpSchemePrefix, True) or Url.StartsWith(HttpsSchemePrefix, True);
end;

function TMarkdownViewer.ResolveLoadedImage(const Source: string): TBitmap;
begin
  if not FLoadedImages.TryGetValue(Source, Result) then
    Result := nil;
end;

function TMarkdownViewer.IsImageBroken(const Source: string): Boolean;
begin
  Result := FModel.ImageSlotState(Source) = TMarkdownImageSlotState.Failed;
end;

function TMarkdownViewer.GetContentHeight: Integer;
begin
  Result := 0;
  if FModel.DisplayList <> nil then
    Result := Ceil(FModel.DisplayList.Height);
end;

function TMarkdownViewer.GetScrollOffset: Single;
begin
  Result := FModel.ScrollOffset;
end;

function TMarkdownViewer.GetDisplayList: IMarkdownDisplayList;
begin
  Result := FModel.DisplayList;
end;

function TMarkdownViewer.GetText: string;
begin
  Result := FModel.FullText;
end;

procedure TMarkdownViewer.SetText(const Value: string);
begin
  if InvokeOnMainThread(
    procedure
    begin
      SetText(Value);
    end) then
    Exit;

  FDesignSampleActive := False;
  FImageDownloader.CancelPending;
  FRequestedImageSources.Clear;
  FModel.Text := Value;
  FModel.ScrollOffset := 0;
  ResolvePendingImages;
  RedrawContent;
end;

procedure TMarkdownViewer.SetImages(const Value: TMarkdownViewerImageSettings);
begin
  FImages.Assign(Value);
end;

function TMarkdownViewer.IsTextStored: Boolean;
begin
  Result := not FDesignSampleActive;
end;

procedure TMarkdownViewer.SetThemePreset(const Value: TMarkdownThemePreset);
begin
  FThemePreset := Value;

  if FOwnsTheme then
    FTheme.Free;

  FTheme := TMarkdownTheme.CreatePreset(Value);
  FOwnsTheme := True;
  FModel.ApplyTheme(FTheme);
  RedrawContent;
end;

procedure TMarkdownViewer.SetTheme(const Value: TMarkdownTheme);
begin
  const IsUnchanged = (Value = nil) or (Value = FTheme);
  if IsUnchanged then
    Exit;

  if FOwnsTheme then
    FTheme.Free;

  FTheme := Value;
  FOwnsTheme := False;
  FModel.ApplyTheme(FTheme);
  RedrawContent;
end;

function TMarkdownViewer.GetSelectedText: string;
begin
  Result := FModel.SelectedText;
end;

end.
