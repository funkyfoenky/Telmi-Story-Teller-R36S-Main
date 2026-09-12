/* Mini PID 1 initramfs — dump klog sur FAT (D:/E:) + ext4, puis tente systemd. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/klog.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

static void wr(int fd, const char *s)
{
	if (fd >= 0 && s)
		(void)write(fd, s, strlen(s));
}

static void dump_all(const char *path)
{
	int out, n, cmd, part, sz;
	char buf[4096];
	static char kbuf[262144];

	out = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (out < 0)
		return;
	wr(out, "=== telmi-initrd dump ===\ncmdline: ");
	cmd = open("/proc/cmdline", O_RDONLY);
	if (cmd >= 0) {
		n = (int)read(cmd, buf, sizeof(buf) - 1);
		if (n > 0)
			(void)write(out, buf, (size_t)n);
		close(cmd);
	}
	wr(out, "\n--- partitions ---\n");
	part = open("/proc/partitions", O_RDONLY);
	if (part >= 0) {
		while ((n = (int)read(part, buf, sizeof(buf))) > 0)
			(void)write(out, buf, (size_t)n);
		close(part);
	}
	wr(out, "--- klog ---\n");
	sz = klogctl(10, NULL, 0);
	if (sz <= 0 || sz > (int)sizeof(kbuf))
		sz = (int)sizeof(kbuf);
	n = klogctl(3, kbuf, sz);
	if (n > 0)
		(void)write(out, kbuf, (size_t)n);
	close(out);
	sync();
}

static int try_mount(const char *dev, const char *dir, const char *fstype)
{
	mkdir(dir, 0755);
	umount(dir);
	return mount(dev, dir, fstype, 0, NULL) == 0;
}

int main(void)
{
	static const char *fats[] = {
		"/dev/mmcblk0p1", "/dev/mmcblk1p1",
		"/dev/mmcblk0p3", "/dev/mmcblk1p3", NULL
	};
	static const char *exts[] = {
		"/dev/mmcblk0p2", "/dev/mmcblk1p2", NULL
	};
	int i, t;
	int got_root = 0;

	mkdir("/proc", 0755);
	mkdir("/sys", 0755);
	mkdir("/dev", 0755);
	mkdir("/mnt", 0755);
	mkdir("/mnt/fat", 0755);
	mkdir("/mnt/root", 0755);
	(void)mount("proc", "/proc", "proc", 0, NULL);
	(void)mount("sysfs", "/sys", "sysfs", 0, NULL);
	if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) != 0)
		(void)mount("tmpfs", "/dev", "tmpfs", 0, NULL);

	for (t = 0; t < 25; t++) {
		if (access("/dev/mmcblk0p1", F_OK) == 0 ||
		    access("/dev/mmcblk1p1", F_OK) == 0)
			break;
		sleep(1);
	}

	for (i = 0; fats[i]; i++) {
		if (access(fats[i], F_OK) != 0)
			continue;
		if (!try_mount(fats[i], "/mnt/fat", "vfat"))
			continue;
		dump_all("/mnt/fat/telmi-early.log");
		dump_all("/mnt/fat/telmi-runtime.log");
		umount("/mnt/fat");
	}

	for (t = 0; t < 20; t++) {
		for (i = 0; exts[i]; i++) {
			if (access(exts[i], F_OK) != 0)
				continue;
			if (!try_mount(exts[i], "/mnt/root", "ext4"))
				continue;
			dump_all("/mnt/root/telmi-early.log");
			mkdir("/mnt/root/var", 0755);
			mkdir("/mnt/root/var/log", 0755);
			dump_all("/mnt/root/var/log/telmi-early.log");
			got_root = 1;
			goto cont;
		}
		sleep(1);
	}

cont:
	if (got_root && access("/mnt/root/lib/systemd/systemd", X_OK) == 0) {
		if (chroot("/mnt/root") == 0) {
			chdir("/");
			execl("/lib/systemd/systemd", "systemd", (char *)NULL);
		}
	}

	for (;;)
		sleep(60);
	return 1;
}
