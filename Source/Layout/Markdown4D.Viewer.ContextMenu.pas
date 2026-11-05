unit Markdown4D.Viewer.ContextMenu;

{$SCOPEDENUMS ON}

// What the viewer's right-click menu offers and which entries are live, decided
// once for every framework. Hosts turn this list into their own menu widget and
// run the clipboard entry with their own clipboard.

interface

uses
  System.Classes,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Viewer.Model;

type
  TViewerContextCommand = (Copy, CopyAsMarkdown, SelectAll, CopyFormulaAsLaTeX, CopyFormulaAsText);

  TViewerContextItem = record
    Command: TViewerContextCommand;
    Caption: string;
    Enabled: Boolean;
    // A separator is drawn above this item when the host builds the menu.
    StartsGroup: Boolean;
    // Shown beside the caption; the control handles the key itself.
    ShortCut: TShortCut;
    class function Create(const Command: TViewerContextCommand; const Caption: string;
      const Enabled, StartsGroup: Boolean; const ShortCut: TShortCut): TViewerContextItem; static;
  end;

  TMarkdownViewerContextMenu = record
    // ShowsCopyAsMarkdown leaves the Copy as Markdown entry out when False, for
    // an application that does not offer the source to its readers.
    class function Build(const Model: TMarkdownViewerModel;
                         const ShowsCopyAsMarkdown: Boolean): TArray<TViewerContextItem>; overload; static;
    // Formula is the formula the menu was opened over, or nil. Over one, the
    // menu offers to copy it as LaTeX and as text, whatever is selected.
    class function Build(const Model: TMarkdownViewerModel; const ShowsCopyAsMarkdown: Boolean;
                         const Formula: IMarkdownMath): TArray<TViewerContextItem>; overload; static;
    // Runs the entries that only touch the selection. Copy returns False because
    // it needs the host's clipboard.
    class function Execute(const Model: TMarkdownViewerModel;
      const Command: TViewerContextCommand): Boolean; static;
  end;

implementation

uses
  System.UITypes,
  Markdown4D.Consts;

const
  CopyShortCut = scCtrl or vkC;
  CopyAsMarkdownShortCut = scCtrl or scShift or vkC;
  SelectAllShortCut = scCtrl or vkA;

class function TViewerContextItem.Create(const Command: TViewerContextCommand; const Caption: string;
  const Enabled, StartsGroup: Boolean; const ShortCut: TShortCut): TViewerContextItem;
begin
  Result.Command := Command;
  Result.Caption := Caption;
  Result.Enabled := Enabled;
  Result.StartsGroup := StartsGroup;
  Result.ShortCut := ShortCut;
end;

class function TMarkdownViewerContextMenu.Build(const Model: TMarkdownViewerModel;
  const ShowsCopyAsMarkdown: Boolean): TArray<TViewerContextItem>;
begin
  Result := Build(Model, ShowsCopyAsMarkdown, nil);
end;

class function TMarkdownViewerContextMenu.Build(const Model: TMarkdownViewerModel; const ShowsCopyAsMarkdown: Boolean;
  const Formula: IMarkdownMath): TArray<TViewerContextItem>;
begin
  const HasSelection = Model.HasSelection;
  Result := [TViewerContextItem.Create(TViewerContextCommand.Copy, CopyMenuCaption, HasSelection, False, CopyShortCut)];

  if ShowsCopyAsMarkdown then
    Result := Result + [TViewerContextItem.Create(TViewerContextCommand.CopyAsMarkdown, CopyAsMarkdownMenuCaption,
                                                  HasSelection, False, CopyAsMarkdownShortCut)];

  if Formula <> nil then
    Result := Result + [TViewerContextItem.Create(TViewerContextCommand.CopyFormulaAsLaTeX,
                                                  CopyFormulaAsLaTeXMenuCaption, True, True, 0),
                        TViewerContextItem.Create(TViewerContextCommand.CopyFormulaAsText,
                                                  CopyFormulaAsTextMenuCaption, True, False, 0)];

  Result := Result + [TViewerContextItem.Create(TViewerContextCommand.SelectAll, SelectAllMenuCaption,
                                                Model.HasSelectableText, True, SelectAllShortCut)];
end;

class function TMarkdownViewerContextMenu.Execute(const Model: TMarkdownViewerModel;
  const Command: TViewerContextCommand): Boolean;
begin
  Result := Command = TViewerContextCommand.SelectAll;
  if Result then
    Model.SelectAll;
end;

end.
