unit Markdown4D.Editor.Keys;

{$SCOPEDENUMS ON}

// The editor keymap, shared by every framework. Virtual key codes are identical
// across the VCL (VK_*) and FMX (vk*) constants, so one table serves both and a
// third host would inherit the same bindings for free.

interface

uses
  System.Classes,
  Markdown4D.Editor.Model;

type
  TEditorKeyAction = (
    None,
    MoveLeft, MoveRight, MoveUp, MoveDown,
    MoveWordLeft, MoveWordRight,
    MoveLineStart, MoveLineEnd,
    MoveDocumentStart, MoveDocumentEnd,
    MovePageUp, MovePageDown,
    DeleteBack, DeleteForward,
    DeleteWordLeft, DeleteWordRight,
    InsertLineBreak, Indent, Outdent,
    SelectAll, Copy, Cut, Paste, Undo, Redo,
    Bold, Italic, Link);

  TEditorKeyStroke = record
    Action: TEditorKeyAction;
    // Shift held on a movement key: carry the selection along instead of
    // collapsing it.
    Extend: Boolean;
    class function Create(const Action: TEditorKeyAction; const Extend: Boolean): TEditorKeyStroke; static;
    function Handled: Boolean;
  end;

  TMarkdownEditorKeymap = record
  strict private
    class function ResolveControl(const Key: Word; const Extend: Boolean): TEditorKeyStroke; static;
    class function ResolvePlain(const Key: Word; const Extend: Boolean): TEditorKeyStroke; static;
  public
    class function Resolve(const Key: Word; const Shift: TShiftState): TEditorKeyStroke; static;
  end;

  // Everything a keystroke can do to the text alone. What is left over needs the
  // on-screen layout (vertical movement, visual line ends, paging) or the host's
  // clipboard, and stays with the concrete editor control.
  TMarkdownEditorKeyDispatch = record
    class function Apply(const Model: TMarkdownEditorModel; const Stroke: TEditorKeyStroke;
      const IndentWidth: Integer): Boolean; static;
  end;

implementation

uses
  System.UITypes,
  Markdown4D.Editor.Actions;

class function TEditorKeyStroke.Create(const Action: TEditorKeyAction; const Extend: Boolean): TEditorKeyStroke;
begin
  Result.Action := Action;
  Result.Extend := Extend;
end;

function TEditorKeyStroke.Handled: Boolean;
begin
  Result := Action <> TEditorKeyAction.None;
end;

class function TMarkdownEditorKeymap.Resolve(const Key: Word; const Shift: TShiftState): TEditorKeyStroke;
begin
  const Extend = ssShift in Shift;

  // AltGr arrives as Ctrl+Alt. Claiming those would swallow the characters that
  // layouts put behind AltGr, so the keystroke is left to the character path.
  if ssAlt in Shift then
    Exit(TEditorKeyStroke.Create(TEditorKeyAction.None, False));

  if ssCtrl in Shift then
    Exit(ResolveControl(Key, Extend));

  Result := ResolvePlain(Key, Extend);
end;

class function TMarkdownEditorKeymap.ResolveControl(const Key: Word; const Extend: Boolean): TEditorKeyStroke;
begin
  var Action := TEditorKeyAction.None;

  case Key of
    vkA:
      Action := TEditorKeyAction.SelectAll;
    vkC:
      Action := TEditorKeyAction.Copy;
    vkX:
      Action := TEditorKeyAction.Cut;
    vkV:
      Action := TEditorKeyAction.Paste;
    vkZ:
      if Extend then
        Action := TEditorKeyAction.Redo
      else
        Action := TEditorKeyAction.Undo;
    vkY:
      Action := TEditorKeyAction.Redo;
    vkB:
      Action := TEditorKeyAction.Bold;
    vkI:
      Action := TEditorKeyAction.Italic;
    vkK:
      Action := TEditorKeyAction.Link;
    vkLeft:
      Action := TEditorKeyAction.MoveWordLeft;
    vkRight:
      Action := TEditorKeyAction.MoveWordRight;
    vkHome:
      Action := TEditorKeyAction.MoveDocumentStart;
    vkEnd:
      Action := TEditorKeyAction.MoveDocumentEnd;
    vkBack:
      Action := TEditorKeyAction.DeleteWordLeft;
    vkDelete:
      Action := TEditorKeyAction.DeleteWordRight;
    vkInsert:
      Action := TEditorKeyAction.Copy;
  end;

  Result := TEditorKeyStroke.Create(Action, Extend);
