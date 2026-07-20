unit Markdown4D.Writer.Emphasis;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Ast.Interfaces;

type
  TEmphasisDelimiterChooser = class
  private
    class function HasAsteriskConflict(const Node, Parent: IMarkdownNode; const Index: Integer;
                                       const LastDelimiter: Char; const ParentDelimiterIsAsterisk: Boolean): Boolean;
    class function HasParentOpenerConflict(const Node, Parent: IMarkdownNode;
                                           const ParentDelimiterIsAsterisk: Boolean): Boolean;
    class function HasParentCloserConflict(const Node, Parent: IMarkdownNode; const Index: Integer;
                                           const ParentDelimiterIsAsterisk: Boolean): Boolean;
    class function HasInnerCloserConflict(const Node: IMarkdownNode): Boolean;
    class function HasPreviousSiblingConflict(const Node, Parent: IMarkdownNode; const Index: Integer;
                                              const LastDelimiter: Char): Boolean;
    class function HasSiblingOpenerConflict(const Node, Parent: IMarkdownNode; const Index: Integer): Boolean;
    class function UnderscoreIsValid(const Node, Parent: IMarkdownNode; const Index: Integer;
                                     const PreviousChar: Char): Boolean;
    class function UnderscoreCanOpen(const Previous, First: Char): Boolean;
    class function UnderscoreCanClose(const Last, Next: Char): Boolean;
    class function NextContextChar(const Parent: IMarkdownNode; const Index: Integer): Char;
    class function FirstContentChar(const Node: IMarkdownNode): Char;
    class function LastContentChar(const Node: IMarkdownNode): Char;
    class function TextEdgeChar(const Literal: string; const FromStart: Boolean): Char;
    class function IsWhitespaceChar(const Value: Char): Boolean;
    class function IsPunctuationChar(const Value: Char): Boolean;

  public
    class function Choose(const Node, Parent: IMarkdownNode; const Index: Integer;
                          const PreviousChar, LastDelimiter: Char;
                          const ParentDelimiterIsAsterisk: Boolean): Char;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  Markdown4D.Defines;

type
  TMarkdownNodeKindHelper = record helper for TMarkdownNodeKind
    function IsEmphasis: Boolean;
  end;

function TMarkdownNodeKindHelper.IsEmphasis: Boolean;
begin
  Result := (Self = TMarkdownNodeKind.Emphasis) or (Self = TMarkdownNodeKind.Strong);
end;

class function TEmphasisDelimiterChooser.Choose(const Node, Parent: IMarkdownNode; const Index: Integer;
                                                const PreviousChar, LastDelimiter: Char;
                                                const ParentDelimiterIsAsterisk: Boolean): Char;
begin
  const NeedsAlternate = HasAsteriskConflict(Node, Parent, Index, LastDelimiter, ParentDelimiterIsAsterisk);
  if NeedsAlternate and UnderscoreIsValid(Node, Parent, Index, PreviousChar) then
    Exit(Underscore);

  Result := Asterisk;
end;

class function TEmphasisDelimiterChooser.HasAsteriskConflict(const Node, Parent: IMarkdownNode; const Index: Integer;
                                                             const LastDelimiter: Char;
                                                             const ParentDelimiterIsAsterisk: Boolean): Boolean;
begin
  if HasParentOpenerConflict(Node, Parent, ParentDelimiterIsAsterisk) then
    Exit(True);

  if HasParentCloserConflict(Node, Parent, Index, ParentDelimiterIsAsterisk) then
    Exit(True);

  if HasInnerCloserConflict(Node) then
    Exit(True);

  if HasPreviousSiblingConflict(Node, Parent, Index, LastDelimiter) then
    Exit(True);

  Result := HasSiblingOpenerConflict(Node, Parent, Index);
end;

class function TEmphasisDelimiterChooser.HasParentOpenerConflict(const Node, Parent: IMarkdownNode;
                                                                 const ParentDelimiterIsAsterisk: Boolean): Boolean;
