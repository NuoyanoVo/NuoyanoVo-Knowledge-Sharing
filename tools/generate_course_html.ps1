param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$Password,

    [string]$CourseUrl = 'https://class.csiec.com/course/view.php?id=22'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$AssetsDir = Join-Path $Root 'assets'
$ExpertDir = Join-Path $AssetsDir 'experts'
$ResourceDir = Join-Path $AssetsDir 'resources'
$HtmlName = (-join @([char]0x62A5, [char]0x544A, [char]0x65F6, [char]0x6BB5, [char]0x6574, [char]0x7406)) + '.html'
$HtmlPath = Join-Path $Root $HtmlName

New-Item -ItemType Directory -Force -Path $ExpertDir, $ResourceDir | Out-Null

function U {
    param([int[]]$Codes)
    return -join ($Codes | ForEach-Object { [char]$_ })
}

$ReportPrefix = U @(0x62A5, 0x544A, 0x4E13, 0x5BB6)
$TitleLabel = U @(0x9898, 0x76EE)
$GroupSummary = U @(0x5C0F, 0x7EC4, 0x603B, 0x7ED3, 0x62A5, 0x544A)
$Untitled = U @(0x672A, 0x586B, 0x5199)
$NoIntro = U @(0x8BE5, 0x9875, 0x9762, 0x672A, 0x63D0, 0x4F9B, 0x4E13, 0x5BB6, 0x7B80, 0x4ECB, 0x3002)
$GroupIntro = U @(0x8BA8, 0x8BBA, 0x533A, 0x6D3B, 0x52A8, 0xFF0C, 0x672A, 0x6807, 0x6CE8, 0x4E13, 0x5BB6, 0x3002)
$IntroTitle = U @(0x4E13, 0x5BB6, 0x7B80, 0x4ECB)
$ResourceTitle = U @(0x8BFE, 0x7A0B, 0x6587, 0x4EF6, 0x8D44, 0x6E90)
$OpeningLeaderName = U @(0x5F00, 0x73ED, 0x81F4, 0x8F9E, 0x9886, 0x5BFC, 0x20, 0x848B, 0x51EF, 0x9662, 0x957F, 0x7B80, 0x4ECB)
$JiangKai = U @(0x848B, 0x51EF)
$OpeningLeaderTitle = U @(0x5F00, 0x73ED, 0x81F4, 0x8F9E, 0x9886, 0x5BFC, 0x7B80, 0x4ECB)
$ReportIntroLabel = U @(0x62A5, 0x544A, 0x5185, 0x5BB9, 0x7B80, 0x4ECB)
$CourseIntroLabel = U @(0x8BFE, 0x7A0B, 0x5185, 0x5BB9, 0x7B80, 0x4ECB)
$ReportContentLabel = U @(0x62A5, 0x544A, 0x5185, 0x5BB9)
$PageTitleFallback = U @(0x5317, 0x4EAC, 0x5927, 0x5B66, 0x0032, 0x0030, 0x0032, 0x0036, 0x201C, 0x6559, 0x80B2, 0x6280, 0x672F, 0x524D, 0x6CBF, 0x201D, 0x6691, 0x671F, 0x5B66, 0x6821)

function Html-Decode {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlDecode($Value)
}

function Html-Encode {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Text-FromHtml {
    param([string]$Html)
    if ($null -eq $Html) { return '' }
    $text = $Html
    $text = [regex]::Replace($text, '(?is)<script.*?</script>', ' ')
    $text = [regex]::Replace($text, '(?is)<style.*?</style>', ' ')
    $text = [regex]::Replace($text, '(?is)<span class="accesshide.*?</span>', ' ')
    $text = [regex]::Replace($text, '(?is)<img\b[^>]*>', ' ')
    $text = [regex]::Replace($text, '(?is)<br\s*/?>', ' ')
    $text = [regex]::Replace($text, '(?is)</p\s*>', ' ')
    $text = [regex]::Replace($text, '(?is)<[^>]+>', ' ')
    $text = Html-Decode $text
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    return $text
}

function Sanitize-FileName {
    param([string]$Name)
    $value = if ([string]::IsNullOrWhiteSpace($Name)) { 'file' } else { $Name.Trim() }
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $value = $value.Replace([string]$char, '_')
    }
    $value = [regex]::Replace($value, '\s+', '_')
    if ($value.Length -gt 120) {
        $ext = [System.IO.Path]::GetExtension($value)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($value)
        $value = $base.Substring(0, [Math]::Min(90, $base.Length)) + $ext
    }
    return $value
}

