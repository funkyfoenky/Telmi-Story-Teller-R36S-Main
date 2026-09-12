# Développement

## Noyau / DTS

Éditer `third_party/linux/` (drivers, DTS), puis `make kernel dtb`.
Ne pas commiter de `Image` ni de `.dtb`.

DTS rétroportés 5.10 utiles en lecture :
https://github.com/AveyondFly/rocknix_dts/tree/main/3326/arkos_4.4_dts

## Telmi

`src/telmi-r36s/platform/r36s/…` puis `make telmi && make inject-sd`.

## firstboot ArkOS

`patches/arkos/firstboot.sh` : skip `apply_all_quirks` / `asoundrc` si
`/etc/telmi-r36-main`. Ne pas utiliser `dtb_selector_win32.exe` (binaire lcdyk) :
`dtb-selector/Select-DTB.bat` ou compiler `dtb_selector.go`.

## Interdits dans git

`*.img` `*.dtb` `Image` `uInitrd` `*.exe` `*.so` `*.ko` `rkbin/`
