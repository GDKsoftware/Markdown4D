unit Markdown4D.Vcl.Viewer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Markdown4D.Layout.Interfaces,
  Markdown4D.Layout.DisplayList,
  Markdown4D.Theme,
  Markdown4D.Viewer.Model,
  Markdown4D.Viewer.ImageDownloader,
  Markdown4D.Viewer.ImageSettings,
  Markdown4D.Viewer.Lifetime,
  Markdown4D.Image.Svg,
  Markdown4D.Vcl.Painter;

type
  TMarkdownLinkClickEvent = procedure(const Sender: TObject; const Url: string) of object;

  TMarkdownLinkHoverEvent = procedure(const Sender: TObject; const Url: string) of object;

  TMarkdownResolveImageEvent = procedure(const Sender: TObject; const Url: string; const Picture: TPicture;
    var Handled: Boolean) of object;

  // Republished from the shared layer so existing code keeps finding the type
  // through this unit.
  TMarkdownViewerImageSettings = Markdown4D.Viewer.ImageSettings.TMarkdownViewerImageSettings;

  // Vetoes or permits one remote image, starting from Images.AllowRemote. Use it
  // to decide per address, for instance to allow only hosts the application
  // knows.
  TMarkdownRemoteImageEvent = procedure(const Sender: TObject; const Url: string;
    var Allow: Boolean) of object;

  TMarkdownViewer = class(TCustomControl)
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
      FMeasurePainter: TMarkdownVclPainter;
      FMeasurePainterLifetime: IPainter;
      FBuffer: TBitmap;
      FFlushTimer: TTimer;
      FLoadedImages: TObjectDictionary<string, TGraphic>;
      FSelecting: Boolean;
      FLastMousePoint: TPoint;
      FHasLastMousePoint: Boolean;
      FCodeHoverActive: Boolean;
      FCodeHoverRect: TLayoutRectF;
      FCodeHoverText: string;
      FCopyButtonRect: TLayoutRectF;
      FCopyFeedback: Boolean;
      FCopyFeedbackTimer: TTimer;
      FPressedLinkUrl: string;
      FHoveredLinkUrl: string;
      FOnLinkClick: TMarkdownLinkClickEvent;
      FOnLinkHover: TMarkdownLinkHoverEvent;
      FOnResolveImage: TMarkdownResolveImageEvent;
      FOnRemoteImageRequest: TMarkdownRemoteImageEvent;
      FOnScroll: TNotifyEvent;
    function InvokeOnMainThread(const Action: TThreadProcedure): Boolean;
    procedure HandleFlushTimer(Sender: TObject);
    procedure ResolvePendingImages;
    procedure ResolvePendingImage(const Source: string);
    function TryResolveImageThroughEvent(const Source, Url: string): Boolean;
    function AllowsRemoteImage(const Url: string): Boolean;
    procedure LoadLocalImage(const Source, FilePath: string);
    procedure HandleImageDataArrived(const Source: string; const Data: TBytes);
    procedure HandleImageDownloadFailed(const Source: string);
    function TryLoadSvg(const Source: string; const Data: TBytes): Boolean;
    procedure ApplyLoadedPicture(const Source: string; const Picture: TPicture);
    procedure ApplyFailedImage(const Source: string);
    procedure StoreLoadedImage(const Source: string; const Graphic: TGraphic);
    function ResolveLoadedImage(const Source: string): TGraphic;
    function IsImageBroken(const Source: string): Boolean;
    procedure RenderToBuffer;
    procedure EnsureBufferSize;
    procedure ScrollToBottom;
    procedure SetScrollPosition(const Value: Single);
    procedure UpdateScrollBar;
    function LineScrollAmount: Integer;
    function ContentPointOf(const X, Y: Integer): TLayoutPointF;
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
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure ChangeScale(Multiplier, Divider: Integer; IsDpiChange: Boolean); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;

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
    property Constraints;
    property Enabled;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnLinkClick: TMarkdownLinkClickEvent read FOnLinkClick write FOnLinkClick;
    property OnLinkHover: TMarkdownLinkHoverEvent read FOnLinkHover write FOnLinkHover;
    property OnResolveImage: TMarkdownResolveImageEvent read FOnResolveImage write FOnResolveImage;
    property OnRemoteImageRequest: TMarkdownRemoteImageEvent read FOnRemoteImageRequest
      write FOnRemoteImageRequest;
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
  end;

