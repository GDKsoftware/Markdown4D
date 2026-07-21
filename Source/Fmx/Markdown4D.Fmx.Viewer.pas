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
      CopyButtonWidth = 54;
      CopyButtonHeight = 22;
      CopyButtonMargin = 6;
      CopyButtonFontSize = 12;
      CopyButtonStrokeWidth = 1.0;
      CopyLabel = 'Copy';
      CopiedLabel = 'Copied';
      CopyFeedbackMilliseconds = 1200;
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
      FCopyFeedbackTimer: TTimer;
      FSelecting: Boolean;
      FLastMousePoint: TPointF;
      FHasLastMousePoint: Boolean;
      FCodeHoverActive: Boolean;
      FCodeHoverRect: TLayoutRectF;
      FCodeHoverText: string;
      FCopyButtonRect: TLayoutRectF;
      FCopyFeedback: Boolean;
      FPressedLinkUrl: string;
      FHoveredLinkUrl: string;
      FOnLinkClick: TMarkdownLinkClickEvent;
      FOnLinkHover: TMarkdownLinkHoverEvent;
      FOnResolveImage: TMarkdownResolveImageEvent;
      FOnScroll: TNotifyEvent;
    procedure CreateFlushTimer;
    procedure CreateCopyFeedbackTimer;
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
    procedure UpdateCodeHover(const Point: TLayoutPointF);
    procedure RefreshCodeHover;
    function PointOnCopyButton(const Point: TLayoutPointF): Boolean;
    procedure ClearCodeHover;
    procedure CopyCodeToClipboard(const Text: string);
    procedure HandleCopyFeedbackTimer(Sender: TObject);
    procedure DrawCopyButton(const Painter: IPainter);
    procedure ResolvePendingImages;
    procedure ResolvePendingImage(const Source: string);
    function TryResolveImageThroughEvent(const Source, Url: string): Boolean;
    procedure LoadLocalImage(const Source, FilePath: string);
    procedure HandleImageDataArrived(const Source: string; const Data: TBytes);
    procedure HandleImageDownloadFailed(const Source: string);
    procedure ApplyLoadedBitmap(const Source: string; const Bitmap: TBitmap);
    procedure ApplyFailedImage(const Source: string);
    procedure StoreLoadedImage(const Source: string; const Bitmap: TBitmap);
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
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.Renderer,
  Markdown4D.Viewer.Shared;

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
  CreateCopyFeedbackTimer;

  TMarkdownViewerShared.RegisterDefaultHighlighters;
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

procedure TMarkdownViewer.CreateCopyFeedbackTimer;
begin
  var TimerService: IFMXTimerService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, TimerService) then
    Exit;

  FCopyFeedbackTimer := TTimer.Create(Self);
  FCopyFeedbackTimer.Enabled := False;
  FCopyFeedbackTimer.Interval := CopyFeedbackMilliseconds;
  FCopyFeedbackTimer.OnTimer := HandleCopyFeedbackTimer;
end;

destructor TMarkdownViewer.Destroy;
begin
  FLifetime.Shutdown;
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
    RefreshCodeHover;
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
  RefreshCodeHover;
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
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard) then
    Exit;

  try
    Clipboard.SetClipboard(Selected);
  except
    on Exception do
      Exit;
  end;
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

    if FCodeHoverActive then
      DrawCopyButton(PainterLifetime);
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
  if PointOnCopyButton(Point) then
  begin
    CopyCodeToClipboard(FCodeHoverText);
    FCopyFeedback := True;
    if Assigned(FCopyFeedbackTimer) then
    begin
      FCopyFeedbackTimer.Enabled := False;
      FCopyFeedbackTimer.Enabled := True;
    end;
    RedrawContent;
    Exit;
  end;

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

  FLastMousePoint := TPointF.Create(X, Y);
  FHasLastMousePoint := True;

  const ContentPoint = ContentPointOf(X, Y);
  if FSelecting then
  begin
    FModel.SetSelectionExtent(ContentPoint);
    RedrawContent;
    Exit;
  end;

  UpdateCodeHover(ContentPoint);
  if PointOnCopyButton(ContentPoint) then
  begin
    Cursor := crHandPoint;
    Exit;
  end;

  UpdateHoverCursor(ContentPoint);
end;

procedure TMarkdownViewer.RefreshCodeHover;
begin
  if not FHasLastMousePoint then
    Exit;

  UpdateCodeHover(ContentPointOf(FLastMousePoint.X, FLastMousePoint.Y));
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

  const Notches = WheelDelta / MouseWheelDeltaPerNotch;
  SetScrollPosition(FModel.ScrollOffset - (Notches * WheelLinesPerNotch * LineScrollAmount));
  Handled := True;
