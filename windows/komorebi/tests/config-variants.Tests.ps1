# Pester 3 drift gate for the two tracked komorebi configurations:
# windows/komorebi/komorebi.home.json (the two-monitor home machine) and
# windows/komorebi/komorebi.work.json (the single-monitor work machine).
# Repo-only: the tests ship with the source tree and are never copied to
# %USERPROFILE% (see MANIFEST.md, like spy-dialog.ps1 these are not deployed).
#
# WHY this gate exists: the repo keeps one config file per machine because exactly
# two keys follow the destination's hardware -- `display_index_preferences` and the
# `monitors` blocks (decision and evidence:
# odd/tasks/komorebi-config-per-machine.md). Everything else is shared: the dialog
# `ignore_rules`, the `manage_rules` (including the composite VectorCraft rule), the
# `object_name_change_applications`, paddings, borders, colours, `resize_delta`,
# `mouse_follows_focus`. A rule added to one variant and not the other is the defect
# this gate catches. A generator that merges a shared file with a per-machine file
# would be the other way to keep them in sync, and it is rejected on purpose: it
# breaks AGENTS.md's "install = copy" contract (no installers, no symlinks).
#
# The comparison is DATA, not text: every value is re-serialized with
# ConvertTo-Json -Depth 20 -Compress, so a composite manage rule (a rule list nested
# inside the rule list) is compared as an array of objects and reindenting a file
# cannot fail the gate. Line endings are deliberately not compared -- each variant is
# a copy of what its machine deploys (as committed, the work file is LF and ends
# without a trailing newline while the home file is CRLF, but a clone with
# core.autocrlf=true may materialise either one differently, and JSON does not care).
#
# What is NOT asserted, on purpose: monitor counts, workspace names and the monitor
# serial IDs. A third machine, or a second panel at work, must not break this gate --
# only shared-key drift must. Paths derive from $PSScriptRoot; nothing here reads git
# history, the network, or the live machine's %USERPROFILE%\komorebi.json.

$variantDir = Split-Path -Parent $PSScriptRoot

# Display name -> path, so every assertion message names the file to copy.
$variantPaths = [ordered]@{
    'komorebi.home.json' = Join-Path $variantDir 'komorebi.home.json'
    'komorebi.work.json' = Join-Path $variantDir 'komorebi.work.json'
}

# The per-machine half of the file: the monitor serial mapping and the monitor blocks.
# These are the only keys allowed to differ between variants.
$perMachineKeys = @('display_index_preferences', 'monitors')

function Read-VariantConfig {
    param([string]$Path)
    # -Raw: parse the file as one document, and let ConvertFrom-Json raise on bad JSON.
    Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function ConvertTo-CanonicalJson {
    param($Value)
    # -InputObject, not the pipeline: piping unwraps a one-element array into its
    # element, which would compare a single-rule list against a bare rule object.
    ConvertTo-Json -InputObject $Value -Depth 20 -Compress
}

Describe 'komorebi configuration variants' {

    foreach ($name in $variantPaths.Keys) {
        It "parses $name as JSON" {
            $config = Read-VariantConfig $variantPaths[$name]
            $config | Should Not BeNullOrEmpty
        }
    }

    It 'declares the same set of top-level keys in both variants' {
        $homeKeys = @((Read-VariantConfig $variantPaths['komorebi.home.json']).PSObject.Properties.Name)
        $workKeys = @((Read-VariantConfig $variantPaths['komorebi.work.json']).PSObject.Properties.Name)

        $onlyHome = @($homeKeys | Where-Object { $workKeys -notcontains $_ })
        $onlyWork = @($workKeys | Where-Object { $homeKeys -notcontains $_ })

        $report = @()
        if ($onlyHome.Count -gt 0) { $report += "only in komorebi.home.json: $($onlyHome -join ', ')" }
        if ($onlyWork.Count -gt 0) { $report += "only in komorebi.work.json: $($onlyWork -join ', ')" }

        # The actual value names the offending keys; an empty string means the key sets agree.
        ($report -join ' | ') | Should BeExactly ''
    }

    # One It per shared key, generated from the home variant's key list (the key-set
    # test above is what proves both lists agree). A failure therefore names the key in
    # the test name AND shows both canonical values, which is what a future session
    # needs to know what to copy where.
    $sharedKeys = @()
    try {
        $homeConfig = Read-VariantConfig $variantPaths['komorebi.home.json']
        $sharedKeys = @($homeConfig.PSObject.Properties.Name | Where-Object { $perMachineKeys -notcontains $_ })
    }
    catch {
        # A broken home variant is already reported by its parse test above; generate no
        # per-key tests instead of aborting the rest of the run.
    }

    foreach ($key in $sharedKeys) {
        It "keeps shared key '$key' identical in both variants" {
            # NOT $home/$work: $HOME is a read-only automatic variable in PowerShell.
            $homeVariant = Read-VariantConfig $variantPaths['komorebi.home.json']
            $workVariant = Read-VariantConfig $variantPaths['komorebi.work.json']
            ConvertTo-CanonicalJson $homeVariant.$key |
                Should BeExactly (ConvertTo-CanonicalJson $workVariant.$key)
        }
    }

    It 'carries the per-machine key display_index_preferences in both variants' {
        foreach ($name in $variantPaths.Keys) {
            $config = Read-VariantConfig $variantPaths[$name]
            $config.PSObject.Properties.Name -contains 'display_index_preferences' |
                Should BeExactly $true
        }
    }

    It 'carries the per-machine key monitors in both variants' {
        foreach ($name in $variantPaths.Keys) {
            $config = Read-VariantConfig $variantPaths[$name]
            $config.PSObject.Properties.Name -contains 'monitors' |
                Should BeExactly $true
        }
    }

    # Difference, not shape: the two known machines have different panel serials (home
    # maps CNK51707R2 + CNK6180S06, work maps CZK83705DT), so the mappings must not be
    # collapsed into one. A third machine gets its own variant, it never edits these two.
    It 'lets display_index_preferences differ (per-machine monitor serials by design)' {
        $homeVariant = Read-VariantConfig $variantPaths['komorebi.home.json']
        $workVariant = Read-VariantConfig $variantPaths['komorebi.work.json']
        ConvertTo-CanonicalJson $homeVariant.display_index_preferences |
            Should Not BeExactly (ConvertTo-CanonicalJson $workVariant.display_index_preferences)
    }

    It 'lets monitors differ (per-machine monitor blocks by design)' {
        $homeVariant = Read-VariantConfig $variantPaths['komorebi.home.json']
        $workVariant = Read-VariantConfig $variantPaths['komorebi.work.json']
        ConvertTo-CanonicalJson $homeVariant.monitors |
            Should Not BeExactly (ConvertTo-CanonicalJson $workVariant.monitors)
    }
}
