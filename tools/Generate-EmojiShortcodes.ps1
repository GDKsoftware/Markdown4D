[CmdletBinding()]
param(
    [string]$Version = 'v4.1.0',
    [string]$EmojiJsonPath,
    [string]$LicensePath,
    [string]$UnitPath
)

# Regenerates the shortcode table in Markdown4D.Emoji.Shortcodes.pas from
# gemoji's db/emoji.json. Without -EmojiJsonPath or -LicensePath the files of
# the given gemoji release are downloaded from GitHub. Only the license header
# and the table are replaced; the code of the unit stays as it is.

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $UnitPath) {
    $UnitPath = Join-Path $RepoRoot 'Source\Core\Markdown4D.Emoji.Shortcodes.pas'
}

$ReleaseUrl = "https://raw.githubusercontent.com/github/gemoji/$Version"
$ProjectUrl = 'https://github.com/github/gemoji'

function Read-SourceText([string]$LocalPath, [string]$RelativeUrl) {
    if ($LocalPath) {
        return Get-Content -LiteralPath $LocalPath -Raw -Encoding UTF8
    }
    $Url = "$ReleaseUrl/$RelativeUrl"
    Write-Verbose "Downloading $Url"
    return (Invoke-WebRequest -Uri $Url -UseBasicParsing).Content
}

function ConvertTo-PascalLiteral([string]$Emoji) {
    $CodeUnits = foreach ($Character in $Emoji.ToCharArray()) {
        '#$' + ([int]$Character).ToString('X4')
    }
    return ($CodeUnits -join '')
}

$EmojiJson = Read-SourceText $EmojiJsonPath 'db/emoji.json'
$LicenseText = Read-SourceText $LicensePath 'LICENSE'

$CopyrightLine = ($LicenseText -split "`r?`n" | Where-Object { $_ -match '^\s*Copyright' } | Select-Object -First 1)
if (-not $CopyrightLine) {
    throw 'No copyright line found in the gemoji LICENSE file.'
}
$CopyrightLine = $CopyrightLine.Trim()

$Mappings = New-Object 'System.Collections.Generic.SortedDictionary[string,string]' ([System.StringComparer]::Ordinal)
foreach ($Entry in ($EmojiJson | ConvertFrom-Json)) {
    if (-not $Entry.emoji) {
        continue
    }
    $Literal = ConvertTo-PascalLiteral $Entry.emoji
    foreach ($Alias in $Entry.aliases) {
        if ($Mappings.ContainsKey($Alias)) {
            throw "Duplicate alias '$Alias' in emoji.json."
        }
        $Mappings.Add($Alias, $Literal)
    }
}

$Header = @"
{
  The shortcode table below is derived from db/emoji.json of gemoji $Version
  ($ProjectUrl). Regenerate it with
  tools/Generate-EmojiShortcodes.ps1. Every alias of an emoji that has a
  Unicode character is one entry; custom aliases without a character (such as
  octocat) are left out. Each value holds the UTF-16 code units of the emoji,
  including variation selectors and zero-width joiners as gemoji lists them.

  gemoji is distributed under the MIT license:

  $CopyrightLine

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
}
"@

$TableLines = New-Object System.Collections.Generic.List[string]
$TableLines.Add("  ShortcodeCount = $($Mappings.Count);")
$TableLines.Add('  Shortcodes: array[0..ShortcodeCount - 1] of TEmojiShortcodeMapping = (')
$EntryIndex = 0
foreach ($Mapping in $Mappings.GetEnumerator()) {
    $EntryIndex++
    $Separator = if ($EntryIndex -eq $Mappings.Count) { ');' } else { ',' }
    $TableLines.Add("    (Name: '$($Mapping.Key)'; Value: $($Mapping.Value))$Separator")
}

$UnitText = Get-Content -LiteralPath $UnitPath -Raw -Encoding UTF8
$NewLine = if ($UnitText.Contains("`r`n")) { "`r`n" } else { "`n" }

$HeaderPattern = '(?s)(?<=^unit [^\r\n]+;\r?\n\r?\n)\{.*?\}(?=\r?\n\r?\ninterface)'
$TablePattern = '(?s)  ShortcodeCount = \d+;.*?\)\);'
if (-not [regex]::IsMatch($UnitText, $HeaderPattern) -or -not [regex]::IsMatch($UnitText, $TablePattern)) {
    throw "Header or table not found in '$UnitPath'."
}

$NormalizedHeader = ($Header -split "`r?`n") -join $NewLine
$NewTable = $TableLines -join $NewLine
$UnitText = [regex]::Replace($UnitText, $HeaderPattern, { param($Match) $NormalizedHeader })
$UnitText = [regex]::Replace($UnitText, $TablePattern, { param($Match) $NewTable })

[System.IO.File]::WriteAllText($UnitPath, $UnitText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote $($Mappings.Count) shortcodes to $UnitPath"
