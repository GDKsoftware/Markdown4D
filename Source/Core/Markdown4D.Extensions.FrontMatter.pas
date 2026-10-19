unit Markdown4D.Extensions.FrontMatter;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  // Recognises a YAML front matter block at the start of a document, the way
  // Obsidian, Jekyll, Hugo and GitHub write it. The front matter node kind, its
  // HTML output and its markdown writer are part of the core; this extension
  // only turns the recognition on. Neither UseCommonMark nor UseGfm includes
  // it; TMarkdown.FrontMatterEnabled adds it to the GFM dialect of the facade.
  TFrontMatterExtension = class(TInterfacedObject, IMarkdownExtension)
  private
    const
      DashTrigger = '-';

  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  Markdown4D.Parser.Blocks;

procedure TFrontMatterExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterBlockParser(TFrontMatterBlockStarter.Create, DashTrigger, TMarkdownPriorities.FrontMatterBlockStart);
end;

end.