implementation

uses
  Markdown4D.DesignSample,
  System.Math,
  System.UITypes,
  System.IOUtils,
  Vcl.Clipbrd,
  Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.GIFImg,
  Markdown4D.Image.Svg.Native,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Layout.Defaults,
  Markdown4D.Layout.HitTest,
  Markdown4D.Layout.Renderer,
  Markdown4D.Viewer.Shared;


constructor TMarkdownViewer.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  FLifetime := TMarkdownViewerLifetime.Create;

  ControlStyle := ControlStyle + [csOpaque];
  Width := DefaultControlWidth;
  Height := DefaultControlHeight;
  TabStop := True;

  FImages := TMarkdownViewerImageSettings.Create;
  FTheme := TMarkdownTheme.CreateLight;
  FOwnsTheme := True;
  FLoadedImages := TObjectDictionary<string, TGraphic>.Create([doOwnsValues]);
  FRequestedImageSources := TDictionary<string, Boolean>.Create;
  FImageDownloader := TMarkdownImageDownloader.Create(HandleImageDataArrived, HandleImageDownloadFailed);
  FImageDownloader.OnAddressAllowed := AllowsRemoteImage;

  FMeasureBitmap := TBitmap.Create;
  FMeasureBitmap.SetSize(1, 1);
  FMeasurePainter := TMarkdownVclPainter.Create(FMeasureBitmap.Canvas, CurrentPPI);
  FMeasurePainterLifetime := FMeasurePainter;
  FModel := TMarkdownViewerModel.Create(FTheme, FMeasurePainterLifetime);

  FBuffer := TBitmap.Create;

  FFlushTimer := TTimer.Create(Self);
  FFlushTimer.Enabled := False;
  FFlushTimer.Interval := FlushTimerIntervalMilliseconds;
  FFlushTimer.OnTimer := HandleFlushTimer;

  FCopyFeedbackTimer := TTimer.Create(Self);
  FCopyFeedbackTimer.Enabled := False;
  FCopyFeedbackTimer.Interval := CopyFeedbackMilliseconds;
  FCopyFeedbackTimer.OnTimer := HandleCopyFeedbackTimer;

  TMarkdownViewerShared.RegisterDefaultHighlighters;
end;

function TMarkdownViewer.InvokeOnMainThread(const Action: TThreadProcedure): Boolean;
begin
  if GetCurrentThreadId = MainThreadID then
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

destructor TMarkdownViewer.Destroy;
begin
  FLifetime.Shutdown;
  FImageDownloader.Free;
  FRequestedImageSources.Free;
  FModel.Free;
  FMeasurePainter := nil;
  FMeasurePainterLifetime := nil;
  FMeasureBitmap.Free;
  FBuffer.Free;
  FLoadedImages.Free;
  if FOwnsTheme then
    FTheme.Free;
  FImages.Free;

  inherited Destroy;
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

  FModel.AppendMarkdown(Markdown, Int64(GetTickCount64));
  FFlushTimer.Enabled := True;
end;

procedure TMarkdownViewer.HandleFlushTimer(Sender: TObject);
begin
  const Flushed = FModel.TryFlush(Int64(GetTickCount64));
  if Flushed then
  begin
    if FModel.ShouldAutoFollow then
      ScrollToBottom;
    ResolvePendingImages;
    RefreshCodeHover;
    UpdateScrollBar;
    Invalidate;
  end;

  if not FModel.IsDirty then
    FFlushTimer.Enabled := False;
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

  try
    Clipboard.AsText := Selected;
  except
    on EClipboardException do
      Exit;
  end;
end;

procedure TMarkdownViewer.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);

  Params.Style := Params.Style or WS_VSCROLL;
end;

procedure TMarkdownViewer.CreateWnd;
begin
  inherited CreateWnd;

  EnsureDesignSample;

  FModel.SetViewport(ClientWidth, ClientHeight);
  ResolvePendingImages;
  UpdateScrollBar;
end;

procedure TMarkdownViewer.Resize;
begin
  inherited Resize;

  FModel.SetViewport(ClientWidth, ClientHeight);
  ResolvePendingImages;
  UpdateScrollBar;
  Invalidate;
