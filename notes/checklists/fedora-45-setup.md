# fedora-45-setup: before publishing

Follow the article on the real machine, then:

- Set `pubDate` to the publish day and confirm every `testedOn` version. RPM Fusion's f45 branch already moved to 620.70.06 (2026-11-05); `dnf upgrade` may install that instead of 615.78.
- Installer: confirm the exact labels of the "Fedora Custom Operating System" add-ons ("Standard", "Common NetworkManager Submodules"), the "Encrypt my data" checkbox and the admin checkbox.
- After the driver: `grep UseKernelSuspendNotifiers /proc/driver/nvidia/params` should print 1. The article assumes it (f45 packaging changelog + old research); verified fact: RPM Fusion's suspend units have an ExecCondition so they only run when it is 0. Then test `systemctl suspend` and adjust the article if resume fails.
- Root password: the article now says "I give root a password" (emergency mode needs it). Confirm that's your choice or reword.
- sshd/firewall step: confirm you want it (article disables sshd and removes the ssh service from firewalld).
- LUKS + NVIDIA: check the passphrase prompt is visible at boot; if not, old research suggests `plymouth.use-simpledrm=1` (RPM Fusion). Add to the article if needed.
- Check the real output of `mokutil --test-key ...` and `modinfo -F signer nvidia`, and that `vainfo --display drm` works from the TTY (otherwise try `LIBVA_DRIVER_NAME=nvidia vainfo --display drm`).
- Re-check the ISO file name and SHA256 on https://fedoraproject.org/misc/#everything (the page showed a BETA badge on 2026-11-08).
- Screenshots next to the article (`./name.png`): software selection screen, MOK Manager, `nvidia-smi`.
- Sources for every claim: `notes/research/fedora-45-base.md`, `notes/research/fedora-45-nvidia.md`.
- Then set `draft: false`.