function Resolve-Link {
    param([string]$BaseUrl, [string]$Href)
    $decoded = Html-Decode $Href
    if ($decoded -match '^https?://') { return $decoded }
    $base = [Uri]$BaseUrl
    return ([Uri]::new($base, $decoded)).AbsoluteUri
}

function Extension-From {
    param([string]$Url, [string]$ContentType)
    $decoded = [System.Net.WebUtility]::UrlDecode($Url)
    $extMatches = [regex]::Matches($decoded, '\.([A-Za-z0-9]{1,8})(?=($|[?#&]))')
    if ($extMatches.Count -gt 0) {
        return '.' + $extMatches[$extMatches.Count - 1].Groups[1].Value.ToLowerInvariant()
    }
    if ($ContentType -match 'pdf') { return '.pdf' }
    if ($ContentType -match 'png') { return '.png' }
    if ($ContentType -match 'jpe?g') { return '.jpg' }
    if ($ContentType -match 'gif') { return '.gif' }
    if ($ContentType -match 'webp') { return '.webp' }
    if ($ContentType -match 'html') { return '.html' }
    return '.bin'
}

function BaseName-FromUrl {
    param([string]$Url, [string]$Fallback)
    $decoded = [System.Net.WebUtility]::UrlDecode($Url)
    if ($decoded -match 'file=.*[\\/](?<name>[^\\/&?]+)$') {
        return $matches['name']
    }
    if ($decoded -match '[\\/](?<name>[^\\/&?]+\.[A-Za-z0-9]{1,8})(?:$|[?#&])') {
        return $matches['name']
    }
    return $Fallback
}

