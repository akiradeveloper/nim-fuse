#include "fuse.h"

int nim_bridge_releasedir(int id, const char *name, struct fuse_file_info *fi);
void nim_bridge_destroy(int id, void *data);
int nim_bridge_getattr(int id, const char *name, struct stat *st);

int c_bridge_releasedir(const char *name, struct fuse_file_info *fi)
{
	return nim_bridge_releasedir(0, name, fi);
}

int c_bridge_getattr(const char *name, struct stat *st)
{
	return nim_bridge_getattr(0, name, st);
}

void c_bridge_destroy(void *data)
{
	nim_bridge_destroy(0, data);
}

static struct fuse_operations c_bridge_ops = {
	.destroy = c_bridge_destroy,
	.getattr = c_bridge_getattr,
	.releasedir = c_bridge_releasedir,
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
