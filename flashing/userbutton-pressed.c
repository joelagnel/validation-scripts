#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/input.h>
#include <stdint.h>
#include <string.h>

int main(int argc, char **argv) {
	uint8_t key_b[KEY_MAX/8 + 1];
	int fd, i;

	memset(key_b, 0, sizeof(key_b));
	fd = open("/dev/input/event0", O_RDWR);
	ioctl(fd, EVIOCGKEY(sizeof(key_b)), key_b);
	if(key_b[34])
		printf("1");
	else
		printf("0");
}
