[CmdletBinding()]
param(
    [string[]]$Client,

    [string]$Target = (Get-Location).Path,

    [switch]$Global,

    [switch]$Local,

    [string]$Source
)

$ErrorActionPreference = 'Stop'

if ($Global -and $Local) {
    throw '-Global and -Local cannot be used together.'
}

$RepoUrl = 'https://github.com/nushey/sdd-flow.git'
$Cache = if ($env:SDD_FLOW_CACHE) { $env:SDD_FLOW_CACHE } else { [System.IO.Path]::Combine($HOME, '.cache', 'sdd-flow') }
$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$Manifest = '.sdd-flow-manifest'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$ClientsFull = @('claude','gemini','codex','opencode','kilo','cursor','windsurf','antigravity','copilot')
$ClientsAll  = @('claude','gemini','codex','opencode','kilo','cursor','windsurf','antigravity','copilot','universal')
$TargetSet   = $PSBoundParameters.ContainsKey('Target')

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required.'
}

function Get-ClaudeHome {
    if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR }
    return (Join-Path $HOME '.claude')
}

function Get-CodexHome {
    if ($env:CODEX_HOME) { return $env:CODEX_HOME }
    return (Join-Path $HOME '.codex')
}

function Get-ConfigHome {
    if ($env:XDG_CONFIG_HOME) { return $env:XDG_CONFIG_HOME }
    return (Join-Path $HOME '.config')
}

function Test-CanPrompt {
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) { return $false }
    return -not ([Environment]::GetCommandLineArgs() | Where-Object { $_ -match '^-noni' })
}

function Get-DevinHome {
    $onWin = ($PSVersionTable.Platform -ne 'Unix') -and ($env:OS -eq 'Windows_NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT')
    if ($onWin -and $env:APPDATA) {
        return (Join-Path $env:APPDATA 'devin')
    }
    return ([System.IO.Path]::Combine((Get-ConfigHome), 'devin'))
}

function Get-ClientLabel($c) {
    switch ($c) {
        'claude'      { return 'Claude Code' }
        'gemini'      { return 'Gemini CLI' }
        'codex'       { return 'OpenAI Codex' }
        'opencode'    { return 'OpenCode' }
        'kilo'        { return 'Kilo Code' }
        'cursor'      { return 'Cursor' }
        'windsurf'    { return 'Windsurf / Devin Desktop' }
        'antigravity' { return 'Google Antigravity' }
        'copilot'     { return 'GitHub Copilot' }
        'universal'   { return 'Universal (skills only)' }
    }
}

