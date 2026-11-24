unit Markdown4D.Tests.FmxExtendedClipboard;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  FMX.Clipboard,
  FMX.Surfaces,
  Markdown4D.Tests.FmxClipboard;

type
  // The in-memory clipboard with the extended service FMX's own services
  // offer, for the tests that need its HasText. HasText answers from
  // HasTextFormat, as FMX's service for Windows answers from the formats on
  // the clipboard whatever a read gives. The members no test uses raise.
  TFakeExtendedClipboardService = class(TFakeClipboardService, IFMXExtendedClipboardService)
  private
    const
      UnusedMemberMessage = 'The fake clipboard does not offer %s';
    var
      FHasTextFormat: Boolean;

  public
    function HasText: Boolean;
    function GetText: string;
    procedure SetText(const Value: string; IsSensitive: Boolean = False);
    function HasImage: Boolean;
    function GetImage: TBitmapSurface;
    procedure SetImage(const Value: TBitmapSurface);
    procedure RegisterCustomFormat(const FormatName: string);
    function IsCustomFormatRegistered(const FormatName: string): Boolean;
    procedure UnregisterCustomFormat(const FormatName: string);
    function HasCustomFormat(const FormatName: string): Boolean;
    function GetCustomFormat(const FormatName: string; const Stream: TStream): Boolean;
    procedure SetCustomFormat(const FormatName: string; const Stream: TStream);
    property HasTextFormat: Boolean read FHasTextFormat write FHasTextFormat;
  end;

implementation

uses
  System.SysUtils;

function TFakeExtendedClipboardService.HasText: Boolean;
begin
  Result := FHasTextFormat;
end;

function TFakeExtendedClipboardService.GetText: string;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['GetText']);
end;

procedure TFakeExtendedClipboardService.SetText(const Value: string; IsSensitive: Boolean);
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['SetText']);
end;

function TFakeExtendedClipboardService.HasImage: Boolean;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['HasImage']);
end;

function TFakeExtendedClipboardService.GetImage: TBitmapSurface;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['GetImage']);
end;

procedure TFakeExtendedClipboardService.SetImage(const Value: TBitmapSurface);
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['SetImage']);
end;

procedure TFakeExtendedClipboardService.RegisterCustomFormat(const FormatName: string);
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['RegisterCustomFormat']);
end;

function TFakeExtendedClipboardService.IsCustomFormatRegistered(const FormatName: string): Boolean;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['IsCustomFormatRegistered']);
end;

procedure TFakeExtendedClipboardService.UnregisterCustomFormat(const FormatName: string);
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['UnregisterCustomFormat']);
end;

function TFakeExtendedClipboardService.HasCustomFormat(const FormatName: string): Boolean;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['HasCustomFormat']);
end;

function TFakeExtendedClipboardService.GetCustomFormat(const FormatName: string; const Stream: TStream): Boolean;
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['GetCustomFormat']);
end;

procedure TFakeExtendedClipboardService.SetCustomFormat(const FormatName: string; const Stream: TStream);
begin
  raise ENotImplemented.CreateFmt(UnusedMemberMessage, ['SetCustomFormat']);
end;

end.
