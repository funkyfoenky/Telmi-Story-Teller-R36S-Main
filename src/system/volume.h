#ifndef VOLUME_H__
#define VOLUME_H__

/* Volume : attenuation PCM (postmix) + Playback analogique.
 * Mix_VolumeMusic est ignore par le backend MP3 2.0.4 ; le DAC analogique
 * n'enleve pas une saturation deja dans les samples. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sound/asound.h>

#include <SDL2/SDL_mixer.h>

#include "system/telmi_rev.h"
#include "utils/file.h"

#define MAX_VOLUME 20
/* Analog : 248/255 (marge latch RK817). PCM 320/256 ≈ +2 dB au max. */
#define R36S_PLAYBACK_MAX 248
#define R36S_PLAYBACK_FLOOR 40
#define R36S_PCM_GAIN_MAX 320
/* Ancres 0.2.7 : 10 % UI = ancien 40 %. */
#define R36S_OLD_PLAYBACK_MAX 204
#define R36S_OLD_PCM_MAX 220
/* 0.2.8 vol 18 = ~70 % UI : trop fort → devient le 100 % actuel. */
#define R36S_VOL028_AT_70 18

static int r36s_spk_ready = 0;
static int r36s_last_hw = -1;
static int r36s_mixer_fd = -1;
static int r36s_playback_numid = -1;
static int r36s_pcm_gain = 90;

static void SDLCALL r36s_postmix(void *udata, Uint8 *stream, int len)
{
	Sint16 *s = (Sint16 *)stream;
	int n = len / 2;
	int i, g, v;

	(void)udata;
	g = r36s_pcm_gain;
	if (g == 256)
		return;
	for (i = 0; i < n; i++) {
		v = ((int)s[i] * g) >> 8;
		if (v > 32767)
			v = 32767;
		else if (v < -32768)
			v = -32768;
		s[i] = (Sint16)v;
	}
}

static void r36s_ensure_spk_path(void)
{
	char cmd[128];

	if (r36s_spk_ready)
		return;
	snprintf(cmd, sizeof(cmd),
		 "amixer -c 0 -q cset name='Playback Path' %s 2>/dev/null || true",
		 telmi_audio_path());
	system(cmd);
	system("amixer -c 0 -q sset DAC unmute 2>/dev/null || true");
	r36s_spk_ready = 1;
}

/* Trouve le numid du control "Playback" et ouvre le mixer une seule fois. */
static void r36s_mixer_init(void)
{
	struct snd_ctl_elem_list elist;
	struct snd_ctl_elem_id *ids = NULL;
	unsigned int i;

	if (r36s_mixer_fd >= 0)
		return;

	r36s_mixer_fd = open("/dev/snd/controlC0", O_RDWR);
	if (r36s_mixer_fd < 0)
		return;

	memset(&elist, 0, sizeof(elist));
	if (ioctl(r36s_mixer_fd, SNDRV_CTL_IOCTL_ELEM_LIST, &elist) < 0)
		return;
	if (elist.count == 0)
		return;

	ids = (struct snd_ctl_elem_id *)calloc(elist.count, sizeof(*ids));
	if (!ids)
		return;
	elist.space = elist.count;
	elist.pids = ids;
	if (ioctl(r36s_mixer_fd, SNDRV_CTL_IOCTL_ELEM_LIST, &elist) < 0) {
		free(ids);
		return;
	}

	for (i = 0; i < elist.count; i++) {
		if (strcmp((const char *)ids[i].name, "Playback") == 0) {
			r36s_playback_numid = ids[i].numid;
			break;
		}
	}
	free(ids);
}

