#!/bin/sh
# Montage contenu Telmi — ArkOS4Clone (blkid Debian, p2 LABEL=root).
# Dual-SD : slot gauche LABEL=TELMI prioritaire ; ne pas monter EASYROMS
# tant qu'il n'est pas relabel TELMI.
# Usage : telmi-mount-content.sh mount|setup|status

TELMI_CONTENT_MODE_FILE=/run/telmi-content-mode
TELMI_CONTENT_LOG=/boot/telmi-content.log

log_telmi() {
	logger -t telmi "$*" 2>/dev/null || true
	echo "[telmi-mount] $*"
	if [ -d /boot ] && { mountpoint -q /boot 2>/dev/null || [ -w /boot ]; }; then
		echo "$(date '+%H:%M:%S') $*" >> "$TELMI_CONTENT_LOG" 2>/dev/null || true
	fi
}

blkid_label() {
	blkid -s LABEL -o value "$1" 2>/dev/null || true
}

blkid_type() {
	blkid -s TYPE -o value "$1" 2>/dev/null || true
}

blkid_dev_by_label() {
	blkid -L "$1" 2>/dev/null || true
}

# Tous les volumes d'un label (blkid -L n'en rend qu'un — souvent p3 OS).
blkid_devs_by_label() {
	blkid -o device -t "LABEL=$1" 2>/dev/null || true
}

ensure_sdcard_link() {
	mkdir -p /mnt /telmi
	if [ ! -L /mnt/SDCARD ] && [ ! -e /mnt/SDCARD ]; then
		ln -sf /telmi /mnt/SDCARD
	elif [ -d /mnt/SDCARD ] && [ ! -L /mnt/SDCARD ]; then
		rmdir /mnt/SDCARD 2>/dev/null && ln -sf /telmi /mnt/SDCARD
	fi
}

get_os_mmc_base() {
	_src=""
	if command -v findmnt >/dev/null 2>&1; then
		_src=$(findmnt -n -o SOURCE / 2>/dev/null || true)
	fi
	if [ -z "$_src" ] || [ "$_src" = "/dev/root" ]; then
		_src=$(awk '$2=="/" {print $1; exit}' /proc/mounts 2>/dev/null || true)
	fi
	case "$_src" in
		/dev/mmcblk*p*)
			echo "$_src" | sed -n 's|^/dev/\(mmcblk[0-9]*\)p[0-9]*|\1|p'
			return 0
			;;
	esac
	_dev=$(blkid_dev_by_label root)
	[ -z "$_dev" ] && _dev=$(blkid_dev_by_label ROOTFS)
	[ -z "$_dev" ] && _dev=$(blkid_dev_by_label rootfs)
	case "$_dev" in
		/dev/mmcblk*p*)
			echo "$_dev" | sed -n 's|^/dev/\(mmcblk[0-9]*\)p[0-9]*|\1|p'
			return 0
			;;
	esac
	_dev=$(blkid_dev_by_label BOOT)
	case "$_dev" in
		/dev/mmcblk*p*)
			echo "$_dev" | sed -n 's|^/dev/\(mmcblk[0-9]*\)p[0-9]*|\1|p'
			return 0
			;;
	esac
	return 1
}

part_on_mmc() {
	_dev="$1"
	_mmc="$2"
	case "$_dev" in
		"/dev/${_mmc}"p[0-9]*|"/dev/${_mmc}") return 0 ;;
	esac
	return 1
}

is_os_system_part() {
	_dev="$1"
	_lbl=$(blkid_label "$_dev")
	case "$_lbl" in
		BOOT|root|rootfs|ROOTFS|EASYROMS) return 0 ;;
	esac
	_fs=$(blkid_type "$_dev")
	[ "$_fs" = "ext4" ] && return 0
	return 1
}

try_mount_vfat() {
	_dev="$1"
	[ -b "$_dev" ] || return 1
	if is_os_system_part "$_dev"; then
		return 1
	fi
	if mount -t vfat "$_dev" /telmi 2>/tmp/telmi-mount.err; then
		return 0
	fi
	if mount -t vfat -o rw,umask=0000,utf8 "$_dev" /telmi 2>/tmp/telmi-mount.err; then
		return 0
	fi
	if mount -t exfat "$_dev" /telmi 2>/tmp/telmi-mount.err; then
		return 0
	fi
	_err=$(cat /tmp/telmi-mount.err 2>/dev/null | tr '\n' ' ')
	log_telmi "WARN: mount echoue $_dev ${_err}"
	return 1
}

