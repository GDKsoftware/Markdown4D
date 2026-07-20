unit Markdown4D;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Defines,
  Markdown4D.Ast.Interfaces,
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Parser.Interfaces;

type
  TMarkdown = class
  private
    class var
      FDefaultPipeline: IMarkdownPipeline;
      FGfmPipeline: IMarkdownPipeline;
      FLock: TObject;
    class function PipelineFor(const Dialect: TMarkdownDialect): IMarkdownPipeline;
    class function DefaultPipeline: IMarkdownPipeline;
    class function GfmPipeline: IMarkdownPipeline;

  public
    class constructor Create;
    class destructor Destroy;
    class function Version: string;
    class function ToHtml(const Source: string; const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;
    class function Parse(const Source: string; const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): IMarkdownDocument;
    class function ToMarkdown(const Document: IMarkdownDocument): string;
    class function CreateIncrementalParser(const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): IMarkdownIncrementalParser;
  end;

implementation

uses
  Markdown4D.Version,
  Markdown4D.Pipeline,
  Markdown4D.Parser.Incremental,
  Markdown4D.Writer.Markdown;

class constructor TMarkdown.Create;
begin
  FLock := TObject.Create;
end;

class destructor TMarkdown.Destroy;
begin
  FLock.Free;
end;

class function TMarkdown.Version: string;
begin
  Result := Markdown4DVersion;
end;

class function TMarkdown.ToHtml(const Source: string; const Dialect: TMarkdownDialect): string;
begin
  Result := PipelineFor(Dialect).ToHtml(Source);
end;

class function TMarkdown.Parse(const Source: string; const Dialect: TMarkdownDialect): IMarkdownDocument;
begin
  Result := PipelineFor(Dialect).Parse(Source);
end;

class function TMarkdown.PipelineFor(const Dialect: TMarkdownDialect): IMarkdownPipeline;
begin
  const IsGfmDialect = (Dialect = TMarkdownDialect.Gfm);
  if IsGfmDialect then
    Exit(GfmPipeline);

  Result := DefaultPipeline;
end;

class function TMarkdown.DefaultPipeline: IMarkdownPipeline;
begin
  if FDefaultPipeline = nil then
  begin
    TMonitor.Enter(FLock);
    try
      if FDefaultPipeline = nil then
        FDefaultPipeline := TMarkdownPipeline.Create.UseCommonMark.UnsafeHtml.Build;
    finally
      TMonitor.Exit(FLock);
    end;
  end;

  Result := FDefaultPipeline;
end;

class function TMarkdown.GfmPipeline: IMarkdownPipeline;
begin
  if FGfmPipeline = nil then
  begin
    TMonitor.Enter(FLock);
    try
      if FGfmPipeline = nil then
        FGfmPipeline := TMarkdownPipeline.Create.UseGfm.UnsafeHtml.Build;
    finally
      TMonitor.Exit(FLock);
    end;
  end;

  Result := FGfmPipeline;
end;

class function TMarkdown.ToMarkdown(const Document: IMarkdownDocument): string;
begin
  if Document = nil then
    Exit('');

  Result := TMarkdownWriter.WriteDocument(Document);
end;

class function TMarkdown.CreateIncrementalParser(const Dialect: TMarkdownDialect): IMarkdownIncrementalParser;
begin
  Result := TMarkdownIncrementalParser.CreateParser(PipelineFor(Dialect));
end;

end.