function Test-ClientDetected($c) {
    switch ($c) {
        'claude' {
            return (Test-Path (Get-ClaudeHome)) -or [bool](Get-Command claude -ErrorAction SilentlyContinue)
        }
        'gemini' {
            return [bool](Get-Command gemini -ErrorAction SilentlyContinue) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'extensions'))) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'skills'))) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'settings.json')))
        }
        'codex' {
            return (Test-Path (Get-CodexHome)) -or [bool](Get-Command codex -ErrorAction SilentlyContinue)
        }
        'opencode' {
            return (Test-Path ([System.IO.Path]::Combine((Get-ConfigHome), 'opencode'))) -or [bool](Get-Command opencode -ErrorAction SilentlyContinue)
        }
        'kilo' {
            return (Test-Path (Join-Path $HOME '.kilo')) `
                -or (Test-Path (Join-Path $HOME '.kilocode')) `
                -or (Test-Path ([System.IO.Path]::Combine((Get-ConfigHome), 'kilo'))) `
                -or [bool](Get-Command kilo -ErrorAction SilentlyContinue)
        }
        'cursor' {
            return (Test-Path (Join-Path $HOME '.cursor')) -or [bool](Get-Command cursor -ErrorAction SilentlyContinue)
        }
        'windsurf' {
            return (Test-Path (Get-DevinHome)) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.codeium', 'windsurf'))) `
                -or (Test-Path (Join-Path $HOME '.windsurf')) `
                -or (Test-Path (Join-Path $HOME '.devin')) `
                -or [bool](Get-Command windsurf -ErrorAction SilentlyContinue) `
                -or [bool](Get-Command devin -ErrorAction SilentlyContinue)
        }
        'antigravity' {
            return (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'antigravity'))) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'antigravity-cli'))) `
                -or (Test-Path ([System.IO.Path]::Combine($HOME, '.gemini', 'config'))) `
                -or [bool](Get-Command agy -ErrorAction SilentlyContinue)
        }
        'copilot' {
            return (Test-Path (Join-Path $HOME '.copilot')) -or [bool](Get-Command copilot -ErrorAction SilentlyContinue)
        }
        default { return $false }
    }
}

function Normalize-Client($raw) {
    switch ($raw.ToLowerInvariant()) {
        'claude'         { return 'claude' }
        'claude-code'    { return 'claude' }
        'gemini'         { return 'gemini' }
        'gemini-cli'     { return 'gemini' }
        'codex'          { return 'codex' }
        'opencode'       { return 'opencode' }
        'kilo'           { return 'kilo' }
        'kilocode'       { return 'kilo' }
        'cursor'         { return 'cursor' }
        'windsurf'       { return 'windsurf' }
        'devin'          { return 'windsurf' }
        'antigravity'    { return 'antigravity' }
        'agy'            { return 'antigravity' }
        'copilot'        { return 'copilot' }
        'github-copilot' { return 'copilot' }
        'universal'      { return 'universal' }
        'all'            { return 'all' }
        default          { return $null }
    }
}

$SelectedClients = New-Object System.Collections.Generic.List[string]

function Add-SelectedClient($c) {
    if (-not $SelectedClients.Contains($c)) {
        $SelectedClients.Add($c)
    }
}

function Test-PluginInstalled($c) {
    switch ($c) {
        'claude' {
            $file = [System.IO.Path]::Combine((Get-ClaudeHome), 'plugins', 'installed_plugins.json')
            $marker = '"sdd-flow@sdd-flow"'
        }
        'codex' {
            $file = Join-Path (Get-CodexHome) 'config.toml'
            $marker = '[plugins."sdd-flow@sdd-flow"]'
        }
        default { return $false }
    }
    return (Test-Path -LiteralPath $file) -and [bool](Select-String -LiteralPath $file -SimpleMatch -Quiet -Pattern $marker)
}

function Expand-ClientToken($raw) {
    $norm = Normalize-Client $raw
    if (-not $norm) {
        throw "Unknown client '$raw' (expected one of: $($ClientsAll -join ', '), all)."
    }
    switch ($norm) {
        'all' {
            foreach ($c in $ClientsFull) { Add-SelectedClient $c }
        }
        default {
            Add-SelectedClient $norm
        }
    }
}

function Get-SkillsDir($c) {
    if ($Global) {
        switch ($c) {
            'claude'      { return (Join-Path (Get-ClaudeHome) 'skills') }
            'gemini'      { return [System.IO.Path]::Combine($HOME, '.gemini', 'skills') }
            'codex'       { return [System.IO.Path]::Combine($HOME, '.agents', 'skills') }
            'universal'   { return [System.IO.Path]::Combine($HOME, '.agents', 'skills') }
            'opencode'    { return [System.IO.Path]::Combine((Get-ConfigHome), 'opencode', 'skills') }
            'kilo'        { return [System.IO.Path]::Combine($HOME, '.kilo', 'skills') }
            'cursor'      { return [System.IO.Path]::Combine($HOME, '.cursor', 'skills') }
            'windsurf'    { return (Join-Path (Get-DevinHome) 'skills') }
            'antigravity' { return [System.IO.Path]::Combine($HOME, '.gemini', 'config', 'skills') }
            'copilot'     { return [System.IO.Path]::Combine($HOME, '.copilot', 'skills') }
        }
    }
    switch ($c) {
        'claude'   { return (Join-Path '.claude' 'skills') }
        'windsurf' { return (Join-Path '.devin' 'skills') }
        'copilot'  { return (Join-Path '.github' 'skills') }
        default    { return (Join-Path '.agents' 'skills') }
    }
}

function Format-HomePath($path) {
    if ($path.StartsWith($HOME)) { return '~' + $path.Substring($HOME.Length) }
    return $path
}

function Select-ClientsWizard {
    $dirs = @($ClientsAll | ForEach-Object { Get-SkillsDir $_ })
    $shared = @($dirs | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($dir in $shared) {
        $rows.Add(@{ Kind = 'h'; Text = "-- $(Format-HomePath $dir) -- shared, installed together" })
        for ($i = 0; $i -lt $dirs.Count; $i++) {
            if ($dirs[$i] -eq $dir) { $rows.Add(@{ Kind = 'c'; Index = $i; Hint = '' }) }
        }
    }
    $rows.Add(@{ Kind = 'h'; Text = '-- Own directory --' })
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        if ($shared -notcontains $dirs[$i]) { $rows.Add(@{ Kind = 'c'; Index = $i; Hint = " ($(Format-HomePath $dirs[$i]))" }) }
    }
    $badges = @($ClientsAll | ForEach-Object { if (Test-ClientDetected $_) { ' [detected]' } else { '' } })
    $plugins = @($ClientsAll | ForEach-Object { Test-PluginInstalled $_ })
    $checked = New-Object bool[] $ClientsAll.Count
    $cursor = 0
    while ($rows[$cursor].Kind -ne 'c') { $cursor++ }
    $message = ''
    $top = -1

    Write-Host ''
    while ($true) {
        if ($top -ge 0) { [Console]::SetCursorPosition(0, $top) }
        $width = [Math]::Max([Console]::WindowWidth - 1, 1)
        Write-Host ('Select client(s) to install (Up/Down move, Space select, Enter confirm):'.PadRight($width))
        for ($r = 0; $r -lt $rows.Count; $r++) {
            $row = $rows[$r]
            if ($row.Kind -eq 'h') {
                Write-Host ($row.Text.PadRight($width))
                continue
            }
            $i = $row.Index
            $c = $ClientsAll[$i]
            $pointer = if ($r -eq $cursor) { '>' } else { ' ' }
            $mark = if ($checked[$i]) { '[x]' } else { '[ ]' }
            $line = "{0} {1} {2,-12} {3}{4}{5}" -f $pointer, $mark, $c, (Get-ClientLabel $c), $row.Hint, $badges[$i]
            if ($plugins[$i]) {
                Write-Host ("$line [plugin installed]".PadRight($width)) -ForegroundColor Red
            } else {
                Write-Host ($line.PadRight($width))
            }
        }
        Write-Host ($message.PadRight($width))
        if ($top -lt 0) { $top = [Console]::CursorTop - $rows.Count - 2 }
        $message = ''

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                for ($r = $cursor - 1; $r -ge 0; $r--) {
                    if ($rows[$r].Kind -eq 'c') { $cursor = $r; break }
                }
            }
            'DownArrow' {
                for ($r = $cursor + 1; $r -lt $rows.Count; $r++) {
                    if ($rows[$r].Kind -eq 'c') { $cursor = $r; break }
                }
            }
            'Spacebar' {
                $i = $rows[$cursor].Index
                $checked[$i] = -not $checked[$i]
            }
            'Enter' {
                for ($i = 0; $i -lt $ClientsAll.Count; $i++) {
                    if ($checked[$i]) { Add-SelectedClient $ClientsAll[$i] }
                }
                if ($SelectedClients.Count -gt 0) {
                    Write-Host "Selected: $($SelectedClients -join ' ')"
                    return
                }
                $message = '  select at least one client'
            }
        }
    }
}

function Select-ScopeWizard {
    Write-Host ''
    Write-Host 'Select installation scope:'
    Write-Host '   1) Global -- user-level (~/.claude, ~/.gemini, ~/.cursor, etc.), available across all projects'
    Write-Host "   2) Local  -- project-level ($Target)"
    Write-Host ''
    while ($true) {
        $choice = Read-Host 'Enter scope [1=global, 2=local] (default: 1)'
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
        switch ($choice.ToLowerInvariant()) {
            { $_ -in @('1','g','global') } {
                $script:Global = [switch]$true
                return
            }
            { $_ -in @('2','l','local') } {
                $script:Global = [switch]$false
                $script:Local = [switch]$true
                return
            }
            default {
                Write-Host '  please enter 1 (global) or 2 (local).'
            }
        }
    }
}

if (-not $Global -and -not $Local -and -not $TargetSet) {
    if (Test-CanPrompt) {
        Select-ScopeWizard
    }
}

if ($Client -and $Client.Count -gt 0) {
    foreach ($entry in $Client) {
        $tokens = $entry -split '[,\s]+' | Where-Object { $_ -ne '' }
        foreach ($t in $tokens) { Expand-ClientToken $t }
    }
} else {
    if (Test-CanPrompt) {
        Select-ClientsWizard
    } else {
        throw "-Client is required in non-interactive mode (one of: $($ClientsAll -join ', '), all)."
    }
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

$Plan = New-Object System.Collections.Generic.List[object]
$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())

function Add-PlanItem($src, $dest) {
    foreach ($existing in $Plan) {
        if ($existing.Dest -eq $dest) { return }
    }
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

function Add-AntigravityAgents($src, $destDir) {
    $stageDir = Join-Path $Stage 'antigravity'
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $src 'agents') -Filter *.md -File) {
        $text = [System.IO.File]::ReadAllText($f.FullName, $Utf8NoBom)
        $open = [regex]::Match($text, '\A---[ \t]*(\r?\n)')
        if ($open.Success) {
            $nl = $open.Groups[1].Value
            $text = $text.Insert($open.Length, "mainAgent: false${nl}")
        }
        $staged = Join-Path $stageDir $f.Name
        [System.IO.File]::WriteAllText($staged, $text, $Utf8NoBom)
        Add-PlanItem $staged (Join-Path $destDir $f.Name)
    }
}

function Add-CopilotAgents($src, $destDir) {
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $src 'agents') -Filter *.md -File) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Add-PlanItem $f.FullName (Join-Path $destDir "$base.agent.md")
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

function Write-Collisions {
    $conflicts = @($Plan | Where-Object {
        (Test-Path -LiteralPath $_.Dest) -and -not (Test-Owned $_.Dest) -and -not (Test-SameContent $_.Src $_.Dest)
    })
    if ($conflicts.Count -eq 0) { return }
    Write-Warning 'replacing these paths, which differ from sdd-flow and were not installed by it:'
    foreach ($c in $conflicts) { Write-Warning "  $($c.Dest)" }
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

function Add-ClientPlan($src, $target, $c) {
    Add-Skills $src (Join-Path $target (Get-SkillsDir $c))
    switch ($c) {
        'claude' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.claude', 'agents'))
        }
        'gemini' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.gemini', 'agents'))
        }
        'codex' {
            Add-Files ([System.IO.Path]::Combine($src, 'integrations', 'codex', 'agents')) *.toml ([System.IO.Path]::Combine($target, '.codex', 'agents'))
        }
        'opencode' {
            Add-OpencodeAgents $src ([System.IO.Path]::Combine($target, '.opencode', 'agents'))
        }
        'kilo' {
            Add-OpencodeAgents $src ([System.IO.Path]::Combine($target, '.kilo', 'agents'))
        }
        'cursor' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.cursor', 'agents'))
        }
        'windsurf' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($target, '.devin', 'agents'))
            $rulesSrc = [System.IO.Path]::Combine($src, 'integrations', 'windsurf', 'windsurfrules')
            Add-PlanItem $rulesSrc ([System.IO.Path]::Combine($target, '.devin', 'rules', 'sdd.md'))
            Add-PlanItem $rulesSrc (Join-Path $target '.windsurfrules')
        }
        'antigravity' {
            Add-AntigravityAgents $src ([System.IO.Path]::Combine($target, '.agents', 'agents'))
        }
        'copilot' {
            Add-CopilotAgents $src ([System.IO.Path]::Combine($target, '.github', 'agents'))
        }
    }
}

function Add-ClientGlobalPlan($src, $c) {
    Add-Skills $src (Get-SkillsDir $c)
    switch ($c) {
        'claude' {
            Add-Files (Join-Path $src 'agents') *.md (Join-Path (Get-ClaudeHome) 'agents')
        }
        'gemini' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($HOME, '.gemini', 'agents'))
        }
        'codex' {
            Add-Files ([System.IO.Path]::Combine($src, 'integrations', 'codex', 'agents')) *.toml (Join-Path (Get-CodexHome) 'agents')
        }
        'opencode' {
            Add-OpencodeAgents $src ([System.IO.Path]::Combine((Get-ConfigHome), 'opencode', 'agents'))
        }
        'kilo' {
            Add-OpencodeAgents $src ([System.IO.Path]::Combine((Get-ConfigHome), 'kilo', 'agents'))
        }
        'cursor' {
            Add-Files (Join-Path $src 'agents') *.md ([System.IO.Path]::Combine($HOME, '.cursor', 'agents'))
        }
        'windsurf' {
            Add-Files (Join-Path $src 'agents') *.md (Join-Path (Get-DevinHome) 'agents')
        }
        'antigravity' {
            Add-Skills $src ([System.IO.Path]::Combine($HOME, '.gemini', 'antigravity-cli', 'skills'))
            Add-AntigravityAgents $src ([System.IO.Path]::Combine($HOME, '.gemini', 'config', 'agents'))
        }
        'copilot' {
            Add-CopilotAgents $src ([System.IO.Path]::Combine($HOME, '.copilot', 'agents'))
        }
    }
}

function Invoke-Hint($c) {
    switch ($c) {
        'claude'      { '  - [claude]      Run /sdd <feature> or /mini-sdd <change> in Claude Code.' }
        'gemini'      { '  - [gemini]      Run /sdd <feature> or ask Gemini CLI to load the ''sdd'' skill.' }
        'codex'       { '  - [codex]       Type /skills or $sdd to load the orchestrator; run /sdd <feature>.' }
        'opencode'    { '  - [opencode]    Say ''/sdd <feature>'' or ''@sdd-developer ...''.' }
        'kilo'        { '  - [kilo]        Use the ''sdd'' skill; say ''/sdd <feature>''.' }
        'cursor'      { '  - [cursor]      Type /sdd or ask the agent to ''spec this''.' }
        'windsurf'    { '  - [windsurf]    Say ''/sdd <feature>'' or ''/mini-sdd <change>'' in Devin Desktop / Windsurf.' }
        'antigravity' { '  - [antigravity] Type /sdd <feature> or ask the agent to use the ''sdd'' skill.' }
        'copilot'     { '  - [copilot]     Ask Copilot to run /sdd <feature> (ensure runSubagent is enabled).' }
        'universal'   {
            '  - [universal]   Skills-only install. sharp-me, sdd-plan, sdd-implement, sdd-review and pr-creation'
            '                  work without role subagents; /sdd and /mini-sdd require them.'
        }
    }
}

$src = Resolve-Source
$src = (Resolve-Path $src).Path
if (-not (Test-Path (Join-Path $src 'skills')) -or -not (Test-Path (Join-Path $src 'agents'))) {
    throw "source has no skills/ and agents/ ($src)"
}

$clientList = $SelectedClients -join ', '

try {
    if ($Global) {
        Write-Host "Installing sdd-flow for: $clientList (global, user-level)"
        Write-Host "  source: $src"

        foreach ($c in $SelectedClients) {
            Add-ClientGlobalPlan $src $c
        }
        Write-Collisions
        Invoke-Plan

        Write-Host ''
        Write-Host "Done. sdd-flow is installed for: $clientList (global -- applies to every project on this machine)."
        Write-Host ''
        Write-Host 'Before you start:'
        Write-Host '  - Every project you use sdd-flow in still needs its own AGENTS.md at the root'
        Write-Host '    (user-provided; SDD never creates it). Global install only skips re-copying'
        Write-Host '    skills/agents per project -- it does not skip that precondition.'
        Write-Host '  - Every project must be a git repository with at least one commit. SDD''s'
        Write-Host '    checker needs Python 3.11+ (python). No remote or GitHub CLI is required.'
    } else {
        New-Item -ItemType Directory -Force -Path $Target | Out-Null
        $target = (Resolve-Path $Target).Path

        Write-Host "Installing sdd-flow for: $clientList (local project)"
        Write-Host "  source: $src"
        Write-Host "  target: $target"

        foreach ($c in $SelectedClients) {
            Add-ClientPlan $src $target $c
        }
        Write-Collisions
        Invoke-Plan

        Write-Host ''
        Write-Host "Done. sdd-flow is installed for: $clientList."
        Write-Host ''
        Write-Host 'Before you start:'
        Write-Host '  - Make sure your project has an AGENTS.md at the root (user-provided; SDD never creates it).'
        Write-Host '  - The project must be a git repository with at least one commit. SDD''s'
        Write-Host '    checker needs Python 3.11+ (python). No remote or GitHub CLI is required.'
    }
    Write-Host ''
    Write-Host 'Invoke:'
    foreach ($c in $SelectedClients) {
        Invoke-Hint $c
    }
    Write-Host ''
    Write-Host 'Re-run this command any time to refresh skills/agents.'
} finally {
    if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}
