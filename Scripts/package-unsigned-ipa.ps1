param(
    [Parameter(Mandatory=$true)]
    [string]$AppPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

$script = "C:\Users\wkn\.codex\skills\ios-ipa-builder\scripts\package_unsigned_ipa.py"

if (-not (Test-Path -LiteralPath $script)) {
    throw "ios-ipa-builder skill script not found: $script"
}

python $script --app $AppPath --output $OutputPath --overwrite

