#include "fuse.h"

struct c_bridge_user_data {
	int id;
};

static int fsId()
{
	struct c_bridge_user_data *udata = fuse_get_context()->private_data;
	return udata->id;
}

int nim_bridge_readdir(int, const char *, fuse_fill_dir_t, off_t, struct fuse_fill_info *);
int nim_bridge_releasedir(int, const char *, struct fuse_file_info *);
void nim_bridge_destroy(int, void *);
int nim_bridge_getattr(int, const char *, struct stat *);

int c_bridge_readdir(int id, const char *name, fuse_fill_dir_t filler, off_t off, struct fuse_fill_info *fi)
{
	return nim_bridge_readdir(fsId(), name, filler, off, fi);
}

int c_bridge_releasedir(const char *name, struct fuse_file_info *fi)
{
	return nim_bridge_releasedir(fsId(), name, fi);
}

int c_bridge_getattr(const char *name, struct stat *st)
{
	return nim_bridge_getattr(fsId(), name, st);
}

void c_bridge_destroy(void *data)
{
	nim_bridge_destroy(fsId(), data);
}

static struct fuse_operations c_bridge_ops = {
	.destroy = c_bridge_destroy,
	.getattr = c_bridge_getattr,
	.releasedir = c_bridge_releasedir,
};


int c_bridge_main(int id, int argc, char *argv[]) 
{
	struct c_bridge_user_data user_data = {
		.id = id
	};
	return fuse_main(argc, argv, &c_bridge_ops, &user_data);
}
