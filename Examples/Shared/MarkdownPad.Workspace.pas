unit MarkdownPad.Workspace;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  MarkdownPad.Workspace.Interfaces;

type
  TPadWorkspace = class(TInterfacedObject, IPadWorkspace)
  strict private
    FDocuments: TList<IPadDocument>;
    FActiveIndex: Integer;
    FNextUntitledNumber: Integer;
    function GetCount: Integer;
    function GetDocument(const Index: Integer): IPadDocument;
    function GetActiveIndex: Integer;
    function GetActiveDocument: IPadDocument;

  public
    constructor Create;
    destructor Destroy; override;
    function IndexOfFile(const FileName: string): Integer;
    function NewDocument: IPadDocument;
    function OpenFile(const FileName: string): IPadDocument;
    procedure CloseDocument(const Index: Integer);
    procedure Activate(const Index: Integer);
    procedure ActivateNext;
    procedure ActivatePrevious;
    property Count: Integer read GetCount;
    property Documents[const Index: Integer]: IPadDocument read GetDocument;
    property ActiveIndex: Integer read GetActiveIndex;
    property ActiveDocument: IPadDocument read GetActiveDocument;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

const
  UntitledCaption = 'Untitled';
  UntitledNumberedFormat = 'Untitled %d';
  FirstUntitledNumber = 1;

type
  TPadDocument = class(TInterfacedObject, IPadDocument)
  strict private
    FFileName: string;
    FText: string;
    FModified: Boolean;
    FCaretPosition: Integer;
    FEditorScrollOffset: Single;
    FPreviewScrollOffset: Single;
    FDiskTimestampUtc: TDateTime;
    FEditState: IInterface;
    FUntitledNumber: Integer;
    function GetFileName: string;
    procedure SetFileName(const Value: string);
    function GetText: string;
    procedure SetText(const Value: string);
    function GetModified: Boolean;
    procedure SetModified(const Value: Boolean);
    function GetCaretPosition: Integer;
    procedure SetCaretPosition(const Value: Integer);
    function GetEditorScrollOffset: Single;
    procedure SetEditorScrollOffset(const Value: Single);
    function GetPreviewScrollOffset: Single;
    procedure SetPreviewScrollOffset(const Value: Single);
    function GetDiskTimestampUtc: TDateTime;
    procedure SetDiskTimestampUtc(const Value: TDateTime);
    function GetEditState: IInterface;
    procedure SetEditState(const Value: IInterface);
    function GetUntitledNumber: Integer;
    procedure SetUntitledNumber(const Value: Integer);

  public
    function IsUntitled: Boolean;
    function DisplayName: string;
  end;

constructor TPadWorkspace.Create;
begin
  inherited Create;

  FDocuments := TList<IPadDocument>.Create;
  FActiveIndex := -1;
  FNextUntitledNumber := FirstUntitledNumber;
end;

destructor TPadWorkspace.Destroy;
begin
  FDocuments.Free;

  inherited Destroy;
end;

function TPadWorkspace.NewDocument: IPadDocument;
begin
  Result := TPadDocument.Create;
  Result.UntitledNumber := FNextUntitledNumber;

  Inc(FNextUntitledNumber);

  FDocuments.Add(Result);
  FActiveIndex := FDocuments.Count - 1;
end;

function TPadWorkspace.OpenFile(const FileName: string): IPadDocument;
begin
  const Existing = IndexOfFile(FileName);
  if Existing >= 0 then
  begin
    FActiveIndex := Existing;
    Exit(FDocuments[Existing]);
  end;

  var Document: IPadDocument := TPadDocument.Create;
  Document.FileName := FileName;
  Document.Text := TFile.ReadAllText(FileName);
  Document.Modified := False;

  try
    Document.DiskTimestampUtc := TFile.GetLastWriteTimeUtc(FileName);
  except
    Document.DiskTimestampUtc := 0;
  end;

  FDocuments.Add(Document);
  FActiveIndex := FDocuments.Count - 1;
  Result := Document;
end;

function TPadWorkspace.IndexOfFile(const FileName: string): Integer;
begin
  for var Index := 0 to FDocuments.Count - 1 do
  begin
    if (FDocuments[Index].FileName <> '') and SameText(FDocuments[Index].FileName, FileName) then
      Exit(Index);
  end;

  Result := -1;
