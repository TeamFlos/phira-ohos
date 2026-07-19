param(
    [string]$Source = (Join-Path $PSScriptRoot "build\outputs\default\phira_ohos_base-default-signed.app"),
    [string]$OutDir = (Join-Path $PSScriptRoot "build\outputs\default-unsigned-patch"),
    [string]$OutName = "phira_ohos_base-default-unsigned-patch.app",
    [string]$SevenZip = "7z",
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"

function Assert-SevenZip {
    $cmd = Get-Command $SevenZip -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $fallback = "C:\Program Files\7-Zip\7z.exe"
        if (Test-Path $fallback) { $script:SevenZip = $fallback; return }
        throw "7z not found. Install 7-Zip or add it to PATH."
    }
}

function Invoke-SevenZip {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    & $script:SevenZip @ArgList
    if ($LASTEXITCODE -ne 0) { throw "7z failed (exit $LASTEXITCODE): $($ArgList -join ' ')" }
}

function Patch-Content {
    param([string]$File, [string]$Pattern, [string]$Replacement)
    $raw = Get-Content -LiteralPath $File -Raw
    $new = $raw -replace $Pattern, $Replacement
    if ($new -eq $raw) { Write-Warning "No match for '$Pattern' in $File" }
    Set-Content -LiteralPath $File -Value $new -NoNewline
    Write-Host "[patched] ${File}: ${Pattern} -> ${Replacement}"
}

function Update-Archive {
    param(
        [string]$Archive,
        [string]$WorkDir,
        [string[]]$Files,
        [switch]$Deflate
    )
    Push-Location -LiteralPath $WorkDir
    try {
        if ($Deflate) {
            Invoke-SevenZip u -tzip -mx=5 $Archive @Files | Out-Null
        } else {
            Invoke-SevenZip u -tzip -mx0 $Archive @Files | Out-Null
        }
    } finally { Pop-Location }
}

Assert-SevenZip

if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source not found: $Source"
}
$resolvedSource = (Resolve-Path -LiteralPath $Source).ProviderPath

$temp     = Join-Path $env:TEMP ("phira_patch_{0}" -f ([guid]::NewGuid().ToString('N')))
$stageApp = Join-Path $temp "stage_app"
$stageHap = Join-Path $temp "stage_hap"
$workHap  = Join-Path $temp "hap_content"
$hapFile  = Join-Path $temp "entry-default.hap"

try {
    Write-Host "Source: $resolvedSource"
    Write-Host "Output: $OutDir"
    New-Item -ItemType Directory -Force -Path $temp, $stageApp, $stageHap, $workHap, $OutDir | Out-Null

    $outApp = Join-Path $OutDir $OutName
    Copy-Item -LiteralPath $resolvedSource -Destination $outApp -Force

    Write-Host "1/5 Patch app-level pack.info ..."
    Invoke-SevenZip x $outApp "-o$stageApp" pack.info -y | Out-Null
    Patch-Content -File (Join-Path $stageApp "pack.info") -Pattern '"releaseType"\s*:\s*"Beta1"' -Replacement '"releaseType": "Release"'
    Update-Archive -Archive $outApp -WorkDir $stageApp -Files "pack.info"

    Write-Host "2/5 Extract entry-default.hap from app ..."
    Invoke-SevenZip e $outApp "-o$temp" entry-default.hap -y | Out-Null
    if (-not (Test-Path -LiteralPath $hapFile)) {
        throw "entry-default.hap not found inside app"
    }

    Write-Host "3/5 Extract hap content ..."
    Invoke-SevenZip x $hapFile "-o$workHap" -y | Out-Null

    Write-Host "4/5 Patch hap-level pack.info + module.json ..."
    Patch-Content -File (Join-Path $workHap "pack.info")   -Pattern '"releaseType"\s*:\s*"Beta1"'   -Replacement '"releaseType": "Release"'
    Patch-Content -File (Join-Path $workHap "module.json") -Pattern '"apiReleaseType"\s*:\s*"Beta1"' -Replacement '"apiReleaseType":"Release"'

    Write-Host "5/5 Update hap inside app (store-only) ..."
    Update-Archive -Archive $hapFile  -WorkDir $workHap  -Files "pack.info", "module.json" -Deflate
    Copy-Item -LiteralPath $hapFile -Destination (Join-Path $stageHap "entry-default.hap") -Force
    Update-Archive -Archive $outApp  -WorkDir $stageHap  -Files "entry-default.hap"

    $item = Get-Item -LiteralPath $outApp
    $sizeMB = [math]::Round($item.Length / 1MB, 2)
    Write-Host ""
    Write-Host ("Done: {0} ({1} MiB)" -f $item.FullName, $sizeMB) -ForegroundColor Green
}
finally {
    if ($KeepTemp) {
        Write-Host "Temp kept: $temp"
    } else {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}