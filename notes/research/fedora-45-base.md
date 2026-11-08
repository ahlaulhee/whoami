# Fedora 45 base install: research notes (verified 2026-11-08)

How to read this: **[UNVERIFIED]** means I could not confirm it in a primary source. **[INFERENCE]** means I derived it from sources but no source says it directly. "Stale" marks sources written before F45.

Headline findings that change what the article says:
- **The "Minimal Install" environment is gone.** In F45 comps (and already F41–F44), the base environment is **"Fedora Custom Operating System"** (`custom-environment`, described as "Basic building block for a custom Fedora system."). It contains `core`, with optional add-ons `standard`, `guest-agents` and `networkmanager-submodules`. See §2.
- **kmscon is the default VT console in F45.** It holds the GPU through exclusive DRM, so you have to start a compositor through `kmscon-launch-gui`. You can also switch a tty back to getty/fbcon. This matters for part 2 (dwl). See §3.
- **RPM now enforces signature checking** (`%_pkgverify_level all`). See §3 and §5.
- **RPM Fusion's multimedia page now uses `dnf install @multimedia ...`**, not `group upgrade`. The page no longer documents a `sound-and-video` step. See §6.

---

## 1. Download, verify, write USB

**Download page**: https://fedoraproject.org/misc/#everything ("Download Fedora Everything 45").
- x86_64 ISO: `https://download.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-45-1.4.iso` (1.2 GiB)
- CHECKSUM: `https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/iso/Fedora-Everything-45-1.4-x86_64-CHECKSUM`
- The page lists the SHA256 as `42abc36792f91575b2f541db19110cc661864819031e57cd5f5c9ec764ebbddf`. Copy it from the page at publish time. Oddity: the page renders a "BETA" badge next to "Fedora Everything 45" even though the files are under `releases/45/` with compose 1.4. Re-check before publishing.

**Verification**, as given on the misc page and on https://fedoraproject.org/security/:
```
curl -O https://fedoraproject.org/fedora.gpg
gpg --with-fingerprint --show-keys --keyid-format long fedora.gpg
gpgv --keyring ./fedora.gpg --output - \
  Fedora-Everything-45-1.4-x86_64-CHECKSUM \
  | sha256sum -c --ignore-missing
```
Sequoia alternative:
```
curl -O https://fedoraproject.org/fedora.pgp
sq keyring list fedora.pgp
sq verify --cleartext --signer-file ./fedora.pgp \
  Fedora-Everything-45-1.4-x86_64-CHECKSUM \
  | sha256sum -c --ignore-missing
```
- The procedure does not import the key into a gpg keyring. It runs `gpgv --keyring ./fedora.gpg` directly.
- F45 key published on /security: ID `rsa4096/655A4B02F577861E 2025-07-29`, fingerprint `4F50 A611 4CD5 C697 6A7F 1179 655A 4B02 F577 861E`.
- Run both commands from the directory that holds the ISO and the CHECKSUM file.

**Writing the USB.** Source: https://docs.fedoraproject.org/en-US/quick-docs/creating-and-using-a-live-installation-image/ (last review 2026-02-22, written for live images but it applies to any ISO).
- Fedora Media Writer is "the official and recommended tool" on Linux, Windows and macOS. Download it from https://fedoraproject.org/workstation/download/ and choose "Select .iso file" to use the Everything ISO.
- dd, exact command from the doc:
  ```
  lsblk
  sudo umount /dev/sdX
  sudo dd if=/path/to/Fedora-Everything-netinst-x86_64-45-1.4.iso of=/dev/sdX bs=4M status=progress && sync
  ```
  The doc says images written with Fedora Media Writer, GNOME Disks, dd or other dd-style tools should boot natively on UEFI.
- Windows: use Fedora Media Writer for Windows (same download page). The doc also names Rufus and balenaEtcher under "Other tools" without giving instructions. **[UNVERIFIED]** whether Rufus must use "DD image" mode for Fedora ISOs. Fedora docs don't say.
- The older page https://docs.fedoraproject.org/en-US/fedora/latest/preparing-boot-media/ returned 404 when fetched. Don't link it.

