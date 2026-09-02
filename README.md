# Telmi Story Teller — R36S

OS dédié **histoires / musique** pour consoles clones R36S (RK3326).
Pas d’émulation. Version actuelle : **0.2.3**.

Ce dépôt contient **tout ce qu’il faut pour baker l’image** (hors rootfs
Ubuntu, généré au bake par debootstrap).

## Bake (Linux / WSL, root)

```bash
sudo apt install debootstrap qemu-user-static parted dosfstools e2fsprogs gzip
sudo bash scripts/all.sh
```

Sortie : `output/soysauce-0.2.3.img` + `.gz`.

Prérequis : accès réseau (miroir Ubuntu ports) pour le rootfs minbase.
Les binaires Telmi, le noyau, U-Boot et les DTB sont déjà dans `vendor/`.

## Contenu

| Dossier | Rôle |
|---------|------|
| `src/` | Sources storyTeller, bootScreen, batmon |
| `overlay/` | systemd `telmi.service`, runtime |
| `res/` | PNG / TTF de l’interface |
| `vendor/prebuilt/` | Kernel `Image`, U-Boot, bins Telmi 0.2.3 |
| `vendor/arkos4clone/` | ~80 DTB clones + `logo.bmp` (sélecteur DTB) |
| `dtb-selector/` | `Select-DTB.bat` (lit `consoles/` sur BOOT) |
| `dts/` | Sources DTS v30 / v20 (rebuild optionnel) |
| `kconfig/` | `telmi_defconfig` si on recompile le noyau |
| `scripts/` | Bake, rootfs, cross-compile |
| `boot/` | `boot.ini` (pas d’uInitrd ArkOS) |

Les DTB du sélecteur sont des **blobs ArkOS4Clone**
(`vendor/arkos4clone/consoles/<modele>/*.dtb`), pas compilés depuis `dts/`.

## Rebuild optionnel

| Cible | Exige |
|-------|--------|
| `make telmi` | sysroot aarch64 + SDL2 (`TELMI_SYSROOT` ou `SYSROOT`) |
| `make kernel` | tree Linux 4.4 dans `../third_party/linux` + Linaro 6.3.1 |
| `make dtb` | `dtc` |

## Layout image

| Partition | Rôle |
|-----------|------|
| p1 BOOT (FAT) | `Image`, DTB, `boot.ini`, packs `consoles/` |
| p2 root (ext4) | minbase + systemd + SDL + Telmi |
| p3 TELMI (FAT) | Stories / Music / Saves |

## Licence

GPL-3.0 — voir `LICENSE`.
