# Fedora 45 + NVIDIA (RTX 5070, Secure Boot): research notes

Researched 2026-11-08. Sources fetched live that day.

Key sources:
- RPM Fusion NVIDIA Howto: https://rpmfusion.org/Howto/NVIDIA. Revision history (`?action=info`) shows the last edit on **2026-10-05 18:18**, so it predates F45 GA. The page still uses F44-era examples (595.58.03, kernel 6.19.14-300.fc44) and links the 615.71.09 supportedchips page.
- RPM Fusion Secure Boot Howto: https://rpmfusion.org/Howto/Secure%20Boot. Last edited **2025-11-06** by NicolasChauvet, so it predates F45 too, but the procedure matches the current akmods README.
- akmods README.secureboot (rawhide branch): https://src.fedoraproject.org/rpms/akmods/raw/rawhide/f/README.secureboot
- RPM Fusion packaging (f45 branch): https://github.com/rpmfusion/xorg-x11-drv-nvidia/tree/f45
- Package state: the F45 `releases` repo has `akmod-nvidia-615.78.08-1.fc45.x86_64.rpm` (dated 2026-10-08), per https://download1.rpmfusion.org/nonfree/fedora/releases/45/Everything/x86_64/os/Packages/a/. **Heads-up:** the f45 git branch got the commit "Update to 620.70.06 release" on 2026-11-05 (https://github.com/rpmfusion/xorg-x11-drv-nvidia/commits/f45). A reader running `dnf update` soon may get 620.70.06 rather than 615.78.08. The guide should not hard-code the version. `updates/45` and `updates/testing/45` returned 404 when I checked, so I could not confirm the 620 publish state **[UNVERIFIED]**.

---

## 1. RPM Fusion NVIDIA procedure (current branch)

