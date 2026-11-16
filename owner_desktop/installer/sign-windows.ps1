param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_CERTIFICATE) -or
    [string]::IsNullOrWhiteSpace($env:WINDOWS_SIGNING_PASSWORD)) {
  throw 'Set the WINDOWS_SIGNING_CERTIFICATE and WINDOWS_SIGNING_PASSWORD environment variables.'
}

$windowsSdkBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$signtool = Get-ChildItem -Path $windowsSdkBin -Filter 'signtool.exe' -Recurse -File |
  Where-Object { $_.Directory.Name -eq 'x64' } |
  Sort-Object { [version]$_.Directory.Parent.Name } -Descending |
  Select-Object -First 1

if ($null -eq $signtool) {
  throw "Could not find the Windows SDK x64 signtool under '$windowsSdkBin'."
}

$certificatePath = Join-Path $env:RUNNER_TEMP 'owner-code-signing.pfx'
try {
  $certificateBytes = [Convert]::FromBase64String($env:WINDOWS_SIGNING_CERTIFICATE)
  [IO.File]::WriteAllBytes($certificatePath, $certificateBytes)
  $password = ConvertTo-SecureString -String $env:WINDOWS_SIGNING_PASSWORD -AsPlainText -Force
  $certificate = Get-PfxCertificate -FilePath $certificatePath -Password $password

  if (-not $certificate.HasPrivateKey) {
    throw 'The Windows code-signing certificate does not contain a private key.'
  }

  foreach ($targetPath in $Path) {
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
      throw "Cannot sign missing file '$targetPath'."
    }

    & $signtool.FullName sign `
      /f $certificatePath `
      /p $env:WINDOWS_SIGNING_PASSWORD `
      /fd SHA256 `
      /tr 'http://timestamp.digicert.com' `
      /td SHA256 `
      $targetPath

    if ($LASTEXITCODE -ne 0) {
      throw "signtool failed to sign '$targetPath' with exit code $LASTEXITCODE."
    }

    $signature = Get-AuthenticodeSignature -FilePath $targetPath
    if ($signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
      throw "The Authenticode signature for '$targetPath' is missing, invalid, or from an unexpected publisher."
    }
  }
}
finally {
  Remove-Item -LiteralPath $certificatePath -Force -ErrorAction SilentlyContinue
}