## 2. Installer, software selection, partitioning, user

**UI.** The F45 Everything netinstall uses the **classic GTK Anaconda** **[INFERENCE, strong]**. Evidence:
- The F45 release notes under "Installer updates" list WebUI enablement only for the Atomic variants, a remote-WebUI tech preview on Atomic, and Stratis support. https://docs.fedoraproject.org/en-US/release-notes/f45/
- The Anaconda team roadmap says the WebUI does not yet support DNF-based (package) installs. It targeted Server Edition for F45 and GTK deprecation only "After 45". https://communityblog.fedoraproject.org/anaconda-webui-progress-update-and-roadmap/ (Sept 2025)
- The F45 Anaconda test week covered WebUI for Atomic, Remote WebUI and Stratis. https://communityblog.fedoraproject.org/anaconda-f45-features-test-week/

**Software selection.** F45 comps: https://forge.fedoraproject.org/releng/fedora-comps/raw/branch/main/comps-f45.xml.in (comps moved from pagure to forge.fedoraproject.org).
- Base environment: **"Fedora Custom Operating System"**, id `custom-environment`, display_order 1. It contains group `core`. Optional add-ons:
  - `standard`
  - `guest-agents`
  - `networkmanager-submodules`
- `minimal-environment` is absent from the F41, F42, F43, F44 and F45 comps files. Any "Minimal Install" wording is stale.
- What `core` brings in F45:
  - Mandatory: audit, bash, coreutils, curl, dnf5, e2fsprogs, glibc, hostname, iproute, iputils, kbd, less, man-db, ncurses, openssh-clients/server, parted, policycoreutils, procps-ng, rpm, selinux-policy-targeted, shadow-utils, sssd-common, sssd-kcm, **sudo**, systemd, util-linux, **vim-minimal**.
  - Default: **dnf5-plugins**, dracut-config-rescue, **firewalld**, **fwupd**, **kmscon**, **NetworkManager**, plymouth, prefixdevname, **systemd-resolved**, **zram-generator-defaults**.
- `networkmanager-submodules` (default): dnsmasq, iptables-nft, NetworkManager-bluetooth, **NetworkManager-wifi**, NetworkManager-wwan, wpa_supplicant. Tick it if the box needs Wi-Fi. NetworkManager itself already comes from `core`.
- `standard` adds:
  - acl, amd-ucode-firmware, at, bash-color-prompt, **bash-completion**, bc, bind-utils, btrfs-progs, bzip2, chrony, cifs-utils, compsize, cpio, crontabs, cryptsetup, dbus, **default-editor**, dos2unix, dosfstools, ethtool, exfatprogs, file
  - fpaste, gnupg2, hunspell, irqbalance, logrotate, lsof, **man-pages**, mcelog, mdadm, microcode_ctl, mtr, net-tools, nfs-utils, nmap-ncat, ntfs-3g, pciutils, plocate, rsync, rsyslog, smartmontools, sos
  - tar, tcpdump, time, traceroute, tree, unzip, usbutils, wget2-wget, which, whois, zip, and more
  - Recommendation for the article: tick **standard** and **Common NetworkManager Submodules**. That choice is mine, not a Fedora recommendation.
- Exact GUI labels in Anaconda come from comps `_name` values. Add-on labels other than the group ids are **[UNVERIFIED]** (likely "Standard", "Guest Agents", "Common NetworkManager Submodules"). Check against a screenshot.

