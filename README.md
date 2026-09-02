# Telmi Story Teller — R36S

OS dédié **histoires / musique** pour consoles clones R36S (RK3326).
Pas d’émulation. Version actuelle : **0.2.3**.

Portage de Telmi story teller 1.10.1 vers R36S
(DTB v30 par défaut, packs ArkOS4Clone via `Select-DTB.bat`).

## Contenu

| Dossier | Rôle |
|---------|------|
| `src/` | storyTeller, bootScreen, batmon (blit `/dev/fb0`) |
| `overlay/` | systemd `telmi.service`, runtime, montage contenu |
| `res/` | PNG / TTF de l’interface |
| `dtb-selector/` | `Select-DTB.bat` pour choisir le modèle sur la partition BOOT |
| `dts/` | Device trees v30 / v20 |
| `kconfig/` | `telmi_defconfig` (noyau 4.4) |
| `content-skel/` | Squelette Stories / Music / Saves |
| `scripts/` | Cross-compile, rootfs, assemblage image |
| `boot/` | `boot.ini` (pas d’uInitrd ArkOS) |

## Layout image

| Partition | Rôle |
|-----------|------|
| p1 BOOT (FAT) | `Image`, DTB, `boot.ini`, packs `consoles/` |
| p2 root (ext4) | minbase + systemd + SDL + Telmi |
| p3 TELMI (FAT) | Stories / Music / Saves |

## Build (Linux / WSL)

Le noyau 4.4 et U-Boot ne sont **pas** dans ce dépôt : placez-les en
`../third_party/linux` et `../third_party/u-boot`, ou exportez `LINUX` / `UBOOT`.

Les blobs U-Boot (logo, idbloader) viennent d’une image vendor en lecture
seule : `TELMI_VENDOR` et `TELMI_UBOOT_IMAGE`.

```bash
# Paquets hôte (Debian / WSL)
sudo bash scripts/setup-host.sh

make telmi      # storyTeller bootScreen batmon
make assets     # copie res/ -> staging
# root + loop devices :
sudo bash scripts/bake-image.sh
```

Sortie : `output/soysauce-<version>.img` (+ `.gz`). Aucune image n’est versionnée ici.

## Licence

GPL-3.0 — voir `LICENSE`.
