unit Markdown4D.Parser.FrontMatter;

{$SCOPEDENUMS ON}

interface

type
  // Finds a YAML front matter block at the very start of a source. The block
  // opens with a line of exactly three dashes on the first line and closes at
  // the first later line of three dashes or three dots; trailing spaces and
  // tabs are allowed on both fences, anything in front of them is not. Without
  // a closing fence there is no front matter, so the document parses as plain
  // CommonMark.
  TFrontMatterScanner = class
  private
    const
      DashFence = '---';
      DotFence = '...';
      TrailingChars: array[0..1] of Char = (' ', #9);
    class function IsFence(const LineText, Fence: string): Boolean; static;
    class function IsClosingFence(const LineText: string): Boolean; static;

  public
    // RawText is the text between the fences with its lines joined by line
    // feeds; LineCount counts both fences as well.
    class function TryScan(const Source: string; out RawText: string; out LineCount: Integer): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  Markdown4D.Defines,
  Markdown4D.Parser.LineReader;

class function TFrontMatterScanner.TryScan(const Source: string; out RawText: string;
                                           out LineCount: Integer): Boolean;
begin
  RawText := '';
  LineCount := 0;
  Result := False;

  const Reader = TLineReader.Create(Source);
  try
    var Line: TSourceLine;
    const HasOpeningFence = Reader.TryReadLine(Line) and IsFence(Line.Text, DashFence);
    if not HasOpeningFence then
      Exit;

    const Inner = TStringBuilder.Create;
    try
      var LinesRead := 1;

      while Reader.TryReadLine(Line) do
      begin
        Inc(LinesRead);

        if IsClosingFence(Line.Text) then
        begin
          RawText := Inner.ToString;
          LineCount := LinesRead;
          Result := True;
          Exit;
        end;

        const IsFirstInnerLine = (LinesRead = 2);
        if not IsFirstInnerLine then
          Inner.Append(LineFeed);

        Inner.Append(Line.Text);
      end;
    finally
      Inner.Free;
    end;
  finally
    Reader.Free;
  end;
end;

class function TFrontMatterScanner.IsFence(const LineText, Fence: string): Boolean;
begin
  Result := (LineText.TrimRight(TrailingChars) = Fence);
end;

class function TFrontMatterScanner.IsClosingFence(const LineText: string): Boolean;
begin
  Result := IsFence(LineText, DashFence) or IsFence(LineText, DotFence);
end;

end.