**Partitioning default.** Anaconda's Fedora profile sets `default_scheme = BTRFS` and `btrfs_compression = zstd:1`. https://github.com/rhinstaller/anaconda/blob/main/data/profile.d/fedora.conf
- Base `default_partitioning` is `/ (min 1 GiB, max 70 GiB)` and `/home (min 512 MiB, free 50 GiB)`. On btrfs these become subvolumes `root` and `home` in one btrfs volume. https://github.com/rhinstaller/anaconda/blob/main/data/anaconda.conf
- Caveat: I read the `main` branch, not an f45 tag.
- **[UNVERIFIED]**: Anaconda also creates an EFI system partition and a separate ext4 `/boot`. Exact sizes in F45 not confirmed. Original layout source: https://fedoraproject.org/wiki/Changes/BtrfsByDefault (F33, stale).

**User / admin.** The GTK Anaconda User Creation spoke has a checkbox to make the user an administrator, which adds them to the `wheel` group. **[UNVERIFIED]** exact F45 wording. The Fedora install guide is outdated per the Anaconda team: https://communityblog.fedoraproject.org/anaconda-webui-progress-update-and-roadmap/ ("The existing Fedora Installation Guide is outdated"). `sudo` is mandatory in `core` (comps).

**F45 installer changes** (release notes): WebUI on Atomic, remote WebUI preview, and a Stratis root option (kickstart or Cockpit GUI). None of them changes the Everything GTK flow.

## 3. F45 release-note items for a minimal box

**kmscon replaces fbcon on VTs.** Sources:
- Change page: https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole
- Fedora Magazine article by the change owner: https://fedoramagazine.org/modernizing-the-console-with-kmscon/ (2026-10-19)

What changed:
- `kmscon` is in `core` (default). `/usr/lib/systemd/system/autovt@.service` → `kmsconvt@.service`, covering tty1–6.
- **Keyboard layout:** `loadkeys` has no effect. kmscon follows localectl over D-Bus:
  ```
  localectl set-keymap us
  ```
- **Font:** `setfont` has no effect. Configure it in `/etc/kmscon/kmscon.conf`:
  ```
  sudo cp /etc/kmscon/kmscon.conf.example /etc/kmscon/kmscon.conf
  ```
  Options: `font-engine` (freetype if installed, else built-in unifont; also pango or psf), `font-name` (font must be in /usr/share/fonts, find names with `fc-list`), `font-size` (pixels), `multi-monitor` (`scaled` default / `clone` / `largest`, relevant for two monitors), `dpms-timeout`, `no-mouse`, `palette`, `hwaccel` (needs `kmscon-gl`).
  - The packages are split: `kmscon`, `kmscon-freetype`, `kmscon-pango` (deprecated), `kmscon-gl`.
  - Font packages: `sudo dnf install cascadia-fonts-all`. A forum reply notes `cascadia-code-nf-fonts` for Nerd Font glyphs (forum, not docs).
  - `man kmscon.conf` lists every option. Restart: `sudo systemctl restart kmsconvt@ttyX`. Logs: `journalctl -u kmsconvt*`.
- **Keep or revert to fbcon on one tty**, exact command from the Magazine:
  ```
  sudo systemctl mask kmsconvt@tty5 && sudo systemctl enable --now getty@tty5
  ```
  Full revert per the Change page: "just not install kmscon, and fbcon with getty service will be the default". **[INFERENCE]** That means `sudo dnf remove kmscon`. Untested.
  - Forum caveat: an `/etc/systemd/system/autovt@ttyN.service` symlink left by `systemctl enable kmsconvt@ttyN` can block `enable getty@ttyN`. https://discussion.fedoraproject.org/t/modernizing-the-console-with-kmscon/205410
- **Graphics (relevant to part 2):** kmscon holds the GPU exclusively via DRM. To start a graphical session from it, use `kmscon-launch-gui`, e.g. `kmscon-launch-gui startx`. Change owner's forum example: `kmscon-launch-gui cage -- mpv test.mp4`.
- Other changes:
  - `tty` now prints `/dev/pts/N`. Use `echo $XDG_VTNR` to get the VT number.
  - Scrollback: Shift+PgUp/PgDn. Zoom: Ctrl +/−.
