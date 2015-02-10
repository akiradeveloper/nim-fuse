#include "fuse.h"

void c_bridge_destroy(void *data)
{
}

static struct fuse_operations c_bridge_ops = {
	.destroy = c_bridge_destroy,
};

struct c_bridge_user_data {
	int id;
};

int c_bridge_main(int id, int argc, char *argv[]) 
{
	struct c_bridge_user_data user_data = {
		.id = id
	};
	return fuse_main(argc, argv, &c_bridge_ops, &user_data);
}
