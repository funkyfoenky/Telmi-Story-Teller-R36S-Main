#!/bin/sh
# Telmi-os runtime — bins sur root ext4, logs sur partition BOOT (FAT).
TELMI_ROOT=/opt/telmi
export PATH="$TELMI_ROOT/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LD_LIBRARY_PATH="$TELMI_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SDL_AUDIODRIVER=alsa
unset AUDIODEV
# storyTeller dessine sur /dev/fb0 (même chemin que bootScreen).
# kmsdrm après le splash fb0 crée une fenêtre SDL invisible.
unset SDL_VIDEODRIVER
unset SDL_FBDEV
unset MESA_LOADER_DRIVER_OVERRIDE
unset LIBGL_ALWAYS_SOFTWARE
unset GALLIUM_DRIVER

log() {
	_l="[telmi] $(date '+%H:%M:%S') $*"
	echo "$_l"
	echo "$_l" >> /boot/telmi-runtime.log 2>/dev/null || true
}

ensure_boot() {
	mkdir -p /boot
	mountpoint -q /boot 2>/dev/null && return 0
	mount -L BOOT /boot 2>/dev/null && return 0
	mount /dev/mmcblk0p1 /boot 2>/dev/null && return 0
	mount /dev/mmcblk1p1 /boot 2>/dev/null && return 0
	# fstab déjà prévu ; dernier recours
	mount /boot 2>/dev/null || true
}

runtime_log() {
	echo "$1" >> /boot/telmi-runtime.log 2>/dev/null || true
}

take_display() {
	for _v in /sys/class/vtconsole/vtcon*; do
		[ -w "$_v/bind" ] || continue
		echo 0 > "$_v/bind" 2>/dev/null || true
	done
	chmod 666 /dev/dri/card0 /dev/dri/renderD128 /dev/fb0 2>/dev/null || true
}

ensure_content_mounted() {
	TELMI_MOUNT=/opt/telmi/bin/telmi-mount-content.sh
	if ! mountpoint -q /telmi 2>/dev/null; then
		if [ -x "$TELMI_MOUNT" ]; then
			# Attendre le slot gauche (mmc externe). 0 = p3 interne gagne toujours.
			TELMI_WAIT_MAX=12 "$TELMI_MOUNT" setup || true
		fi
	fi
	mkdir -p /telmi /telmi/.tmp_update /telmi/Stories /telmi/Music /telmi/Saves/Stories /telmi/logs /mnt
	if [ ! -L /mnt/SDCARD ] && [ ! -e /mnt/SDCARD ]; then
		ln -sf /telmi /mnt/SDCARD
	fi
	if ! mountpoint -q /telmi/.tmp_update 2>/dev/null; then
		mount --bind /opt/telmi /telmi/.tmp_update 2>/dev/null || true
	fi
	if [ ! -e /opt/telmi/res/selectStories.png ]; then
		log "WARN : assets absents /opt/telmi/res"
	else
		log "assets OK /opt/telmi/res"
	fi
	if [ ! -f /telmi/Saves/.parameters ]; then
		cat > /telmi/Saves/.parameters <<'EOF'
{"audioVolumeStartup":0.5,"audioVolumeMax":1.0,"screenBrightnessStartup":0.4,"screenBrightnessMax":0.8,"screenOnInactivityTime":180,"screenOffInactivityTime":300,"musicInactivityTime":1800,"storyDisplayTiles":true,"storyDisableNightMode":false,"storyDisableTimeline":false,"musicDisableRepeatModes":false,"bootSplashscreen":""}
EOF
	fi
	if mountpoint -q /telmi 2>/dev/null; then
		log "contenu monte $(findmnt -n -o SOURCE,FSTYPE /telmi 2>/dev/null || echo ok)"
	else
		log "WARN : partition TELMI absente — Stories resteront vides"
	fi
	return 0
}

