unit Markdown4D.Viewer.ImageSettings;

{$SCOPEDENUMS ON}

// What a viewer may do with the image destinations a document names: whether a
// remote address may be fetched at all, how large a single response may grow,
// and whether a relative path may leave the folder the document came from.
// Shared by the VCL and FMX viewers so both offer the same switches; each
// viewer republishes the type under its own unit for existing callers.

interface

uses
  System.Classes;

type
  TMarkdownViewerImageSettings = class(TPersistent)
  private
    const
      DefaultMaxBytes = 8 * 1024 * 1024;
    var
      FBaseUrl: string;
      FAllowRemote: Boolean;
      FMaxBytes: Integer;
      FRestrictToDocumentFolder: Boolean;

  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;

  published
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    // Whether http and https destinations may be fetched. Opening a document
    // tells every host it names that the document was read, so an application
    // showing documents it did not write may want this off, or may want to
    // decide per address through the viewer's OnRemoteImageRequest event.
    property AllowRemote: Boolean read FAllowRemote write FAllowRemote default True;
    // Upper bound on one downloaded image. Without it a response claiming to be
    // an image can grow until memory runs out. Zero removes the bound.
    property MaxBytes: Integer read FMaxBytes write FMaxBytes default DefaultMaxBytes;
    // Keeps a relative image path inside the document's own folder, so a
    // destination such as "..\..\..\secrets.png" resolves to nothing.
    property RestrictToDocumentFolder: Boolean read FRestrictToDocumentFolder write FRestrictToDocumentFolder
      default False;
  end;

implementation

constructor TMarkdownViewerImageSettings.Create;
begin
  inherited Create;

  FAllowRemote := True;
  FMaxBytes := DefaultMaxBytes;
end;

procedure TMarkdownViewerImageSettings.Assign(Source: TPersistent);
begin
  if not (Source is TMarkdownViewerImageSettings) then
  begin
    inherited Assign(Source);
    Exit;
  end;

  const Other = TMarkdownViewerImageSettings(Source);
  FBaseUrl := Other.FBaseUrl;
  FAllowRemote := Other.FAllowRemote;
  FMaxBytes := Other.FMaxBytes;
  FRestrictToDocumentFolder := Other.FRestrictToDocumentFolder;
end;

end.
