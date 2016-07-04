---
title: Char Device Driver in Linux
date: 2016-07-01 00:19:24
categories: [Tech, OS, Linux, Driver]
tags:
	- Linux
	- driver
	- char
	- module
---

# 字符型设备驱动介绍
字符设备主要是给一些传输速率较低，主要用于控制的设备所使用的驱动框架。
如鼠标，键盘，打印机。

# 字符设备驱动基本结构和API
cdev的代码在/fs/char_dev.c中

<!--more-->

## 重要结构
struct cdev
dev_t num
struct file_operations

## 基本API
* cdev_init
> cdev_init(&cdev, &cdev_ops)
* cdev_clloc(void)
* alloc_chrdev_region, 分配设备号
alloc_chrdev_region($num, baseminor, count, char *name)
* cdev_add
* cdev_del
* unregister_chrdev_region()

# 一些值得探讨的问题
* 字符设备驱动适用于速度较慢的，为什么？为什么字符设备适合速度慢的？块设备驱动适合速度快的？
* owner和THIS_MODULE的作用？
* 设备号的分配和释放实现流程
> 通过一个哈希表
* cdev框架背后的实现流程
> 通过哈希表cdev_map
* ioctl
* module_init && module_ext
* /dev目录相关
    * 如何从/dev/node 到 file_operation相应函数
    * /dev和cdev是什么关系？在/dev下面只有block和char设备？

## 设备号的分配和释放实现流程

>设备号的作用是什么？

### 设备号的构成
dev_t，是设备号的类型，无符号整数
```c
//on arm processor，增加可移植性
typedef unsigned int _u32;
//保证和文件中其他类型保证风格一致
typedef _u32 _kernel_dev_t
typedef _kernel_dev_t dev_t
```

dev_t中，高12位是major, 低20位时minor.
相关的宏有MKDEV, MINOR, MAJOR(位于/include/linux/kdev_t.h)，通过移位实现其功能。

其中，major用来定位设备驱动程序，minor用来表示驱动程序所管理的若干设备。

## 设备号的分配和释放
既然设备号需要分配和释放，那么设备号是需要被管理的，其使用状态需要被检测。
检测设备号，需要哪些信息呢？
* major
* minor base
* minor count
另外，需要和cdev结合起来
* cdev

以上，应该是基本的元素。
在Linux中，选择哈希表作为管理设备号的手段。

其中主要的结构是
```c
struct char_device_struct {
    struct char_device_struct *next;
    unsigned int major;
    unsigned int baseminor;
    unsigned int minorct;
    char name[64];
    struct cdev *cdev;
} *chrdevs[CHRDEV_MAJOR_HASH_SIZE];
```
初始化指向该结构的指针数组，大小为255. 通过index = major/255为索引，确认对应的char_device_struct指针。
如果该指针没有被使用，为NULL.
如果被使用，那么将会指向对应的char_device_struct。如果有多个驱动使用：
* major相同，此设备号不冲突，则多个设备驱动以链表设备存在
* major不同，但是index不同，如2和257，则通过插入排序链接到对应的指针上，排序方向是从小到大。

## 字符设备的框架实现
### 字符设备的注册
cdev_add函数负责将字符设备加入系统。

基本原理：
字符设备的管理，同样通过哈希表完成。定义probe指针数组，数组每个指针成员对应major/index相同的设备。cdev_add就是将cdev加入哈希表中。

实现分析：
核心结构体
```c
struct kobj_map {
    struct probe {
        struct probe *next;
        dev_t dev;
        unsigned long range;
        struct module *owner;
        kobj_probe_t *get;
        int (*lock)(dev_t, void *);
        //为什么不是cdev,应为不仅仅cdev用到这个模型
        void *data;
    } *probes[255];
    struct mutex *lock;
};
```
其中，定义了大小为255，类型为struct probe的数组指针。在字符设备框架中，每个probe对应一个字符设备（还是驱动？）。

## 字符设备和用户空间的交互
> 字符设备和用户空间的交互，通过设备文件来实现。
> 根据设备类型、设备号建立设备文件，其根本是建立一个inode结构体，inode->fops根据设备类型初始化为不同的fops，inode->rdev初始化为设备号。
> 而打开设备文件的过程，就是将字符设备和设备文件相互联系的过程。open最后会调用到 chrdev_open，其中会根据设备号查找到对应的cdev，并覆盖flip中的fops, 然后调用cdev->open函数。

以上的过程中，省略了很多细节，下面详细说明。

