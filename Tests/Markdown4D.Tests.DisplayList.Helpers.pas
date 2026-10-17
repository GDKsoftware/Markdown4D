unit Markdown4D.Tests.DisplayList.Helpers;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Layout.DisplayList;

type
  TMarkdownTestDisplayListHelpers = class
  public
    // The first text run that shows Text, spaces around it aside; nil when no
    // run does.
    class function TextRunShowing(const DisplayList: IMarkdownDisplayList; const Text: string): IDisplayTextRun;
    class function ShowsText(const DisplayList: IMarkdownDisplayList; const Text: string): Boolean;
  end;

implementation

uses
  System.SysUtils;

class function TMarkdownTestDisplayListHelpers.TextRunShowing(const DisplayList: IMarkdownDisplayList;
  const Text: string): IDisplayTextRun;
begin
  for var Index := 0 to DisplayList.ItemCount - 1 do
  begin
    var Run: IDisplayTextRun;
    const IsMatch = (Supports(DisplayList.Items[Index], IDisplayTextRun, Run) and (Run.Text.Trim = Text));
    if IsMatch then
    begin
      Result := Run;
      Exit;
    end;
  end;

  Result := nil;
end;

class function TMarkdownTestDisplayListHelpers.ShowsText(const DisplayList: IMarkdownDisplayList;
  const Text: string): Boolean;
begin
  Result := (TextRunShowing(DisplayList, Text) <> nil);
end;

end.
