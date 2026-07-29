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
    type
      // Safe drops raw HTML and scripting destinations, which is what a caller
      // rendering someone else's document needs. Unsafe reproduces the
      // specification byte for byte and trusts the input.
      TRenderMode = (Safe, Unsafe);
    class var
      FPipelines: array[TMarkdownDialect, TRenderMode] of IMarkdownPipeline;
      FLock: TObject;
    class function PipelineFor(const Dialect: TMarkdownDialect; const Mode: TRenderMode): IMarkdownPipeline;
    class function BuildPipeline(const Dialect: TMarkdownDialect; const Mode: TRenderMode): IMarkdownPipeline;

  public
    class constructor Create;
    class destructor Destroy;
    class function Version: string;
    // Renders with raw HTML omitted and javascript:, vbscript:, file: and
    // non-image data: destinations emptied. Use this for anything that did not
    // come from the application itself.
    class function ToHtml(const Source: string; const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;
    // Renders exactly what the CommonMark and GFM specifications prescribe:
    // raw HTML and every destination reach the output untouched. Only safe for
    // documents the application trusts, or when the result passes through an
    // HTML sanitizer afterwards.
    class function ToUnsafeHtml(const Source: string; const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): string;
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
  Result := PipelineFor(Dialect, TRenderMode.Safe).ToHtml(Source);
end;

class function TMarkdown.ToUnsafeHtml(const Source: string; const Dialect: TMarkdownDialect): string;
begin
  Result := PipelineFor(Dialect, TRenderMode.Unsafe).ToHtml(Source);
end;

class function TMarkdown.Parse(const Source: string; const Dialect: TMarkdownDialect): IMarkdownDocument;
begin
  Result := PipelineFor(Dialect, TRenderMode.Safe).Parse(Source);
end;

class function TMarkdown.PipelineFor(const Dialect: TMarkdownDialect; const Mode: TRenderMode): IMarkdownPipeline;
begin
  if FPipelines[Dialect, Mode] = nil then
  begin
    TMonitor.Enter(FLock);
    try
      if FPipelines[Dialect, Mode] = nil then
        FPipelines[Dialect, Mode] := BuildPipeline(Dialect, Mode);
    finally
      TMonitor.Exit(FLock);
    end;
  end;

  Result := FPipelines[Dialect, Mode];
end;

class function TMarkdown.BuildPipeline(const Dialect: TMarkdownDialect; const Mode: TRenderMode): IMarkdownPipeline;
begin
  var Builder := TMarkdownPipeline.Create.UseCommonMark;

  const IsGfmDialect = (Dialect = TMarkdownDialect.Gfm);
  if IsGfmDialect then
    Builder := Builder.UseGfm;

  const IsUnsafe = (Mode = TRenderMode.Unsafe);
  if IsUnsafe then
    Builder := Builder.UnsafeHtml.UnsafeLinks;

  Result := Builder.Build;
end;

class function TMarkdown.ToMarkdown(const Document: IMarkdownDocument): string;
begin
  if Document = nil then
    Exit('');

  Result := TMarkdownWriter.WriteDocument(Document);
end;

class function TMarkdown.CreateIncrementalParser(const Dialect: TMarkdownDialect): IMarkdownIncrementalParser;
begin
  Result := TMarkdownIncrementalParser.CreateParser(PipelineFor(Dialect, TRenderMode.Safe));
end;

end.
