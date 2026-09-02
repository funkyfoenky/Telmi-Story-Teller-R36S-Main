/* SDL_mixer ArkOS 2.0.4 : pas de Mix_MusicDuration (API 2.6+).
 * Duree lue depuis le fichier (Xing MP3 / WAV) pour la barre de timeline. */
#include "SDL2/SDL_mixer.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

double Mix_MusicDuration(Mix_Music *music)
{
	(void)music;
	return 0.0;
}

static uint32_t telmi_be32(const unsigned char *p)
{
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
	       ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static uint32_t telmi_le32(const unsigned char *p)
{
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
	       ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int telmi_id3v2_skip(FILE *fp)
{
	unsigned char h[10];
	uint32_t size;

	if (fread(h, 1, 10, fp) != 10)
		return -1;
	if (h[0] != 'I' || h[1] != 'D' || h[2] != '3') {
		fseek(fp, 0, SEEK_SET);
		return 0;
	}
	size = ((uint32_t)(h[6] & 0x7f) << 21) | ((uint32_t)(h[7] & 0x7f) << 14) |
	       ((uint32_t)(h[8] & 0x7f) << 7) | (uint32_t)(h[9] & 0x7f);
	if (h[5] & 0x10)
		size += 10;
	if (fseek(fp, (long)size, SEEK_CUR) != 0)
		return -1;
	return 0;
}

static double telmi_mp3_duration(FILE *fp, long filesize)
{
	static const int br_v1[16] = {0, 32, 40, 48, 56, 64, 80, 96, 112, 128,
				      160, 192, 224, 256, 320, 0};
	static const int br_v2[16] = {0, 8, 16, 24, 32, 40, 48, 56, 64, 80,
				      96, 112, 128, 144, 160, 0};
	static const int sr_v1[4] = {44100, 48000, 32000, 0};
	static const int sr_v2[4] = {22050, 24000, 16000, 0};
	unsigned char hdr[4], tag[4];
	unsigned int b1, ver, layer, br_i, sr_i, ch;
	int bitrate = 128, srate = 44100, spf = 1152, side = 32;
	long frame0 = 0, rest;
	uint32_t flags, frames;

	if (telmi_id3v2_skip(fp) < 0)
		return 0.0;

	for (;;) {
		int c = fgetc(fp);
		if (c == EOF)
			return 0.0;
		if (c != 0xff)
			continue;
		c = fgetc(fp);
		if (c == EOF)
			return 0.0;
		if ((c & 0xe0) != 0xe0)
			continue;
		hdr[0] = 0xff;
		hdr[1] = (unsigned char)c;
		if (fread(hdr + 2, 1, 2, fp) != 2)
			return 0.0;
		break;
	}

	b1 = hdr[1];
	ver = (b1 >> 3) & 3; /* 3=MPEG1, 2=MPEG2, 0=MPEG2.5 */
	layer = (b1 >> 1) & 3;
	br_i = (hdr[2] >> 4) & 0x0f;
	sr_i = (hdr[2] >> 2) & 0x03;
	ch = (hdr[3] >> 6) & 0x03; /* 3 = mono */

	if (layer != 1) /* Layer III = 1 in this bitfield */
		goto cbr;
	if (ver == 1)
		return 0.0;

	if (ver == 3) {
		bitrate = br_v1[br_i];
		srate = sr_v1[sr_i];
		spf = 1152;
		side = (ch == 3) ? 17 : 32;
	} else {
		bitrate = br_v2[br_i];
		srate = (ver == 2) ? sr_v2[sr_i] : sr_v2[sr_i] / 2;
		spf = 576;
		side = (ch == 3) ? 9 : 17;
	}
	if (bitrate <= 0 || srate <= 0)
		goto cbr;

	frame0 = ftell(fp); /* just after 4-byte header */
	if (fseek(fp, side, SEEK_CUR) != 0)
		goto cbr;
	if (fread(tag, 1, 4, fp) == 4 &&
	    (memcmp(tag, "Xing", 4) == 0 || memcmp(tag, "Info", 4) == 0)) {
		if (fread(tag, 1, 4, fp) != 4)
			goto cbr;
		flags = telmi_be32(tag);
		if (flags & 0x1) {
			if (fread(tag, 1, 4, fp) != 4)
				goto cbr;
			frames = telmi_be32(tag);
			if (frames > 0 && srate > 0)
				return (double)frames * (double)spf / (double)srate;
		}
	}

cbr:
	if (bitrate <= 0)
		bitrate = 128;
	if (srate <= 0)
		srate = 44100;
	rest = filesize - (frame0 > 0 ? frame0 - 4 : 0);
	if (rest < 0)
		rest = filesize;
	return (double)rest * 8.0 / ((double)bitrate * 1000.0);
}

static double telmi_wav_duration(FILE *fp, long filesize)
{
	unsigned char riff[12], chunk[8], fmt[16];
	uint32_t byte_rate = 0, data_bytes = 0;
	long pos;

	(void)filesize;
	if (fread(riff, 1, 12, fp) != 12)
		return 0.0;
	if (memcmp(riff, "RIFF", 4) != 0)
		return 0.0;
	while (fread(chunk, 1, 8, fp) == 8) {
		uint32_t sz = telmi_le32(chunk + 4);
		if (memcmp(chunk, "fmt ", 4) == 0) {
			memset(fmt, 0, sizeof(fmt));
			if (sz > sizeof(fmt)) {
				if (fread(fmt, 1, sizeof(fmt), fp) != sizeof(fmt))
					return 0.0;
				if (fseek(fp, (long)sz - (long)sizeof(fmt), SEEK_CUR) != 0)
					return 0.0;
			} else {
				if (fread(fmt, 1, sz, fp) != sz)
					return 0.0;
			}
			byte_rate = telmi_le32(fmt + 8);
			if (sz & 1)
				fseek(fp, 1, SEEK_CUR);
			continue;
		}
		if (memcmp(chunk, "data", 4) == 0) {
			data_bytes = sz;
			break;
		}
		pos = (long)sz + (sz & 1);
		if (fseek(fp, pos, SEEK_CUR) != 0)
			break;
	}
	if (byte_rate == 0 || data_bytes == 0)
		return 0.0;
	return (double)data_bytes / (double)byte_rate;
}

double telmi_audio_file_duration(const char *path)
{
	FILE *fp;
	struct stat st;
	unsigned char magic[12];
	double d = 0.0;

	if (path == NULL || path[0] == '\0')
		return 0.0;
	if (stat(path, &st) != 0 || st.st_size < 16)
		return 0.0;
	fp = fopen(path, "rb");
	if (!fp)
		return 0.0;
	if (fread(magic, 1, 12, fp) != 12) {
		fclose(fp);
		return 0.0;
	}
	fseek(fp, 0, SEEK_SET);
	if (memcmp(magic, "RIFF", 4) == 0)
		d = telmi_wav_duration(fp, st.st_size);
	else
		d = telmi_mp3_duration(fp, st.st_size);
	fclose(fp);
	if (d < 0.5)
		d = 0.0;
	if (d > 24 * 3600)
		d = 0.0;
	return d;
}
