[CmdletBinding()]
param(
  [ValidateSet("smoke", "core", "cache", "ahb", "mmio", "soc", "full")]
  [string]$Suite = "smoke",

  [switch]$DryRun,
  [switch]$KeepGoing,

  [string]$List = "",
  [string]$Make = "make"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SimDir = Resolve-Path (Join-Path $ScriptDir "..")
if ([string]::IsNullOrWhiteSpace($List)) {
  $List = Join-Path $ScriptDir "regression_list.txt"
}

if (!(Test-Path $List)) {
  throw "Missing regression list: $List"
}

function Read-RegressionList {
  param([string]$Path)

  $items = @()
  $lineNo = 0
  foreach ($line in Get-Content -Path $Path) {
    $lineNo++
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }

    $parts = $line -split "\|", 5
    if ($parts.Count -lt 4) {
      throw "Bad regression list line ${lineNo}: $line"
    }

    $items += [pscustomobject]@{
      Name     = $parts[0].Trim()
      TbFile   = $parts[1].Trim()
      TopName  = $parts[2].Trim()
      Suites   = @($parts[3].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      PlusArgs = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "" }
    }
  }

  return $items
}

$allTests = Read-RegressionList -Path $List
$selected = @($allTests | Where-Object { $_.Suites -contains $Suite })

if ($selected.Count -eq 0) {
  throw "No tests selected for suite '$Suite'"
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runDir = Join-Path $SimDir "log/regress/$stamp-$Suite"

Write-Host "Regression suite : $Suite"
Write-Host "Selected tests   : $($selected.Count)"
Write-Host "Simulation dir   : $SimDir"
Write-Host "Run log dir      : $runDir"
Write-Host ""

$failures = @()

Push-Location $SimDir
try {
  if (!$DryRun) {
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
  }

  for ($idx = 0; $idx -lt $selected.Count; $idx++) {
    $test = $selected[$idx]
    $ordinal = $idx + 1
    $makeArgs = @("sim", "TB_FILE=$($test.TbFile)", "TOP_NAME=$($test.TopName)")
    if (![string]::IsNullOrWhiteSpace($test.PlusArgs)) {
      $makeArgs += "SIM_PLUSARGS=$($test.PlusArgs)"
    }

    $cmdText = "$Make " + ($makeArgs -join " ")
    Write-Host "[$ordinal/$($selected.Count)] $($test.Name)"
    Write-Host "  $cmdText"

    if ($DryRun) {
      continue
    }

    $runLog = Join-Path $runDir "$($test.Name).run.log"
    & $Make @makeArgs 2>&1 | Tee-Object -FilePath $runLog
    $exitCode = $LASTEXITCODE

    $compileLog = Join-Path $SimDir "log/compile.log"
    $simLog = Join-Path $SimDir "log/sim.log"
    if (Test-Path $compileLog) {
      Copy-Item -Path $compileLog -Destination (Join-Path $runDir "$($test.Name).compile.log") -Force
    }
    if (Test-Path $simLog) {
      Copy-Item -Path $simLog -Destination (Join-Path $runDir "$($test.Name).sim.log") -Force
    }

    if ($exitCode -ne 0) {
      $failures += $test.Name
      Write-Host "  FAIL: exit code $exitCode" -ForegroundColor Red
      if (!$KeepGoing) {
        break
      }
    } else {
      Write-Host "  PASS" -ForegroundColor Green
    }
    Write-Host ""
  }
}
finally {
  Pop-Location
}

if ($DryRun) {
  Write-Host ""
  Write-Host "Dry run complete. No simulations were launched."
  exit 0
}

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "Regression PASS: $Suite" -ForegroundColor Green
  Write-Host "Logs: $runDir"
  exit 0
}

Write-Host "Regression FAIL: $Suite" -ForegroundColor Red
Write-Host "Failed tests:"
foreach ($failure in $failures) {
  Write-Host "  $failure"
}
Write-Host "Logs: $runDir"
exit 1
