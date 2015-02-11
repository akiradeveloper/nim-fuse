#include "fuse.h"

struct c_bridge_user_data {
	int id;
};

static int fsId()
{
	struct c_bridge_user_data *udata = fuse_get_context()->private_data;
	return udata->id;
}

int nim_bridge_getattr(int id, const char * a, struct stat * b);
int nim_bridge_readlink(int id, const char * a, size_t b);
int nim_bridge_mknod(int id, const char * a, size_t b);
int nim_bridge_mkdir(int id, const char * a, mode_t b);
int nim_bridge_unlink(int id, const char * a);
int nim_bridge_rmdir(int id, const char * a);
int nim_bridge_symlink(int id, const char * a, const char * b);
int nim_bridge_rename(int id, const char * a, const char * b);
int nim_bridge_link(int id, const char * a, const char * b);
int nim_bridge_chmod(int id, const char * a, mode_t b);
int nim_bridge_chown(int id, const char * a, uid_t b, gid_t c);
int nim_bridge_truncate(int id, const char * a, off_t b);
int nim_bridge_open(int id, const char * a, struct fuse_file_info * b);
int nim_bridge_read(int id, const char * a, char * b, size_t c, off_t d, struct fuse_file_info * e);
int nim_bridge_write(int id, const char * a, const char * b, size_t c, off_t d, struct fuse_file_info * e);
int nim_bridge_statfs(int id, const char * a, struct statvfs * b);
int nim_bridge_flush(int id, const char * a, struct fuse_file_info * b);
int nim_bridge_release(int id, const char * a, struct fuse_file_info * b);
int nim_bridge_fsync(int id, const char * a, int b, struct fuse_file_info * c);
int nim_bridge_setxattr(int id, const char * a, const char * b, size_t c, int d);
int nim_bridge_getxattr(int id, const char * a, const char * b, size_t c);
int nim_bridge_listxattr(int id, const char * a, char * b, size_t c);
int nim_bridge_removexattr(int id, const char * a, const char * b);
int nim_bridge_opendir(int id, const char * a, struct fuse_file_info * b);
int nim_bridge_readdir(int id, const char * a, void * b, fuse_fill_dir_t c, off_t d, struct fuse_file_info * e);
int nim_bridge_releasedir(int id, const char * a, struct fuse_file_info * b);
int nim_bridge_fsyncdir(int id, const char * a, int b, struct fuse_file_info * c);
void nim_bridge_init(int id, struct fuse_conn_info * a);
void nim_bridge_destroy(int id, void * a);
int nim_bridge_access(int id, const char * a, int b);
int nim_bridge_create(int id, const char * a, mode_t b, struct fuse_file_info * c);
int nim_bridge_ftruncate(int id, const char * a, off_t b, struct fuse_file_info * c);
int nim_bridge_fgetattr(int id, const char * a, struct stat * b, struct fuse_file_info * c);
int nim_bridge_lock(int id, const char * a, struct fuse_file_info * b, int c, struct flock * d);
int nim_bridge_utimens(int id, const char * a, const struct timespec b);
int nim_bridge_bmap(int id, const char * a, size_t b, uint64_t c);

static int c_bridge_getattr(const char * a, struct stat * b)
{
	return nim_bridge_getattr(fsId(), a, b);
}

static int c_bridge_readlink(const char * a, size_t b)
{
	return nim_bridge_readlink(fsId(), a, b);
}

static int c_bridge_mknod(const char * a, size_t b)
{
	return nim_bridge_mknod(fsId(), a, b);
}

static int c_bridge_mkdir(const char * a, mode_t b)
{
	return nim_bridge_mkdir(fsId(), a, b);
}

static int c_bridge_unlink(const char * a)
{
	return nim_bridge_unlink(fsId(), a);
}

static int c_bridge_rmdir(const char * a)
{
	return nim_bridge_rmdir(fsId(), a);
}

static int c_bridge_symlink(const char * a, const char * b)
{
	return nim_bridge_symlink(fsId(), a, b);
}

static int c_bridge_rename(const char * a, const char * b)
{
	return nim_bridge_rename(fsId(), a, b);
}

static int c_bridge_link(const char * a, const char * b)
{
	return nim_bridge_link(fsId(), a, b);
}

static int c_bridge_chmod(const char * a, mode_t b)
{
	return nim_bridge_chmod(fsId(), a, b);
}

static int c_bridge_chown(const char * a, uid_t b, gid_t c)
{
	return nim_bridge_chown(fsId(), a, b, c);
}

static int c_bridge_truncate(const char * a, off_t b)
{
	return nim_bridge_truncate(fsId(), a, b);
}

static int c_bridge_open(const char * a, struct fuse_file_info * b)
{
	return nim_bridge_open(fsId(), a, b);
}

static int c_bridge_read(const char * a, char * b, size_t c, off_t d, struct fuse_file_info * e)
{
	return nim_bridge_read(fsId(), a, b, c, d, e);
}