end;

procedure TMarkdownViewer.ChangeScale(Multiplier, Divider: Integer; IsDpiChange: Boolean);
begin
  inherited ChangeScale(Multiplier, Divider, IsDpiChange);

  FMeasurePainter.PixelsPerInch := CurrentPPI;
  FModel.RefreshLayout;
  UpdateScrollBar;
  Invalidate;
end;

procedure TMarkdownViewer.Paint;
begin
  EnsureDesignSample;
  EnsureBufferSize;
  RenderToBuffer;
  Canvas.Draw(0, 0, FBuffer);
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
  UpdateScrollBar;
end;

procedure TMarkdownViewer.EnsureBufferSize;
begin
  const BufferWidth = Max(1, ClientWidth);
  const BufferHeight = Max(1, ClientHeight);
  const SizeChanged = (FBuffer.Width <> BufferWidth) or (FBuffer.Height <> BufferHeight);
  if SizeChanged then
    FBuffer.SetSize(BufferWidth, BufferHeight);
end;

procedure TMarkdownViewer.RenderToBuffer;
begin
  const Painter = TMarkdownVclPainter.Create(FBuffer.Canvas, CurrentPPI);
  const PainterLifetime: IPainter = Painter;
  Painter.ImageResolver := ResolveLoadedImage;
  Painter.BrokenImageQuery := IsImageBroken;

  const ScrollY = Round(FModel.ScrollOffset);
  SetWindowOrgEx(FBuffer.Canvas.Handle, 0, ScrollY, nil);
  try
    const Viewport = TLayoutRectF.Create(0, ScrollY, ClientWidth, ScrollY + ClientHeight);
    TMarkdownDisplayListRenderer.Render(FModel.DisplayList, PainterLifetime, Viewport, FTheme.BackgroundColor);

    for var SelectionRect in FModel.SelectionRects do
    begin
      PainterLifetime.FillRect(SelectionRect, SelectionFillColor);
    end;

    if FCodeHoverActive then
      DrawCopyButton(PainterLifetime);
  finally
    SetWindowOrgEx(FBuffer.Canvas.Handle, 0, 0, nil);
  end;
end;

function TMarkdownViewer.ResolveLoadedImage(const Source: string): TGraphic;
begin
  if not FLoadedImages.TryGetValue(Source, Result) then
    Result := nil;
end;

function TMarkdownViewer.IsImageBroken(const Source: string): Boolean;
begin
  Result := FModel.ImageSlotState(Source) = TMarkdownImageSlotState.Failed;
end;

procedure TMarkdownViewer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button <> TMouseButton.mbLeft then
    Exit;

  SetFocus;

  const Point = ContentPointOf(X, Y);
  if PointOnCopyButton(Point) then
  begin
    CopyCodeToClipboard(FCodeHoverText);
    FCopyFeedback := True;
    FCopyFeedbackTimer.Enabled := False;
    FCopyFeedbackTimer.Enabled := True;
    Invalidate;
    Exit;
  end;

  if TryFindLinkUrl(Point, FPressedLinkUrl) then
    Exit;

  FPressedLinkUrl := '';
  FSelecting := True;
  FModel.SetSelectionAnchor(Point);
  Invalidate;
end;

procedure TMarkdownViewer.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);

  FLastMousePoint := Point(X, Y);
  FHasLastMousePoint := True;

  const ContentPoint = ContentPointOf(X, Y);
  if FSelecting then
  begin
    FModel.SetSelectionExtent(ContentPoint);
    Invalidate;
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

procedure TMarkdownViewer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
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

function TMarkdownViewer.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  const Notches = WheelDelta / WHEEL_DELTA;
  SetScrollPosition(FModel.ScrollOffset - (Notches * WheelLinesPerNotch * LineScrollAmount));

  Result := True;
end;

procedure TMarkdownViewer.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  case Key of
    VK_UP:
      SetScrollPosition(FModel.ScrollOffset - LineScrollAmount);
    VK_DOWN:
      SetScrollPosition(FModel.ScrollOffset + LineScrollAmount);
    VK_PRIOR:
      SetScrollPosition(FModel.ScrollOffset - ClientHeight);
    VK_NEXT:
      SetScrollPosition(FModel.ScrollOffset + ClientHeight);
    VK_HOME:
      SetScrollPosition(0);
    VK_END:
      ScrollToBottom;
    Ord('C'):
      if ssCtrl in Shift then
        CopySelectionToClipboard;
  end;
