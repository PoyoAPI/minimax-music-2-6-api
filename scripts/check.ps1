Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$ExcludedDirNames = @(".git", "node_modules", "__pycache__")

function Get-RelativePath {
  param([string]$BasePath, [string]$TargetPath)
  $base = [System.IO.Path]::GetFullPath($BasePath)
  if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $base += [System.IO.Path]::DirectorySeparatorChar
  }
  $target = [System.IO.Path]::GetFullPath($TargetPath)
  $baseUri = New-Object System.Uri($base)
  $targetUri = New-Object System.Uri($target)
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

function Read-AllText {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path)
}

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message"
}

function Get-PublicFiles {
  Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
    $relative = Get-RelativePath -BasePath $Root -TargetPath $_.FullName
    $parts = $relative -split '[\\/]'
    -not ($parts | Where-Object { $ExcludedDirNames -contains $_ })
  }
}

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function ConvertTo-ProcessArgument {
  param([string]$Value)
  if ($Value -notmatch '[\s"]') { return $Value }
  return '"' + ($Value.Replace('\', '\\').Replace('"', '\"')) + '"'
}

function Test-MarkdownLinks {
  Write-Step "Checking Markdown relative links"
  $markdownFiles = Get-PublicFiles | Where-Object { $_.Extension -eq ".md" }
  $failures = New-Object System.Collections.Generic.List[string]

  foreach ($file in $markdownFiles) {
    $content = Read-AllText $file.FullName
    $matches = [regex]::Matches($content, '(?<!\!)\[[^\]]+\]\(([^)]+)\)|!\[[^\]]*\]\(([^)]+)\)')
    foreach ($match in $matches) {
      $target = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
      $target = $target.Trim()
      if (-not $target) { continue }
      if ($target.StartsWith("#")) { continue }
      if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { continue }
      $cleanTarget = ($target -split '#')[0]
      $cleanTarget = ($cleanTarget -split '\?')[0]
      if (-not $cleanTarget) { continue }
      $decodedTarget = [Uri]::UnescapeDataString($cleanTarget)
      $baseDir = Split-Path -Parent $file.FullName
      $resolved = Join-Path $baseDir $decodedTarget
      if ($decodedTarget.EndsWith("/") -or $decodedTarget.EndsWith("\")) {
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
          $relativeFile = Get-RelativePath -BasePath $Root -TargetPath $file.FullName
          $failures.Add("${relativeFile}: missing directory link $target")
        }
      } elseif (-not (Test-Path -LiteralPath $resolved -PathType Leaf) -and -not (Test-Path -LiteralPath $resolved -PathType Container)) {
        $relativeFile = Get-RelativePath -BasePath $Root -TargetPath $file.FullName
        $failures.Add("${relativeFile}: missing link $target")
      }
    }
  }

  if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Markdown link check failed"
  }
}

function Test-NodeSyntax {
  Write-Step "Checking Node.js syntax"
  Assert-Command "node"
  $nodeFiles = Get-PublicFiles | Where-Object { $_.Extension -eq ".mjs" }
  foreach ($file in $nodeFiles) {
    & node --check $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed: $($file.FullName)" }
  }
}

function Test-PythonSyntaxIfPresent {
  Write-Step "Checking Python syntax if present"
  $pythonFiles = @(Get-PublicFiles | Where-Object { $_.Extension -eq ".py" })
  if ($pythonFiles.Count -eq 0) { return }
  Assert-Command "python"
  $script = 'import ast, pathlib, sys; [ast.parse(pathlib.Path(p).read_text(), filename=p) for p in sys.argv[1:]]'
  & python -c $script @($pythonFiles | ForEach-Object { $_.FullName })
  if ($LASTEXITCODE -ne 0) { throw "Python syntax check failed" }
}

function Test-TypeScriptSyntaxIfPresent {
  Write-Step "Checking TypeScript syntax if present"
  $tsFiles = @(Get-PublicFiles | Where-Object { $_.Extension -eq ".ts" })
  if ($tsFiles.Count -eq 0) { return }
  Assert-Command "npx.cmd"
  & npx.cmd --yes --package typescript tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --lib ES2022,DOM --skipLibCheck @($tsFiles | ForEach-Object { $_.FullName })
  if ($LASTEXITCODE -ne 0) { throw "TypeScript check failed" }
}

function Invoke-NoKeyCommand {
  param([string]$Command, [string[]]$Arguments, [string]$ExpectedText)
  $oldApiKey = $env:POYO_API_KEY
  $oldBaseUrl = $env:POYO_BASE_URL
  $oldCallbackUrl = $env:POYO_CALLBACK_URL
  Remove-Item Env:\POYO_API_KEY -ErrorAction SilentlyContinue
  Remove-Item Env:\POYO_BASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:\POYO_CALLBACK_URL -ErrorAction SilentlyContinue

  try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Command
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.Arguments = ($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " "
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $joinedOutput = "$stdout`n$stderr"
    if ($process.ExitCode -eq 0) { throw "Expected no-key command to fail: $Command $($Arguments -join ' ')" }
    if ($joinedOutput -notmatch [regex]::Escape($ExpectedText)) { throw "No-key command did not print expected message: $Command $($Arguments -join ' ')" }
  } finally {
    if ($null -ne $oldApiKey) { $env:POYO_API_KEY = $oldApiKey }
    if ($null -ne $oldBaseUrl) { $env:POYO_BASE_URL = $oldBaseUrl }
    if ($null -ne $oldCallbackUrl) { $env:POYO_CALLBACK_URL = $oldCallbackUrl }
  }
}

function Test-NoKeyBehavior {
  Write-Step "Checking no-key behavior"
  Assert-Command "node"
  Invoke-NoKeyCommand -Command "node" -Arguments @((Join-Path $Root "node/index.mjs")) -ExpectedText "POYO_API_KEY"
}

function Test-SecretScan {
  Write-Step "Scanning public files for sensitive values"
  $devHostPattern = "dev" + "-api\.poyo\.ai"
  $nonProdDataPattern = "test" + "\s*(database|db|materials|fixtures)"
  $otherBrandPattern = "API" + "Dot"
  $falPattern = "fal" + "\.ai"
  $localPathPattern = "(?!Env:)[A-Z]:\\"
  $privatePattern = "\." + "private"

  $patterns = @(
    @{ Name = "dev API host"; Pattern = $devHostPattern },
    @{ Name = "real bearer token"; Pattern = 'Authorization:\s*Bearer\s+(?!<POYO_API_KEY>|YOUR_API_KEY|YOUR_POYO_API_KEY_HERE|\$POYO_API_KEY)[A-Za-z0-9._~+/=-]{12,}' },
    @{ Name = "real unified task id"; Pattern = "task-unified-(?!example\b)[A-Za-z0-9-]+" },
    @{ Name = "non-production data reference"; Pattern = $nonProdDataPattern },
    @{ Name = "competitor brand reference"; Pattern = $otherBrandPattern },
    @{ Name = "disallowed comparison reference"; Pattern = $falPattern },
    @{ Name = "local Windows path"; Pattern = $localPathPattern },
    @{ Name = "private notes reference"; Pattern = $privatePattern }
  )

  $failures = New-Object System.Collections.Generic.List[string]
  $files = Get-PublicFiles | Where-Object { $_.Extension -in @(".md", ".mjs", ".js", ".ts", ".py", ".json", ".yml", ".yaml", ".example", ".ps1", "") }
  foreach ($file in $files) {
    $content = Read-AllText $file.FullName
    $relative = Get-RelativePath -BasePath $Root -TargetPath $file.FullName
    foreach ($pattern in $patterns) {
      if ($pattern.Name -eq "local Windows path" -and $relative -eq "scripts\check.ps1") { continue }
      if ($content -match $pattern.Pattern) { $failures.Add("${relative}: matched $($pattern.Name)") }
    }
  }

  if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Sensitive information scan failed"
  }
}

Test-MarkdownLinks
Test-NodeSyntax
Test-PythonSyntaxIfPresent
Test-TypeScriptSyntaxIfPresent
Test-NoKeyBehavior
Test-SecretScan

Write-Host ""
Write-Host "All checks passed."