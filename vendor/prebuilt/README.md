# Prebuilts 0.2.3

Artefacts nécessaires au bake, extraits de la chaîne Telmi-os 0.2.3 :

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
