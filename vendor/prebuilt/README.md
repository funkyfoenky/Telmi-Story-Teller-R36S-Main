# Prebuilts Telmi-os 0.3.2

Artefacts nécessaires au bake (U-Boot blobs 0.1.0 lecture seule).
Recompiler `storyTeller` (`make telmi`) et, pour Vol+/Vol−, le module
`gpio_keys.ko` (`make kernel`) avant un bake 0.3.2.

| Fichier | Rôle |
|---------|------|
| `boot/Image` | Noyau 4.4 `telmi_defconfig` (`CONFIG_KEYBOARD_GPIO=m`) |
| `uboot/*.img` | idbloader / uboot / trust (blobs 0.1.0, lecture seule) |
| `telmi/bin/` | storyTeller, bootScreen, batmon |
| `telmi/lib/` | libSDL2_gfx |
| `telmi/modules/gpio_keys.ko` | Vol+/Vol− (optionnel si Image déjà module) |

Les DTB des clones et `logo.bmp` sont dans `../arkos4clone/`.
Les PNG/TTF sont dans `../../res/`.

Le rootfs Ubuntu n’est **pas** versionné : `scripts/build-rootfs.sh` le
génère via debootstrap au bake.
