unit Markdown4D.Extensions.Math;

{$SCOPEDENUMS ON}

interface

uses
  Markdown4D.Extensions.Interfaces;

type
  // Registers the "$...$" and "$$...$$" syntax plus the ```math fence alias.
  // The math node kind itself, its HTML output and its markdown writer are
  // part of the core; this extension only turns the parsers on. UseGfm
  // includes it, so TMarkdown and the viewers recognise math out of the box.
  TMathExtension = class(TInterfacedObject, IMarkdownExtension)
  public
    procedure Setup(const Pipeline: IMarkdownPipelineBuilder);
  end;

implementation

uses
  Markdown4D.Defines,
  Markdown4D.Parser.Blocks,
  Markdown4D.Parser.Inlines;

procedure TMathExtension.Setup(const Pipeline: IMarkdownPipelineBuilder);
begin
  Pipeline.RegisterBlockParser(TMathBlockStarter.Create, Dollar, TMarkdownPriorities.MathBlockStart);
  Pipeline.RegisterInlineParser(TMathInlineParser.Create, Dollar, TMarkdownPriorities.MathInline);
end;

end.
