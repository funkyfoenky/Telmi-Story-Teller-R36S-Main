# Build from source

## Prérequis

WSL Ubuntu, ~20 Go disque (noyau + toolchain).

```bash
sudo apt install git make gcc bc bison flex libssl-dev device-tree-compiler \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
  python3 rsync curl wget xz-utils dosfstools e2fsprogs parted gzip \
  golang-go p7zip-full libncurses-dev
```

`make setup` installe ça et clone les submodules (`--depth 1`).

## Toolchain lcdyk (recommandé pour le 4.4)

Le `Image` ArkOS4Clone est construit avec **gcc-linaro 6.3.1-2017.05**.
`make toolchain` le pose dans `cache/toolchains/` (gcc 6). Si Linaro est
absent, `build-telmi.sh` télécharge les headers/crt **Ubuntu 20.04 arm64**
(`cache/focal-dev`) pour ne pas lier `GLIBC_2.33+` avec le gcc 13 du distro.

## Noyau

```bash
make kernel
# → staging/boot/Image
```

Defconfig : `clone_defconfig` (devices ArkOS4Clone). Tree :
https://github.com/lcdyk0517/arkos.bsp.4.4/tree/rg351

## DTB

```bash
make dtb
# → staging/boot/*.dtb  (priorité rk3326-r36s-v30-linux.dtb)
```

Les `.dts` sont dans `third_party/linux/arch/arm64/boot/dts/rockchip/`.
Pas de DTB précompilés dans git.

## U-Boot

```bash
make uboot
# → staging/uboot/idbloader.img uboot.img trust.img
```

Sources : `third_party/u-boot` (`./make.sh odroidgoa` si le script existe).
Les blobs **rkbin** vont dans `cache/rkbin/` (gitignored).

## Telmi

```bash
make telmi
```

Sysroot : soit `cache/sysroot` extrait d’une SD/image **en lecture seule**,
soit les headers `-dev` arm64 téléchargés par `build-telmi.sh`.

## Image 0.2.0

`make image` assemble MBR + U-Boot (secteurs 64 / 16384 / 24576) + p1 BOOT
(Image, DTB, boot.ini LF, sélecteur) + p2 ext4 (rootfs + overlay Telmi) +
p3 TELMI 2 Go.

Rootfs : `cache/rootfs.tar` produit par `scripts/build-rootfs.sh` (debootstrap,
paquets téléchargés au build, pas stockés dans git).
