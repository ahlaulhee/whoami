---
slug: fedora-45-setup
title: Setting up Fedora 45 from a minimal install
description: Fedora 45 Everything netinstall, dnf5 tweaks, RPM Fusion, codecs, firmware and the NVIDIA driver with Secure Boot left on.
pubDate: 2026-11-08
tags: [fedora, nvidia]
testedOn: [Fedora 45, kernel 7.2, akmod-nvidia 615.78, RTX 5070]
series:
  name: Fedora 45 + Mango from scratch
  part: 1
draft: false
---

This is the base for the rest of the series: a Fedora 45 install with no desktop environment, every package source I use enabled, and the NVIDIA driver loaded with Secure Boot still on. It ends at a text console. Part 2 builds the Mango desktop on top of it.

## Before you start

My machine has an RTX 5070 and two monitors. Everything NVIDIA-specific here assumes a Turing or newer card (GTX 16 series, RTX 20 series and later). Older cards need a different driver branch; the [RPM Fusion NVIDIA page](https://rpmfusion.org/Howto/NVIDIA) lists which one.

The netinstall image downloads every package during the installation, so plug in Ethernet if you can. Wi-Fi works too, as long as you pick the NetworkManager add-on described below.

Leave Secure Boot on in the firmware settings. The driver section shows how to sign the module so the firmware accepts it.

## Download and verify the ISO

Fedora Everything is on the [Fedora "misc" downloads page](https://fedoraproject.org/misc/#everything). For x86_64 you want the netinstall ISO and its `CHECKSUM` file:

```bash
curl -LO https://download.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-45-1.4.iso
curl -LO https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/iso/Fedora-Everything-45-1.4-x86_64-CHECKSUM
```

Check that the `CHECKSUM` file is signed by Fedora and that the ISO matches it. These are the commands from [Fedora's security page](https://fedoraproject.org/security/), run in the folder with both files:

```bash
curl -O https://fedoraproject.org/fedora.gpg
gpgv --keyring ./fedora.gpg --output - \
  Fedora-Everything-45-1.4-x86_64-CHECKSUM \
  | sha256sum -c --ignore-missing
```

The last line should end in `OK`. If you want to see which keys you are trusting, `gpg --with-fingerprint --show-keys --keyid-format long fedora.gpg` lists them. The Fedora 45 key is `4F50 A611 4CD5 C697 6A7F 1179 655A 4B02 F577 861E`.

## Write the USB stick

[Fedora Media Writer](https://fedoraproject.org/workstation/download/) is the official tool on Linux, Windows and macOS. Choose "Select .iso file" and point it at the ISO you just verified.

From Linux, `dd` works as well. Find the stick with `lsblk` and replace `/dev/sdX` with it; everything on that device is erased:

```bash
lsblk
sudo umount /dev/sdX*
sudo dd if=Fedora-Everything-netinst-x86_64-45-1.4.iso of=/dev/sdX bs=4M status=progress && sync
```

## Install Fedora 45 Everything

Boot from the stick. The Everything image uses the classic installer, with a summary screen of sections (spokes) you visit one by one.

### Software selection

Pick **Fedora Custom Operating System**, which installs the `core` group, and tick two of its add-ons:

- **Standard** brings the tools you expect on any Linux box: `bash-completion`, `man-pages`, `nano`, `tar`, `unzip`, `rsync`, `lspci`, CPU microcode and so on.
- **Common NetworkManager Submodules** adds Wi-Fi and Bluetooth support to NetworkManager. Skip it only if the machine will always be on Ethernet.

`core` alone already includes `sudo`, `vi`, NetworkManager, firewalld, zram swap, `fwupd` and the dnf5 plugins used below.

### Disk

The automatic layout is fine: an EFI partition, a small `/boot`, and one btrfs volume with `root` and `home` subvolumes using zstd compression.

Tick **Encrypt my data**. Later in this guide you create a private key that can sign kernel modules your firmware will trust, and RPM Fusion treats disk encryption as a requirement for keeping that key on the machine.

### User

Create your user and tick the option that makes it an administrator. That adds the user to the `wheel` group, which is what lets it use `sudo`.

If you leave the root account locked, systemd's emergency and rescue modes refuse to open a shell ("the root account is locked"). Those modes are where you end up when a bad `/etc/fstab` or a broken update stops the boot, so I give root a password here even though I never log in as root.

Begin the installation, wait for it to download and install everything, and reboot into the new system.

## First boot and the console

You land on a text login. Fedora 45 replaced the kernel's old framebuffer console with [kmscon](https://fedoramagazine.org/modernizing-the-console-with-kmscon/), which has proper font rendering, scrollback with Shift+PgUp and zoom with Ctrl and `+`/`-`.

The old tools for the console don't work under kmscon anymore. `loadkeys` does nothing; set the keyboard layout with `localectl` instead, and kmscon picks it up:

```bash
sudo localectl set-keymap us
```

`setfont` doesn't work either. Fonts and sizes live in `/etc/kmscon/kmscon.conf`. Start from the example file if you want to change them:

```bash
sudo cp /etc/kmscon/kmscon.conf.example /etc/kmscon/kmscon.conf
```

`man kmscon.conf` lists the options. To get the old console back on one terminal (tty5 here), mask kmscon there and start a regular getty:

```bash
sudo systemctl mask kmsconvt@tty5 && sudo systemctl enable --now getty@tty5
```

## Tune dnf5

Fedora's `dnf` is dnf5, and it reads its main settings from `/etc/dnf/dnf.conf`. Two settings are worth changing:

```bash
sudo dnf config-manager setopt max_parallel_downloads=10 defaultyes=True
```

- `max_parallel_downloads` defaults to 3 (the maximum is 20). Ten helps a lot on big updates.
- `defaultyes=True` makes Enter mean "yes" at the confirmation prompt. You still get the prompt, which is the difference from `assumeyes`.

Now update everything. The installer pulls fresh packages, but there is usually a newer kernel by the time you boot:

```bash
sudo dnf upgrade --refresh
```

`dnf needs-restarting` tells you whether a reboot is recommended. After the first update the answer is almost always yes, and the NVIDIA driver later needs you to be on the newest kernel anyway:

```bash
systemctl reboot
```

Also install git. It's not part of any base group, and part 2 needs it:

```bash
sudo dnf install git
```

### Turn off the SSH server

Fedora enables `sshd` by default, and the default firewall zone lets SSH in. I never log into this machine remotely, so both go:

```bash
sudo systemctl disable --now sshd
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --reload
```

## Enable RPM Fusion

[RPM Fusion](https://rpmfusion.org/Configuration) has the software Fedora can't ship: the NVIDIA driver, the full ffmpeg, Steam. Install both the free and nonfree repositories:

```bash
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

Fedora 45 makes `rpm` refuse packages whose signing key isn't imported. That doesn't get in the way here: the release packages install the RPM Fusion keys, and dnf asks you to import them the first time you install something from those repositories. Answer yes.

Also enable Fedora's OpenH264 repository. Cisco builds and hosts that package, and the repository is disabled by default:

```bash
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
```

## Multimedia codecs

Fedora ships `ffmpeg-free`, which leaves out patent-encumbered codecs. Swap it for RPM Fusion's full build, then install the multimedia group. These are the commands from the [RPM Fusion multimedia page](https://rpmfusion.org/Howto/Multimedia):

```bash
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
sudo dnf install @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
```

The same page has `mesa-va-drivers-freeworld`, `mesa-vulkan-drivers-freeworld` and the Intel media drivers. Those are for AMD and Intel graphics. On an NVIDIA-only machine, skip them. Hardware video decoding on NVIDIA comes after the driver, further down.

## Firmware updates with fwupd

`fwupd` came with `core`. It downloads firmware from the [LVFS](https://fwupd.org/) for whatever devices the vendor publishes there: BIOS/UEFI on many boards, SSDs, docks, some peripherals.

```bash
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

UEFI updates are staged and applied on the next reboot. Fedora's fwupd UEFI binary is signed, so this works with Secure Boot on.

A BIOS update can wipe the keys you enroll in the next section. Run firmware updates before setting up the NVIDIA driver, and keep in mind that you may have to re-enroll the key after future BIOS updates.

## NVIDIA driver

The RTX 5070 is a Blackwell card, and NVIDIA only supports Blackwell with its open kernel modules ([NVIDIA README](https://download.nvidia.com/XFree86/Linux-x86_64/615.78.08/README/kernel_open.html)). RPM Fusion's `akmod-nvidia` already uses the open modules by default, so there is no extra package or option to set.

`akmods` builds the kernel module on your machine, and rebuilds it every time a new kernel arrives. With Secure Boot on, the firmware refuses modules that aren't signed by a key it trusts, and you end up with a black screen or software rendering. So create a signing key and enroll it in the firmware first, then install the driver. From then on akmods signs every build automatically.

### Enroll a MOK key for Secure Boot

Confirm that Secure Boot is on:

```bash
mokutil --sb-state
```

Install the tools and generate a key pair, as described in RPM Fusion's [Secure Boot page](https://rpmfusion.org/Howto/Secure%20Boot):

```bash
sudo dnf install kmodtool akmods mokutil openssl
sudo kmodgenca -a
```

The certificate goes to `/etc/pki/akmods/certs/public_key.der` and the private key to `/etc/pki/akmods/private/`.

Queue the certificate for enrollment. `mokutil` asks you to choose a one-time password, which you type again right after the reboot:

```bash
sudo mokutil --import /etc/pki/akmods/certs/public_key.der
systemctl reboot
```

Before GRUB, a blue MOK Manager screen shows up:

1. Choose **Enroll MOK**.
2. Choose **Continue**.
3. Confirm with **Yes**.
4. Type the password you chose. The keyboard is QWERTY on this screen, whatever layout you use.
5. Choose **Reboot**.

Back in Fedora, check that the key is enrolled:

```bash
mokutil --test-key /etc/pki/akmods/certs/public_key.der
```

It should report that the key is already enrolled.

### Install akmod-nvidia

RPM Fusion wants you on a fully updated system running the newest kernel. If you skipped the reboot after updating, do it now. Then install the driver along with the CUDA package, which is where `nvidia-smi` comes from:

```bash
sudo dnf upgrade --refresh
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
```

Don't reboot yet. akmods builds the module in the background, which can take up to five minutes. This prints the driver version once the build is done, and `modinfo: ERROR: Module nvidia not found` while it is still running:

```bash
modinfo -F version nvidia
```

Mark the driver as something you installed on purpose, so `dnf autoremove` never removes it:

```bash
sudo dnf mark user akmod-nvidia
```

Once `modinfo` prints a version, reboot:

```bash
systemctl reboot
```

The package handles the rest. In particular, don't do any of these:

- Don't add `nvidia-drm.modeset=1` to the kernel command line. Modeset is on by default, and RPM Fusion says the parameter now conflicts with Fedora's early-boot display handling.
- Don't blacklist nouveau yourself. The package puts `rd.driver.blacklist=nouveau,nova_core` on the kernel command line.
- Don't install `xorg-x11-drv-nvidia-libs.i686` by hand. Fedora pulls in the 32-bit libraries automatically; they matter later for Steam.
- Don't rebuild the initramfs with `dracut`. RPM Fusion recommends keeping the driver out of it.
- Don't enable `nvidia-suspend`, `nvidia-resume` and `nvidia-hibernate` by hand. With the open modules the kernel preserves video memory across suspend, and RPM Fusion's units only run when that mechanism is off.

The driver's preset also enables `nvidia-powerd`, which handles Dynamic Boost on laptops. On a desktop it has nothing to do:

```bash
sudo systemctl disable --now nvidia-powerd
```

### Check that the driver loaded

```bash
nvidia-smi
lsmod | grep nouveau
cat /sys/module/nvidia_drm/parameters/modeset
modinfo -F signer nvidia
```

`nvidia-smi` should show the card and the driver version. `lsmod | grep nouveau` should print nothing, `modeset` should be `Y`, and `modinfo -F signer nvidia` should print the name of your akmods key instead of an empty line.

Suspend once to make sure the machine comes back with a working screen:

```bash
grep UseKernelSuspendNotifiers /proc/driver/nvidia/params
systemctl suspend
```

The first line should report `1`, which means the kernel handles video memory during suspend.

### If it doesn't load

- **The build failed.** akmods leaves its logs in `/var/cache/akmods/nvidia/`. A failed build has a `.failed.log` named after the driver version and kernel. Once you've fixed the cause, rebuild with `sudo akmods --force --kernels $(uname -r)`.
- **The module was built, but the kernel rejects it.** The key wasn't enrolled when the module was built, or a firmware update removed it. Import and enroll the key again, run the same `akmods --force` command, and reboot.
- **You rebooted before the build finished.** akmods checks for missing modules at boot and builds them. Give it a few minutes, check with `modinfo -F version nvidia`, and reboot again.

## Hardware video decoding

`libva-nvidia-driver` translates VA-API, the video decoding interface Firefox and many other programs use, to NVDEC on the GPU. mpv doesn't need it; it talks to NVDEC directly. The package comes from Fedora's own repositories:

```bash
sudo dnf install libva-nvidia-driver libva-utils
vainfo --display drm
```

`vainfo` should name `VA-API NVDEC driver` as the driver and list the codecs it can decode.

## Where this leaves you

You have a Fedora 45 system with no desktop, RPM Fusion and the full codecs installed, firmware up to date, and the NVIDIA driver loaded and signed for Secure Boot. Every new kernel gets its module rebuilt and signed by akmods without you doing anything.

Part 2 starts from this console and builds the desktop: Mango, a scrolling Wayland compositor based on dwl, with a Quickshell status bar and the tools around it.
