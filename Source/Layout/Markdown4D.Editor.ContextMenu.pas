unit Markdown4D.Editor.ContextMenu;

{$SCOPEDENUMS ON}

// What the editor's right-click menu offers and which entries are live, decided
// once for every framework. Hosts turn this list into their own menu widget and
// run the clipboard entries with their own clipboard.

interface

uses
  System.Classes,
  Markdown4D.Editor.Model;

type
  TEditorContextCommand = (Undo, Redo, Cut, Copy, Paste, DeleteSelection, SelectAll);

  TEditorContextItem = record
    Command: TEditorContextCommand;
    Caption: string;
    Enabled: Boolean;
    // A separator is drawn above this item when the host builds the menu.
    StartsGroup: Boolean;
    // Shown beside the caption; the control handles the key itself.
    ShortCut: TShortCut;
    class function Create(const Command: TEditorContextCommand; const Caption: string;
      const Enabled, StartsGroup: Boolean; const ShortCut: TShortCut): TEditorContextItem; static;
  end;

  TMarkdownEditorContextMenu = record
    class function Build(const Model: TMarkdownEditorModel;
      const ClipboardHasText: Boolean): TArray<TEditorContextItem>; static;
    // Runs the entries that only touch the text. Clipboard entries return False
    // because they need the host's clipboard.
    class function Execute(const Model: TMarkdownEditorModel;
      const Command: TEditorContextCommand): Boolean; static;
  end;

implementation

uses
  System.UITypes,
  Markdown4D.Consts;

const
  UndoShortCut = scCtrl or vkZ;
  RedoShortCut = scCtrl or vkY;
  CutShortCut = scCtrl or vkX;
  CopyShortCut = scCtrl or vkC;
  PasteShortCut = scCtrl or vkV;
  DeleteShortCut = vkDelete;
  SelectAllShortCut = scCtrl or vkA;

class function TEditorContextItem.Create(const Command: TEditorContextCommand; const Caption: string;
  const Enabled, StartsGroup: Boolean; const ShortCut: TShortCut): TEditorContextItem;
begin
  Result.Command := Command;
  Result.Caption := Caption;
  Result.Enabled := Enabled;
  Result.StartsGroup := StartsGroup;
  Result.ShortCut := ShortCut;
end;

class function TMarkdownEditorContextMenu.Build(const Model: TMarkdownEditorModel;
  const ClipboardHasText: Boolean): TArray<TEditorContextItem>;
begin
  const HasSelection = Model.HasSelection;
  const HasText = Length(Model.Text) > 0;

  Result := [
    TEditorContextItem.Create(TEditorContextCommand.Undo, UndoMenuCaption, Model.CanUndo, False, UndoShortCut),
    TEditorContextItem.Create(TEditorContextCommand.Redo, RedoMenuCaption, Model.CanRedo, False, RedoShortCut),
    TEditorContextItem.Create(TEditorContextCommand.Cut, CutMenuCaption, HasSelection, True, CutShortCut),
    TEditorContextItem.Create(TEditorContextCommand.Copy, CopyMenuCaption, HasSelection, False, CopyShortCut),
    TEditorContextItem.Create(TEditorContextCommand.Paste, PasteMenuCaption, ClipboardHasText, False,
      PasteShortCut),
    TEditorContextItem.Create(TEditorContextCommand.DeleteSelection, DeleteMenuCaption, HasSelection, False,
      DeleteShortCut),
    TEditorContextItem.Create(TEditorContextCommand.SelectAll, SelectAllMenuCaption, HasText, True, SelectAllShortCut)
  ];
end;

class function TMarkdownEditorContextMenu.Execute(const Model: TMarkdownEditorModel;
  const Command: TEditorContextCommand): Boolean;
begin
  Result := True;

  case Command of
    TEditorContextCommand.Undo:
      Model.Undo;
    TEditorContextCommand.Redo:
      Model.Redo;
    TEditorContextCommand.DeleteSelection:
      Model.DeleteForward;
    TEditorContextCommand.SelectAll:
      Model.SelectAll;
  else
    Result := False;
  end;
end;

end.
