#!/bin/bash
set -euo pipefail

LOG=/var/log/arch-nightly-update.log
exec >>"$LOG" 2>&1

echo "======================================="
echo "=============== $(date) ==============="
echo "======================================="

# Update system
/usr/bin/pacman -Syu --noconfirm

# Reboot only if the running kernel version doesn't match the installed kernel package version
# (simple + safe; avoids rebooting every night)
if /usr/bin/pacman -Q linux >/dev/null 2>&1; then
  installed_ver=$(/usr/bin/pacman -Q linux | awk '{print $2}')
  running_ver=$(/usr/bin/uname -r)

  installed_ver=${installed_ver//\./ }
  installed_ver=${installed_ver//-/ }
  installed_ver=${installed_ver//_/ }

  running_ver=${running_ver//\./ }
  running_ver=${running_ver//-/ }
  running_ver=${running_ver//_/ }

  if [[ "$running_ver" != *"$installed_ver"* ]]; then
    echo "Kernel updated ($running_ver -> $installed_ver). Rebooting..."
    /usr/bin/systemctl reboot
    # echo "reboot disabled"
  else
    echo "No reboot required."
  fi
else
  echo "linux package not installed (custom kernel?). No reboot logic applied."
fi
