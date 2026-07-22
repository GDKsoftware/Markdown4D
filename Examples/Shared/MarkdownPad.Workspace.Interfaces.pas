unit MarkdownPad.Workspace.Interfaces;

{$SCOPEDENUMS ON}

interface

type
  IPadDocument = interface
    ['{B1E7A0C2-3D4F-4A6B-9C11-7E2F5A8D0C31}']
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
    function IsUntitled: Boolean;
    function DisplayName: string;
    property FileName: string read GetFileName write SetFileName;
    property Text: string read GetText write SetText;
    property Modified: Boolean read GetModified write SetModified;
    property CaretPosition: Integer read GetCaretPosition write SetCaretPosition;
    property EditorScrollOffset: Single read GetEditorScrollOffset write SetEditorScrollOffset;
    property PreviewScrollOffset: Single read GetPreviewScrollOffset write SetPreviewScrollOffset;
    property DiskTimestampUtc: TDateTime read GetDiskTimestampUtc write SetDiskTimestampUtc;
    property EditState: IInterface read GetEditState write SetEditState;
    property UntitledNumber: Integer read GetUntitledNumber write SetUntitledNumber;
  end;

  IPadWorkspace = interface
    ['{C2F8B1D3-4E5A-4B7C-8D22-8F3A6B9E1D42}']
    function GetCount: Integer;
    function GetDocument(const Index: Integer): IPadDocument;
    function GetActiveIndex: Integer;
    function GetActiveDocument: IPadDocument;
    function IndexOfFile(const FileName: string): Integer;
    function NewDocument: IPadDocument;
    function OpenFile(const FileName: string): IPadDocument;
    procedure CloseDocument(const Index: Integer);
    procedure Move(const FromIndex, ToIndex: Integer);
    procedure Activate(const Index: Integer);
    procedure ActivateNext;
    procedure ActivatePrevious;
    property Count: Integer read GetCount;
    property Documents[const Index: Integer]: IPadDocument read GetDocument;
    property ActiveIndex: Integer read GetActiveIndex write Activate;
    property ActiveDocument: IPadDocument read GetActiveDocument;
  end;

implementation

end.
