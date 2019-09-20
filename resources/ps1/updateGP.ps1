# This script have to be copied in _BatchFW_Graphic_Packs
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$latestRelease = Invoke-WebRequest -UseBasicParsing https://github.com/slashiee/cemu_graphic_packs/releases/latest -Headers @{"Accept"="application/json"}
# The releases are returned in the format {"id":3622206,"tag_name":"hello-1.0.0.11",...}, we have to extract the tag_name.
$json = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $json.tag_name
$pos = $latestVersion.IndexOf("Github")
$leftPart = $latestVersion.Substring(0, $pos)
$rightPart = $latestVersion.Substring($pos+6)
$url = "https://github.com/slashiee/cemu_graphic_packs/releases/download/$latestVersion/graphicPacks" + $rightPart + ".zip"

# --- Download the file to the current location
$OutputPath = "$((Get-Location).Path)\graphicPacks" + $rightPart + ".zip"

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

Write-host $OutputPath" succesfully download from "$url

Expand-Archive -Path $OutputPath -DestinationPath $((Get-Location).Path) -Force
$cr=$LASTEXITCODE
If ($cr -eq 1) {
    Write-Host "Error when uncompressing "$OutputPath" !"
    Exit 2
}
Remove-Item $OutputPath
$LogPath = "graphicPacks" + $rightPart + ".doNotDelete"
New-Item -Path . -Name $LogPath -ItemType file

Exit $LASTEXITCODE
