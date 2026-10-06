# install.ps1 — install sdd-flow into any supported agentic client (Windows).
#
# sdd-flow is an Agent Skills + subagents pack (agentskills.io), NOT an MCP
# server. This script copies the 5 skills into the client's skill directory and
# the 5 subagent prompts into the client's agent directory, in the right shape.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.
#
# Usage:
#   scripts\install.ps1 -Client <codex|opencode|kilo|cursor|windsurf|antigravity> `
#                       [-Target <dir> | -Global] [-Source <path|url>] [-Force]
#
#   # One-liner from anywhere (clones sdd-flow to a cache):
#   irm https://raw.githubusercontent.com/nushey/sdd-flow/main/scripts/install.ps1 | `
#     iex  # (then run: install.ps1 -Client codex)  — see README for the saved-file flow
#
#   # Or run from a local clone (auto-detected, no network):
#   git clone https://github.com/nushey/sdd-flow; sdd-flow\scripts\install.ps1 -Client kilo
#
#   # Global (user-level, all-projects) install instead of a project:
#   sdd-flow\scripts\install.ps1 -Client codex -Global
#
#   -Force replaces existing files/folders whose names collide with the pack but
#   that sdd-flow did not install (by default the install stops and lists them).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('codex','opencode','kilo','cursor','windsurf','antigravity')]
    [string]$Client,

    [string]$Target = (Get-Location).Path,

    [switch]$Global,

    [string]$Source,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$RepoUrl = 'https://github.com/nushey/sdd-flow.git'
$Cache = if ($env:SDD_FLOW_CACHE) { $env:SDD_FLOW_CACHE } else { [System.IO.Path]::Combine($HOME, '.cache', 'sdd-flow') }
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = '.sdd-flow-manifest'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required.'
}

function Resolve-Source {
    if ($Source) {
        if ($Source -match '^https?://' -or $Source -match '^git@') {
            Clone-OrUpdate $Source $Cache
            return $Cache
        }
        return (Resolve-Path $Source).Path
    }
    $repoLocal = Join-Path $ScriptDir '..'
    if ((Test-Path (Join-Path $repoLocal 'skills')) -and (Test-Path (Join-Path $repoLocal 'agents'))) {
        return (Resolve-Path $repoLocal).Path
    }
    Clone-OrUpdate $RepoUrl $Cache
    return $Cache
}

function Normalize-Url($url) {
    $u = $url.TrimEnd('/')
    if ($u.EndsWith('.git')) { $u = $u.Substring(0, $u.Length - 4) }
    return $u
}

function Clone-OrUpdate($url, $dest) {
    if (Test-Path (Join-Path $dest '.git')) {
        $cached = git -C $dest config --get remote.origin.url
        if ($LASTEXITCODE -ne 0) { throw "cannot read the origin of the cache at $dest" }
        if ((Normalize-Url $cached) -ne (Normalize-Url $url)) {
            throw "the cache at $dest was cloned from $cached, not $url. Remove that cache or set SDD_FLOW_CACHE to another directory."
        }
        Write-Host "Updating cached sdd-flow at $dest"
        git -C $dest fetch --depth 1 origin HEAD | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git fetch failed; nothing was installed.' }
        git -C $dest checkout -q FETCH_HEAD | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git checkout failed in $dest (local changes kept); nothing was installed." }
    } else {
        Write-Host "Cloning sdd-flow from $url"
        git clone --depth 1 $url $dest | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git clone failed; nothing was installed.' }
    }
}

# Every pack item is queued as (source, destination) first, checked for
# collisions, and only then copied. Destinations installed by sdd-flow are
# recorded by name in a .sdd-flow-manifest file next to them.
$Plan = New-Object System.Collections.Generic.List[object]
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())

function Add-PlanItem($src, $dest) {
    $Plan.Add([pscustomobject]@{ Src = $src; Dest = $dest })
}

function Add-Skills($src, $destSkills) {
    foreach ($d in Get-ChildItem -LiteralPath (Join-Path $src 'skills') -Directory) {
        Add-PlanItem $d.FullName (Join-Path $destSkills $d.Name)
    }
}