static int c_bridge_write(const char * a, const char * b, size_t c, off_t d, struct fuse_file_info * e)
{
	return nim_bridge_write(fsId(), a, b, c, d, e);
}

static int c_bridge_statfs(const char * a, struct statvfs * b)
{
	return nim_bridge_statfs(fsId(), a, b);
}

static int c_bridge_flush(const char * a, struct fuse_file_info * b)
{
	return nim_bridge_flush(fsId(), a, b);
}

static int c_bridge_release(const char * a, struct fuse_file_info * b)
{
	return nim_bridge_release(fsId(), a, b);
}

static int c_bridge_fsync(const char * a, int b, struct fuse_file_info * c)
{
	return nim_bridge_fsync(fsId(), a, b, c);
}

static int c_bridge_setxattr(const char * a, const char * b, size_t c, int d)
{
	return nim_bridge_setxattr(fsId(), a, b, c, d);
}

static int c_bridge_getxattr(const char * a, const char * b, size_t c)
{
	return nim_bridge_getxattr(fsId(), a, b, c);
}

static int c_bridge_listxattr(const char * a, char * b, size_t c)
{
	return nim_bridge_listxattr(fsId(), a, b, c);
}

static int c_bridge_removexattr(const char * a, const char * b)
{
	return nim_bridge_removexattr(fsId(), a, b);
}

static int c_bridge_opendir(const char * a, struct fuse_file_info * b)
{
	return nim_bridge_opendir(fsId(), a, b);
}

static int c_bridge_readdir(const char * a, void * b, fuse_fill_dir_t c, off_t d, struct fuse_file_info * e)
{
	return nim_bridge_readdir(fsId(), a, b, c, d, e);
}

static int c_bridge_releasedir(const char * a, struct fuse_file_info * b)
{
	return nim_bridge_releasedir(fsId(), a, b);
}

static int c_bridge_fsyncdir(const char * a, int b, struct fuse_file_info * c)
{
	return nim_bridge_fsyncdir(fsId(), a, b, c);
}

static void c_bridge_init(struct fuse_conn_info * a)
{
	return nim_bridge_init(fsId(), a);
}

static void c_bridge_destroy(void * a)
{
	return nim_bridge_destroy(fsId(), a);
}

static int c_bridge_access(const char * a, int b)
{
	return nim_bridge_access(fsId(), a, b);
}

static int c_bridge_create(const char * a, mode_t b, struct fuse_file_info * c)
{
	return nim_bridge_create(fsId(), a, b, c);
}

static int c_bridge_ftruncate(const char * a, off_t b, struct fuse_file_info * c)
{
	return nim_bridge_ftruncate(fsId(), a, b, c);
}

static int c_bridge_fgetattr(const char * a, struct stat * b, struct fuse_file_info * c)
{
	return nim_bridge_fgetattr(fsId(), a, b, c);
}

static int c_bridge_lock(const char * a, struct fuse_file_info * b, int c, struct flock * d)
{
	return nim_bridge_lock(fsId(), a, b, c, d);
}

static int c_bridge_utimens(const char * a, const struct timespec b)
{
	return nim_bridge_utimens(fsId(), a, b);
}

static int c_bridge_bmap(const char * a, size_t b, uint64_t c)
{
	return nim_bridge_bmap(fsId(), a, b, c);
}

static struct fuse_operations c_bridge_ops = {
	.getattr = c_bridge_getattr,
	.readlink = c_bridge_readlink,
	.mknod = c_bridge_mknod,
	.mkdir = c_bridge_mkdir,
	.unlink = c_bridge_unlink,
	.rmdir = c_bridge_rmdir,
	.symlink = c_bridge_symlink,
	.rename = c_bridge_rename,
	.link = c_bridge_link,
	.chmod = c_bridge_chmod,
	.chown = c_bridge_chown,
	.truncate = c_bridge_truncate,
	.open = c_bridge_open,
	.read = c_bridge_read,
	.write = c_bridge_write,
	.statfs = c_bridge_statfs,
	.flush = c_bridge_flush,
	.release = c_bridge_release,
	.fsync = c_bridge_fsync,
	.setxattr = c_bridge_setxattr,
	.getxattr = c_bridge_getxattr,
	.listxattr = c_bridge_listxattr,
	.removexattr = c_bridge_removexattr,
	.opendir = c_bridge_opendir,
	.readdir = c_bridge_readdir,
	.releasedir = c_bridge_releasedir,
	.fsyncdir = c_bridge_fsyncdir,
	.init = c_bridge_init,
	.destroy = c_bridge_destroy,
	.access = c_bridge_access,
	.create = c_bridge_create,
	.ftruncate = c_bridge_ftruncate,
	.fgetattr = c_bridge_fgetattr,
	.lock = c_bridge_lock,
	.utimens = c_bridge_utimens,
	.bmap = c_bridge_bmap,
};

int c_bridge_main(int id, int argc, char *argv[]) 
{
	struct c_bridge_user_data user_data = {
		.id = id
	};
	return fuse_main(argc, argv, &c_bridge_ops, &user_data);
}