default_wait_max() {
	if [ -n "${TELMI_WAIT_MAX+x}" ] && [ -n "$TELMI_WAIT_MAX" ]; then
		echo "$TELMI_WAIT_MAX"
		return 0
	fi
	echo 20
}

is_fatish() {
	_fs="$1"
	case "$_fs" in
		vfat|msdos|fat|fat32|exfat|"") return 0 ;;
	esac
	return 1
}

mount_by_telmi_label_external() {
	_os=$(get_os_mmc_base) || _os=""
	for _dev in $(blkid_devs_by_label TELMI); do
		[ -b "$_dev" ] || continue
		if [ -n "$_os" ] && part_on_mmc "$_dev" "$_os"; then
			log_telmi "skip TELMI interne $_dev (OS=$_os)"
			continue
		fi
		if try_mount_vfat "$_dev"; then
			echo external > "$TELMI_CONTENT_MODE_FILE"
			log_telmi "content=external dev=$_dev (label TELMI hors OS)"
			return 0
		fi
	done
	return 1
}

mount_external_content() {
	_os=$(get_os_mmc_base) || _os=""

	if mount_by_telmi_label_external; then
		return 0
	fi

	for _mmc in mmcblk0 mmcblk1 mmcblk2 mmcblk3; do
		[ -d "/sys/block/$_mmc" ] || continue
		[ "$_mmc" = "$_os" ] && continue

		for _p in "${_mmc}p1" "${_mmc}p2" "${_mmc}p3" "${_mmc}p4"; do
			_dev="/dev/$_p"
			[ -b "$_dev" ] || continue
			is_os_system_part "$_dev" && continue
			_fs=$(blkid_type "$_dev")
			_lbl=$(blkid_label "$_dev")
			if [ "$_lbl" = "TELMI" ] || [ "$_p" = "${_mmc}p1" ] || is_fatish "$_fs"; then
				log_telmi "try $_dev fs=${_fs:--} lbl=${_lbl:--}"
				if try_mount_vfat "$_dev"; then
					echo external > "$TELMI_CONTENT_MODE_FILE"
					log_telmi "content=external dev=$_dev"
					return 0
				fi
			fi
		done
	done
	return 1
}

mount_internal_content() {
	# Fallback : p3 LABEL=TELMI de la carte OS seulement.
	_os=$(get_os_mmc_base) || _os=""
	[ -n "$_os" ] || return 1
	for _dev in $(blkid_devs_by_label TELMI); do
		[ -b "$_dev" ] || continue
		part_on_mmc "$_dev" "$_os" || continue
		if try_mount_vfat "$_dev"; then
			echo internal > "$TELMI_CONTENT_MODE_FILE"
			log_telmi "content=internal dev=$_dev (label TELMI carte OS)"
			return 0
		fi
	done
	return 1
}

rescan_empty_mmc_hosts() {
	for _h in /sys/class/mmc_host/mmc*; do
		[ -d "$_h" ] || continue
		_hn=$(basename "$_h")
		# test -w est faux sur sysfs ; écrire quand même.
		if echo 1 > "$_h/rescan" 2>/dev/null; then
			log_telmi "rescan $_hn"
		fi
	done
	udevadm settle --timeout=2 2>/dev/null || true
}

log_mmc_probe() {
	_os=$(get_os_mmc_base) || _os="?"
	_blks=""
	for _b in /sys/block/mmcblk*; do
		[ -e "$_b" ] || continue
		_blks="$_blks $(basename "$_b")"
	done
	_hosts=""
	for _h in /sys/class/mmc_host/mmc*; do
		[ -e "$_h" ] || continue
		_hosts="$_hosts $(basename "$_h")"
	done
	_devs=$(ls /dev/mmcblk* 2>/dev/null | tr '\n' ' ')
	log_telmi "os_mmc=$_os blocks=${_blks:- none}"
	log_telmi "mmc_host=${_hosts:- none} devs=${_devs:- none}"
	log_telmi "TELMI=$(blkid_devs_by_label TELMI | tr '\n' ' ')"
	dmesg 2>/dev/null | grep -iE 'mmc(blk)?[0-9]|dwmmc|dw_mmc|ff370000|ff380000' | tail -n 30 | while IFS= read -r _l; do
		log_telmi "dmesg $_l"
	done
}

