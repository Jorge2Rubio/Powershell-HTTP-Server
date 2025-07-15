## This is a simple HTTP server that helps with file transfers between Windows machines. <br>
(Admin privileges are required.)

HTTP FILE SERVER USAGE: <br>
======================

Basic Usage: <br>
  .\server.ps1 [-Port <number>] [-Path <directory>]

Options: <br>
  -Port       Specify the port to listen on (default: 4000) <br>
  -Path       Specify the directory to serve (default: current directory) <br>
  -Help       Show this help message <br>

Examples:
  .\server.ps1 <br>
  .\server.ps1 -Port 8080 -Path "C:\Shared" <br>
  .\server.ps1 -Help <br>

Features:
  - Directory browsing with navigation links
  - File downloads with proper MIME types
  - Automatic firewall rule management
  - Security against path traversal attacks
