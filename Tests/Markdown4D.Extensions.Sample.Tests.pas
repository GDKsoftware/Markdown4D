unit Markdown4D.Extensions.Sample.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkExtensionTests = class
  private
    class function RenderWithMarkExtension(const Source: string): string;
    class function RenderWithoutExtension(const Source: string): string;

  public
    [Test]
    procedure ToHtml_DelimitedText_RendersMarkElement;

    [Test]
    procedure ToHtml_DelimitedEmphasis_RendersNestedInlines;

    [Test]
    procedure ToHtml_SingleDelimiters_KeepsLiteralText;

    [Test]
    procedure ToHtml_UnclosedDelimiter_KeepsLiteralText;

    [Test]
    procedure ToHtml_WithoutExtension_KeepsLiteralText;
  end;

implementation

uses
  Markdown4D.Extensions.Interfaces,
  Markdown4D.Extensions.Sample,
  Markdown4D.Pipeline;

procedure TMarkExtensionTests.ToHtml_DelimitedText_RendersMarkElement;
begin
  Assert.AreEqual('<p><mark>text</mark></p>'#10, RenderWithMarkExtension('==text=='));
end;

procedure TMarkExtensionTests.ToHtml_DelimitedEmphasis_RendersNestedInlines;
begin
  Assert.AreEqual('<p><mark><em>em</em></mark></p>'#10, RenderWithMarkExtension('==*em*=='));
end;

procedure TMarkExtensionTests.ToHtml_SingleDelimiters_KeepsLiteralText;
begin
  Assert.AreEqual('<p>=text=</p>'#10, RenderWithMarkExtension('=text='));
end;

procedure TMarkExtensionTests.ToHtml_UnclosedDelimiter_KeepsLiteralText;
begin
  Assert.AreEqual('<p>==text</p>'#10, RenderWithMarkExtension('==text'));
end;

procedure TMarkExtensionTests.ToHtml_WithoutExtension_KeepsLiteralText;
begin
  Assert.AreEqual('<p>==text==</p>'#10, RenderWithoutExtension('==text=='));
end;

class function TMarkExtensionTests.RenderWithMarkExtension(const Source: string): string;
begin
  const Builder = TMarkdownPipeline.Create.UseCommonMark.Use(TMarkExtension.Create);

  const Pipeline = Builder.Build;
  Result := Pipeline.ToHtml(Source);
end;

class function TMarkExtensionTests.RenderWithoutExtension(const Source: string): string;
begin
  const Pipeline = TMarkdownPipeline.Create.UseCommonMark.Build;

  Result := Pipeline.ToHtml(Source);
end;

end.
