@echo off
REM ai-stack — lanceur Windows (double-clic).
REM Trouve Git Bash et exécute install.sh.

setlocal
set "BASH="
where bash >nul 2>nul && set "BASH=bash"
if not defined BASH (
  if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
)
if not defined BASH (
  if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
)
if not defined BASH (
  echo ai-stack : Git Bash introuvable. Installe-le depuis https://git-scm.com
  pause
  exit /b 1
)

"%BASH%" "%~dp0install.sh" %*
pause