end;

procedure TMarkdownViewer.WMVScroll(var Message: TWMVScroll);
begin
  case Message.ScrollCode of
    SB_LINEUP:
      SetScrollPosition(FModel.ScrollOffset - LineScrollAmount);
    SB_LINEDOWN:
      SetScrollPosition(FModel.ScrollOffset + LineScrollAmount);
    SB_PAGEUP:
      SetScrollPosition(FModel.ScrollOffset - ClientHeight);
    SB_PAGEDOWN:
      SetScrollPosition(FModel.ScrollOffset + ClientHeight);
    SB_TOP:
      SetScrollPosition(0);
    SB_BOTTOM:
      ScrollToBottom;
    SB_THUMBPOSITION, SB_THUMBTRACK:
      begin
        var Info := Default(TScrollInfo);
        Info.cbSize := SizeOf(Info);
        Info.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Handle, SB_VERT, Info) then
          SetScrollPosition(Info.nTrackPos);
      end;
  end;

  Message.Result := 0;
end;

procedure TMarkdownViewer.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TMarkdownViewer.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS;
end;

procedure TMarkdownViewer.CMMouseLeave(var Message: TMessage);
begin
  inherited;

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
  UpdateScrollBar;
  Invalidate;

  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TMarkdownViewer.UpdateScrollBar;
begin
  if not HandleAllocated then
    Exit;

  var ContentHeight := 0;
  if FModel.DisplayList <> nil then
    ContentHeight := Round(FModel.DisplayList.Height);

  var Info := Default(TScrollInfo);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  Info.nMin := 0;
  Info.nMax := Max(0, ContentHeight - 1);
  Info.nPage := ClientHeight;
  Info.nPos := Round(FModel.ScrollOffset);
  SetScrollInfo(Handle, SB_VERT, Info, True);
end;

function TMarkdownViewer.LineScrollAmount: Integer;
begin
  Result := MulDiv(ScrollLineDips, CurrentPPI, ReferencePixelsPerInch);
end;

function TMarkdownViewer.ContentPointOf(const X, Y: Integer): TLayoutPointF;
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
      Invalidate;
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
  Invalidate;
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
    Invalidate;
  end;
end;

procedure TMarkdownViewer.CopyCodeToClipboard(const Text: string);
begin
  if Text = '' then
    Exit;

  try
    Clipboard.AsText := Text;
  except
    on EClipboardException do
      Exit;
  end;
end;

procedure TMarkdownViewer.HandleCopyFeedbackTimer(Sender: TObject);
begin
  FCopyFeedback := False;
  FCopyFeedbackTimer.Enabled := False;
  Invalidate;
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
  const Resolved = TMarkdownViewerShared.TryResolveImageUrl(Source, FImages.BaseUrl, FDocumentFolder,
    FImages.RestrictToDocumentFolder, Url);
  if not Resolved then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  if TryResolveImageThroughEvent(Source, Url) then
    Exit;

  if TMarkdownViewerShared.IsHttpUrl(Url) then
  begin
    if not AllowsRemoteImage(Url) then
    begin
      ApplyFailedImage(Source);
      Exit;
    end;

    FRequestedImageSources.Add(Source, True);
    FImageDownloader.Download(Source, Url, FImages.MaxBytes);
    Exit;
  end;

  LoadLocalImage(Source, Url);
end;

// Starts from the setting and lets the application narrow or widen it per
// address, which is the point of having the event at all.
function TMarkdownViewer.AllowsRemoteImage(const Url: string): Boolean;
begin
  Result := FImages.AllowRemote;

  if Assigned(FOnRemoteImageRequest) then
    FOnRemoteImageRequest(Self, Url, Result);
end;

function TMarkdownViewer.TryResolveImageThroughEvent(const Source, Url: string): Boolean;
begin
  if not Assigned(FOnResolveImage) then
    Exit(False);

  const Picture = TPicture.Create;
  try
    var Handled := False;
    FOnResolveImage(Self, Url, Picture, Handled);
    if not Handled then
      Exit(False);

    ApplyLoadedPicture(Source, Picture);
    Result := True;
  finally
    Picture.Free;
  end;
