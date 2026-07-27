unit Markdown4D.Text.FileFormat.Tests;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  Markdown4D.Text.FileFormat;

type
  [TestFixture]
  TMarkdownTextFileTests = class
  private
    var
      FRootDir: string;
      FPath: string;
    procedure WriteBytes(const Bytes: TArray<Byte>);
    function ReadBytes: TArray<Byte>;
    function RoundTrip(const Bytes: TArray<Byte>): TArray<Byte>;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Load_CrlfFile_ReportsCrlfAndNormalizesToLf;

    [Test]
    procedure Load_LfFile_ReportsLf;

    [Test]
    procedure Load_CrOnlyFile_ReportsCr;

    [Test]
    procedure Load_FileWithoutLineBreak_UsesPlatformDefault;

    [Test]
    procedure Save_CrlfFormat_WritesCrlfBack;

    [Test]
    procedure RoundTrip_CrlfWithoutBom_IsByteIdentical;

    [Test]
    procedure RoundTrip_Utf8WithBom_KeepsBom;

    [Test]
    procedure RoundTrip_Utf8WithoutBom_StaysWithoutBom;

    [Test]
    procedure RoundTrip_Utf16LittleEndian_KeepsEncodingAndBom;

    [Test]
    procedure Load_AnsiFile_ReadsAccentedCharacters;

    [Test]
    procedure RoundTrip_AnsiFile_StaysAnsi;

    [Test]
    procedure Load_Utf8WithoutBom_ReadsAccentedCharacters;

    [Test]
    procedure Default_UsesUtf8WithoutBom;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

const
  Utf8BomBytes: array[0..2] of Byte = ($EF, $BB, $BF);

procedure TMarkdownTextFileTests.Setup;
begin
  FRootDir := TPath.Combine(TPath.GetTempPath, Format('Markdown4D_%s', [TPath.GetGUIDFileName]));
  TDirectory.CreateDirectory(FRootDir);

  FPath := TPath.Combine(FRootDir, 'sample.md');
end;

procedure TMarkdownTextFileTests.TearDown;
begin
  if TDirectory.Exists(FRootDir) then
    TDirectory.Delete(FRootDir, True);
end;

procedure TMarkdownTextFileTests.WriteBytes(const Bytes: TArray<Byte>);
begin
  TFile.WriteAllBytes(FPath, Bytes);
end;

function TMarkdownTextFileTests.ReadBytes: TArray<Byte>;
begin
  Result := TFile.ReadAllBytes(FPath);
end;

function TMarkdownTextFileTests.RoundTrip(const Bytes: TArray<Byte>): TArray<Byte>;
begin
  WriteBytes(Bytes);

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  TMarkdownTextFile.Save(FPath, Text, Format);
  Result := ReadBytes;
end;