end;

class function TMarkdownEditorKeymap.ResolvePlain(const Key: Word; const Extend: Boolean): TEditorKeyStroke;
begin
  var Action := TEditorKeyAction.None;

  case Key of
    vkLeft:
      Action := TEditorKeyAction.MoveLeft;
    vkRight:
      Action := TEditorKeyAction.MoveRight;
    vkUp:
      Action := TEditorKeyAction.MoveUp;
    vkDown:
      Action := TEditorKeyAction.MoveDown;
    vkHome:
      Action := TEditorKeyAction.MoveLineStart;
    vkEnd:
      Action := TEditorKeyAction.MoveLineEnd;
    vkPrior:
      Action := TEditorKeyAction.MovePageUp;
    vkNext:
      Action := TEditorKeyAction.MovePageDown;
    vkBack:
      Action := TEditorKeyAction.DeleteBack;
    vkDelete:
      if Extend then
        Action := TEditorKeyAction.Cut
      else
        Action := TEditorKeyAction.DeleteForward;
    vkInsert:
      if Extend then
        Action := TEditorKeyAction.Paste;
    vkReturn:
      Action := TEditorKeyAction.InsertLineBreak;
    vkTab:
      if Extend then
        Action := TEditorKeyAction.Outdent
      else
        Action := TEditorKeyAction.Indent;
  end;

  Result := TEditorKeyStroke.Create(Action, Extend);
end;

class function TMarkdownEditorKeyDispatch.Apply(const Model: TMarkdownEditorModel;
  const Stroke: TEditorKeyStroke; const IndentWidth: Integer): Boolean;
begin
  Result := True;

  case Stroke.Action of
    TEditorKeyAction.MoveLeft:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveCaret(-1, Stroke.Extend);
      end;
    TEditorKeyAction.MoveRight:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveCaret(1, Stroke.Extend);
      end;
    TEditorKeyAction.MoveWordLeft:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveWordLeft(Stroke.Extend);
      end;
    TEditorKeyAction.MoveWordRight:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveWordRight(Stroke.Extend);
      end;
    TEditorKeyAction.MoveDocumentStart:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveCaretTo(0, Stroke.Extend);
      end;
    TEditorKeyAction.MoveDocumentEnd:
      begin
        Model.BreakUndoCoalescing;
        Model.MoveCaretTo(Length(Model.Text), Stroke.Extend);
      end;
    TEditorKeyAction.DeleteBack:
      Model.DeleteBackward;
    TEditorKeyAction.DeleteForward:
      Model.DeleteForward;
    TEditorKeyAction.DeleteWordLeft:
      Model.DeleteWordLeft;
    TEditorKeyAction.DeleteWordRight:
      Model.DeleteWordRight;
    TEditorKeyAction.InsertLineBreak:
      TMarkdownEditorActions.InsertLineBreak(Model);
    TEditorKeyAction.Indent:
      TMarkdownEditorActions.Indent(Model, IndentWidth);
    TEditorKeyAction.Outdent:
      TMarkdownEditorActions.Outdent(Model, IndentWidth);
    TEditorKeyAction.SelectAll:
      Model.SelectAll;
    TEditorKeyAction.Undo:
      Model.Undo;
    TEditorKeyAction.Redo:
      Model.Redo;
    TEditorKeyAction.Bold:
      Model.ExecuteCommand(TEditorCommand.Bold);
    TEditorKeyAction.Italic:
      Model.ExecuteCommand(TEditorCommand.Italic);
    TEditorKeyAction.Link:
      Model.ExecuteCommand(TEditorCommand.Link);
  else
    Result := False;
  end;
end;

end.