begin
  const IsOnlyChildOfEmphasis = (Parent <> nil) and Parent.Kind.IsEmphasis and (Parent.ChildCount = 1);
  if not IsOnlyChildOfEmphasis then
    Exit(False);

  Result := ParentDelimiterIsAsterisk and (Node.Kind = TMarkdownNodeKind.Emphasis);
end;

class function TEmphasisDelimiterChooser.HasParentCloserConflict(const Node, Parent: IMarkdownNode;
                                                                 const Index: Integer;
                                                                 const ParentDelimiterIsAsterisk: Boolean): Boolean;
begin
  const HasEmphasisParent = (Parent <> nil) and Parent.Kind.IsEmphasis;
  if not HasEmphasisParent then
    Exit(False);

  const IsLastOfSeveralChildren = (Parent.ChildCount > 1) and (Index = Parent.ChildCount - 1);
  const SameKind = (Parent.Kind = Node.Kind);

  Result := IsLastOfSeveralChildren and SameKind and ParentDelimiterIsAsterisk;
end;

class function TEmphasisDelimiterChooser.HasInnerCloserConflict(const Node: IMarkdownNode): Boolean;
begin
  if Node.ChildCount < 2 then
    Exit(False);

  const LastChild = Node.Children[Node.ChildCount - 1];
  const SameKind = (LastChild.Kind = Node.Kind);
  if not SameKind then
    Exit(False);

  const InnerPrevious = LastContentChar(Node.Children[Node.ChildCount - 2]);

  Result := not UnderscoreCanOpen(InnerPrevious, FirstContentChar(LastChild));
end;

class function TEmphasisDelimiterChooser.HasPreviousSiblingConflict(const Node, Parent: IMarkdownNode;
                                                                    const Index: Integer;
                                                                    const LastDelimiter: Char): Boolean;
begin
  if LastDelimiter <> Asterisk then
    Exit(False);

  const HasPreviousSibling = (Parent <> nil) and (Index > 0);
  if not HasPreviousSibling then
    Exit(False);

  Result := (Parent.Children[Index - 1].Kind = Node.Kind);
end;

class function TEmphasisDelimiterChooser.HasSiblingOpenerConflict(const Node, Parent: IMarkdownNode;
                                                                  const Index: Integer): Boolean;
begin
  const HasNextSibling = (Parent <> nil) and (Index < Parent.ChildCount - 1);
  if not HasNextSibling then
    Exit(False);

  const Sibling = Parent.Children[Index + 1];
  if Sibling.Kind <> Node.Kind then
    Exit(False);

  Result := not UnderscoreCanClose(LastContentChar(Sibling), NextContextChar(Parent, Index + 1));
end;

class function TEmphasisDelimiterChooser.UnderscoreIsValid(const Node, Parent: IMarkdownNode; const Index: Integer;
                                                           const PreviousChar: Char): Boolean;
begin
  const CanOpen = UnderscoreCanOpen(PreviousChar, FirstContentChar(Node));
  const CanClose = UnderscoreCanClose(LastContentChar(Node), NextContextChar(Parent, Index));

  Result := CanOpen and CanClose;
end;

class function TEmphasisDelimiterChooser.UnderscoreCanOpen(const Previous, First: Char): Boolean;
begin
  const LeftFlanking = (not IsWhitespaceChar(First)) and
    ((not IsPunctuationChar(First)) or IsWhitespaceChar(Previous) or IsPunctuationChar(Previous));
  const RightFlanking = (not IsWhitespaceChar(Previous)) and
    ((not IsPunctuationChar(Previous)) or IsWhitespaceChar(First) or IsPunctuationChar(First));

  Result := LeftFlanking and ((not RightFlanking) or IsPunctuationChar(Previous));
end;

class function TEmphasisDelimiterChooser.UnderscoreCanClose(const Last, Next: Char): Boolean;
begin
  const RightFlanking = (not IsWhitespaceChar(Last)) and
    ((not IsPunctuationChar(Last)) or IsWhitespaceChar(Next) or IsPunctuationChar(Next));
  const LeftFlanking = (not IsWhitespaceChar(Next)) and
    ((not IsPunctuationChar(Next)) or IsWhitespaceChar(Last) or IsPunctuationChar(Last));

  Result := RightFlanking and ((not LeftFlanking) or IsPunctuationChar(Next));
