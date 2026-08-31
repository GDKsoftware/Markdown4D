[CmdletBinding()]
param(
    [string]$ResultsPath,
    [string]$ReadmePath
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ResultsPath) {
    $ResultsPath = Join-Path $RepoRoot 'Tests\results\dunitx-results.xml'
}
if (-not $ReadmePath) {
    $ReadmePath = Join-Path $RepoRoot 'README.md'
}

if (-not (Test-Path -LiteralPath $ResultsPath)) {
    Write-Warning "Test results not found at '$ResultsPath'. Dashboard not updated."
    exit 0
}
if (-not (Test-Path -LiteralPath $ReadmePath)) {
    Write-Warning "README not found at '$ReadmePath'. Dashboard not updated."
    exit 0
}

[xml]$Results = Get-Content -LiteralPath $ResultsPath -Raw

$CorpusNames = @('CommonMark', 'Gfm', 'RoundTrip', 'Incremental')
$FixtureToCorpus = @{
    'TCommonMarkSpecTests'         = 'CommonMark'
    'TGfmSpecTests'                = 'Gfm'
    'TRoundTripTests'              = 'RoundTrip'
    'TIncrementalEquivalenceTests' = 'Incremental'
}
$Counts = @{}
foreach ($CorpusName in $CorpusNames) {
    $Counts[$CorpusName] = @{ Total = 0; Passed = 0 }
}

$Fixtures = $Results.SelectNodes('//test-suite[@type="Fixture"]')
foreach ($Fixture in $Fixtures) {
    $FixtureName = [string]$Fixture.GetAttribute('name')
    if (-not $FixtureToCorpus.ContainsKey($FixtureName)) {
        continue
    }
    $CorpusName = $FixtureToCorpus[$FixtureName]
    foreach ($TestCase in $Fixture.SelectNodes('.//test-case')) {
        $TestName = [string]$TestCase.GetAttribute('name')
        if ($TestName -match '_Corpus_ContainsAllExamples$') {
            continue
        }
        $Counts[$CorpusName].Total++
        if ($TestCase.GetAttribute('result') -eq 'Success') {
            $Counts[$CorpusName].Passed++
        }
    }
}

$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add('| Corpus | Tests | Passed | Pass rate |')
$Lines.Add('|--------|------:|-------:|----------:|')

$GrandTotal = 0
$GrandPassed = 0
foreach ($CorpusName in $CorpusNames) {
    $Total = $Counts[$CorpusName].Total
    $Passed = $Counts[$CorpusName].Passed
    $GrandTotal += $Total
    $GrandPassed += $Passed
    if ($Total -gt 0) {
        $Percentage = [math]::Round(100.0 * $Passed / $Total, 1)
    } else {
        $Percentage = 0.0
    }
    $Lines.Add(('| {0} | {1} | {2} | {3}% |' -f $CorpusName, $Total, $Passed, $Percentage.ToString('0.0', $Invariant)))
}

if ($GrandTotal -gt 0) {
    $GrandPercentage = [math]::Round(100.0 * $GrandPassed / $GrandTotal, 1)
} else {
    $GrandPercentage = 0.0
}
$Lines.Add(('| **Total** | **{0}** | **{1}** | **{2}%** |' -f $GrandTotal, $GrandPassed, $GrandPercentage.ToString('0.0', $Invariant)))

$Table = $Lines -join "`n"

$StartMarker = '<!-- conformance:start -->'
$EndMarker = '<!-- conformance:end -->'

$Readme = [System.IO.File]::ReadAllText($ReadmePath)
$StartIndex = $Readme.IndexOf($StartMarker)
$EndIndex = $Readme.IndexOf($EndMarker)

if ($StartIndex -lt 0 -or $EndIndex -lt 0 -or $EndIndex -lt $StartIndex) {
    Write-Warning "Conformance markers not found in '$ReadmePath'. Dashboard not updated."
    exit 0
}

$Before = $Readme.Substring(0, $StartIndex)
$After = $Readme.Substring($EndIndex + $EndMarker.Length)
$Updated = $Before + $StartMarker + "`n" + $Table + "`n" + $EndMarker + $After

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReadmePath, $Updated, $Utf8NoBom)

Write-Host ('Conformance dashboard updated: {0}/{1} tests passing ({2}%).' -f $GrandPassed, $GrandTotal, $GrandPercentage.ToString('0.0', $Invariant))
