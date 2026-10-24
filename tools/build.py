"""Build the standalone, offline Windows launcher using only Python's stdlib."""
from pathlib import Path
import base64
import hashlib

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src" / "PJ-Gaming.ps1").read_text(encoding="utf-8")
marker = "$script:EmbeddedVideoReview = '' # PJ_EMBED_VIDEO_REVIEW"
if source.count(marker) != 1:
    raise ValueError("Expected exactly one offline video-review marker")
review = base64.b64encode((ROOT / "docs" / "video-review.md").read_bytes()).decode("ascii")
source = source.replace(marker, f"$script:EmbeddedVideoReview = '{review}' # PJ_EMBED_VIDEO_REVIEW")
payload = base64.b64encode(source.encode("utf-8")).decode("ascii")
header = r'''@echo off
setlocal DisableDelayedExpansion
title PJ Gaming - Personal Windows Settings
set "PJ_GAMING_FILE=%~f0"
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
  echo Windows PowerShell is required. This file is for Windows 10 and 11.
  pause
  exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -Command "try { $t=[IO.File]::ReadAllText($env:PJ_GAMING_FILE); $b=($t -split '(?m)^::PJ_PAYLOAD_BASE64\r?$')[1].Trim(); $s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b)); & ([ScriptBlock]::Create($s)); exit 0 } catch { Write-Host ('PJ Gaming could not start: '+$_.Exception.Message); exit 1 }"
if errorlevel 1 (
  echo No security settings were bypassed. See the error above.
  pause
  exit /b 1
)
exit /b 0
::PJ_PAYLOAD_BASE64
'''
out = ROOT / "dist"
out.mkdir(exist_ok=True)
artifact = out / "PJ-Gaming.cmd"
artifact.write_bytes((header.replace("\n", "\r\n") + payload + "\r\n").encode("ascii"))
(out / "SHA256SUMS.txt").write_text(
    f"{hashlib.sha256(artifact.read_bytes()).hexdigest()}  {artifact.name}\n", encoding="ascii"
)
print(artifact)