/* Applique la valeur hw (0-255) directement via ioctl — pas de fork amixer. */
static int r36s_set_playback_hw(int hw)
{
	struct snd_ctl_elem_value ev;

	r36s_mixer_init();
	if (r36s_mixer_fd < 0 || r36s_playback_numid < 0) {
		/* Fallback amixer si ioctl indisponible */
		char cmd[160];
		if (hw <= 0)
			system("amixer -c 0 -q sset Playback 0 mute 2>/dev/null || true");
		else {
			snprintf(cmd, sizeof(cmd),
				 "amixer -c 0 -q sset Playback %d unmute 2>/dev/null || true", hw);
			system(cmd);
		}
		return 0;
	}

	memset(&ev, 0, sizeof(ev));
	ev.id.numid = r36s_playback_numid;
	ev.value.integer.value[0] = hw;
	ev.value.integer.value[1] = hw;
	ioctl(r36s_mixer_fd, SNDRV_CTL_IOCTL_ELEM_WRITE, &ev);

	return 0;
}

int setVolumeRaw(int value, int add)
{
	(void)add;
	return value;
}

/* Courbe 0.2.7 (50 % UI ≈ ancien 70 %). */
static int r36s_old_ui_to_internal(int volume)
{
	int mapped;

	if (volume <= 0)
		return 0;
	if (volume >= 25)
		return 25;
	if (volume <= 13)
		mapped = (volume * 18) / 13;
	else
		mapped = 18 + ((volume - 13) * 7) / 12;
	if (mapped < 1)
		mapped = 1;
	if (mapped > 25)
		mapped = 25;
	return mapped;
}

static void r36s_old_gains(int volume, int *pcm, int *hw)
{
	int v = r36s_old_ui_to_internal(volume);

	if (v <= 0) {
		*pcm = 0;
		*hw = 0;
		return;
	}
	*pcm = (v * R36S_OLD_PCM_MAX) / 25;
	if (*pcm < 8)
		*pcm = 8;
	*hw = R36S_PLAYBACK_FLOOR +
	      (v * (R36S_OLD_PLAYBACK_MAX - R36S_PLAYBACK_FLOOR)) / 25;
}

/* 100 % UI = volume 0.2.8 à 70 %. En dessous : même courbe, plus basse
 * (50 % UI ≈ 32 % de 0.2.8, donc moins fort qu'avant). */
static void r36s_calc_gains(int volume, int *pcm, int *hw)
{
	int vol08, t, extra, span, pcm0, hw0;

	if (volume <= 0) {
		*pcm = 0;
		*hw = 0;
		return;
	}
	vol08 = (volume * R36S_VOL028_AT_70) / 25;
	if (vol08 < 1)
		vol08 = 1;

	t = vol08 * 4;
	if (t <= 25) {
		r36s_old_gains(t, pcm, hw);
		return;
	}
	r36s_old_gains(25, &pcm0, &hw0);
	extra = t - 25;
	span = 75;
	*pcm = pcm0 + (extra * (R36S_PCM_GAIN_MAX - pcm0)) / span;
	*hw = hw0 + (extra * (R36S_PLAYBACK_MAX - hw0)) / span;
	if (*pcm > R36S_PCM_GAIN_MAX)
		*pcm = R36S_PCM_GAIN_MAX;
	if (*hw > R36S_PLAYBACK_MAX)
		*hw = R36S_PLAYBACK_MAX;
}

/* volume : 0..25 (echelle Telmi / system.json) */
int setVolume(int volume)
{
	int hw;

	if (volume < 0)
		volume = 0;
	if (volume > 25)
		volume = 25;

	r36s_ensure_spk_path();

	/* Postmix : vrai gain numerique (Mix_VolumeMusic no-op sur MP3 mpg123). */
	r36s_calc_gains(volume, &r36s_pcm_gain, &hw);
	Mix_SetPostMix(r36s_postmix, NULL);
	Mix_Volume(-1, MIX_MAX_VOLUME);
	Mix_VolumeMusic(MIX_MAX_VOLUME);

	if (hw == r36s_last_hw)
		return volume;
	r36s_last_hw = hw;

	r36s_set_playback_hw(hw);

	return volume;
}

#endif /* VOLUME_H__ */