procedure TMarkdownTextFileTests.Load_CrlfFile_ReportsCrlfAndNormalizesToLf;
begin
  WriteBytes(TEncoding.UTF8.GetBytes('first'#13#10'second'));

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.LineEnding = TMarkdownLineEnding.CrLf);
  Assert.AreEqual('first'#10'second', Text);
end;

procedure TMarkdownTextFileTests.Load_LfFile_ReportsLf;
begin
  WriteBytes(TEncoding.UTF8.GetBytes('first'#10'second'));

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.LineEnding = TMarkdownLineEnding.Lf);
  Assert.AreEqual('first'#10'second', Text);
end;

procedure TMarkdownTextFileTests.Load_CrOnlyFile_ReportsCr;
begin
  WriteBytes(TEncoding.UTF8.GetBytes('first'#13'second'));

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.LineEnding = TMarkdownLineEnding.Cr);
  Assert.AreEqual('first'#10'second', Text);
end;

procedure TMarkdownTextFileTests.Load_FileWithoutLineBreak_UsesPlatformDefault;
begin
  WriteBytes(TEncoding.UTF8.GetBytes('single line'));

  var Format: TMarkdownTextFormat;
  TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.LineEnding = TMarkdownTextFormat.Default.LineEnding);
end;

procedure TMarkdownTextFileTests.Save_CrlfFormat_WritesCrlfBack;
begin
  const Format = TMarkdownTextFormat.Create(TMarkdownTextEncoding.Utf8, TMarkdownLineEnding.CrLf);
  TMarkdownTextFile.Save(FPath, 'first'#10'second', Format);

  Assert.AreEqual('first'#13#10'second', TEncoding.UTF8.GetString(ReadBytes));
end;

procedure TMarkdownTextFileTests.RoundTrip_CrlfWithoutBom_IsByteIdentical;
begin
  const Original = TEncoding.UTF8.GetBytes('# Title'#13#10#13#10'Body text'#13#10);

  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(RoundTrip(Original)));
end;

procedure TMarkdownTextFileTests.RoundTrip_Utf8WithBom_KeepsBom;
begin
  const Original = TArray<Byte>.Create(Utf8BomBytes[0], Utf8BomBytes[1], Utf8BomBytes[2]) +
    TEncoding.UTF8.GetBytes('with mark');
  const Written = RoundTrip(Original);

  Assert.AreEqual(Integer(Length(Original)), Integer(Length(Written)));
  Assert.AreEqual(Integer(Utf8BomBytes[0]), Integer(Written[0]));
  Assert.AreEqual(Integer(Utf8BomBytes[2]), Integer(Written[2]));
end;

procedure TMarkdownTextFileTests.RoundTrip_Utf8WithoutBom_StaysWithoutBom;
begin
  const Original = TEncoding.UTF8.GetBytes('no mark here');
  const Written = RoundTrip(Original);

  Assert.AreEqual(Integer(Length(Original)), Integer(Length(Written)));
  Assert.AreNotEqual(Integer(Utf8BomBytes[0]), Integer(Written[0]));
end;

procedure TMarkdownTextFileTests.RoundTrip_Utf16LittleEndian_KeepsEncodingAndBom;
begin
  const Original = TEncoding.Unicode.GetPreamble + TEncoding.Unicode.GetBytes('wide text');
  const Written = RoundTrip(Original);

  Assert.AreEqual(Integer(Length(Original)), Integer(Length(Written)));
  Assert.AreEqual('wide text', TEncoding.Unicode.GetString(Written, 2, Length(Written) - 2));
end;

procedure TMarkdownTextFileTests.Load_AnsiFile_ReadsAccentedCharacters;
begin
  WriteBytes(TEncoding.ANSI.GetBytes('caf'#$00E9' pl'#$00E2'tre'));

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.Encoding = TMarkdownTextEncoding.Ansi);
  Assert.AreEqual('caf'#$00E9' pl'#$00E2'tre', Text);
end;

procedure TMarkdownTextFileTests.RoundTrip_AnsiFile_StaysAnsi;
begin
  const Original = TEncoding.ANSI.GetBytes('caf'#$00E9);
  const Written = RoundTrip(Original);

  Assert.AreEqual(Integer(Length(Original)), Integer(Length(Written)));
  Assert.AreEqual('caf'#$00E9, TEncoding.ANSI.GetString(Written));
end;

procedure TMarkdownTextFileTests.Load_Utf8WithoutBom_ReadsAccentedCharacters;
begin
  WriteBytes(TEncoding.UTF8.GetBytes('caf'#$00E9' na'#$00EF'ef'));

  var Format: TMarkdownTextFormat;
  const Text = TMarkdownTextFile.Load(FPath, Format);

  Assert.IsTrue(Format.Encoding = TMarkdownTextEncoding.Utf8);
  Assert.AreEqual('caf'#$00E9' na'#$00EF'ef', Text);
end;

procedure TMarkdownTextFileTests.Default_UsesUtf8WithoutBom;
begin
  Assert.IsTrue(TMarkdownTextFormat.Default.Encoding = TMarkdownTextEncoding.Utf8);
end;

end.
