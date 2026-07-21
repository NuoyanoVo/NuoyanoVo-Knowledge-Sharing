$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$htmlName = (-join @([char]0x62A5, [char]0x544A, [char]0x65F6, [char]0x6BB5, [char]0x6574, [char]0x7406)) + '.html'
$introText = -join @([char]0x4E13, [char]0x5BB6, [char]0x7B80, [char]0x4ECB)
$jiangText = -join @([char]0x848B, [char]0x51EF)
$reportIntroText = -join @([char]0x62A5, [char]0x544A, [char]0x5185, [char]0x5BB9, [char]0x7B80, [char]0x4ECB)
$guoFullText = -join @([char]0x6559, [char]0x80B2, [char]0x90E8, [char]0x6559, [char]0x80B2, [char]0x6570, [char]0x5B57, [char]0x5316, [char]0x4E13, [char]0x5BB6, [char]0x54A8, [char]0x8BE2, [char]0x59D4, [char]0x5458, [char]0x4F1A)
$jiaYuchaoFullText = -join @([char]0x5E94, [char]0x8BE5, [char]0x5982, [char]0x4F55, [char]0x7406, [char]0x89E3)
$guoPdfText = (-join @([char]0x90ED, [char]0x7ECD, [char]0x9752)) + ' AI'
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
$titlePdfHrefs = @([regex]::Matches($html, 'class="title-pdf-link"[^>]+href="([^"]+\.pdf)"') | ForEach-Object { [System.Uri]::UnescapeDataString($_.Groups[1].Value) })
$titlePdfHrefText = $titlePdfHrefs -join "`n"
$profilesJson = [regex]::Match($html, '(?is)<script id="profiles-data" type="application/json">\s*(.*?)\s*</script>').Groups[1].Value
$profiles = $profilesJson | ConvertFrom-Json
$introHtml = (($profiles.PSObject.Properties | ForEach-Object { [string]$_.Value.introHtml }) -join "`n")

Assert-True ($html -match '<!doctype html>') 'html document must include doctype'
Assert-True ($html -match [regex]::Escape($introText)) 'html must include expert intro modal'
Assert-True ($rowCount -eq 18) "expected 18 report rows, found $rowCount"
Assert-True ($expertCount -ge 18) "expected at least 18 expert triggers, found $expertCount"
Assert-True ($html -match [regex]::Escape($jiangText)) 'html must include Jiang Kai opening profile'
Assert-True ($introHtml -match '<strong[^>]*>\s*' + [regex]::Escape($reportIntroText) + '\s*</strong>') 'report intro label must be bold and separate'
Assert-True ($html -notmatch '<th>\s*Course Link\s*</th>') 'Course Link column must be removed'
Assert-True ($html -notmatch 'https://disk\.pku\.edu\.cn/link/') 'pku disk report external links must be removed from html'
Assert-True ($html -match 'class="title-pdf-link"') 'local pdf links must be attached to the Title column'
Assert-True ($titlePdfHrefs.Count -eq 9) "expected 9 report title pdf links, found $($titlePdfHrefs.Count)"
Assert-True ($titlePdfHrefText -match [regex]::Escape($guoPdfText)) 'downloaded pku disk pdfs must be linked from title cells'
Assert-True ($html -match [regex]::Escape($guoFullText)) 'Guo Shaoqing profile must include full later paragraph content'
Assert-True ($html -match [regex]::Escape($jiaYuchaoFullText)) 'Jia Yuchao profile must include report intro content'
Assert-True (Test-Path -LiteralPath $expertDir) 'missing assets/experts directory'
Assert-True (Test-Path -LiteralPath $resourceDir) 'missing assets/resources directory'

$expertFiles = @(Get-ChildItem -LiteralPath $expertDir -File -ErrorAction SilentlyContinue)
$resourceFiles = @(Get-ChildItem -LiteralPath $resourceDir -File -ErrorAction SilentlyContinue)

Assert-True ($expertFiles.Count -ge 15) "expected at least 15 local expert image/placeholder assets, found $($expertFiles.Count)"
Assert-True ($resourceFiles.Count -ge 1) 'expected at least one downloaded course resource'
Assert-True ($resourceLinkCount -ge 1) 'expected at least one local resource link in html'

"PASS html=$htmlPath rows=$rowCount expertTriggers=$expertCount expertFiles=$($expertFiles.Count) resourceFiles=$($resourceFiles.Count)"
