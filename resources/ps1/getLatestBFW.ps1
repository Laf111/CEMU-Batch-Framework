# This script output the latest release file
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {

    $latestRelease = Invoke-WebRequest -UseBasicParsing https://github.com/Laf111/CEMU-Batch-Framework/releases/latest -Headers @{"Accept"="application/json"}
    # The releases are returned in the format {"id":3622206,"tag_name":"hello-1.0.0.11",...}, we have to extract the tag_name.
} catch {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Exit 1
}

$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name

Write-Host $latestVersion

Exit $LASTEXITCODE