function Relative-Href {
    param([string]$RelativePath)
    return (($RelativePath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

function Save-TextFile {
    param([string]$Path, [string]$Content)
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Download-Binary {
    param(
        [string]$Url,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [string]$Directory,
        [string]$Prefix,
        [string]$FallbackName
    )

    try {
        $probe = Invoke-WebRequest -Uri $Url -WebSession $Session -MaximumRedirection 10 -TimeoutSec 90
        $finalUrl = $probe.BaseResponse.ResponseUri.AbsoluteUri
        $contentType = $probe.Headers['Content-Type']
        if ([string]::IsNullOrWhiteSpace($contentType)) {
            $contentType = $probe.BaseResponse.ContentType
        }
        $ext = Extension-From $finalUrl $contentType
        $baseName = BaseName-FromUrl $finalUrl $FallbackName
        if (-not ([System.IO.Path]::GetExtension($baseName))) {
            $baseName = $baseName + $ext
        }
        $safe = Sanitize-FileName ($Prefix + '-' + $baseName)
        $dest = Join-Path $Directory $safe
        Invoke-WebRequest -Uri $finalUrl -WebSession $Session -OutFile $dest -MaximumRedirection 10 -TimeoutSec 120 | Out-Null
        return [pscustomobject]@{
            Path = $dest
            FileName = [System.IO.Path]::GetFileName($dest)
            Relative = $null
            ContentType = $contentType
            FinalUrl = $finalUrl
            Success = $true
            Error = ''
        }
    } catch {
        return [pscustomobject]@{
            Path = ''
            FileName = ''
            Relative = ''
            ContentType = ''
            FinalUrl = $Url
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Extract-PageContentHtml {
    param([string]$PageHtml)

    $startMatch = [regex]::Match($PageHtml, '(?is)<div class="box py-3 generalbox[^>]*>')
    if (-not $startMatch.Success) {
        return ''
    }

    $start = $startMatch.Index
    $end = $PageHtml.IndexOf('<div class="mt-5 mb-1 activity-navigation"', $start)
    if ($end -lt 0) {
        $end = $PageHtml.IndexOf('</section>', $start)
    }
    if ($end -lt 0) {
        $end = [Math]::Min($PageHtml.Length, $start + 30000)
    }

    $body = $PageHtml.Substring($start, $end - $start)
    $body = [regex]::Replace($body, '(?is)<div class="modified">.*?</div>', ' ')
    return $body
}

function Extract-BodyLinks {
    param(
        [string]$BodyHtml,
        [string]$BaseUrl
    )

    $links = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $matches = [regex]::Matches($BodyHtml, '(?is)<a\b[^>]*\bhref="([^"]+)"[^>]*>(.*?)</a>')
    foreach ($match in $matches) {
        $href = Resolve-Link $BaseUrl $match.Groups[1].Value
        if ($seen.ContainsKey($href)) { continue }
        $seen[$href] = $true
        $label = Text-FromHtml $match.Groups[2].Value
        if ([string]::IsNullOrWhiteSpace($label)) {
            $label = $href
        }
        $links.Add([pscustomobject]@{
            Href = $href
            Label = $label
        })
    }
    return $links.ToArray()
}

function Link-DisplayLabel {
    param(
        [string]$Label,
        [string]$Href
    )

    if ([string]::IsNullOrWhiteSpace($Label) -or $Label -match '^https?://') {
        if ($Href -match 'disk\.pku\.edu\.cn') {
            return $ReportContentLabel
        }
        return 'Link'
    }
    return $Label
}

function Resolve-PkuDiskTitle {
    param([string]$Href)

    if ($Href -notmatch 'disk\.pku\.edu\.cn/link/') {
        return ''
    }

    try {
        $response = Invoke-WebRequest -Uri $Href -MaximumRedirection 10 -TimeoutSec 60
        $finalUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
        $match = [regex]::Match($finalUrl, '[?&]title=([^&]+)')
        if ($match.Success) {
            return [System.Net.WebUtility]::UrlDecode($match.Groups[1].Value)
        }
    } catch {
        return ''
    }

    return ''
}

function Find-LocalReportFiles {
    param(
        [string]$Title,
        [string]$Directory
    )

    $found = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Title) -or -not (Test-Path -LiteralPath $Directory)) {
        return $found.ToArray()
    }

    $exact = Join-Path $Directory $Title
    if (Test-Path -LiteralPath $exact) {
        $file = Get-Item -LiteralPath $exact
        $found.Add([pscustomobject]@{
            FileName = $file.Name
            LocalHref = 'assets/resources/' + (Relative-Href $file.Name)
        })
        return $found.ToArray()
    }

    $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($Title)
    $prefixes = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($nameWithoutExtension)) {
        $firstToken = ($nameWithoutExtension -split '\s+')[0]
        if ($firstToken.Length -ge 2) {
            $prefixes.Add($firstToken)
        }
        if ($nameWithoutExtension.Length -ge 3) {
            $prefixes.Add($nameWithoutExtension.Substring(0, 3))
        }
    }

    $files = @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.pdf' -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        foreach ($prefix in $prefixes) {
            if ($file.Name.StartsWith($prefix)) {
                $found.Add([pscustomobject]@{
                    FileName = $file.Name
                    LocalHref = 'assets/resources/' + (Relative-Href $file.Name)
                })
                break
            }
        }
    }

    return $found.ToArray()
}

function Enrich-ReportLinks {
    param(
        [object[]]$Links,
        [string]$Directory
    )

    $enriched = New-Object System.Collections.Generic.List[object]
    foreach ($link in @($Links)) {
        $diskTitle = Resolve-PkuDiskTitle $link.Href
        $localFiles = Find-LocalReportFiles -Title $diskTitle -Directory $Directory
        $enriched.Add([pscustomobject]@{
            Href = $link.Href
            Label = $link.Label
            DiskTitle = $diskTitle
            LocalFiles = $localFiles
        })
    }
    return $enriched.ToArray()
}

function Build-LinkListHtml {
    param([object[]]$Links)

    $items = New-Object System.Text.StringBuilder
    foreach ($link in @($Links)) {
        foreach ($localFile in @($link.LocalFiles)) {
            [void]$items.Append('<a class="inline-link" href="')
            [void]$items.Append((Html-Encode $localFile.LocalHref))
            [void]$items.Append('" download>')
            [void]$items.Append((Html-Encode $localFile.FileName))
            [void]$items.Append('</a>')
        }
        [void]$items.Append('<a class="inline-link" href="')
        [void]$items.Append((Html-Encode $link.Href))
        [void]$items.Append('" target="_blank" rel="noreferrer">')
        [void]$items.Append((Html-Encode (Link-DisplayLabel $link.Label $link.Href)))
        [void]$items.Append('</a>')
    }
    return $items.ToString()
}

function Build-IntroHtml {
    param(
        [string]$PlainText,
        [object[]]$Links
    )

    $text = if ($null -eq $PlainText) { '' } else { $PlainText.Trim() }
    $text = [regex]::Replace($text, '\s*最后修改:.*$', '').Trim()
    foreach ($link in @($Links)) {
        if (-not [string]::IsNullOrWhiteSpace($link.Href)) {
            $text = $text.Replace($link.Href, '').Trim()
        }
        if ($link.Label -match '^https?://' -and -not [string]::IsNullOrWhiteSpace($link.Label)) {
            $text = $text.Replace($link.Label, '').Trim()
        }
    }
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return '<p>' + (Html-Encode $NoIntro) + '</p>'
    }

    $labels = @($ReportIntroLabel, $CourseIntroLabel, $ReportContentLabel)
    $pattern = '(' + (($labels | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s*[:' + [char]0xFF1A + ']'
    $matches = [regex]::Matches($text, $pattern)
    $html = New-Object System.Text.StringBuilder

    if ($matches.Count -eq 0) {
        [void]$html.Append('<p>' + (Html-Encode $text) + '</p>')
        return $html.ToString()
    }

    $first = $matches[0]
    $lead = $text.Substring(0, $first.Index).Trim()
    if (-not [string]::IsNullOrWhiteSpace($lead)) {
        [void]$html.Append('<p>' + (Html-Encode $lead) + '</p>')
    }

    for ($i = 0; $i -lt $matches.Count; $i++) {
        $label = $matches[$i].Groups[1].Value
        $contentStart = $matches[$i].Index + $matches[$i].Length
        $contentEnd = if ($i + 1 -lt $matches.Count) { $matches[$i + 1].Index } else { $text.Length }
        $content = $text.Substring($contentStart, $contentEnd - $contentStart).Trim()
        if ($label -eq $ReportContentLabel) {
            continue
        } else {
            [void]$html.Append('<p><strong>' + (Html-Encode $label) + '</strong><br>' + (Html-Encode $content) + '</p>')
        }
    }

    return $html.ToString()
}

function Login-Course {
    param([string]$Username, [string]$Password)
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $login = Invoke-WebRequest -Uri 'https://class.csiec.com/login/index.php' -WebSession $session -TimeoutSec 60
    $token = $login.Forms[0].Fields['logintoken']
    $body = @{
        username = $Username
        password = $Password
        logintoken = $token
        anchor = ''
        rememberusername = '1'
    }
    Invoke-WebRequest -Uri 'https://class.csiec.com/login/index.php' -Method Post -Body $body -WebSession $session -MaximumRedirection 10 -TimeoutSec 60 | Out-Null
    return $session
}

$PlaceholderSvg = @'
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">
  <rect width="240" height="240" rx="40" fill="#edf2f7"/>
  <circle cx="120" cy="92" r="42" fill="#8aa0b8"/>
  <path d="M52 208c12-45 45-70 68-70s56 25 68 70" fill="#8aa0b8"/>
</svg>
'@
$placeholderPath = Join-Path $ExpertDir 'placeholder.svg'
Save-TextFile $placeholderPath $PlaceholderSvg

$session = Login-Course -Username $Username -Password $Password
$course = Invoke-WebRequest -Uri $CourseUrl -WebSession $session -TimeoutSec 90
$courseHtml = $course.Content
$courseTitleMatch = [regex]::Match($courseHtml, '(?is)<h1>(.*?)</h1>')
$courseTitle = if ($courseTitleMatch.Success) { Text-FromHtml $courseTitleMatch.Groups[1].Value } else { $PageTitleFallback }
if ([string]::IsNullOrWhiteSpace($courseTitle)) { $courseTitle = $PageTitleFallback }

$sections = [regex]::Matches($courseHtml, '(?is)<li\s+id="section-(\d+)"[^>]*aria-label="([^"]*)"')
$rows = New-Object System.Collections.Generic.List[object]
$resources = New-Object System.Collections.Generic.List[object]
$rowIndex = 0

for ($i = 0; $i -lt $sections.Count; $i++) {
    $sectionId = [int]$sections[$i].Groups[1].Value
    $timeSlot = Html-Decode $sections[$i].Groups[2].Value
    $start = $sections[$i].Index
    $end = if ($i + 1 -lt $sections.Count) { $sections[$i + 1].Index } else { $courseHtml.Length }
    $fragment = $courseHtml.Substring($start, $end - $start)

    $activities = [regex]::Matches($fragment, '(?is)<li class="activity\s+([^"]*)"[^>]*id="module-(\d+)".*?<div class="activityinstance">\s*<a[^>]*href="([^"]+)"[^>]*>.*?<span class="instancename">(.*?)</span>\s*</a>')
    foreach ($activity in $activities) {
        $classes = $activity.Groups[1].Value
        $moduleId = [int]$activity.Groups[2].Value
        $href = Resolve-Link $CourseUrl $activity.Groups[3].Value
        $name = Text-FromHtml $activity.Groups[4].Value

        if ($classes -match 'modtype_resource') {
            $resources.Add([pscustomobject]@{
                ModuleId = $moduleId
                SectionId = $sectionId
                TimeSlot = $timeSlot
                Name = $name
                Url = $href
                LocalFile = ''
                LocalHref = ''
                Error = ''
            })
        }

        $isReport = $name.StartsWith($ReportPrefix)
        $isOpeningLeader = ($name -eq $OpeningLeaderName)
        $isGroupSummary = ($name -eq $GroupSummary)
        if ($isReport -or $isOpeningLeader -or $isGroupSummary) {
            $rowIndex++
            $expert = $name
            $title = $name
            if ($isReport) {
                $rx = '^' + [regex]::Escape($ReportPrefix) + '\s*[:' + [char]0xFF1A + ']\s*(.*?)\s*[;' + [char]0xFF1B + ']\s*' + [regex]::Escape($TitleLabel) + '\s*[:' + [char]0xFF1A + ']\s*(.*)$'
                $match = [regex]::Match($name, $rx)
                if ($match.Success) {
                    $expert = $match.Groups[1].Value.Trim()
                    $title = $match.Groups[2].Value.Trim()
                    if ([string]::IsNullOrWhiteSpace($title)) { $title = $Untitled }
                }
            } elseif ($isOpeningLeader) {
                $expert = $JiangKai
                $title = $OpeningLeaderTitle
            }

            $rows.Add([pscustomobject]@{
                Id = 'row-' + $rowIndex
                Index = $rowIndex
                SectionId = $sectionId
                TimeSlot = $timeSlot
                Expert = $expert
                Title = $title
                RawName = $name
                Url = $href
                IsReport = $isReport
                HasDetailPage = ($isReport -or $isOpeningLeader)
                Intro = if ($isGroupSummary) { $GroupIntro } else { $NoIntro }
                IntroHtml = ''
                ImageHref = 'assets/experts/placeholder.svg'
                ImageFile = 'placeholder.svg'
                Resources = @()
                ReportLinks = @()
            })
        }
    }
}

foreach ($row in $rows) {
    if (-not $row.HasDetailPage) { continue }
    try {
        $detail = Invoke-WebRequest -Uri $row.Url -WebSession $session -TimeoutSec 90
        $bodyHtml = Extract-PageContentHtml $detail.Content
        $intro = Text-FromHtml $bodyHtml
        $links = Extract-BodyLinks -BodyHtml $bodyHtml -BaseUrl $row.Url
        $links = Enrich-ReportLinks -Links $links -Directory $ResourceDir
        if (-not [string]::IsNullOrWhiteSpace($intro)) {
            $row.Intro = $intro
        }
        $row.ReportLinks = $links
        $row.IntroHtml = Build-IntroHtml -PlainText $row.Intro -Links $links

        $imageMatches = [regex]::Matches($bodyHtml, '(?is)<img\b[^>]*\bsrc="([^"]+)"[^>]*>')
        foreach ($image in $imageMatches) {
            $src = Resolve-Link $row.Url $image.Groups[1].Value
            if ($src -match '/theme/image\.php') { continue }
            $download = Download-Binary -Url $src -Session $session -Directory $ExpertDir -Prefix ('expert-' + ('{0:d2}' -f $row.Index)) -FallbackName ('expert-' + $row.Index + '.jpg')
            if ($download.Success) {
                $row.ImageFile = $download.FileName
                $row.ImageHref = 'assets/experts/' + (Relative-Href $download.FileName)
                break
            }
        }
    } catch {
        $row.Intro = $row.Intro + ' ' + $_.Exception.Message
        $row.IntroHtml = Build-IntroHtml -PlainText $row.Intro -Links @()
    }
}

foreach ($row in $rows) {
    if ([string]::IsNullOrWhiteSpace($row.IntroHtml)) {
        $row.IntroHtml = Build-IntroHtml -PlainText $row.Intro -Links @($row.ReportLinks)
    }
}

foreach ($resource in $resources) {
    try {
        $probe = Invoke-WebRequest -Uri $resource.Url -WebSession $session -MaximumRedirection 10 -TimeoutSec 90
        $contentType = $probe.Headers['Content-Type']
        if ([string]::IsNullOrWhiteSpace($contentType)) { $contentType = $probe.BaseResponse.ContentType }
        $downloadUrl = $probe.BaseResponse.ResponseUri.AbsoluteUri

        if ($contentType -match 'text/html') {
            $links = [regex]::Matches($probe.Content, '(?is)(?:href|src)="([^"]*pluginfile\.php[^"]+)"')
            if ($links.Count -gt 0) {
                $downloadUrl = Resolve-Link $resource.Url $links[0].Groups[1].Value
            }
        }

        $download = Download-Binary -Url $downloadUrl -Session $session -Directory $ResourceDir -Prefix ('resource-' + $resource.ModuleId) -FallbackName ($resource.Name + '.bin')
        if ($download.Success) {
            $resource.LocalFile = $download.FileName
            $resource.LocalHref = 'assets/resources/' + (Relative-Href $download.FileName)
        } else {
            $resource.Error = $download.Error
        }
    } catch {
        $resource.Error = $_.Exception.Message
    }
}

foreach ($row in $rows) {
    $rowResources = @($resources | Where-Object { $_.SectionId -eq $row.SectionId -and -not [string]::IsNullOrWhiteSpace($_.LocalHref) })
    $row.Resources = $rowResources
}

$profileMap = @{}
foreach ($row in $rows) {
    $profileMap[$row.Id] = [ordered]@{
        expert = $row.Expert
        title = $row.Title
        timeSlot = $row.TimeSlot
        introHtml = $row.IntroHtml
        imageHref = $row.ImageHref
        pageUrl = $row.Url
    }
}
$profilesJson = ($profileMap | ConvertTo-Json -Depth 8)
$profilesJson = $profilesJson.Replace('</script', '<\/script')

$tableRows = New-Object System.Text.StringBuilder
foreach ($row in $rows) {
    $resourceLinks = New-Object System.Text.StringBuilder
    foreach ($resource in $row.Resources) {
        [void]$resourceLinks.Append('<a class="resource-chip" href="')
        [void]$resourceLinks.Append((Html-Encode $resource.LocalHref))
        [void]$resourceLinks.Append('" download>')
        [void]$resourceLinks.Append((Html-Encode $resource.Name))
        [void]$resourceLinks.Append('</a>')
    }
    if ($resourceLinks.Length -eq 0) {
        [void]$resourceLinks.Append('<span class="muted">-</span>')
    }

    $localPdfLinks = New-Object System.Collections.Generic.List[object]
    $seenPdfLinks = @{}
    foreach ($link in @($row.ReportLinks)) {
        foreach ($localFile in @($link.LocalFiles)) {
            if ([string]::IsNullOrWhiteSpace($localFile.LocalHref)) { continue }
            if ($seenPdfLinks.ContainsKey($localFile.LocalHref)) { continue }
            $seenPdfLinks[$localFile.LocalHref] = $true
            $localPdfLinks.Add($localFile)
        }
    }

    $titleHtml = Html-Encode $row.Title
    if ($localPdfLinks.Count -gt 0) {
        $firstPdf = $localPdfLinks[0]
        $titleBuilder = New-Object System.Text.StringBuilder
        [void]$titleBuilder.Append('<a class="title-pdf-link" href="')
        [void]$titleBuilder.Append((Html-Encode $firstPdf.LocalHref))
        [void]$titleBuilder.Append('" download>')
        [void]$titleBuilder.Append((Html-Encode $row.Title))
        [void]$titleBuilder.Append('</a>')
        if ($localPdfLinks.Count -gt 1) {
            [void]$titleBuilder.Append('<div class="title-pdf-list">')
            for ($pdfIndex = 1; $pdfIndex -lt $localPdfLinks.Count; $pdfIndex++) {
                $pdf = $localPdfLinks[$pdfIndex]
                [void]$titleBuilder.Append('<a class="title-pdf-link" href="')
                [void]$titleBuilder.Append((Html-Encode $pdf.LocalHref))
                [void]$titleBuilder.Append('" download>')
                [void]$titleBuilder.Append((Html-Encode $pdf.FileName))
                [void]$titleBuilder.Append('</a>')
            }
            [void]$titleBuilder.Append('</div>')
        }
        $titleHtml = $titleBuilder.ToString()
    }

    [void]$tableRows.AppendLine('<tr class="report-row">')
    [void]$tableRows.AppendLine('<td>' + $row.Index + '</td>')
    [void]$tableRows.AppendLine('<td>' + (Html-Encode $row.TimeSlot) + '</td>')
    [void]$tableRows.AppendLine('<td><button class="expert-trigger" type="button" data-expert-id="' + (Html-Encode $row.Id) + '"><img class="avatar" src="' + (Html-Encode $row.ImageHref) + '" alt=""><span>' + (Html-Encode $row.Expert) + '</span></button></td>')
    [void]$tableRows.AppendLine('<td class="title-cell">' + $titleHtml + '</td>')
    [void]$tableRows.AppendLine('<td>' + $resourceLinks.ToString() + '</td>')
    [void]$tableRows.AppendLine('</tr>')
}

$resourceItems = New-Object System.Text.StringBuilder
foreach ($resource in $resources) {
    [void]$resourceItems.AppendLine('<li>')
    [void]$resourceItems.Append('<span class="resource-meta">' + (Html-Encode $resource.TimeSlot) + '</span>')
    if (-not [string]::IsNullOrWhiteSpace($resource.LocalHref)) {
        [void]$resourceItems.Append('<a href="' + (Html-Encode $resource.LocalHref) + '" download>' + (Html-Encode $resource.Name) + '</a>')
    } else {
        [void]$resourceItems.Append('<a href="' + (Html-Encode $resource.Url) + '" target="_blank" rel="noreferrer">' + (Html-Encode $resource.Name) + '</a>')
        if (-not [string]::IsNullOrWhiteSpace($resource.Error)) {
            [void]$resourceItems.Append('<span class="resource-error">' + (Html-Encode $resource.Error) + '</span>')
        }
    }
    [void]$resourceItems.AppendLine('</li>')
}

$generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$html = @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(Html-Encode $courseTitle) - $(Html-Encode $ReportPrefix)</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f9;
      --panel: #ffffff;
      --text: #1f2933;
      --muted: #64748b;
      --line: #d7dee8;
      --accent: #246b6f;
      --accent-2: #8b5e34;
      --soft: #e8f2f2;
      --shadow: 0 16px 40px rgba(31, 41, 51, .12);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: "Microsoft YaHei", "PingFang SC", "Segoe UI", Arial, sans-serif;
      line-height: 1.55;
    }
    header {
      background: #183642;
      color: white;
      padding: 28px clamp(18px, 5vw, 56px);
    }
    header h1 {
      margin: 0 0 8px;
      font-size: clamp(24px, 3vw, 38px);
      font-weight: 760;
      letter-spacing: 0;
    }
    header p {
      margin: 0;
      color: rgba(255,255,255,.78);
    }
    main {
      max-width: 1240px;
      margin: 0 auto;
      padding: 24px clamp(14px, 3vw, 28px) 48px;
    }
    .toolbar {
      display: flex;
      gap: 12px;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;
    }
    .summary {
      color: var(--muted);
      font-size: 14px;
    }
    .search {
      width: min(360px, 100%);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px 12px;
      font-size: 15px;
      background: white;
    }
    .table-wrap {
      overflow-x: auto;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: 0 1px 2px rgba(31,41,51,.04);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      min-width: 980px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 12px 14px;
      text-align: left;
      vertical-align: middle;
    }
    th {
      background: #eef3f6;
      color: #243b53;
      font-size: 14px;
      font-weight: 700;
      position: sticky;
      top: 0;
      z-index: 1;
    }
    tr:last-child td { border-bottom: 0; }
    .expert-trigger {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      border: 0;
      background: transparent;
      color: var(--accent);
      padding: 0;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }
    .expert-trigger:hover span { text-decoration: underline; }
    .avatar {
      width: 46px;
      height: 46px;
      border-radius: 50%;
      object-fit: cover;
      border: 2px solid var(--soft);
      background: var(--soft);
      flex: 0 0 auto;
    }
    .resource-chip {
      display: inline-flex;
      align-items: center;
      min-height: 28px;
      margin: 2px 4px 2px 0;
      padding: 4px 8px;
      border-radius: 8px;
      background: #f1f6f4;
      color: var(--accent);
      text-decoration: none;
      font-size: 13px;
      white-space: nowrap;
    }
    .resource-chip:hover { text-decoration: underline; }
    .title-pdf-link {
      color: var(--accent);
      font-weight: 700;
      text-decoration: none;
    }
    .title-pdf-link:hover { text-decoration: underline; }
    .title-pdf-list {
      display: flex;
      flex-direction: column;
      gap: 4px;
      margin-top: 6px;
      font-size: 13px;
    }
    .inline-link {
      display: inline-flex;
      margin: 4px 8px 0 0;
      color: var(--accent);
      font-weight: 700;
    }
    .muted { color: var(--muted); }
    .resources {
      margin-top: 24px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px 20px;
    }
    .resources h2 {
      margin: 0 0 12px;
      font-size: 20px;
    }
    .resources ul {
      margin: 0;
      padding-left: 20px;
      columns: 2;
    }
    .resources li {
      break-inside: avoid;
      margin: 6px 0;
    }
    .resource-meta {
      display: inline-block;
      min-width: 128px;
      color: var(--muted);
      font-size: 13px;
      margin-right: 8px;
    }
    .resource-error {
      color: #b42318;
      margin-left: 8px;
      font-size: 12px;
    }
    .modal-backdrop {
      position: fixed;
      inset: 0;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 20px;
      background: rgba(15, 23, 42, .5);
      z-index: 10;
    }
    .modal-backdrop.open { display: flex; }
    .modal {
      width: min(760px, 100%);
      max-height: min(760px, 90vh);
      overflow: auto;
      background: white;
      border-radius: 8px;
      box-shadow: var(--shadow);
    }
    .modal-head {
      display: flex;
      gap: 16px;
      align-items: center;
      padding: 20px;
      border-bottom: 1px solid var(--line);
    }
    .modal-head img {
      width: 88px;
      height: 88px;
      border-radius: 50%;
      object-fit: cover;
      background: var(--soft);
    }
    .modal-head h2 {
      margin: 0 0 4px;
      font-size: 24px;
    }
    .modal-head p {
      margin: 0;
      color: var(--muted);
    }
    .modal-body {
      padding: 20px;
    }
    .modal-body h3 {
      margin: 0 0 8px;
      font-size: 18px;
      color: var(--accent-2);
    }
    .modal-body p {
      margin: 0 0 14px;
      white-space: pre-wrap;
    }
    .intro-content p {
      margin: 0 0 16px;
    }
    .intro-content strong {
      display: inline-block;
      margin-bottom: 4px;
      color: var(--accent-2);
    }
    .close-btn {
      margin-left: auto;
      width: 38px;
      height: 38px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: white;
      cursor: pointer;
      font-size: 22px;
      line-height: 1;
    }
    @media (max-width: 760px) {
      .toolbar { align-items: stretch; flex-direction: column; }
      .resources ul { columns: 1; }
      .modal-head { align-items: flex-start; }
    }
  </style>
</head>
<body>
  <header>
    <h1>$(Html-Encode $courseTitle)</h1>
    <p>$(Html-Encode $ReportPrefix) / $(Html-Encode $ResourceTitle) - generated $generatedAt</p>
  </header>
  <main>
    <div class="toolbar">
      <div class="summary">Rows: $($rows.Count) &nbsp; Resources: $($resources.Count)</div>
      <input id="search" class="search" type="search" placeholder="Search expert, title, or time">
    </div>
    <div class="table-wrap">
      <table id="report-table">
        <thead>
          <tr>
            <th>#</th>
            <th>Time</th>
            <th>Expert / Activity</th>
            <th>Title</th>
            <th>Files</th>
          </tr>
        </thead>
        <tbody>
$($tableRows.ToString())
        </tbody>
      </table>
    </div>
    <section class="resources">
      <h2>$(Html-Encode $ResourceTitle)</h2>
      <ul>
$($resourceItems.ToString())
      </ul>
    </section>
  </main>

  <div id="modal-backdrop" class="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="modal-name">
    <article class="modal">
      <div class="modal-head">
        <img id="modal-image" src="assets/experts/placeholder.svg" alt="">
        <div>
          <h2 id="modal-name"></h2>
          <p id="modal-time"></p>
        </div>
        <button id="modal-close" class="close-btn" type="button" aria-label="Close">&times;</button>
      </div>
      <div class="modal-body">
        <h3 id="modal-title"></h3>
        <h3>$(Html-Encode $IntroTitle)</h3>
        <div id="modal-intro" class="intro-content"></div>
        <p><a id="modal-link" href="#" target="_blank" rel="noreferrer">Open in Moodle</a></p>
      </div>
    </article>
  </div>

  <script id="profiles-data" type="application/json">
$profilesJson
  </script>
  <script>
    const profiles = JSON.parse(document.getElementById('profiles-data').textContent);
    const backdrop = document.getElementById('modal-backdrop');
    const closeBtn = document.getElementById('modal-close');
    const search = document.getElementById('search');

    function openProfile(id) {
      const profile = profiles[id];
      if (!profile) return;
      document.getElementById('modal-image').src = profile.imageHref || 'assets/experts/placeholder.svg';
      document.getElementById('modal-name').textContent = profile.expert || '';
      document.getElementById('modal-time').textContent = profile.timeSlot || '';
      document.getElementById('modal-title').textContent = profile.title || '';
      document.getElementById('modal-intro').innerHTML = profile.introHtml || '';
      document.getElementById('modal-link').href = profile.pageUrl || '#';
      backdrop.classList.add('open');
    }

    document.querySelectorAll('[data-expert-id]').forEach((button) => {
      button.addEventListener('click', () => openProfile(button.dataset.expertId));
    });

    closeBtn.addEventListener('click', () => backdrop.classList.remove('open'));
    backdrop.addEventListener('click', (event) => {
      if (event.target === backdrop) backdrop.classList.remove('open');
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') backdrop.classList.remove('open');
    });

    search.addEventListener('input', () => {
      const value = search.value.trim().toLowerCase();
      document.querySelectorAll('#report-table tbody tr').forEach((row) => {
        row.style.display = row.textContent.toLowerCase().includes(value) ? '' : 'none';
      });
    });
  </script>
</body>
</html>
"@

Save-TextFile $HtmlPath $html

$expertFiles = @(Get-ChildItem -LiteralPath $ExpertDir -File -ErrorAction SilentlyContinue)
$resourceFiles = @(Get-ChildItem -LiteralPath $ResourceDir -File -ErrorAction SilentlyContinue)
"generated=$HtmlPath rows=$($rows.Count) experts=$($expertFiles.Count) resources=$($resourceFiles.Count)"