### 建立设备节点
对于字符设备，设备节点往往是用户自己在用户空间生成。
如example中的hello char device，其主设备号为246， 此设备号为0。
`$ mknod /dev/chr_dev c 246 0`

分析上面的这个命令，首先可以通过strace命令track mknod命令究竟做了什么。
执行`sudo strace mknod /dev/chr_dev c 246 0`
该命令来自于busybox/coreutils/mknod.c
其中，和讨论内容有关的部分如下：
```c
execve("/bin/mknod", ["mknod", "/dev/chr_dev", "c", "246", "0"], [/* 25 vars */]) = 0
...
mknod("/dev/chr_dev", S_IFCHR|0666, makedev(246, 0)) = 0
```
可见mknod命令最终通过mknod函数实现。mknod的定义：
```c
SYSCALL_DEFINE3(mknod, const char __user *, filename, umode_t, mode, unsigned, dev)
{
    return sys_mknodat(AT_FDCWD, filename, mode, dev);
}
```
而sys_mknodat的定义如下：
```c
<fs/namei.c>
SYSCALL_DEFINE4(mknodat, int, dfd, const char __user *, filename, umode_t, mode,
        unsigned, dev)
{
    struct dentry *dentry;
    struct path path;
    int error;
    unsigned int lookup_flags = 0;

    error = may_mknod(mode);
    if (error)
        return error;
retry:
    dentry = user_path_create(dfd, filename, &path, lookup_flags);
    if (IS_ERR(dentry))
        return PTR_ERR(dentry);

    if (!IS_POSIXACL(path.dentry->d_inode))
        mode &= ~current_umask();
    error = security_path_mknod(&path, dentry, mode, dev);
    if (error)
        goto out;
    switch (mode & S_IFMT) {
        case 0: case S_IFREG:
            error = vfs_create(path.dentry->d_inode,dentry,mode,true);
            break;
        case S_IFCHR: case S_IFBLK:
            error = vfs_mknod(path.dentry->d_inode,dentry,mode,
                    new_decode_dev(dev));
            break;
        case S_IFIFO: case S_IFSOCK:
            error = vfs_mknod(path.dentry->d_inode,dentry,mode,0);
            break;
    }
out:
    done_path_create(&path, dentry);
    if (retry_estale(error, lookup_flags)) {
        lookup_flags |= LOOKUP_REVAL;
        goto retry;
    }
    return error;
}
```
其中涉及到文件系统的暂时略去，sys_mknodat通过/dev目录上挂载的文件系统接口为/dev/chr_dev生成了一个新的inode，并将设备号对其进行初始化。

具体过程如下：
假设根文件系统ext3
* 从根目录下寻找dev目录所对应的inode
* 通过dev的inode的结构中的i_op成员指针所指向的ext3_dir_inode_operations，调用其中的mknod方法，会导致ext3_mknod函数被调用
* 在ext3_mknod中调用init_special_inode函数，会根据节点类型对i_fop进行不同的初始化。
    * char: inode->i_fop = &def_chr_ops, inode->rdev = rdev;(设备号)
    * blk: inode->i_fop = &def_blk_ops
    * 另外还有fifo和socket(略过)

以上，是建立/dev/node的过程，那么node是如何和对应的cdev建立联系的呢？

### 连接设备结点和cdev
操作结点之前，需要通过open打开设备文件。
`int open(const char *filename, int flags, mode_t mode)`

系统会从用户空间的open调用到file_operations中的open函数。
用户空间open的返回值是int fd, 而在file_operations中的函数第一个参数是struct file *flip，而真正的重点是file_operations，被存储在cdev->fops中，所以，将上述三个部分联系起来是重点。

inode, fd, file之间的关系：
Linux文件系统中，每个文件都有一个inode与之相对应。Linux进程会为自己打开的文件维护一个文件描述表，其类型是struct file，通过动态分配的fd进行索引。

在open之后，fd, flip, fops已经各就各位，通过fd可以找到对应的flip，而flip->ops就是cdev->ops，接下来就可以 愉快的玩耍了。

上面说的是open, 接下来说说close函数。

close
```c
close(fd)
    -> sys_close(fd)
        filp = current->files->fdt->fd[fd]
        filp_close(filp, files)
            //对块设备很重要，字符设备无需使用缓存机制
            filp->fops->flush
            //如果count == 0，则调用release函数
            fput(file)
```

以上是字符设备操作的相关基本流程。

## 字符设备驱动中的一些高级操作
### ioctl
#### ioctl的使用方式

#### ioctl调用流程

#### ioctl的命令



