unit Markdown4D.Vcl.ScrollBarTheme.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Theme;

type
  [TestFixture]
  TMarkdownScrollBarThemeTests = class
  public
    [Test]
    [TestCase('Light', 'Light,')]
    [TestCase('Dark', 'Dark,DarkMode_Explorer')]
    procedure ThemeName_PerPreset_FollowsBackground(const Preset: TMarkdownThemePreset; const Expected: string);

    [Test]
    procedure Apply_ControlWithoutHandle_LeavesHandleUnallocated;
  end;

implementation

uses
  Vcl.Controls,
  Markdown4D.Vcl.ScrollBarTheme;

procedure TMarkdownScrollBarThemeTests.ThemeName_PerPreset_FollowsBackground(const Preset: TMarkdownThemePreset;
  const Expected: string);
begin
  const Theme = TMarkdownTheme.CreatePreset(Preset);
  try
    const Actual = TMarkdownScrollBarTheme.ThemeName(Theme.BackgroundColor);

    Assert.AreEqual(Expected, Actual);
  finally
    Theme.Free;
  end;
end;

procedure TMarkdownScrollBarThemeTests.Apply_ControlWithoutHandle_LeavesHandleUnallocated;
begin
  const Control = TWinControl.Create(nil);
  try
    const Theme = TMarkdownTheme.CreatePreset(TMarkdownThemePreset.Dark);
    try
      TMarkdownScrollBarTheme.Apply(Control, Theme.BackgroundColor);
    finally
      Theme.Free;
    end;

    Assert.IsFalse(Control.HandleAllocated, 'applying the scroll bar theme must not force a window handle');
  finally
    Control.Free;
  end;
end;

end.
