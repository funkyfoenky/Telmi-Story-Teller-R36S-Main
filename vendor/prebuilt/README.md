# Prebuilts Telmi-os 0.2.5

Artefacts nécessaires au bake (noyau / U-Boot / bins inchangés depuis 0.2.3 ;
l’overlay et les DTB dual-SD sont dans le dépôt, versionnés à part) :

| Fichier | Rôle |
|---------|------|
| `boot/Image` | Noyau 4.4 `telmi_defconfig` |
| `uboot/*.img` | idbloader / uboot / trust (blobs 0.1.0, lecture seule) |
| `telmi/bin/` | storyTeller, bootScreen, batmon |
| `telmi/lib/` | libSDL2_gfx |

Les DTB des clones et `logo.bmp` sont dans `../arkos4clone/`.
Les PNG/TTF sont dans `../../res/`.

Le rootfs Ubuntu n’est **pas** versionné : `scripts/build-rootfs.sh` le
génère via debootstrap au bake.