end;

procedure TMarkdownViewer.DoMouseLeave;
begin
  inherited DoMouseLeave;

  Cursor := crDefault;
  SetHoveredLinkUrl('');
  FHasLastMousePoint := False;
  ClearCodeHover;
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

procedure TMarkdownViewer.UpdateCodeHover(const Point: TLayoutPointF);
begin
  var Region: TMarkdownCodeBlockRegion;
  const OverCode = FModel.TryGetCodeBlockAt(Point, Region);
  const Fits = OverCode and (Region.Rect.Width >= CopyButtonWidth + 2 * CopyButtonMargin) and
    (Region.Rect.Height >= CopyButtonHeight + CopyButtonMargin);

  if not Fits then
  begin
    if FCodeHoverActive then
    begin
      FCodeHoverActive := False;
      FCopyFeedback := False;
      RedrawContent;
    end;
    Exit;
  end;

  const Right = Region.Rect.Right - CopyButtonMargin;
  const Top = Region.Rect.Top + CopyButtonMargin;
  const ButtonRect = TLayoutRectF.Create(Right - CopyButtonWidth, Top, Right, Top + CopyButtonHeight);

  const Unchanged = FCodeHoverActive and SameValue(FCodeHoverRect.Top, Region.Rect.Top) and
    SameValue(FCodeHoverRect.Left, Region.Rect.Left) and (FCodeHoverText = Region.Text);
  if Unchanged then
    Exit;

  FCodeHoverActive := True;
  FCodeHoverRect := Region.Rect;
  FCodeHoverText := Region.Text;
  FCopyButtonRect := ButtonRect;
  FCopyFeedback := False;
  RedrawContent;
end;

function TMarkdownViewer.PointOnCopyButton(const Point: TLayoutPointF): Boolean;
begin
  Result := FCodeHoverActive and FCopyButtonRect.Contains(Point);
end;

procedure TMarkdownViewer.ClearCodeHover;
begin
  if FCodeHoverActive or FCopyFeedback then
  begin
    FCodeHoverActive := False;
    FCopyFeedback := False;
    FCodeHoverText := '';
    RedrawContent;
  end;
end;

procedure TMarkdownViewer.CopyCodeToClipboard(const Text: string);
begin
  if Text = '' then
    Exit;

  var Clip: IFMXClipboardService;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clip) then
    Exit;

  try
    Clip.SetClipboard(Text);
  except
    on Exception do
      Exit;
  end;
end;

procedure TMarkdownViewer.HandleCopyFeedbackTimer(Sender: TObject);
begin
  FCopyFeedback := False;
  if Assigned(FCopyFeedbackTimer) then
    FCopyFeedbackTimer.Enabled := False;
  RedrawContent;
end;

procedure TMarkdownViewer.DrawCopyButton(const Painter: IPainter);
begin
  var Caption := CopyLabel;
  if FCopyFeedback then
    Caption := CopiedLabel;

  const Font = TMarkdownFontStyle.Create(FTheme.BaseFont.FamilyName, CopyButtonFontSize);

  Painter.FillRect(FCopyButtonRect, FTheme.BackgroundColor);
  Painter.DrawRect(FCopyButtonRect, FTheme.TableBorderColor, CopyButtonStrokeWidth);

  const Size = Painter.MeasureText(Caption, Font);
  const Tx = FCopyButtonRect.Left + (CopyButtonWidth - Size.Width) / 2;
  const Ty = FCopyButtonRect.Top + (CopyButtonHeight - Painter.LineHeight(Font)) / 2;

  var LabelColor := FTheme.BlockQuoteTextColor;
  if FCopyFeedback then
    LabelColor := FTheme.LinkColor;

  Painter.DrawTextRun(TLayoutPointF.Create(Tx, Ty), Caption, Font, LabelColor);
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
  if not TMarkdownViewerShared.TryResolveImageUrl(Source, FImages.BaseUrl, FDocumentFolder, Url) then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  if TryResolveImageThroughEvent(Source, Url) then
    Exit;

  if TMarkdownViewerShared.IsHttpUrl(Url) then
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
  ClearCodeHover;
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
  ClearCodeHover;
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
  ClearCodeHover;
  FModel.ApplyTheme(FTheme);
  RedrawContent;
end;

function TMarkdownViewer.GetSelectedText: string;
begin
  Result := FModel.SelectedText;
end;

end.
