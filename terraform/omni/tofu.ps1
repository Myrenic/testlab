param(
    [Parameter(Mandatory)]
    [ValidateSet("init", "plan", "apply", "destroy")]
    [string]$Command
)

Push-Location $PSScriptRoot

try {
    switch ($Command) {
        "init"    { tofu init }
        "plan"    { tofu plan }
        "apply"   { tofu apply }
        "destroy" { tofu destroy }
    }
} finally {
    Pop-Location
}
