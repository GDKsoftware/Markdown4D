unit MarkdownPad.EditorView;

{$SCOPEDENUMS ON}

// Framework-neutral abstraction over a form's live editor and preview controls,
// plus the buffer-swap document switch shared by the MarkdownPad forms. Each
// form implements IPadEditorView against its own TMarkdownEditor / TMarkdownViewer,
// so the switch logic below no longer has to be duplicated per framework. The
// workspace/session glue lives next door in MarkdownPad.SessionSync.

interface

uses
  MarkdownPad.Workspace.Interfaces,
  Markdown4D.Editor.Model;

type
  IPadEditorView = interface
    ['{8F2C1A7D-4B3E-4C9A-A1F6-2D5E7B9C0A34}']
    function GetEditorText: string;
    procedure SetEditorText(const Value: string);
    // Takes over incoming disk content through the smallest possible edit, so
    // undo history and caret survive. False means the text was already identical.
    function MergeEditorText(const Value: string): Boolean;
    function GetEditorCaret: Integer;
    procedure SetEditorCaret(const Value: Integer);
    function GetPreviewScrollOffset: Single;
    procedure SetPreviewScrollOffset(const Value: Single);
    function FirstVisibleSourceLine: Integer;
    procedure ScrollToSourceLine(const LineIndex: Integer);
    function SaveEditState: IMarkdownEditorState;
    procedure LoadEditState(const State: IMarkdownEditorState);
    procedure FlushPreview;
    // Find: highlight/advance in the editor, count matches, and search the
    // rendered preview. Needles come from the form's find edits (via IPadShell).
    procedure EditorFindNext(const Needle: string);
    function EditorFindMatchCount(const Needle: string): Integer;
    procedure EditorHighlightMatches(const Needle: string);
    function EditorReplaceCurrent(const Needle, Replacement: string): Boolean;
    function EditorReplaceAll(const Needle, Replacement: string): Integer;
    procedure PreviewFindText(const Needle: string);
    // Brackets the incoming-document load so the form suppresses its own change
    // handling while the editor and preview are repopulated.
    procedure BeginSwap;
    procedure EndSwap;
    property EditorText: string read GetEditorText write SetEditorText;
    property EditorCaret: Integer read GetEditorCaret write SetEditorCaret;
    property PreviewScrollOffset: Single read GetPreviewScrollOffset write SetPreviewScrollOffset;
  end;

  TPadDocumentSwitch = record
    // Persists the outgoing document's live editor/preview state, activates the
    // target index, and loads the incoming document into the view. Returns the
    // new active document (nil when the workspace has no active document, in
    // which case the caller should skip its tab/title refresh).
    class function Execute(const Workspace: IPadWorkspace; const View: IPadEditorView;
      const CurrentDocument: IPadDocument; const Index: Integer): IPadDocument; static;

    // Copies the live editor/preview state onto the document without switching,
    // so callers that persist or close a document store the current position.
    class procedure Capture(const View: IPadEditorView; const Document: IPadDocument); static;
  end;

implementation

uses
  System.SysUtils;

class function TPadDocumentSwitch.Execute(const Workspace: IPadWorkspace;
  const View: IPadEditorView; const CurrentDocument: IPadDocument;
  const Index: Integer): IPadDocument;
begin
  if CurrentDocument <> nil then
    Capture(View, CurrentDocument);

  Workspace.Activate(Index);
  Result := Workspace.ActiveDocument;

  if Result = nil then
    Exit;

  View.BeginSwap;
  try
    var State: IMarkdownEditorState;
    if Supports(Result.EditState, IMarkdownEditorState, State) then
      View.LoadEditState(State)
    else
      View.EditorText := Result.Text;

    View.FlushPreview;
    View.EditorCaret := Result.CaretPosition;
    View.ScrollToSourceLine(Round(Result.EditorScrollOffset));
    View.PreviewScrollOffset := Result.PreviewScrollOffset;
  finally
    View.EndSwap;
  end;
end;

class procedure TPadDocumentSwitch.Capture(const View: IPadEditorView; const Document: IPadDocument);
begin
  Document.Text                := View.EditorText;
  Document.CaretPosition       := View.EditorCaret;
  Document.EditorScrollOffset  := View.FirstVisibleSourceLine;
  Document.PreviewScrollOffset := View.PreviewScrollOffset;
  Document.EditState           := View.SaveEditState;
end;

end.