function Add-Files($srcDir, $filter, $destDir) {
    foreach ($f in Get-ChildItem -LiteralPath $srcDir -Filter $filter -File) {
        Add-PlanItem $f.FullName (Join-Path $destDir $f.Name)
    }
}

function Add-OpencodeAgents($src, $destDir) {
    # Insert `mode: subagent` after the opening frontmatter delimiter.
    $stageDir = Join-Path $Stage 'opencode'
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $src 'agents') -Filter *.md -File) {
        $text = [System.IO.File]::ReadAllText($f.FullName, $Utf8NoBom)
        $open = [regex]::Match($text, '\A---[ \t]*(\r?\n)')
        if ($open.Success) { $text = $text.Insert($open.Length, 'mode: subagent' + $open.Groups[1].Value) }
        $staged = Join-Path $stageDir $f.Name
        [System.IO.File]::WriteAllText($staged, $text, $Utf8NoBom)
        Add-PlanItem $staged (Join-Path $destDir $f.Name)
    }
}

function Test-Owned($dest) {
    $m = Join-Path (Split-Path -Parent $dest) $Manifest
    return (Test-Path -LiteralPath $m) -and (@(Get-Content -LiteralPath $m) -contains (Split-Path -Leaf $dest))
}

function Get-RelativeFiles($root) {
    @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($root.Length) } | Sort-Object)
}

function Test-SameContent($src, $dest) {
    $srcIsDir = Test-Path -LiteralPath $src -PathType Container
    if ($srcIsDir -ne (Test-Path -LiteralPath $dest -PathType Container)) { return $false }
    if (-not $srcIsDir) { return (Get-FileHash -LiteralPath $src).Hash -eq (Get-FileHash -LiteralPath $dest).Hash }
    $srcFiles = Get-RelativeFiles $src
    if (($srcFiles -join '|') -ne ((Get-RelativeFiles $dest) -join '|')) { return $false }
    foreach ($rel in $srcFiles) {
        if ((Get-FileHash -LiteralPath ($src + $rel)).Hash -ne (Get-FileHash -LiteralPath ($dest + $rel)).Hash) { return $false }
    }
    return $true
}

function Assert-NoCollisions {
    $conflicts = @($Plan | Where-Object {
        (Test-Path -LiteralPath $_.Dest) -and -not (Test-Owned $_.Dest) -and -not (Test-SameContent $_.Src $_.Dest)
    })
    if ($conflicts.Count -eq 0) { return }
    Write-Host 'These paths exist, differ from sdd-flow and were not installed by it:'
    foreach ($c in $conflicts) { Write-Host "  $($c.Dest)" }
    if ($Force) { Write-Host '  -Force: replacing them.'; return }
    throw 'Nothing was installed. Move them away, or re-run with -Force to replace them.'
}

function Invoke-Plan {
    foreach ($item in $Plan) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $item.Dest) | Out-Null
        if ((Test-Path -LiteralPath $item.Dest) -and (Test-SameContent $item.Src $item.Dest)) {
            Write-Host "  unchanged: $($item.Dest)"
        } else {
            if (Test-Path -LiteralPath $item.Dest) { Remove-Item -LiteralPath $item.Dest -Recurse -Force }
            Copy-Item -LiteralPath $item.Src -Destination $item.Dest -Recurse
            Write-Host "  installed: $($item.Dest)"
        }
        if (-not (Test-Owned $item.Dest)) {
            Add-Content -LiteralPath (Join-Path (Split-Path -Parent $item.Dest) $Manifest) -Value (Split-Path -Leaf $item.Dest)
        }
    }
}

