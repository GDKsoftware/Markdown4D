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
      // The last index says whether the pipeline recognises front matter. A
      // pipeline, once built, lives until the process ends, so switching
      // FrontMatterEnabled only picks another cell and never frees one that a
      // parse on another thread may still be using.
      FPipelines: array[TMarkdownDialect, TRenderMode, Boolean] of IMarkdownPipeline;
      FLock: TObject;
      FFrontMatterEnabled: Boolean;
    class function PipelineFor(const Dialect: TMarkdownDialect; const Mode: TRenderMode;
                               const FrontMatter: Boolean): IMarkdownPipeline;
    class function BuildPipeline(const Dialect: TMarkdownDialect; const Mode: TRenderMode;
                                 const FrontMatter: Boolean): IMarkdownPipeline;
    class procedure SetFrontMatterEnabled(const Value: Boolean); static;

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
    // Parses text that is not the start of a document, such as markdown made
    // out of an HTML block, so a leading "---" never becomes front matter.
    class function ParseFragment(const Source: string; const Dialect: TMarkdownDialect = TMarkdownDialect.Gfm): IMarkdownDocument;
    class function ToMarkdown(const Document: IMarkdownDocument): string;
    class function CreateIncrementalParser(const Dialect: TMarkdownDialect = TMarkdownDialect.CommonMark): IMarkdownIncrementalParser;
    // Adds front matter recognition to the GFM dialect of Parse, ToHtml and
    // ToUnsafeHtml, and so to the viewers and editors. The CommonMark dialect
    // stays pure CommonMark. Meant to be set once at startup; a parse already
    // running when it changes finishes with the old setting.
    class property FrontMatterEnabled: Boolean read FFrontMatterEnabled write SetFrontMatterEnabled;
  end;

implementation

uses
  Markdown4D.Version,
  Markdown4D.Pipeline,
  Markdown4D.Extensions.FrontMatter,
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
  Result := PipelineFor(Dialect, TRenderMode.Safe, FFrontMatterEnabled).ToHtml(Source);
end;

class function TMarkdown.ToUnsafeHtml(const Source: string; const Dialect: TMarkdownDialect): string;
begin
  Result := PipelineFor(Dialect, TRenderMode.Unsafe, FFrontMatterEnabled).ToHtml(Source);
end;

class function TMarkdown.Parse(const Source: string; const Dialect: TMarkdownDialect): IMarkdownDocument;
begin
  Result := PipelineFor(Dialect, TRenderMode.Safe, FFrontMatterEnabled).Parse(Source);
end;

class function TMarkdown.ParseFragment(const Source: string; const Dialect: TMarkdownDialect): IMarkdownDocument;
begin
  Result := PipelineFor(Dialect, TRenderMode.Safe, False).Parse(Source);
end;

class function TMarkdown.PipelineFor(const Dialect: TMarkdownDialect; const Mode: TRenderMode;
                                     const FrontMatter: Boolean): IMarkdownPipeline;
begin
  const UsesFrontMatter = FrontMatter and (Dialect = TMarkdownDialect.Gfm);

  // The fast path reads the reference without holding the lock, so it carries a
  // barrier of its own: on a weakly ordered processor a thread could otherwise
  // see the reference before the object it points at is fully written. Leaving
  // the lock below publishes the write side.
  const Existing = FPipelines[Dialect, Mode, UsesFrontMatter];
  MemoryBarrier;

  if Existing <> nil then
  begin
    Result := Existing;
    Exit;
  end;

  TMonitor.Enter(FLock);
  try
    if FPipelines[Dialect, Mode, UsesFrontMatter] = nil then
      FPipelines[Dialect, Mode, UsesFrontMatter] := BuildPipeline(Dialect, Mode, UsesFrontMatter);

    Result := FPipelines[Dialect, Mode, UsesFrontMatter];
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TMarkdown.BuildPipeline(const Dialect: TMarkdownDialect; const Mode: TRenderMode;
                                       const FrontMatter: Boolean): IMarkdownPipeline;
begin
  var Builder := TMarkdownPipeline.Create.UseCommonMark;

  const IsGfmDialect = (Dialect = TMarkdownDialect.Gfm);
  if IsGfmDialect then
    Builder := Builder.UseGfm;

  if FrontMatter then
    Builder := Builder.Use(TFrontMatterExtension.Create);

  const IsUnsafe = (Mode = TRenderMode.Unsafe);
  if IsUnsafe then
    Builder := Builder.UnsafeHtml.UnsafeLinks;

  Result := Builder.Build;
end;

class procedure TMarkdown.SetFrontMatterEnabled(const Value: Boolean);
begin
  FFrontMatterEnabled := Value;
  MemoryBarrier;
end;

class function TMarkdown.ToMarkdown(const Document: IMarkdownDocument): string;
begin
  if Document = nil then
  begin
    Result := '';
    Exit;
  end;

  Result := TMarkdownWriter.WriteDocument(Document);
end;

// Streamed segments are parsed one by one, so a segment after the first that
// starts with "---" must not become front matter; the streaming parser leaves
// front matter out altogether.
class function TMarkdown.CreateIncrementalParser(const Dialect: TMarkdownDialect): IMarkdownIncrementalParser;
begin
  Result := TMarkdownIncrementalParser.CreateParser(PipelineFor(Dialect, TRenderMode.Safe, False));
end;

end.