end;

procedure TMarkdownViewer.LoadLocalImage(const Source, FilePath: string);
begin
  if not TFile.Exists(FilePath) then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  if TMarkdownSvgSupport.IsAvailable then
  begin
    const FileData = TFile.ReadAllBytes(FilePath);
    if TMarkdownSvgSupport.LooksLikeSvg(FileData) then
    begin
      if not TryLoadSvg(Source, FileData) then
        ApplyFailedImage(Source);
      Exit;
    end;
  end;

  const Picture = TPicture.Create;
  try
    try
      Picture.LoadFromFile(FilePath);
    except
      on Exception do
      begin
        ApplyFailedImage(Source);
        Exit;
      end;
    end;

    ApplyLoadedPicture(Source, Picture);
  finally
    Picture.Free;
  end;
end;

procedure TMarkdownViewer.HandleImageDataArrived(const Source: string; const Data: TBytes);
begin
  FRequestedImageSources.Remove(Source);

  if TMarkdownSvgSupport.IsAvailable and TMarkdownSvgSupport.LooksLikeSvg(Data) then
  begin
    if not TryLoadSvg(Source, Data) then
      ApplyFailedImage(Source);
    Exit;
  end;

  const Picture = TPicture.Create;
  try
    const Stream = TBytesStream.Create(Data);
    try
      try
        Picture.LoadFromStream(Stream);
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

    ApplyLoadedPicture(Source, Picture);
  finally
    Picture.Free;
  end;
end;

procedure TMarkdownViewer.HandleImageDownloadFailed(const Source: string);
begin
  FRequestedImageSources.Remove(Source);
  ApplyFailedImage(Source);
end;

function TMarkdownViewer.TryLoadSvg(const Source: string; const Data: TBytes): Boolean;
begin
  var Raster: TMarkdownSvgRaster;
  if not TMarkdownSvgSupport.TryRasterize(Data, 0, 0, Raster) then
    Exit(False);

  const Picture = TPicture.Create;
  try
    const Bitmap = TBitmap.Create;
    try
      Bitmap.PixelFormat := pf32bit;
      Bitmap.SetSize(Raster.Width, Raster.Height);
      Bitmap.AlphaFormat := afPremultiplied;

      const RowBytes = Raster.Width * 4;
      for var Y := 0 to Raster.Height - 1 do
      begin
        const DestRow: PByte = Bitmap.ScanLine[Y];
        System.Move(Raster.Pixels[Y * RowBytes], DestRow^, RowBytes);
      end;

      Picture.Bitmap.Assign(Bitmap);
    finally
      Bitmap.Free;
    end;

    ApplyLoadedPicture(Source, Picture);
  finally
    Picture.Free;
  end;

  Result := True;
end;

procedure TMarkdownViewer.ApplyLoadedPicture(const Source: string; const Picture: TPicture);
begin
  const HasGraphic = (Picture.Graphic <> nil) and not Picture.Graphic.Empty;
  if not HasGraphic then
  begin
    ApplyFailedImage(Source);
    Exit;
  end;

  StoreLoadedImage(Source, Picture.Graphic);
  FModel.NotifyImageArrived(Source, TLayoutSizeF.Create(Picture.Graphic.Width, Picture.Graphic.Height));
  UpdateScrollBar;
  Invalidate;
end;

procedure TMarkdownViewer.ApplyFailedImage(const Source: string);
begin
  FModel.NotifyImageFailed(Source);
  Invalidate;
end;

procedure TMarkdownViewer.StoreLoadedImage(const Source: string; const Graphic: TGraphic);
begin
  const Clone = TGraphicClass(Graphic.ClassType).Create;
  try
    Clone.Assign(Graphic);
  except
    Clone.Free;
    raise;
  end;

  FLoadedImages.AddOrSetValue(Source, Clone);
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
  UpdateScrollBar;
  Invalidate;
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
  UpdateScrollBar;
  Invalidate;
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
  UpdateScrollBar;
  Invalidate;
end;

function TMarkdownViewer.GetSelectedText: string;
begin
  Result := FModel.SelectedText;
end;

end.