function Add-ClientPlan($src, $target, $client) {
    Add-Skills $src ([System.IO.Path]::Combine($target, '.agents', 'skills'))
    switch ($client) {
        'codex'    { Add-Files ([System.IO.Path]::Combine($src, 'integrations', 'codex', 'agents')) *.toml ([System.IO.Path]::Combine($target, '.codex', 'agents')) }
        'opencode' { Add-OpencodeAgents $src ([System.IO.Path]::Combine($target, '.opencode', 'agents')) }
        'kilo'     { Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.kilo', 'agent')) }
        'cursor'   { Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.cursor', 'agents')) }
        'windsurf' {
            $rulesSrc = [System.IO.Path]::Combine($src, 'integrations', 'windsurf', 'windsurfrules')
            Add-PlanItem $rulesSrc ([System.IO.Path]::Combine($target, '.devin', 'rules', 'sdd.md'))
            Add-PlanItem $rulesSrc (Join-Path $target '.windsurfrules')
        }
    }
}

function Add-ClientGlobalPlan($src, $client) {
    switch ($client) {
        'codex' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.agents', 'skills'))
            Add-Files ([System.IO.Path]::Combine($src, 'integrations', 'codex', 'agents')) *.toml ([System.IO.Path]::Combine($HOME, '.codex', 'agents'))
        }
        'opencode' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.config', 'opencode', 'skills'))
            Add-OpencodeAgents $src ([System.IO.Path]::Combine($HOME, '.config', 'opencode', 'agents'))
        }
        'kilo' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.kilo', 'skills'))
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($HOME, '.kilo', 'agent'))
        }
        'cursor' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.cursor', 'skills'))
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($HOME, '.cursor', 'agents'))
        }
        'windsurf' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.codeium', 'windsurf', 'skills'))
            Write-Host '  skip:   global rules -- no confirmed user-level rules directory for Windsurf/Devin Desktop.'
            Write-Host '          Install rules per-project: scripts\install.ps1 -Client windsurf -Target <dir>'
        }
        'antigravity' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.gemini', 'config', 'skills'))
        }
    }
}

function Invoke-Hint($client) {
    switch ($client) {
        'codex'       { '  - Type /skills or use the agent to load the ''sdd'' skill; run /sdd <feature>.' }
        'opencode'    { '  - The agent auto-loads the ''sdd'' skill; say ''/sdd <feature>'' or ''@sdd-developer ...''.' }
        'kilo'        { '  - Use the ''sdd'' skill; say ''/sdd <feature>''.' }
        'cursor'      { '  - Type /sdd or let the agent load the ''sdd'' skill by asking to ''spec this''.' }
        'windsurf'    { '  - Partial install: no role subagents are installed for this client, so /sdd and /mini-sdd stop before writing artifacts unless the roles are available. See INSTALL.md.' }
        'antigravity' { '  - Partial install: skills only. /sdd and /mini-sdd require subagent delegation and stop before writing artifacts on this client. See INSTALL.md.' }
    }
}

$src = Resolve-Source
$src = (Resolve-Path $src).Path
if (-not (Test-Path (Join-Path $src 'skills')) -or -not (Test-Path (Join-Path $src 'agents'))) {
    throw "source has no skills/ and agents/ ($src)"
}

try {
    if ($Global) {
        Write-Host "Installing sdd-flow for '$Client' (global, user-level)"
        Write-Host "  source: $src"

        Add-ClientGlobalPlan $src $Client
        Assert-NoCollisions
        Invoke-Plan

        Write-Host ''
        Write-Host "Done. sdd-flow is installed for $Client (global -- applies to every project on this machine)."
        Write-Host ''
        Write-Host 'Before you start:'
        Write-Host '  - Every project you use sdd-flow in still needs its own AGENTS.md at the root'
        Write-Host '    (user-provided; SDD never creates it). Global install only skips re-copying'
        Write-Host '    skills/agents per project -- it does not skip that precondition.'
        Write-Host '  - Every project must be a git repository. Install the GitHub CLI (gh) and run'
        Write-Host '    `gh auth login` -- the Verifier opens PRs with it.'
    } else {
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        $target = (Resolve-Path $Target).Path

        Write-Host "Installing sdd-flow for '$Client'"
        Write-Host "  source: $src"
        Write-Host "  target: $target"

        Add-ClientPlan $src $target $Client
        Assert-NoCollisions
        Invoke-Plan

        Write-Host ''
        Write-Host "Done. sdd-flow is installed for $Client."
        Write-Host ''
        Write-Host 'Before you start:'
        Write-Host '  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).'
        Write-Host '  - The project must be a git repository. Install the GitHub CLI (gh) and run'
        Write-Host '    `gh auth login` -- the Verifier opens PRs with it.'
    }
    Write-Host ''
    Write-Host 'Invoke:'
    Invoke-Hint $Client
    Write-Host ''
    Write-Host 'Re-run this command any time to refresh skills/agents.'
} finally {
    if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}
