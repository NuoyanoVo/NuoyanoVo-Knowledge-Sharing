$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$htmlName = (-join @([char]0x62A5, [char]0x544A, [char]0x65F6, [char]0x6BB5, [char]0x6574, [char]0x7406)) + '.html'
$introText = -join @([char]0x4E13, [char]0x5BB6, [char]0x7B80, [char]0x4ECB)
$htmlPath = Join-Path $root $htmlName
$expertDir = Join-Path $root 'assets\experts'
$resourceDir = Join-Path $root 'assets\resources'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True (Test-Path -LiteralPath $htmlPath) 'missing generated html'

$html = Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
$rowCount = ([regex]::Matches($html, '<tr\s+class="report-row"')).Count
$expertCount = ([regex]::Matches($html, 'data-expert-id=')).Count
$resourceLinkCount = ([regex]::Matches($html, 'assets/resources/')).Count

Assert-True ($html -match '<!doctype html>') 'html document must include doctype'
Assert-True ($html -match [regex]::Escape($introText)) 'html must include expert intro modal'
Assert-True ($rowCount -eq 17) "expected 17 report rows, found $rowCount"
Assert-True ($expertCount -ge 16) "expected at least 16 expert triggers, found $expertCount"
Assert-True (Test-Path -LiteralPath $expertDir) 'missing assets/experts directory'
Assert-True (Test-Path -LiteralPath $resourceDir) 'missing assets/resources directory'

$expertFiles = @(Get-ChildItem -LiteralPath $expertDir -File -ErrorAction SilentlyContinue)
$resourceFiles = @(Get-ChildItem -LiteralPath $resourceDir -File -ErrorAction SilentlyContinue)

Assert-True ($expertFiles.Count -ge 1) 'expected at least one local expert image or placeholder asset'
Assert-True ($resourceFiles.Count -ge 1) 'expected at least one downloaded course resource'
Assert-True ($resourceLinkCount -ge 1) 'expected at least one local resource link in html'

"PASS html=$htmlPath rows=$rowCount expertTriggers=$expertCount expertFiles=$($expertFiles.Count) resourceFiles=$($resourceFiles.Count)"
