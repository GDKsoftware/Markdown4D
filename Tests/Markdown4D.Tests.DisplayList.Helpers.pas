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
    // The keys of the <details> sections laid out, in display order.
    class function DisclosureKeys(const DisplayList: IMarkdownDisplayList): TArray<Integer>;
    // The text of every text run, in display order.
    class function TextRuns(const DisplayList: IMarkdownDisplayList): TArray<string>;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections;

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

class function TMarkdownTestDisplayListHelpers.DisclosureKeys(const DisplayList: IMarkdownDisplayList): TArray<Integer>;
begin
  const Keys = TList<Integer>.Create;
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Disclosure: IDisplayDisclosure;
      if Supports(DisplayList.Items[Index], IDisplayDisclosure, Disclosure) then
        Keys.Add(Disclosure.Key);
    end;

    Result := Keys.ToArray;
  finally
    Keys.Free;
  end;
end;

class function TMarkdownTestDisplayListHelpers.TextRuns(const DisplayList: IMarkdownDisplayList): TArray<string>;
begin
  const Texts = TList<string>.Create;
  try
    for var Index := 0 to DisplayList.ItemCount - 1 do
    begin
      var Run: IDisplayTextRun;
      if Supports(DisplayList.Items[Index], IDisplayTextRun, Run) then
        Texts.Add(Run.Text);
    end;

    Result := Texts.ToArray;
  finally
    Texts.Free;
  end;
end;

end.
