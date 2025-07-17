<#
.SYNOPSIS
    Simple HTTP file server for sharing files over a local network

.DESCRIPTION
    This script creates a lightweight HTTP server that serves files from a specified directory.
    It includes directory browsing, file downloads, and automatic firewall rule management.

.PARAMETER Port
    The port number to listen on (default: 4000)

.PARAMETER Path
    The directory path to serve files from (default: current directory)

.PARAMETER Help
    Show this help message and exit

.EXAMPLE
    .\FileServer.ps1
    Starts the server on port 4000 serving files from the current directory

.EXAMPLE
    .\FileServer.ps1 -Port 8080 -Path "C:\Shared"
    Starts the server on port 8080 serving files from C:\Shared

.EXAMPLE
    .\FileServer.ps1 -Help
    Displays this help information

.NOTES
    File Name      : FileServer.ps1
    Requires       : PowerShell 5.1 or later
    Requires Admin : Yes (for firewall rule management)
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$Port = 4000,
    
    [Parameter(Mandatory=$false)]
    [string]$Path = (Get-Location).Path,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

#region Help Display
function Show-Help {
    @"
    
HTTP FILE SERVER USAGE:
======================

Basic Usage:
  .\FileServer.ps1 [-Port <number>] [-Path <directory>]

Options:
  -Port       Specify the port to listen on (default: 4000)
  -Path       Specify the directory to serve (default: current directory)
  -Help       Show this help message

Examples:
  .\FileServer.ps1
  .\FileServer.ps1 -Port 8080 -Path "C:\Shared"
  .\FileServer.ps1 -Help

Features:
  - Directory browsing with navigation links
  - File downloads with proper MIME types
  - Automatic firewall rule management

"@
}

if ($Help) {
    Show-Help
    exit
}
#endregion

#region Initial Setup
$http = New-Object System.Net.HttpListener
$http.Prefixes.Add("http://*:$Port/")
$basePath = Resolve-Path $Path
$firewallRuleName = "PowerShell HTTP Server Port $Port"

# MIME types for proper file handling
$mimeTypes = @{
    '.txt'='text/plain'; '.html'='text/html'; '.htm'='text/html'; '.css'='text/css'
    '.js'='application/javascript'; '.json'='application/json'; '.xml'='application/xml'
    '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.png'='image/png'; '.gif'='image/gif'
    '.pdf'='application/pdf'; '.zip'='application/zip'; '.7z'='application/x-7z-compressed'
    '.exe'='application/octet-stream'; '.msi'='application/octet-stream'
    '.mp3'='audio/mpeg'; '.mp4'='video/mp4'; '.mpeg'='video/mpeg'
    # Add more as needed
}
#endregion

#region Functions
function Get-MimeType($file) {
    $extension = [System.IO.Path]::GetExtension($file).ToLower()
    if ($mimeTypes.ContainsKey($extension)) {
        return $mimeTypes[$extension]
    }
    return 'application/octet-stream'
}

function Add-FirewallRule {
    try {
        if (-not (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $firewallRuleName -Direction Inbound `
                -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
            Write-Host "[+] Added firewall rule: $firewallRuleName" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to add firewall rule: $_"
        Write-Warning "You may need to run as Administrator"
    }
}

function Remove-FirewallRule {
    try {
        if (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $firewallRuleName
            Write-Host "[-] Removed firewall rule: $firewallRuleName" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Failed to remove firewall rule: $_"
    }
}

function Stop-Server {
    Write-Host "`nStopping server..." -ForegroundColor Cyan
    $http.Stop()
    $http.Close()
    Remove-FirewallRule
    exit
}
#endregion

#region Main Execution
# Setup Ctrl+C handler
[console]::TreatControlCAsInput = $false
Register-ObjectEvent -InputObject ([console]::TreatControlCAsInput) -EventName add_OnCancel -Action {
    Stop-Server
} | Out-Null

# Add firewall rule (requires admin)
Add-FirewallRule

# Start server
try {
    $http.Start()
    $ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress
    
    Write-Host "`nHTTP Server Ready!" -ForegroundColor Green
    Write-Host "Local: http://localhost:$Port" -ForegroundColor Yellow
    Write-Host "LAN:   http://$($ips[0]):$Port" -ForegroundColor Yellow
    Write-Host "Serving: $basePath" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop`n" -ForegroundColor DarkGray

    while ($http.IsListening) {
        $context = $http.GetContext()
        $request = $context.Request
        $response = $context.Response

        try {
            $localPath = [System.Web.HttpUtility]::UrlDecode($request.Url.LocalPath.TrimStart('/'))
            $filePath = Join-Path $basePath $localPath

            # Security check to prevent path traversal
            $fullBasePath = [System.IO.Path]::GetFullPath($basePath)
            $fullFilePath = [System.IO.Path]::GetFullPath($filePath)
            if ($fullFilePath -notlike "$fullBasePath*") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("403 - Forbidden")
                $response.StatusCode = 403
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
                $response.Close()
                continue
            }

            # Handle directory requests (root and subdirectories)
            if ($localPath -eq '' -or (Test-Path $filePath -PathType Container)) {
                # Ensure directory URLs end with /
                if (-not $request.Url.LocalPath.EndsWith('/') -and $localPath -ne '') {
                    $response.Redirect($request.Url.LocalPath + '/')
                    $response.Close()
                    continue
                }

                $files = Get-ChildItem $filePath | Sort-Object Name
                $relativePath = if ($localPath -eq '') { '' } else { "$localPath/" }
                
                $html = @"
<html>
<head><title>Index of /$relativePath</title>
<style>
    body { font-family: Consolas, monospace; margin: 20px }
    a { color: #0066cc; text-decoration: none }
    a:hover { text-decoration: underline }
    .size { text-align: right; display: inline-block; width: 100px }
    .date { display: inline-block; width: 150px }
</style>
</head>
<body>
<h1>Index of /$relativePath</h1>
<hr>
<pre>
"@
                # Add parent directory link if not in root
                if ($localPath -ne '') {
                    $html += "<a href=""../"">../</a>`n"
                }

                foreach ($file in $files) {
                    $size = if ($file.PSIsContainer) { "-" } else { "{0:N0} KB" -f ($file.Length/1KB) }
                    $date = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                    $name = if ($file.PSIsContainer) { "$($file.Name)/" } else { $file.Name }
                    
                    $html += "<span class='date'>$date</span> <span class='size'>$size</span> <a href='$name'>$name</a>`n"
                }
                
                $html += "</pre><hr></body></html>"
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $response.ContentType = "text/html"
                Write-Host "Directory listing: $($request.UserHostAddress) => /$relativePath" -ForegroundColor DarkGray
            }
            # File download
            elseif (Test-Path $filePath -PathType Leaf) {
                $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
                $buffer = $fileBytes
                $response.ContentType = Get-MimeType $filePath
                Write-Host "Serving file: $($request.UserHostAddress) => $localPath" -ForegroundColor DarkGray
            }
            # Not found
            else {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
                $response.StatusCode = 404
                Write-Host "404: $($request.UserHostAddress) => $localPath" -ForegroundColor Yellow
            }

            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        catch {
            $buffer = [System.Text.Encoding]::UTF8.GetBytes("500 - Server Error")
            $response.StatusCode = 500
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            Write-Warning "Error processing $localPath : $_"
        }
        finally {
            $response.Close()
        }
    }
}
catch {
    Write-Error "Server failed: $_"
}
finally {
    Stop-Server
}
#endregion