mount_telmi_content() {
	ensure_sdcard_link
	mkdir -p /telmi
	umount /telmi/.tmp_update 2>/dev/null || true
	if mountpoint -q /telmi 2>/dev/null; then
		_src=$(findmnt -n -o SOURCE /telmi 2>/dev/null || true)
		_os=$(get_os_mmc_base) || _os=""
		if [ -n "$_os" ] && [ -n "$_src" ] && part_on_mmc "$_src" "$_os"; then
			log_telmi "deja interne $_src — tentative slot gauche"
			umount /telmi 2>/dev/null || true
		else
			log_telmi "deja monte $_src"
			return 0
		fi
	fi
	umount /telmi 2>/dev/null || true

	log_mmc_probe
	_max=$(default_wait_max)
	rescan_empty_mmc_hosts

	# Slot gauche d'abord (attendre l'apparition mmc). p3 OS seulement ensuite.
	_i=0
	while [ "$_i" -le "$_max" ]; do
		if mount_external_content; then
			return 0
		fi
		if [ "$_i" -ge "$_max" ]; then
			break
		fi
		sleep 1
		_i=$((_i + 1))
		if [ $((_i % 2)) -eq 0 ]; then
			rescan_empty_mmc_hosts
		fi
	done

	if mount_internal_content; then
		return 0
	fi

	rm -f "$TELMI_CONTENT_MODE_FILE"
	log_telmi "content=missing (waited ${_max}s)"
	return 1
}

setup_tmp_update() {
	mkdir -p /telmi/.tmp_update
	umount /telmi/.tmp_update 2>/dev/null || true
	mount --bind /opt/telmi /telmi/.tmp_update 2>/dev/null || true
}

seed_content_tree() {
	mkdir -p /telmi/Stories /telmi/Music /telmi/Saves/Stories /telmi/logs
	if [ ! -f /telmi/Saves/.parameters ]; then
		cat > /telmi/Saves/.parameters <<'EOF'
{"audioVolumeStartup":0.5,"audioVolumeMax":1.0,"screenBrightnessStartup":0.4,"screenBrightnessMax":0.8,"screenOnInactivityTime":180,"screenOffInactivityTime":300,"musicInactivityTime":1800,"storyDisplayTiles":true,"storyDisableNightMode":false,"storyDisableTimeline":false,"musicDisableRepeatModes":false,"bootSplashscreen":""}
EOF
	fi
	# Toujours réécrire : Telmi Sync exige icon + label v1.10.1
	cat > /telmi/autorun.inf <<'EOF'
[autorun]
icon  = .tmp_update/res/sdcard.ico
label = TelmiOS-v1.10.1
EOF
	mkdir -p /telmi/.tmp_update/res
	if [ -f /opt/telmi/res/sdcard.ico ]; then
		cp -f /opt/telmi/res/sdcard.ico /telmi/.tmp_update/res/sdcard.ico 2>/dev/null || true
	fi
}

setup_content_full() {
	if ! mountpoint -q /telmi 2>/dev/null; then
		return 1
	fi
	seed_content_tree
	setup_tmp_update
	ensure_sdcard_link
	return 0
}

print_status() {
	if mountpoint -q /telmi 2>/dev/null; then
		_src=$(findmnt -n -o SOURCE /telmi 2>/dev/null || awk '$2=="/telmi"{print $1;exit}' /proc/mounts)
		_mode=$(cat "$TELMI_CONTENT_MODE_FILE" 2>/dev/null || echo unknown)
		echo "mounted $_src mode=$_mode"
	else
		echo "not mounted"
	fi
}

case "$1" in
	mount) mount_telmi_content ;;
	setup) mount_telmi_content && setup_content_full ;;
	status) print_status ;;
	*)
		echo "Usage: $0 mount|setup|status" >&2
		exit 1
		;;
esac
