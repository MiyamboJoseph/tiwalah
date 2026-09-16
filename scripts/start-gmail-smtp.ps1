<#!
.SYNOPSIS
Starts Tilawah locally with Gmail SMTP credentials kept only in this process.

.DESCRIPTION
Prompts for a Gmail address and a Google App Password, then starts Phoenix with
STARTTLS on smtp.gmail.com:587. It never writes the App Password to disk or to
the Windows user environment.
#>

$ErrorActionPreference = "Stop"

$gmailAddress = Read-Host "Gmail address used to send Tilawah emails"

if ([string]::IsNullOrWhiteSpace($gmailAddress) -or $gmailAddress -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
  throw "Enter a valid Gmail address."
}

$securePassword = Read-Host "Google App Password (16 characters)" -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
  $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) -replace "\s", ""

  if ($appPassword.Length -ne 16) {
    throw "Google App Passwords are 16 characters. Do not use your ordinary Gmail password."
  }

  $env:SMTP_RELAY = "smtp.gmail.com"
  $env:SMTP_PORT = "587"
  $env:SMTP_USERNAME = $gmailAddress
  $env:SMTP_PASSWORD = $appPassword
  $env:MAIL_FROM_EMAIL = $gmailAddress
  $env:MAIL_FROM_NAME = "Tilawah Recitation Circle"

  Write-Host "Starting Tilawah with Gmail SMTP on smtp.gmail.com:587..." -ForegroundColor Green
  Set-Location (Join-Path $PSScriptRoot "..")
  mix phx.server
}
finally {
  if ($passwordPointer -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  }

  Remove-Item Env:SMTP_PASSWORD -ErrorAction SilentlyContinue
}
