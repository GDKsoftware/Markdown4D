unit Markdown4DStudio.Startup.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TStudioStartupTests = class
  private
    FSavedFrontMatterEnabled: Boolean;

  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ConfigureMarkdown_FromDefaults_EnablesFrontMatter;
  end;

implementation

uses
  Markdown4D,
  Markdown4DStudio.Startup;

procedure TStudioStartupTests.Setup;
begin
  FSavedFrontMatterEnabled := TMarkdown.FrontMatterEnabled;
  TMarkdown.FrontMatterEnabled := False;
end;

procedure TStudioStartupTests.TearDown;
begin
  TMarkdown.FrontMatterEnabled := FSavedFrontMatterEnabled;
end;

procedure TStudioStartupTests.ConfigureMarkdown_FromDefaults_EnablesFrontMatter;
begin
  TStudioStartup.ConfigureMarkdown;

  Assert.IsTrue(TMarkdown.FrontMatterEnabled);
end;

end.
