## This is a simple HTTP server that helps with file transfers between Windows machines.

Usage:

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
  - Security against path traversal attacks