- Known issue thread "Kmscon on Fedora 45 refuses to start X": https://discussion.fedoraproject.org/t/kmscon-on-fedora-45-refuses-to-start-x/207227

**RPM signature enforcement.** https://fedoraproject.org/wiki/Changes/Enforcing_signature_checking_by_default
- `%_pkgverify_level` now defaults to `all` instead of `digest`. `rpm` refuses unsigned packages, or packages whose key isn't imported, unless you pass `--nosignature`.
- "There's no impact on the average system only utilizing packages from official or 3rd party repositories." dnf5 ≥ 5.2.14 has per-package integration (dnf5 issue #2479, closed 2025-12-04).
- dnf5 can install unsigned packages from a repo configured with `gpgcheck=0`.
- Legacy revert: `echo '%_pkgverify_level digest' > /etc/rpm/macros.verify`.
- Impact on a raw `rpm -i some.rpm`: you must first `sudo rpm --import KEY`, or use `--nosignature`. For RPM Fusion see §5.
- The F45 release notes don't mention this change. Only the wiki covers it.

**ptrace restricted.** https://fedoraproject.org/wiki/Changes/Restrict_ptrace_by_default and the release notes.
- Fresh installs get `kernel.yama.ptrace_scope = 1`. Installing gdb, strace, ltrace, elfutils, lldb or delve pulls in `yama-ptrace-enable`, which sets scope 0.
- Manual: `sudo dnf install yama-ptrace-enable`. Check: `sysctl kernel.yama.ptrace_scope`.

**Other F45 items:**
- **Vendor change in DNF:** the F45 release notes section says "Starting with Fedora Linux **46**", DNF5 refuses silent vendor switches (e.g. Fedora ↔ RPM Fusion). Workarounds:
  - Per transaction: `--from-vendor=VENDOR` or `--setopt=allow_vendor_change=1`.
  - Permanent: `allow_vendor_change = true` in a drop-in under `/etc/dnf/libdnf5.conf.d/`.
  - Upstream dnf5.conf docs still list default `True`. The release-note wording is inconsistent, so treat it as F46 behaviour **[UNVERIFIED for F45]**.
- RPM 6.1. https://docs.fedoraproject.org/en-US/release-notes/f45/
- zram: `zram-generator-defaults` is a default in `core` (comps), so zram swap is on out of the box **[INFERENCE]**.
- firewalld and systemd-resolved are defaults in `core` (comps).
- Common bugs list: https://discussion.fedoraproject.org/tags/c/ask/common-issues/82/all/f45

## 4. dnf5 configuration

Source: https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html (upstream main).
- Main file: **`/etc/dnf/dnf.conf`**. Fedora's dnf5 package ships it as `%config(noreplace)`. https://src.fedoraproject.org/rpms/dnf5/blob/f45/f/dnf5.spec
- Drop-ins:
  - User: `/etc/dnf/libdnf5.conf.d/*.conf` (e.g. `20-user-settings.conf`).
  - Distro: `/usr/share/dnf5/libdnf.conf.d/*.conf`.
  - Files are sorted by name and merged, and a user file masks a distro file of the same name. `/etc/dnf/dnf.conf` is read **last** and wins.
- Repo overrides: `/etc/dnf/repos.override.d/`. `config-manager setopt` writes repo options to `99-config_manager.repo` there and never edits the `.repo` file.

| option | default | notes |
|---|---|---|
| `max_parallel_downloads` | `3` | max `20` |
| `defaultyes` | `False` | default answer at the prompt becomes Yes (≠ `assumeyes`) |
| `fastestmirror` | `False` | Picks by TCP latency, "overrides the order provided by the mirrorlist/metalink file itself, and does not take into consideration mirrorlist parameters such as mirror bandwidth nor preferred mirrors for client IP addresses". By default the metalink/mirror manager's ordering is used. That is why it is discouraged **[INFERENCE from doc wording]**. |
| `installonly_limit` | `3` | min 2, `1` not allowed, `0` = unlimited |
| `keepcache` | `False` | |
| `install_weak_deps` | `True` | |

`setopt` syntax, from https://dnf5.readthedocs.io/en/latest/dnf5_plugins/config-manager.8.html. It writes main options to `/etc/dnf/dnf.conf`:
```
sudo dnf config-manager setopt max_parallel_downloads=10 defaultyes=True
sudo dnf config-manager setopt keepcache=1
sudo dnf config-manager unsetopt keepcache
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
```
`config-manager` lives in `dnf5-plugins`, which is a default in `core`. The doc examples use `dnf5 ...`. On Fedora `dnf` is dnf5.

**First update:**
```
sudo dnf upgrade --refresh
```
`--refresh` forces a metadata refresh. Upstream command docs aren't quoted here, but this is standard dnf5 CLI **[UNVERIFIED exact doc citation]**.

**Reboot check:** `dnf needs-restarting` exists in dnf5 (`dnf5-plugins`). https://dnf5.readthedocs.io/en/latest/dnf5_plugins/needs_restarting.8.html
```
dnf needs-restarting      # exit 1 = reboot recommended
dnf needs-restarting -s   # services
```
- `-r/--reboothint` "Has no effect, kept for compatibility": plain `dnf needs-restarting` already gives the reboot hint.
- The reboot list covers the kernel, systemd and others. You can extend it via `/etc/dnf/suggest-reboot.d/*.conf`; the doc's example adds `nvidia-driver`.
- After the first full update a new kernel is likely, so reboot.

## 5. RPM Fusion

Source: https://rpmfusion.org/Configuration (last edited 2026-11-04, lists Fedora 45 release RPMs).
```
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```
openh264, "On Fedora 41 and later":
```
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
```
AppStream metadata, still documented. It's only useful for GNOME Software/KDE Discover, so it can be skipped on a TTY box:
```
sudo dnf update @core
sudo dnf install rpmfusion-\*-appstream-data
```
The page notes: "Since DNF5 (Fedora 41 and later), the Fedora groups cannot be extended by RPM Fusion".

**Signature enforcement interaction:**
- The page doesn't add `--nogpgcheck` for Fedora; it only does so for EL.
- dnf5's `localpkg_gpgcheck` defaults to `False`, so dnf5 won't check the command-line release RPMs. https://dnf5.readthedocs.io/en/latest/dnf5.conf.5.html
- The F45 change says dnf5 integrates with RPM's verify level. **[INFERENCE]** The command works as written on F45, and the page's 2026-11-04 edit supports that.
- When the first package comes from the RPM Fusion repos, dnf5 prompts to import the RPM Fusion keys shipped by the release packages under `/etc/pki/rpm-gpg/` **[INFERENCE]**. Answer `y`.
- Key fingerprints: https://rpmfusion.org/keys (not fetched; **[UNVERIFIED]** that the page lists F45 keys).

## 6. Multimedia

Source: https://rpmfusion.org/Howto/Multimedia (last edited 2026-08-26).
```
sudo dnf swap ffmpeg-free ffmpeg --allowerasing
sudo dnf install @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
```
- The old `dnf group upgrade multimedia ...` and `sound-and-video` steps are **no longer on the page**. The `sound-and-video` group still exists in F45 comps under the Applications category, but RPM Fusion doesn't reference it.
- After the swap, `libavcodec-freeworld` is not needed.
- **NVIDIA hardware decode** (VAAPI wrapper over NVDEC/NVENC):
  ```
  sudo dnf install libva-nvidia-driver
  # optionally both arches:
  sudo dnf install libva-nvidia-driver.{i686,x86_64}
  ```
  The page mentions **no env var** (no `NVD_BACKEND`, no `LIBVA_DRIVER_NAME`). If the article uses them, source them from upstream nvidia-vaapi-driver / NvidiaResearch. **[UNVERIFIED here]**
- **Skip on an NVIDIA-only box:**
  - `intel-media-driver` and `libva-intel-driver` (Intel)
  - `mesa-va-drivers-freeworld` and `dnf swap mesa-vulkan-drivers{,-freeworld}`. The page says these "mainly concern AMD hardware".
- F45 comps `multimedia` group includes `libva-intel-media-driver` (x86_64), so `@multimedia` pulls it on any x86_64 box. Harmless. Add `--exclude=libva-intel-media-driver` if you want it gone **[INFERENCE]**.
- Optional extras: tainted repos (`rpmfusion-free-release-tainted` → `libdvdcss`; `rpmfusion-nonfree-release-tainted` → firmware). Not needed here.

## 7. fwupd

- **Installed:** `fwupd` is a *default* package in `core` in F45 comps, so the Custom OS / core selection includes it.
- Fedora's fwupd `Recommends: fwupd-efi`. https://src.fedoraproject.org/rpms/fwupd/blob/rawhide/f/fwupd.spec
- Fedora's `fwupd-efi` spec runs `%pesign` and ships `fwupd*.efi.signed`. https://src.fedoraproject.org/rpms/fwupd-efi/blob/rawhide/f/fwupd-efi.spec **[INFERENCE]** So UEFI capsule updates work with Secure Boot ON via Fedora's signed shim chain. Upstream: the binary "will need to be signed by an authority trusted with shim" (https://github.com/fwupd/fwupd/blob/main/plugins/uefi-capsule/README.md). There is also a `use-shim-for-sb` flag.
- Commands, from https://fwupd.github.io/libfwupdplugin/fwupdmgr.html:
  ```
  fwupdmgr refresh       # download metadata from LVFS (https://fwupd.org/)
  fwupdmgr get-devices
  fwupdmgr get-updates
  fwupdmgr update        # asks for confirmation; "may then reboot to deploy updates that require a restart"
  fwupdmgr security      # HSI report (optional)
  fwupdmgr check-reboot-needed
  ```
- UEFI/BIOS capsules are staged and applied on the next reboot (capsule plugin README: capsule is processed "on next reboot"). Peripheral updates often apply live.
- LVFS docs: https://lvfs.readthedocs.io/
- **[UNVERIFIED]** whether `sudo` is required. The CLI uses polkit, which on a TTY without an agent may prompt or fail. Simplest for the article: use `sudo fwupdmgr ...`.
- GPU firmware: NVIDIA consumer GPUs are generally not updatable via LVFS **[UNVERIFIED]**.

## 8. What the base system lacks before part 2

From F45 comps, comparing `core` with other groups:
- `core` already has: `sudo`, `vim-minimal` (provides `vi`), `man-db`, `less`, `curl`, `openssh-*`, `NetworkManager` (`nmcli`), `firewalld`, `dnf5-plugins`, `fwupd`, `kmscon`.
- Missing unless `standard` is ticked: **`bash-completion`**, **`man-pages`**, **`default-editor`** (nano), `tar`, `unzip`, `rsync`, `pciutils` (`lspci`, useful to confirm the GPU), `usbutils`, `which`, `file`, `wget2-wget`, `plocate`, `btrfs-progs`, `chrony`, `microcode_ctl`/`amd-ucode-firmware`.
  - **[UNVERIFIED]** whether btrfs-progs is pulled in anyway by a btrfs install. Anaconda normally installs the filesystem tools it needs **[INFERENCE]**.
- **`git`** is in no base group (only development-tools, fedora-packager, etc.). Install it explicitly.
- Wi-Fi needs `networkmanager-submodules` (`NetworkManager-wifi`, `wpa_supplicant`).
- Add after install with dnf5 group syntax (`@group` works in `dnf install`, per the RPM Fusion page usage above):
  ```
  sudo dnf install @standard
  sudo dnf install git
  ```
  **[UNVERIFIED]** the exact dnf5 `group install` spelling. `dnf group install standard` should be equivalent but I didn't check it in dnf5 docs.
- Part 2 build dependencies (compilers, wlroots-devel, etc.) are deliberately not covered here.
