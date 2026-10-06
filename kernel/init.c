// SPDX-License-Identifier: GPL-2.0
/*
 * Milestone-1 init for the Note 9 test image. Built against the kernel's
 * own nolibc (tools/include/nolibc), so there is no external userspace.
 *
 * It mounts devtmpfs, then prints every key press and release from the
 * first few input devices to the console (the on-screen log). It never
 * exits: if init exits, the kernel panics and stops reacting to keys.
 */

#define NR_INPUTS	4
#define EV_KEY		1

struct ev {			/* struct input_event on arm64 */
	long long sec, usec;
	unsigned short type, code;
	int value;
};

static const char *key_name(unsigned int code)
{
	switch (code) {
	case 114: return "Volume Down";
	case 115: return "Volume Up";
	case 116: return "Power";
	case 212: return "Camera (Bixby key)";
	default:  return "other key";
	}
}

static void watch(int n)
{
	char path[24];
	struct ev e;
	int fd;

	snprintf(path, sizeof(path), "/dev/input/event%d", n);
	while ((fd = open(path, O_RDONLY)) < 0)
		sleep(1);	/* driver may probe after init starts */
	printf("note9-mainline: listening on %s\n", path);
	while (read(fd, &e, sizeof(e)) == sizeof(e)) {
		if (e.type != EV_KEY)
			continue;
		printf("note9-mainline: %s (code %u) %s\n", key_name(e.code),
		       e.code, e.value ? "pressed" : "released");
	}
	printf("note9-mainline: %s stopped\n", path);
	for (;;)
		sleep(3600);
}

int main(void)
{
	int i;

	printf("\nnote9-mainline: init running. Press Power, Volume Up/Down, Bixby.\n"
	       "To leave: hold Power + Volume Down until the phone restarts.\n");
	if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL))
		printf("note9-mainline: mounting devtmpfs failed\n");
	for (i = 0; i < NR_INPUTS; i++)
		if (fork() == 0)
			watch(i);
	for (;;)
		sleep(3600);
	return 0;
}
