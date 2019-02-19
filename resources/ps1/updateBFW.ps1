# This script have to be copied in _BatchFW_Graphic_Packs
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$latestRelease = Invoke-WebRequest -UseBasicParsing https://github.com/Laf111/CEMU-Batch-Framework/releases/latest -Headers @{"Accept"="application/json"}
# The releases are returned in the format {"id":3622206,"tag_name":"hello-1.0.0.11",...}, we have to extract the tag_name.
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name

$url = "https://github.com/Laf111/CEMU-Batch-Framework/releases/download/" + $latestVersion + "/CEMU_BatchFW_" + $latestVersion + ".zip"

# --- Download the file to the current location
$OutputPath = "$((Get-Location).Path)\CEMU_BatchFW_" + $latestVersion + ".zip"

try {
    Invoke-RestMethod -Method Get -Uri $url -OutFile $OutputPath
} catch {
    # Dig into the exception to get the Response details.
    # Note that value__ is not a typo.
    Write-Host "Connexion failed !"
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    Exit 1
}

Expand-Archive -Path $OutputPath -DestinationPath $((Get-Location).Path) -Force
$cr=$LASTEXITCODE
If ($cr -eq 1) {
    Write-Host "Error when uncompressing "$OutputPath" !"
    Exit 2
}
Remove-Item $OutputPath
Write-host "BFW_VERSION="+$latestVersion

Exit $LASTEXITCODE