init_display() {
	echo -n "640x480" > /tmp/screen_resolution
	echo -n "283" > /tmp/deviceModel
	for _b in /sys/class/backlight/*/brightness; do
		[ -f "$_b" ] || continue
		_max=$(cat "$(dirname "$_b")/max_brightness" 2>/dev/null || echo 255)
		echo "$_max" > "$_b" 2>/dev/null || true
		log "backlight $_b = $_max"
	done
	runtime_log "[telmi] drm=$(ls /sys/class/drm/ 2>/dev/null | tr '\n' ' ')"
	runtime_log "[telmi] bat=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo '?')"
}

run_sdl() {
	_app="$1"
	shift
	log "Lancement $_app (blit fb0)"
	rm -f /boot/storyTeller.steps /tmp/storyTeller.steps 2>/dev/null
	"$_app" "$@" >> /boot/telmi-runtime.log 2>&1
	_ec=$?
	if [ -f /boot/storyTeller.steps ]; then
		runtime_log "--- storyTeller.steps ---"
		cat /boot/storyTeller.steps >> /boot/telmi-runtime.log 2>/dev/null || true
	fi
	if [ "$_ec" -eq 0 ]; then
		log "$_app termine OK"
		return 0
	fi
	log "$_app echec (code $_ec)"
	return "$_ec"
}

show_telmi_splash() {
	if [ ! -x "$TELMI_ROOT/bin/bootScreen" ]; then
		log "WARN : bootScreen absent"
		return 0
	fi
	log "splash Telmi (bootScreen hold fb0)"
	"$TELMI_ROOT/bin/bootScreen" Boot >> /boot/telmi-runtime.log 2>&1 || log "bootScreen ignore"
}

main() {
	ensure_boot
	: > /boot/telmi-runtime.log 2>/dev/null || true
	rm -f /boot/bootScreen.steps /boot/storyTeller.steps 2>/dev/null
	log "Demarrage Telmi-os"
	if [ -f /opt/telmi/telmiVersion/image-version.txt ]; then
		log "Image $(cat /opt/telmi/telmiVersion/image-version.txt) build $(cat /opt/telmi/telmiVersion/build-id.txt 2>/dev/null)"
	fi
	runtime_log "[telmi] runtime pid $$ telmi-os"
	init_display
	take_display
	# Splash en fond : rester mmap'é jusqu'à ce que storyTeller prenne fb0.
	show_telmi_splash &
	_splash_pid=$!
	ensure_content_mounted

	# Vol+/Vol- = gpio_keys.ko (module). Jamais builtin : ça cassait la manette en 0.2.6.
	if [ -f /opt/telmi/modules/gpio_keys.ko ]; then
		if insmod /opt/telmi/modules/gpio_keys.ko 2>/tmp/telmi-gpiokeys.err; then
			log "gpio_keys module charge"
		else
			log "WARN gpio_keys $(tr '\n' ' ' </tmp/telmi-gpiokeys.err 2>/dev/null)"
		fi
		sleep 0.3
	fi

	rm -f /tmp/.offOrder 2>/dev/null
	[ -x "$TELMI_ROOT/bin/batmon" ] && "$TELMI_ROOT/bin/batmon" &

	cd "$TELMI_ROOT"
	_play_path=SPK
	[ -f /boot/TELMI-AUDIO-PATH.txt ] && _ap=$(tr -d '[:space:]' </boot/TELMI-AUDIO-PATH.txt) && \
		case "$_ap" in SPK|HP|SPK_HP) _play_path="$_ap" ;; esac
	rm -f /var/lib/alsa/asound.state
	log "audio_path=$_play_path"
	amixer -c 0 cset name='Playback Path' "$_play_path" >/dev/null 2>&1 || true
	amixer -c 0 sset Playback 97% unmute >/dev/null 2>&1 || true
	amixer -c 0 sset DAC unmute >/dev/null 2>&1 || true
	_cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo 0)
	echo -n "$_cap" > /tmp/percBat 2>/dev/null || true
	log "percBat=$_cap"

	log "Lancement storyTeller"
	sync 2>/dev/null || true
	run_sdl "$TELMI_ROOT/bin/storyTeller" || log "storyTeller echec"

	if [ ! -f /tmp/.offOrder ]; then
		log "attente extinction (.offOrder)"
		while true; do
			[ -f /tmp/.offOrder ] && break
			sleep 1
		done
	fi

	# Logo sleep AVANT de tuer le splash boot (sinon le panneau s'eteint).
	log "splash sleep (Screen_Off)"
	take_display
	echo 0 > /sys/class/graphics/fb0/blank 2>/dev/null || true
	if [ -x "$TELMI_ROOT/bin/bootScreen" ]; then
		"$TELMI_ROOT/bin/bootScreen" End >> /boot/telmi-runtime.log 2>&1 &
		_end_pid=$!
		sleep 1
	fi
	kill "$_splash_pid" 2>/dev/null || true
	sleep 2
	log "extinction"
	systemctl poweroff --force 2>/dev/null || poweroff -f 2>/dev/null || halt -f
}

main "$@"
