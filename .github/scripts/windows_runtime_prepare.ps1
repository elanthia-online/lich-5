# Prepare CI through production manifest policy, real consent and repair restart.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
# A fresh receipt directory prevents earlier artifacts from authorizing consent.
$artifacts = Join-Path $root "tmp/windows-webui/runtime-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force $artifacts | Out-Null
$ruby = (Get-Command ruby).Source
$rubyw = Join-Path (Split-Path $ruby) 'rubyw.exe'
if (-not (Test-Path $rubyw)) { throw 'The selected Ruby has no rubyw.exe' }

# Click only the real Yes control on the exact production dialog owned by this run.
# GetDlgItem/BM_CLICK: https://learn.microsoft.com/en-us/windows/win32/controls/bm-click
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WindowsRuntimeConsent {
  delegate bool Visitor(IntPtr window, IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumWindows(Visitor visit, IntPtr data);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr dialog, int id);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr window, uint message, IntPtr w, IntPtr l);
  public static bool Approve(uint process) {
    bool clicked = false;
    EnumWindows((window, data) => {
      uint owner; GetWindowThreadProcessId(window, out owner);
      if (owner != process) return true;
      var title = new StringBuilder(256); GetWindowText(window, title, title.Capacity);
      if (title.ToString() != "Lich5: Ruby Gem Check") return true;
      var yes = GetDlgItem(window, 6);
      if (yes == IntPtr.Zero) return true;
      SetForegroundWindow(window);
      clicked = PostMessage(yes, 0x00F5, IntPtr.Zero, IntPtr.Zero);
      return !clicked;
    }, IntPtr.Zero);
    return clicked;
  }
}
'@

$startedAt = [DateTime]::UtcNow
# Reject PID reuse as well as unrelated Ruby processes before consent or cleanup.
function Get-ObservedRuby($file) {
  try {
    $childId = [int]($file.BaseName -replace '^process-', '')
    $observedAt = [double]::Parse((Get-Content $file.FullName)[1], [Globalization.CultureInfo]::InvariantCulture)
    $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
    if ($child -and $child.Path -in @($ruby, $rubyw) -and
        $child.StartTime.ToUniversalTime() -ge $startedAt -and
        ([DateTimeOffset]$child.StartTime.ToUniversalTime()).ToUnixTimeMilliseconds() -le ($observedAt * 1000)) {
      return $child
    }
  } catch {
    # A process may exit while its identity is being read; it is ineligible.
    return $null
  }
}

$clicked = [System.Collections.Generic.HashSet[int]]::new()
$environment = @{}
$names = @('RUBYOPT', 'RUBYLIB', 'BUNDLE_GEMFILE', 'BUNDLE_PATH', 'BUNDLER_SETUP', 'RUBYGEMS_GEMDEPS', 'GEM_HOME', 'GEM_PATH', 'LICH_CI_RUNTIME_ARTIFACTS')
$startup = $null
try {
  foreach ($name in $names) {
    $environment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
  }
  $env:LICH_CI_RUNTIME_ARTIFACTS = $artifacts
  $env:RUBYOPT = '-r' + (Join-Path $root '.github/scripts/windows_runtime_observer.rb').Replace('\', '/')
  $startup = Start-Process -FilePath $rubyw -ArgumentList 'lich.rbw' -WorkingDirectory $root -PassThru -RedirectStandardOutput "$artifacts/startup.stdout.log" -RedirectStandardError "$artifacts/startup.stderr.log"
  $clock = [Diagnostics.Stopwatch]::StartNew()
  while ($clock.Elapsed.TotalMinutes -lt 10) {
    foreach ($file in Get-ChildItem $artifacts -Filter 'process-*.txt') {
      $child = Get-ObservedRuby $file
      if ($child -and -not $clicked.Contains($child.Id) -and [WindowsRuntimeConsent]::Approve($child.Id)) {
        [void]$clicked.Add($child.Id)
        "Approved actual gem-repair Yes button for PID $($child.Id)" | Tee-Object -FilePath "$artifacts/consent.log" -Append
      }
    }
    if (Test-Path "$artifacts/ready.json") { break }
    Start-Sleep -Seconds 1
  }
  if (-not (Test-Path "$artifacts/ready.json")) { throw 'Production runtime preparation did not reach accepted activation within ten minutes' }
  $ready = Get-Content "$artifacts/ready.json" -Raw | ConvertFrom-Json
  $initial = Get-Content "$artifacts/policy-$($startup.Id).json" -Raw | ConvertFrom-Json
  $final = Get-Content "$artifacts/policy-$($ready.pid).json" -Raw | ConvertFrom-Json
  if ($ready.accepted_runtime_activated -ne $true -or @($final.needed).Count -ne 0) {
    throw 'Production startup did not activate a complete accepted gem set'
  }
  $repairNeeded = @($initial.needed).Count -ne 0
  if ($repairNeeded -and (-not $clicked.Contains($startup.Id) -or $ready.pid -eq $startup.Id)) {
    throw 'Required repair did not receive real consent and restart before activation'
  }
  if (-not $repairNeeded -and $ready.pid -ne $startup.Id) { throw 'Unexpected restart of an already-compliant runtime' }
  [ordered]@{ verdict='pass'; repair_needed=$repairNeeded; initial_pid=$startup.Id; activated_pid=$ready.pid; approved_pids=@($clicked); initially_needed=@($initial.needed); remaining_needed=@($final.needed); scope='production runtime preparation; full WebUI acceptance is a separate gate' } |
    ConvertTo-Json -Depth 6 | Set-Content "$artifacts/runtime-result.json"
  'Production Windows runtime preparation and accepted activation passed.' | Tee-Object -FilePath $env:GITHUB_STEP_SUMMARY -Append
} catch {
  [ordered]@{ verdict='fail'; error=$_.Exception.Message; approved_pids=@($clicked) } |
    ConvertTo-Json -Depth 6 | Set-Content "$artifacts/runtime-result.json"
  throw
} finally {
  # Preserve receipts even if copying a recovery log or stopping a child fails.
  if (Test-Path 'temp/lich5-missing-gems.log') {
    Copy-Item 'temp/lich5-missing-gems.log' "$artifacts/recovery.log" -ErrorAction Continue
  }
  foreach ($file in Get-ChildItem $artifacts -Filter 'process-*.txt') {
    $child = Get-ObservedRuby $file
    if ($child) { Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue }
  }
  # Startup can fail before the observer writes its first receipt.
  try {
    if ($startup -and -not $startup.HasExited) { $startup.Kill() }
  } catch {
    Write-Warning "Startup process cleanup: $($_.Exception.Message)"
  }
  foreach ($name in $names) {
    [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
  }
}