end;

procedure TPadWorkspace.CloseDocument(const Index: Integer);
begin
  if (Index < 0) or (Index >= FDocuments.Count) then
    Exit;

  FDocuments.Delete(Index);

  if FDocuments.Count = 0 then
  begin
    FActiveIndex := -1;
    Exit;
  end;

  if Index < FActiveIndex then
    Dec(FActiveIndex)
  else if (Index = FActiveIndex) and (FActiveIndex > FDocuments.Count - 1) then
    FActiveIndex := FDocuments.Count - 1;
end;

procedure TPadWorkspace.Activate(const Index: Integer);
begin
  if (Index >= 0) and (Index < FDocuments.Count) then
    FActiveIndex := Index;
end;

procedure TPadWorkspace.ActivateNext;
begin
  if FDocuments.Count = 0 then
    Exit;

  FActiveIndex := (FActiveIndex + 1) mod FDocuments.Count;
end;

procedure TPadWorkspace.ActivatePrevious;
begin
  if FDocuments.Count = 0 then
    Exit;

  FActiveIndex := (FActiveIndex + FDocuments.Count - 1) mod FDocuments.Count;
end;

function TPadWorkspace.GetCount: Integer;
begin
  Result := FDocuments.Count;
end;

function TPadWorkspace.GetDocument(const Index: Integer): IPadDocument;
begin
  Result := FDocuments[Index];
end;

function TPadWorkspace.GetActiveIndex: Integer;
begin
  Result := FActiveIndex;
end;

function TPadWorkspace.GetActiveDocument: IPadDocument;
begin
  if (FActiveIndex < 0) or (FActiveIndex >= FDocuments.Count) then
    Exit(nil);

  Result := FDocuments[FActiveIndex];
end;

function TPadDocument.DisplayName: string;
begin
  if not IsUntitled then
    Exit(TPath.GetFileName(FFileName));

  if FUntitledNumber > FirstUntitledNumber then
    Result := Format(UntitledNumberedFormat, [FUntitledNumber])
  else
    Result := UntitledCaption;
end;

function TPadDocument.IsUntitled: Boolean;
begin
  Result := FFileName = '';
end;

function TPadDocument.GetFileName: string;
begin
  Result := FFileName;
end;

procedure TPadDocument.SetFileName(const Value: string);
begin
  FFileName := Value;
end;

function TPadDocument.GetText: string;
begin
  Result := FText;
end;

procedure TPadDocument.SetText(const Value: string);
begin
  FText := Value;
end;

function TPadDocument.GetModified: Boolean;
begin
  Result := FModified;
end;

procedure TPadDocument.SetModified(const Value: Boolean);
begin
  FModified := Value;
end;

function TPadDocument.GetCaretPosition: Integer;
begin
  Result := FCaretPosition;
end;

procedure TPadDocument.SetCaretPosition(const Value: Integer);
begin
  FCaretPosition := Value;
end;

function TPadDocument.GetEditorScrollOffset: Single;
begin
  Result := FEditorScrollOffset;
end;

procedure TPadDocument.SetEditorScrollOffset(const Value: Single);
begin
  FEditorScrollOffset := Value;
end;

function TPadDocument.GetPreviewScrollOffset: Single;
begin
  Result := FPreviewScrollOffset;
end;

procedure TPadDocument.SetPreviewScrollOffset(const Value: Single);
begin
  FPreviewScrollOffset := Value;
end;

function TPadDocument.GetDiskTimestampUtc: TDateTime;
begin
  Result := FDiskTimestampUtc;
end;

procedure TPadDocument.SetDiskTimestampUtc(const Value: TDateTime);
begin
  FDiskTimestampUtc := Value;
end;

function TPadDocument.GetEditState: IInterface;
begin
  Result := FEditState;
end;

procedure TPadDocument.SetEditState(const Value: IInterface);
begin
  FEditState := Value;
end;

function TPadDocument.GetUntitledNumber: Integer;
begin
  Result := FUntitledNumber;
end;

procedure TPadDocument.SetUntitledNumber(const Value: Integer);
begin
  FUntitledNumber := Value;
end;

end.
