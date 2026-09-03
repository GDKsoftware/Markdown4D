unit Markdown4D.Viewer.ContextMenu;

{$SCOPEDENUMS ON}

// What the viewer's right-click menu offers and which entries are live, decided
// once for every framework. Hosts turn this list into their own menu widget and
// run the clipboard entry with their own clipboard.

interface

uses
  Markdown4D.Viewer.Model;

type
  TViewerContextCommand = (Copy, SelectAll);

  TViewerContextItem = record
    Command: TViewerContextCommand;
    Caption: string;
    Enabled: Boolean;
    // A separator is drawn above this item when the host builds the menu.
    StartsGroup: Boolean;
    class function Create(const Command: TViewerContextCommand; const Caption: string;
      const Enabled, StartsGroup: Boolean): TViewerContextItem; static;
  end;

  TMarkdownViewerContextMenu = record
    class function Build(const Model: TMarkdownViewerModel): TArray<TViewerContextItem>; static;
    // Runs the entries that only touch the selection. Copy returns False because
    // it needs the host's clipboard.
    class function Execute(const Model: TMarkdownViewerModel;
      const Command: TViewerContextCommand): Boolean; static;
  end;

implementation

const
  CopyCaption = 'Copy';
  SelectAllCaption = 'Select All';

class function TViewerContextItem.Create(const Command: TViewerContextCommand; const Caption: string;
  const Enabled, StartsGroup: Boolean): TViewerContextItem;
begin
  Result.Command := Command;
  Result.Caption := Caption;
  Result.Enabled := Enabled;
  Result.StartsGroup := StartsGroup;
end;

class function TMarkdownViewerContextMenu.Build(const Model: TMarkdownViewerModel): TArray<TViewerContextItem>;
begin
  Result := [
    TViewerContextItem.Create(TViewerContextCommand.Copy, CopyCaption, Model.HasSelection, False),
    TViewerContextItem.Create(TViewerContextCommand.SelectAll, SelectAllCaption, Model.HasSelectableText, True)
  ];
end;

class function TMarkdownViewerContextMenu.Execute(const Model: TMarkdownViewerModel;
  const Command: TViewerContextCommand): Boolean;
begin
  Result := Command = TViewerContextCommand.SelectAll;
  if Result then
    Model.SelectAll;
end;

end.