Prerequisite (from the Howto): "have followed the Configuration page to have at least the RPM Fusion nonfree section available" (https://rpmfusion.org/Configuration).

**Secure Boot first.** Verbatim from https://rpmfusion.org/Howto/NVIDIA#Installing_the_drivers:
> If you have secure boot enabled in BIOS/EFI, you must sign the nvidia kmod. Either disable secure boot, or follow the Secure Boot HowTo to create and import your own generated secure boot key. Once done, kmod will be automatically signed with key. It is critical this is done **before** installing the kmod. Failure to do so will disable the driver and result in a blank screen.

> Please remember that once the driver is installed, there is no need to configure anything else by default. Changes will take effect after a ***full reboot*** on the newest kernel.

Section "Current GeForce/Quadro/Tesla" ("suitable for any GPU found in 2017 and later"; "The 595+ driver is available by default on Fedora 44+ ... dropped support for some older GPU than Pascal"). Exact block:
```
sudo dnf update -y # and reboot if you are not on the latest kernel
sudo dnf install akmod-nvidia # rhel/centos users can use kmod-nvidia instead
sudo dnf install xorg-x11-drv-nvidia-cuda #optional for cuda/nvdec/nvenc support
```
After installing:
> After the RPM transaction ends, please remember to wait until the kmod has been built. This can take up to 5 minutes on some systems.
> Once the module is built, "modinfo -F version nvidia" should outputs the version of the driver such as 595.58.03 and not modinfo: ERROR: Module nvidia not found.
> If you are not running on the latest kernel, use -k to mention the latest one like in modinfo -F version nvidia -k 6.19.14-300.fc44.x86_64

So: `modinfo -F version nvidia` (on F45 it should print 615.78.08, or 620.x after an update). `nvidia-smi` comes from `xorg-x11-drv-nvidia-cuda`. `akmod-nvidia` pulls in `xorg-x11-drv-nvidia`; it is not listed separately in the current section (the OSTree section does list it) **[INFERENCE from page layout]**.

**dnf autoremove protection** (https://rpmfusion.org/Howto/NVIDIA#dnf_autoremove), "With DNF-5 (Fedora-41+)":
```
sudo dnf mark user akmod-nvidia
```
(`sudo dnf mark install akmod-nvidia` is the old dnf4 form, for Fedora ≤40 and EL10.)

**Open kernel modules** (https://rpmfusion.org/Howto/NVIDIA#Kernel_Open):
> With current kmod-nvidia package ... the driver package comes with two kinds: proprietary and open (but pre-built). By default, the prebuilt open version will be used, so no need to change anything.

`akmod-nvidia-open` lives in rpmfusion-nonfree-tainted. The page says: "Please do not use or advertise this package by default, it's only needed when one needs to apply downstream changes to the kernel space driver." That makes the old `%_with_kmod_nvidia_open` macro unnecessary; the current page does not mention it. Plain `akmod-nvidia` is correct for an RTX 5070.

**Modeset** (https://rpmfusion.org/Howto/NVIDIA#KMS): enabled by default. Quote:
> The parameter nvidia-drm.modeset=1 was previously set and should be cleared from current installations. This parameter produces a bad interaction with a Fedora Kernel specific patch to deal with early boot display with simpledrm. To avoid any issue, don't use nvidia-drm.modeset=1 parameter from cmdline.

To disable: `sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=0'`. To undo: `sudo grubby --update-kernel=ALL --remove-args='nvidia-drm.modeset=0'`.

**Nouveau blacklisting is handled by the package.** The f45 spec has `%global _dracutopts rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core`, and the `%post` scriptlet runs `grubby --remove-args='nomodeset' --args='%{_dracutopts}'` (https://github.com/rpmfusion/xorg-x11-drv-nvidia/blob/f45/xorg-x11-drv-nvidia.spec, lines 12 and 474). Note that it now blacklists **nova_core** too. Check after reboot with `lsmod |grep nouveau`, which should print nothing (https://rpmfusion.org/Howto/NVIDIA#Nouveau_compatibility).

**Suspend** (https://rpmfusion.org/Howto/NVIDIA#Suspend). Block from the page:
```
sudo dnf install xorg-x11-drv-nvidia-power
sudo systemctl enable nvidia-{suspend,resume,hibernate}
# Optional: tweak "nvidia options NVreg_TemporaryFilePath=/var/tmp" from /etc/modprobe.d/nvidia.conf as needed if you have issue with /tmp as tmpfs with nvidia suspend )
```
The packaging has moved past that wiki text:
- The main package has `Recommends: xorg-x11-drv-nvidia-power` (spec line 65), so dnf installs it by default.
- The f45 preset file `70-nvidia.preset` enables `nvidia-hibernate`, `nvidia-suspend-then-hibernate`, `nvidia-resume`, `nvidia-suspend` and `nvidia-powerd` (https://github.com/rpmfusion/xorg-x11-drv-nvidia/blob/f45/70-nvidia.preset).
- In `nvidia-power-management.conf` (f45) every option is **commented out**: `#options nvidia NVreg_PreserveVideoMemoryAllocations=1`, `#options nvidia NVreg_TemporaryFilePath=/var/tmp`, `#options nvidia NVreg_UseKernelSuspendNotifiers=1`. The comment on the last one reads "Enable kernel suspend notifiers for open modules, the kernel handles video memory preservation directly". The spec changelog has entries "Enable kernel suspend notifiers for open modules" and "Disable old systemd suspend services".
- **[INFERENCE]** The manual `systemctl enable` step is probably redundant on F45. Whether the services actually end up enabled now is **[UNVERIFIED]**: the changelog says old suspend services were disabled, and that conflicts with the preset. Check on the machine with `systemctl is-enabled nvidia-suspend.service`.
- NVIDIA's 615.78.08 README describes `NVreg_PreserveVideoMemoryAllocations=1` together with `/usr/lib/systemd/system/nvidia-suspend.service` etc. (https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/README/powermanagement.html).

**32-bit libs** (https://rpmfusion.org/Howto/NVIDIA#x86_64_.2864bit.29_users):
> ...if you installed kmod-nvidia then you will require xorg-x11-drv-nvidia-libs.i686. With Current Fedora (not EL), this is handled automatically by RPM (Boolean dependencies).

So no manual i686 install is needed on F45.

Other: `sudo dnf install vulkan` for the Vulkan libs (#Vulkan). The Howto recommends **against** bundling nvidia into the initramfs (#Bundling_NVIDIA_into_the_initramfs).

## 2. Secure Boot with akmods

From https://rpmfusion.org/Howto/Secure%20Boot (last edited 2025-11-06) and README.secureboot (https://src.fedoraproject.org/rpms/akmods/raw/rawhide/f/README.secureboot):

```
sudo dnf install kmodtool akmods mokutil openssl
sudo kmodgenca -a
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
systemctl reboot
```
- `kmodgenca -a`: "use default values to complete the cacert.config file, and to generate automatically the cert and the private key." If the files already exist it exits unless you pass `-f`. Keys go to `/etc/pki/akmods/certs` and `/etc/pki/akmods/private/` (README).
- The README also says: "At the first run of the akmods.service, certificate and keypair will be created with default value". Either way the key still has to be **enrolled before** the module is installed and loaded.
- `mokutil --import` "asks to generate a password to enroll the public key. You will need this soon."
- MOK Manager screens, verbatim from the Howto and README:
  1. "On the next boot MOK Management is launched and you have to choose "Enroll MOK""
  2. "Choose "Continue" to enroll the key or "View key 0" to show the keys already enrolled."
  3. "Confirm enrollment by selecting "Yes"."
  4. "You will be invited to enter the password generated above. WARNING: keyboard is mapped to QWERTY!"
  5. "The new key is enrolled, and the system asks you to reboot."
- Verify enrollment (README):
  ```
  mokutil --list-enrolled
  mokutil --test-key /etc/pki/akmods/certs/public_key.der
  ```
  The README does not quote the expected `--test-key` output. On an enrolled key, mokutil prints something like "...is already enrolled" **[UNVERIFIED wording]**. Also useful: `mokutil --sb-state` prints SecureBoot enabled/disabled **[UNVERIFIED in a primary Fedora source; standard mokutil option]**.
- Firmware updates: "you might have to reimport the Secureboot key" with the same `mokutil --import` command (Howto §Updating the BIOS/EFI).
- Securing the key: the Howto calls rootfs encryption (or moving the key off-box) a "mandatory requirement".
- Verify the module is signed: `modinfo -F signer nvidia` should print the akmods CA's CN, not empty. Neither RPM Fusion page documents this command **[UNVERIFIED in primary source]**. The default CN comes from `cacert.config.in` in the akmods repo (https://src.fedoraproject.org/rpms/akmods/blob/rawhide/f/cacert.config.in); I did not check the exact CN string **[UNVERIFIED]**.

## 3. RTX 50 / Blackwell (RTX 5070) requirements

- **Open kernel modules are mandatory for Blackwell.** NVIDIA's 615.71.09 and 615.78.08 README, kernel_open.html: "The proprietary flavor supports GPU architectures Turing, Ampere, Ada, and Hopper. Blackwell and later are only supported by [the open flavor]". And: ".run Installation will default to the open flavor of kernel modules." (https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/README/kernel_open.html)
- RPM Fusion's default `akmod-nvidia` already uses the open flavor (see §1), so no extra step is needed.
- **615.x supports the RTX 5070.** Both https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/README/supportedchips.html and the 615.71.09 page list "NVIDIA GeForce RTX 5070" (two entries), "RTX 5070 Ti" and the laptop variants. I did not extract the GB205 chip name or PCI ID from the page **[UNVERIFIED: GB205 label]**.
- Open modules README (https://github.com/NVIDIA/open-gpu-kernel-modules, now at 620.70.06): "can be used on any Turing or later GPU". Supported kernels: "Linux kernel 4.15 or newer".
- Minimum driver for RTX 50: commonly cited as 570.x. I did not confirm this against an NVIDIA primary source here **[UNVERIFIED]**. It doesn't matter for F45, since 615 is far past it.
- Kernel 7.2: I found no RPM Fusion or NVIDIA note saying 7.2 needs anything special **[UNVERIFIED either way]**. The Howto does say the 340xx/390xx legacy branches may break on newer kernels; that does not apply to the 5070.

## 4. Verification after reboot

```
nvidia-smi                                   # needs xorg-x11-drv-nvidia-cuda
modinfo -F version nvidia                    # Howto
lsmod | grep nvidia
lsmod |grep nouveau                          # Howto: should print nothing
cat /sys/module/nvidia_drm/parameters/modeset   # expect Y
cat /sys/module/nvidia_drm/parameters/fbdev     # expect Y on recent drivers [UNVERIFIED default]
modinfo -F signer nvidia
```
- Modeset default: NVIDIA's 615.78.08 README says "NVIDIA's DRM KMS support is enabled by default, but can be disabled with the 'modeset' kernel module parameter" (https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/README/kms.html). RPM Fusion says the same (§1). Expected value `Y` is **[INFERENCE]** from those two.
- fbdev: the 615.78.08 kms.html contains no "fbdev" string (searched). I could not confirm its default from a primary source **[UNVERIFIED]**. Tell readers to check the sysfs file rather than promising a value.
- akmods logs, from the akmods script (https://src.fedoraproject.org/rpms/akmods/raw/rawhide/f/akmods):
  - success: `/var/cache/akmods/nvidia/<kmodverrel>-for-<kernel>.log`
  - failure: `/var/cache/akmods/nvidia/<kmodverrel>-for-<kernel>.failed.log`
  - running log: `/var/cache/akmods/nvidia/.last.log`
  - So `ls /var/cache/akmods/nvidia/` followed by reading the `*.failed.log` is the troubleshooting path.
  - The script's message is "Building rpms failed; see /var/cache/akmods/${kmodname}/...failed.log for details".
  - Journal: `journalctl -b -u akmods` **[INFERENCE: akmods.service unit exists in the package]**. Per-kernel builds also run as `akmods@<kernel>.service` (the Howto's initramfs section edits `akmods@.service`).
- Rebuild: the script supports `--force` ("try all, even if they failed earlier") and `--kernels <kernel>` ("build and install only for kernel <kernel>"):
  ```
  sudo akmods --force --kernels $(uname -r)
  ```
  The script itself tells users to run "'/usr/sbin/akmods --force' as root".
- `sudo dracut -f`: **not needed** for the normal flow. The package adds the nouveau blacklist via `rd.driver.blacklist` on the kernel cmdline and ships `99-nvidia-dracut.conf` (f45 branch file list). The Howto advises against putting nvidia in the initramfs. Only users who deliberately bundle nvidia need the `akmods@.service` `ExecStartPost=/usr/bin/dracut --force --add-drivers " nvidia nvidia-drm nvidia-modeset nvidia-uvm " ...` override shown in the Howto **[INFERENCE that a manual dracut -f is otherwise unnecessary]**.

## 5. Common failure modes (Fedora + Secure Boot)

- **Key not enrolled / module unsigned:** the Howto warns "Failure to do so will disable the driver and result in a blank screen." The exact `modprobe: ERROR: could not insert 'nvidia': Key was rejected by service` text is standard kernel and kmod output. No RPM Fusion page quotes it **[UNVERIFIED in primary source]**.
  - Fix, from the Secure Boot Howto: enroll the key with `mokutil --import ...`, reboot, then rebuild with `sudo akmods --force --kernels $(uname -r)` and reboot.
  - If the module was built before the key existed, it was not signed. The rebuild re-signs it **[INFERENCE]**.
- **Kernel updated before akmods finished:** the Howto says to wait up to 5 minutes after install and to check with `modinfo -F version nvidia -k <newest kernel>`. Reboot only once that prints a version. If you rebooted too early, akmods rebuilds at boot ("As you start your computer, the akmod system will check if there are any missing kmods and if so, rebuild", #Akmods), or you can run `akmods --force`.
- **Black screen / llvmpipe fallback:** the package ships `nvidia-fallback.service` (f45 file list). The changelog has "Add missing nova_core to nvidia-fallback". **[INFERENCE]** It re-enables nouveau when nvidia fails to load, which leaves the user on nouveau/llvmpipe. Confirm with `lsmod | grep nouveau` and the akmods logs.
- **Stale `nvidia-drm.modeset=1` on the cmdline** from old guides: the Howto says to remove it (§1).
- **dnf autoremove removing akmod-nvidia:** prevent with `sudo dnf mark user akmod-nvidia`.
- **After a firmware update the key may be gone:** re-import (§2).
- Kernel 7.2: nothing documented (§3) **[UNVERIFIED]**.

## 6. Hardware video decode (VA-API)

- RPM Fusion Howto #VDPAU/VAAPI (shown with a leading `#` in the original):
  ```
  sudo dnf install libva-nvidia-driver libva-utils vdpauinfo
  ```
  `vainfo` comes from **libva-utils** (no separate `vainfo` package in that command).
- `libva-nvidia-driver` is a **Fedora** package (dist-git https://src.fedoraproject.org/rpms/libva-nvidia-driver, multimedia-sig), so it comes from the Fedora repos, not RPM Fusion. Its F45 version is **[UNVERIFIED]**.
- nvidia-vaapi-driver README (https://github.com/elFarto/nvidia-vaapi-driver):
  - `NVD_BACKEND`: "Either `egl`, or `direct` (default)". **`NVD_BACKEND=direct` is now the default and no longer needs setting.** Older guides set it because "The EGL backend is broken on driver versions 525 or later".
  - "This library requires that the `nvidia_drm` kernel module is configured with the parameter `nvidia-drm.modeset=1`". On Fedora, modeset is already on by default (§1). Do **not** add it to the cmdline (RPM Fusion warning). Verify with `cat /sys/module/nvidia_drm/parameters/modeset`.
  - `LIBVA_DRIVER_NAME=nvidia` is "Required for libva 2.20+, forces libva to load this driver" (Firefox section).
  - Requirements: "NVIDIA driver series 470 or 500+".
  - "When using nvidia open gpu kernel modules, the usage of the decode engine may not be displayed correctly" in nvidia-smi.
  - The README text has drifted (it mentions an installer script and "this fork"). It is the canonical repo URL, but the README may be in flux.
- NVENC/NVDEC via ffmpeg: `sudo dnf install xorg-x11-drv-nvidia-cuda-libs` (Howto #NVENC/NVDEC).
- Test: `vainfo` should show `Driver version: VA-API NVDEC driver [...]` and open `/usr/lib64/dri/nvidia_drv_video.so` (Howto sample output; the sample shows `[egl backend]` and is old).
