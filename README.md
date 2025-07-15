## This is a simple HTTP server that helps with file transfers between Windows machines.
(Admin privileges are required.)

HTTP FILE SERVER USAGE:
======================

Basic Usage:
  .\server.ps1 [-Port <number>] [-Path <directory>]

Options:
  -Port       Specify the port to listen on (default: 4000)
  -Path       Specify the directory to serve (default: current directory)
  -Help       Show this help message

Examples:
  .\server.ps1
  .\server.ps1 -Port 8080 -Path "C:\Shared"
  .\server.ps1 -Help

Features:
  - Directory browsing with navigation links
  - File downloads with proper MIME types
  - Automatic firewall rule management
  - Security against path traversal attacks
