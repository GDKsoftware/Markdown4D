unit Markdown4DStudio.Shell;

{$SCOPEDENUMS ON}

// Seam between the framework-agnostic TPadController and the concrete VCL/FMX
// form. The form implements IPadShell; the controller drives the chrome, tab
// strip, dialogs and per-app text through it without knowing the framework.

interface

uses
  Markdown4DStudio.Session;

type
  // Outcome of the "save before closing?" prompt.
  TPadCloseChoice = (Save, Discard, Cancel);

  // Outcome of the prompt shown when saving would overwrite a file that changed
  // on disk after this buffer was loaded.
  TPadConflictChoice = (Overwrite, Reload, Cancel);

  IPadShell = interface
    ['{2B7E4C10-9D3A-4F62-8E1C-1A6F0B5D7C34}']
    // Chrome the controller refreshes after model changes.
    procedure RebuildTabs;
    procedure SetDocumentTitle(const Name: string);
    procedure SetStatus(const PositionText, WordsText: string);
    procedure ApplyRestoredViewMode(const Mode: TPadViewMode);

    // Contents outline: the form owns the list control (and any framework-
    // specific reentrancy guarding); the controller supplies the content.
    procedure SetTocCaptions(const Captions: TArray<string>);
    procedure SetActiveTocIndex(const Index: Integer);

    // Find bar: needles come from the form's edits, the count label is a sink.
    function EditorFindNeedle: string;
    function EditorReplaceValue: string;
    function PreviewFindNeedle: string;
    procedure SetFindCount(const Value: string);

    // Per-app / per-framework values the controller reads.
    function SampleMarkdown: string;
    function DarkThemeActive: Boolean;
    function EffectiveViewMode: TPadViewMode;

    // Dialogs and app lifetime, implemented with the native framework toolkit.
    function PromptOpenFile(out FileName: string): Boolean;
    function PromptSaveFile(const SuggestedName: string; out FileName: string): Boolean;
    function PromptExportHtml(const SuggestedName: string; out FileName: string): Boolean;
    function ConfirmClose: TPadCloseChoice;
    function ConfirmCloseDocument(const DocName: string): TPadCloseChoice;
    function ConfirmSaveOverChangedFile(const DocName: string): TPadConflictChoice;
    procedure ShowOpenError(const FileName, ErrorMessage: string);
    procedure ShowSaveError(const FileName, ErrorMessage: string);
    // Clipboard mechanism differs per framework (Win32 CF_HTML vs IFMXClipboardService).
    procedure CopyHtmlToClipboard(const Fragment: string);
    procedure CloseApplication;
  end;

implementation

end.
