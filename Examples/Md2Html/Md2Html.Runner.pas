unit Md2Html.Runner;

{$SCOPEDENUMS ON}

interface

type
  TMd2HtmlOptions = record
    InputFile: string;
    OutputFile: string;
    UseGfm: Boolean;
    XhtmlOutput: Boolean;
    SafeHtml: Boolean;
  end;

  TMd2HtmlRunner = class
  private
    const
      GfmSwitch = '--gfm';
      XhtmlSwitch = '--xhtml';
      SafeSwitch = '--safe';
      VersionSwitch = '--version';
      SwitchPrefix = '--';
      UsageText = 'Usage: Md2Html <input.md> [output.html] [--gfm] [--xhtml] [--safe] [--version]';
      VersionFormat = 'Markdown4D %s';
      UnknownSwitchFormat = 'Unknown option: %s';
      TooManyArgumentsFormat = 'Unexpected argument: %s';
      InputFileMissingFormat = 'Input file not found: %s';
      SuccessExitCode = 0;
      FailureExitCode = 1;
    class function HasVersionSwitch: Boolean;
    class function TryParseArguments(out Options: TMd2HtmlOptions): Boolean;
    class function Convert(const Options: TMd2HtmlOptions): Integer;
    class function ReadSource(const FileName: string): string;
    class function RenderHtml(const Options: TMd2HtmlOptions; const Source: string): string;
    class procedure WriteHtml(const Options: TMd2HtmlOptions; const Html: string);

  public
    class function Run: Integer;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Markdown4D,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Pipeline;

class function TMd2HtmlRunner.Run: Integer;
begin
  if HasVersionSwitch then
  begin
    Writeln(Output, Format(VersionFormat, [TMarkdown.Version]));
    Exit(SuccessExitCode);
  end;

  var Options: TMd2HtmlOptions;
  if not TryParseArguments(Options) then
  begin
    Writeln(ErrOutput, UsageText);
    Exit(FailureExitCode);
  end;

  Result := Convert(Options);
end;

class function TMd2HtmlRunner.HasVersionSwitch: Boolean;
begin
  for var Index := 1 to ParamCount do
    if SameText(ParamStr(Index), VersionSwitch) then
      Exit(True);

  Result := False;
end;

class function TMd2HtmlRunner.TryParseArguments(out Options: TMd2HtmlOptions): Boolean;
begin
  Options := Default(TMd2HtmlOptions);

  for var Index := 1 to ParamCount do
  begin
    const Argument = ParamStr(Index);

    if Argument.StartsWith(SwitchPrefix) then
    begin
      if SameText(Argument, GfmSwitch) then
        Options.UseGfm := True
      else if SameText(Argument, XhtmlSwitch) then
        Options.XhtmlOutput := True
      else if SameText(Argument, SafeSwitch) then
        Options.SafeHtml := True
      else
      begin
        Writeln(ErrOutput, Format(UnknownSwitchFormat, [Argument]));
        Exit(False);
      end;
      Continue;
    end;

    if Options.InputFile = '' then
      Options.InputFile := Argument
    else if Options.OutputFile = '' then
      Options.OutputFile := Argument
    else
    begin
      Writeln(ErrOutput, Format(TooManyArgumentsFormat, [Argument]));
      Exit(False);
    end;
  end;

  Result := Options.InputFile <> '';
end;

class function TMd2HtmlRunner.Convert(const Options: TMd2HtmlOptions): Integer;
begin
  try
    if not TFile.Exists(Options.InputFile) then
      raise EFileNotFoundException.CreateFmt(InputFileMissingFormat, [Options.InputFile]);

    const Source = ReadSource(Options.InputFile);
    const Html = RenderHtml(Options, Source);
    WriteHtml(Options, Html);
    Result := SuccessExitCode;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, Format('%s: %s', [E.ClassName, E.Message]));
      Result := FailureExitCode;
    end;
  end;
end;

class function TMd2HtmlRunner.ReadSource(const FileName: string): string;
begin
  const Reader = TStreamReader.Create(FileName, True);
  try
    Result := Reader.ReadToEnd;
  finally
    Reader.Free;
  end;
end;

class function TMd2HtmlRunner.RenderHtml(const Options: TMd2HtmlOptions; const Source: string): string;
begin
  var Builder: IMarkdownPipelineBuilder := TMarkdownPipeline.Create;

  if Options.UseGfm then
    Builder := Builder.UseGfm
  else
    Builder := Builder.UseCommonMark;

  if Options.XhtmlOutput then
    Builder := Builder.XhtmlOutput;

  if not Options.SafeHtml then
    Builder := Builder.UnsafeHtml;

  Result := Builder.Build.ToHtml(Source);
end;

class procedure TMd2HtmlRunner.WriteHtml(const Options: TMd2HtmlOptions; const Html: string);
begin
  if Options.OutputFile = '' then
  begin
    Write(Output, Html);
    Exit;
  end;

  TFile.WriteAllText(Options.OutputFile, Html, TEncoding.UTF8);
end;

end.
