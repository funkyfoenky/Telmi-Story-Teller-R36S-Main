# Provenance — dépôt source-only

Ce git ne contient **pas** de noyau précompilé, pas de `.dtb`, pas d’`.exe`,
pas d’image SD. Tout ce qui est commité est du texte / du C / du shell / du Go.

## Compilable depuis ce dépôt

| Composant | Sources | Build |
|-----------|---------|--------|
| Noyau 4.4.189 | submodule `third_party/linux` = [arkos.bsp.4.4](https://github.com/lcdyk0517/arkos.bsp.4.4) `rg351` @ `1b6c735` | `make kernel` (`telmi_defconfig`) |
| DTB | DTS dans le même tree (+ [rocknix_dts](https://github.com/AveyondFly/rocknix_dts) en option) | `make dtb` |
| U-Boot | submodule `third_party/u-boot` = [u-boot-rk3326](https://github.com/christianhaitian/u-boot-rk3326) | `make uboot` |
| Telmi | `src/telmi-r36s` + `third_party/telmi-story-teller` | `make telmi` |
| Sélecteur DTB | `third_party/arkos4clone-src/dtb_selector.go` | `go build` (optionnel) |
| firstboot / clone | `patches/arkos/` + `third_party/arkos4clone-src/sh/` | copiés au bake |

## Licences

- Telmi-R36-Main (overlay, scripts) : GPL-3 — `LICENSE`
- Telmi-story-teller : GPL-3
- Noyau Linux : GPL-2
- ArkOS4Clone scripts / Go : MIT (lcdyk)
- U-Boot : GPL-2

## Ce qui n’est *pas* du source ouvert (hors git, fetch au build)

1. **Toolchain Linaro 6.3.1** — binaire, `make toolchain` → `cache/toolchains/`.
2. **rkbin (Rockchip)** — blobs DDR / ATF pour packager `idbloader` et `trust.img`.
   U-Boot source se compile ; le ROM RK3326 attend encore ces blobs.
   Téléchargés dans `cache/rkbin/` s’ils manquent, **jamais commités**.
3. **Mali-G31** (`libmali*.so`) — propriétaire ARM/Rockchip. Lima/Panfrost
   demandent un noyau ≥ 5.10, incompatible avec ce hardware 4.4.
4. **Rootfs Ubuntu/Debian** — `debootstrap` tire des `.deb` au build
   (`cache/rootfs/`), pas un compile from-source de glibc/apt.
5. **Assets PNG/TTF Telmi** — images/polices runtime (pas d’ELF). Les DTB
   et `Image` se compilent ; ils ne sont pas dans git.
6. **firmware/ du noyau** — le tree lcdyk peut contenir des blobs GPU/wifi
   amont (hors Telmi-R36-Main). Ils restent dans le submodule, pas recopiés à part.


Sans (2) et (3), on obtient un `Image` + DTB + bins Telmi. Une image
bootable clone a encore besoin des blobs Rockchip/Mali au *link* final,
pas dans git.