end;

class function TEmphasisDelimiterChooser.NextContextChar(const Parent: IMarkdownNode; const Index: Integer): Char;
begin
  if Parent = nil then
    Exit(LineFeed);

  const HasNextSibling = (Index < Parent.ChildCount - 1);
  if HasNextSibling then
    Exit(FirstContentChar(Parent.Children[Index + 1]));

  case Parent.Kind of
    TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
      Result := Asterisk;
    TMarkdownNodeKind.Link, TMarkdownNodeKind.Image:
      Result := CloseBracket;
    TMarkdownNodeKind.CustomInline:
      Result := Tilde;
  else
    Result := LineFeed;
  end;
end;

class function TEmphasisDelimiterChooser.FirstContentChar(const Node: IMarkdownNode): Char;
begin
  Result := Asterisk;
  var Current := Node;

  while Current <> nil do
  begin
    case Current.Kind of
      TMarkdownNodeKind.Text:
        Exit(TextEdgeChar((Current as IMarkdownText).Literal, True));
      TMarkdownNodeKind.CodeSpan:
        Exit(Backtick);
      TMarkdownNodeKind.Link:
        Exit(OpenBracket);
      TMarkdownNodeKind.Image:
        Exit(ExclamationMark);
      TMarkdownNodeKind.Autolink, TMarkdownNodeKind.InlineHtml:
        Exit(LessThan);
      TMarkdownNodeKind.SoftLineBreak:
        Exit(LineFeed);
      TMarkdownNodeKind.HardLineBreak:
        Exit(Backslash);
      TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
        Exit(Asterisk);
      TMarkdownNodeKind.CustomInline:
        Exit(Tilde);
    else
      begin
        if Current.ChildCount = 0 then
          Exit(Asterisk);

        Current := Current.Children[0];
      end;
    end;
  end;
end;

class function TEmphasisDelimiterChooser.LastContentChar(const Node: IMarkdownNode): Char;
begin
  Result := Asterisk;
  var Current := Node;

  while Current <> nil do
  begin
    case Current.Kind of
      TMarkdownNodeKind.Text:
        Exit(TextEdgeChar((Current as IMarkdownText).Literal, False));
      TMarkdownNodeKind.CodeSpan:
        Exit(Backtick);
      TMarkdownNodeKind.Link, TMarkdownNodeKind.Image:
        Exit(CloseParen);
      TMarkdownNodeKind.Autolink, TMarkdownNodeKind.InlineHtml:
        Exit(GreaterThan);
      TMarkdownNodeKind.SoftLineBreak, TMarkdownNodeKind.HardLineBreak:
        Exit(LineFeed);
      TMarkdownNodeKind.Emphasis, TMarkdownNodeKind.Strong:
        Exit(Asterisk);
      TMarkdownNodeKind.CustomInline:
        Exit(Tilde);
    else
      begin
        if Current.ChildCount = 0 then
          Exit(Asterisk);

        Current := Current.Children[Current.ChildCount - 1];
      end;
    end;
  end;
end;

class function TEmphasisDelimiterChooser.TextEdgeChar(const Literal: string; const FromStart: Boolean): Char;
begin
  if Literal = '' then
    Exit(Asterisk);

  var EdgeChar := Literal[Length(Literal)];
  if FromStart then
    EdgeChar := Literal[1];

  if CharInSet(EdgeChar, [Tab, LineFeed, CarriageReturn]) then
    Exit(Ampersand);

  Result := EdgeChar;
end;

class function TEmphasisDelimiterChooser.IsWhitespaceChar(const Value: Char): Boolean;
begin
  Result := Value.IsWhiteSpace;
end;

class function TEmphasisDelimiterChooser.IsPunctuationChar(const Value: Char): Boolean;
begin
  Result := Value.IsPunctuation or Value.IsSymbol;
end;

end.
