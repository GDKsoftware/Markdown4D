unit MarkdownPad.Commands.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  MarkdownPad.Commands;

type
  [TestFixture]
  TPadCommandsTests = class
  private
    var
      FRegistry: TPadCommandRegistry;
      FInvoked: Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Register_ThenCommands_PreservesRegistrationOrder;

    [Test]
    procedure Count_ReflectsRegistrations;

    [Test]
    procedure Clear_EmptiesRegistry;

    [Test]
    procedure Action_IsInvocable;

    [Test]
    procedure Match_EmptyQuery_ReturnsAllInRegistrationOrder;

    [Test]
    procedure Match_NoSubsequence_ExcludesCommand;

    [Test]
    procedure Match_CaseInsensitive;

    [Test]
    procedure Match_SortedByScoreDescending;

    [Test]
    procedure Match_ConsecutiveRunScoresHigherThanScattered;

    [Test]
    procedure Match_WordStartScoresHigher;

    [Test]
    procedure Match_EarlierMatchScoresHigher;

    [Test]
    procedure Match_TieKeepsRegistrationOrder;

    [Test]
    procedure FuzzyScore_Subsequence_ReturnsTrue;

    [Test]
    procedure FuzzyScore_NotSubsequence_ReturnsFalse;

    [Test]
    procedure FuzzyScore_EmptyQuery_ReturnsTrueZeroScore;
  end;

implementation

const
  SampleCategory = 'Cat';
  NoShortcut = '';

procedure TPadCommandsTests.Setup;
begin
  FRegistry := TPadCommandRegistry.Create;
  FInvoked := False;
end;

procedure TPadCommandsTests.TearDown;
begin
  FRegistry.Free;
end;

procedure TPadCommandsTests.Register_ThenCommands_PreservesRegistrationOrder;
begin
  FRegistry.Register('Alpha', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Beta', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Gamma', SampleCategory, NoShortcut, nil);

  const Commands = FRegistry.Commands;

  Assert.AreEqual(3, Length(Commands));
  Assert.AreEqual('Alpha', Commands[0].Name);
  Assert.AreEqual('Beta', Commands[1].Name);
  Assert.AreEqual('Gamma', Commands[2].Name);
end;

procedure TPadCommandsTests.Count_ReflectsRegistrations;
begin
  Assert.AreEqual(0, FRegistry.Count);

  FRegistry.Register('One', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Two', SampleCategory, NoShortcut, nil);

  Assert.AreEqual(2, FRegistry.Count);
end;

procedure TPadCommandsTests.Clear_EmptiesRegistry;
begin
  FRegistry.Register('One', SampleCategory, NoShortcut, nil);
  FRegistry.Clear;

  Assert.AreEqual(0, FRegistry.Count);
end;

procedure TPadCommandsTests.Action_IsInvocable;
begin
  FRegistry.Register('Do', SampleCategory, NoShortcut,
    procedure
    begin
      FInvoked := True;
    end);

  const Commands = FRegistry.Commands;
  Commands[0].Action();

  Assert.IsTrue(FInvoked);
end;

procedure TPadCommandsTests.Match_EmptyQuery_ReturnsAllInRegistrationOrder;
begin
  FRegistry.Register('First', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Second', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Third', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('');

  Assert.AreEqual(3, Length(Matches));
  Assert.AreEqual('First', Matches[0].Command.Name);
  Assert.AreEqual('Second', Matches[1].Command.Name);
  Assert.AreEqual('Third', Matches[2].Command.Name);
end;

procedure TPadCommandsTests.Match_NoSubsequence_ExcludesCommand;
begin
  FRegistry.Register('Save', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('zz');

  Assert.AreEqual(0, Length(Matches));
end;

procedure TPadCommandsTests.Match_CaseInsensitive;
begin
  FRegistry.Register('Save', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('sav');

  Assert.AreEqual(1, Length(Matches));
  Assert.AreEqual('Save', Matches[0].Command.Name);
end;

procedure TPadCommandsTests.Match_SortedByScoreDescending;
begin
  FRegistry.Register('Save', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Split view', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Save As', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('sa');

  Assert.IsTrue(Length(Matches) >= 2);
  Assert.IsTrue(Matches[0].Score >= Matches[1].Score);
end;

procedure TPadCommandsTests.Match_ConsecutiveRunScoresHigherThanScattered;
begin
  FRegistry.Register('Sidebar', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Save As', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('sa');

  Assert.AreEqual(2, Length(Matches));
  Assert.AreEqual('Save As', Matches[0].Command.Name);
  Assert.IsTrue(Matches[0].Score > Matches[1].Score);
end;

procedure TPadCommandsTests.Match_WordStartScoresHigher;
begin
  FRegistry.Register('Reopen', SampleCategory, NoShortcut, nil);
  FRegistry.Register('Open File', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('o');

  Assert.AreEqual(2, Length(Matches));
  Assert.AreEqual('Open File', Matches[0].Command.Name);
  Assert.IsTrue(Matches[0].Score > Matches[1].Score);
end;

procedure TPadCommandsTests.Match_EarlierMatchScoresHigher;
begin
  FRegistry.Register('abcx', SampleCategory, NoShortcut, nil);
  FRegistry.Register('axb', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('x');

  Assert.AreEqual(2, Length(Matches));
  Assert.AreEqual('axb', Matches[0].Command.Name);
  Assert.IsTrue(Matches[0].Score > Matches[1].Score);
end;

procedure TPadCommandsTests.Match_TieKeepsRegistrationOrder;
begin
  FRegistry.Register('apple', SampleCategory, NoShortcut, nil);
  FRegistry.Register('avocado', SampleCategory, NoShortcut, nil);

  const Matches = FRegistry.Match('a');

  Assert.AreEqual(2, Length(Matches));
  Assert.AreEqual(Matches[0].Score, Matches[1].Score);
  Assert.AreEqual('apple', Matches[0].Command.Name);
  Assert.AreEqual('avocado', Matches[1].Command.Name);
end;

procedure TPadCommandsTests.FuzzyScore_Subsequence_ReturnsTrue;
begin
  var CommandScore: Integer;
  Assert.IsTrue(TPadFuzzyMatcher.Score('Save As', 'sa', CommandScore));
end;

procedure TPadCommandsTests.FuzzyScore_NotSubsequence_ReturnsFalse;
begin
  var CommandScore: Integer;
  Assert.IsFalse(TPadFuzzyMatcher.Score('Save', 'zz', CommandScore));
end;

procedure TPadCommandsTests.FuzzyScore_EmptyQuery_ReturnsTrueZeroScore;
begin
  var CommandScore: Integer;
  Assert.IsTrue(TPadFuzzyMatcher.Score('Save', '', CommandScore));
  Assert.AreEqual(0, CommandScore);
end;

end.
