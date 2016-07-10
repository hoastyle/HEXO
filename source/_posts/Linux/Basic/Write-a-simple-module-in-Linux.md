---
title: Write a simple module in Linux
date: 2016-06-28 00:15:57
categories: [Tech, OS, Linux, Driver, Basic]
tags:
	- Linux
	- driver
	- module
	- external
---

<blockquote class="blockquote-center"><font size="5">**编写，编译并安装简单的内核模块**</font></blockquote>

本文主要介绍了以下内容：
* module的简单介绍
* 在Linux中编译module
* Simple driver module example
* what is module?
* module and Linux

> 注意
* 文章中的所有Example都基于ARM架构
* Licence: GPL

# module的简单介绍
module也就是模块，其优点在于可以动态扩展核心部分的功能而无需将整个软件重新编译连接。广义上来说，Windows上动态链接库DLL是一种module. Linux中的共享库so也可以称为module.
而本文中的module，特指Linux内核模块。Linux内核模块可以在系统运行期间动态扩展系统功能而无需重新启动或者无需重新编译整个系统。内核模块的这个特性为Linux内核的开发者提供了很大的便利。

<!--more-->
Linux内核模块以ko的形式存在，可以通过：
`$ insmod test.ko`
`$ rmmod test`
对模块进行加载和卸载。

# 在Linux中编译module
**Kbuild**是Linux kernel所使用的编译系统。为了使modules和编译框架兼容并保证gcc flag的正确性，必须使用kbuild编译module.
Kbuild提供in-tree编译和out-of-tree编译功能。

为了能够简便快捷的编译模块，module的作者除了提供module代码之外，还需要提供一个makefile文件，用户只需要简单的通过"make"命令就可以编译这个模块。

## How to Build External Modules
首先，为了编译一个external module, 必须有一个包含了编译过程中使用的配置文件和头文件的prebuild内核。如果你正在使用的是发行版的内核，那么会有一个包含了上述文件的package.

> 问题1： `make modules_prepare的用法`

### 编译模块的相关命令
编译一个外部模块的命令：
`$ make -C <path_of_kernel_src> M=$PWD`

其中，"-C"的意思是将目录切换到directory. M不是make的选项，而是内核根目录下Makefile使用的变量，表明external module的文件所在目录.

使用正在使用的内核编译external module:
`make -C /lib/modules/'uname -r'/build M=$PWD`

在通过modules_install安装(只是将生成的ko移动到特定的目录下)刚刚编译的external modules
`make -C /lib/modules/'uname -r'/build M=$PWD modules_install`
modules_install会将生成的ko文件拷贝到/lib/modules/$(version)/extra/下，并通过depmod更新模块间的依赖信息modules.dep。
有了该信息，就可以通过`$ modprobe module_name`加载模块。

### Make target in Linux
这里指的target是在编译命令中的target，如下所示：
`make -C &KDIR M=$PWD [target]`

在编译外部模块时，只有以下几个make targets是可用的。

* modules
	和make不带任何target的作用一样。
* modules_install
	安装externel module，默认的位置是/lib/modules/<kernel_release>/extra/，可以通过INSTALL_MOD_PATH指定路径。
* clean
	删除编译过程中所有的文件
* help
	列出external modules可用的targets

### Build Seperate Files
可以编译模块中一个单独的文件。该方法对于kernel, module, external module都适用。

Example: (test.ko, consist of bar.o and baz.o)
```
$ make -C $KDIR M=$PWD bar.o
$ make -C $KDIR M=$PWD baz.o
$ make -C $KDIR M=$PWD test.ko
$ make -C $KDIR M=$PWD /

```

## 为external module创建kbuild file
### 源文件为单个文件
`obj-m := <module_name>.o`
> kbuild将根据module_name.c生成module_name.o，然后link生成module_name.ko.
> 上面这行命令即可以放在Kbuild文件中，也可以放在Makefile中。

### 源文件为多个文件
`obj-m := <module_name>.o`
`<module_name>-y := <src1>.o <src2>.o ...`

更多的用法请参考/Documentation/kbuild/makefiles.txt
以 module 8123.ko为例，包括4个文件
* 8123_if.c
* 8123_if.h
* 8123_pci.c
* 8123_bin.o_shipped

### 共享makefile
External module往往会搭配一个makefile文件，支持“make”命令编译module.

makefile
```c
ifneq ($(KERNELRELEASE),)
# kbuild part of makefile
obj-m  := 8123.o
8123-y := 8123_if.o 8123_pci.o 8123_bin.o

else
# normal makefile
KDIR ?= /lib/modules/`uname -r`/build

default:
	$(MAKE) -C $(KDIR) M=$$PWD

# Module specific targets
genbin:
	echo "X" > 8123_bin.o_shipped

endif
```

这个文件将Kbuild和Makefile合二为一，Kbuild是作为in-tree module编译时使用的命令。
当该module的文件被放到kernel目录下，kernle/Makefile中定义了KERNELRELEASE变量，就会执行前面的两行指令。

在内核中编译模块时，使用`make modules`.

else部分是作为external module的makefile.

### 单独的Kbuild和Makefile
Kbuild
```c
obj-m  := 8123.o
8123-y := 8123_if.o 8123_pci.o 8123_bin.o
```

Makefile
```c
KDIR ?= /lib/modules/`uname -r`/build

default:
    $(MAKE) -C $(KDIR) M=$$PWD

# Module specific targets
genbin:
    echo "X" > 8123_bin.o_shipped
```

现在内核编译系统会先查找Kbuild, 再查找Makefile.

### Binary Blobs

### 生成多个modules
obj-m := foo.o bar.o
foo-y := <foo>
bar-y := <bar>

## include
规则：
* 1 头文件如果只包含模块内部使用的api，那么和源文件放在同一目录就可以了.
* 2 如果头文件需要被kernel的其他部分所引用，那么应该放在include/linux中

例外：
在比较大型的子系统中，有自己的include目录: include，架构相关的头文件同样有自己的目录：arch/$(ARCH)/include

### 头文件的include
当文件中引用include/linux中的头文件时，仅需要
`#include <linux/module.h>`

Kbuild系统将会给gcc添加对应的目录, 所以该目录将会被搜索。

如果是某些特殊的头文件目录，可以通过`ccflags-y或者CFLAGS_<filename>.o`来通知Kbuild系统.

Example, 其中include是头文件所在文件夹，和-I之间没有space
Kbuild
```c
obj-m := 8123.o

ccflags-y := -Iinclude
8123-y := 8123_if.o 8123_pci.o 8123_bin.o
```

## Module Installation
in-tree默认安装在/lib/modules/$(RELEASEKERNEL)/kernel
out-tree默认安装在/lib/modules/$(KERNELRELEASE)extra

### INSTALL_MOD_PATH
`$ make INSTALL_MOD_PATH=/path modules_install`
当前安装目录：/path/lib/modules/$(KERNELRELEASE)/kernel

### INSTALL_MOD_DIR
`$ make INSTALL_MOD_DIR=path modules_install`
当前安装目录：/lib/modules/$(KERNELRELEASE)/path

# Simple driver module example
参考代码：[simple driver](https://github.com/hoastyle/Learn/tree/master/Linux/driver/Exercise/hello/simple)
简单字符设备参考代码：[char driver](https://github.com/hoastyle/Learn/tree/master/Linux/driver/Exercise/hello/char)

其中，选择重要的部分进行说明。

## 模块中的基本头文件
以下三个头文件是必须的
```c
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
```

init.h定义了驱动初始化和退出相关的函数。
module.h定义了模块相关的函数、变量以及宏。
kernel.h定义了经常用到的函数原型以及宏。

## module_init & module_exit
基本上每个Linux驱动中都有module_init和module_exit.

其作用是根据需求添加对应的module初始化函数。
那么为什么不直接加在统一的初始化函数中呢？(在前面的文章中提到过类似的统一初始化函数driver_init)。
通过这种方式，可以分离出统一的初始化函数。新增驱动的初始化函数只需要通过该宏加入系统中即可，而不用每次修改统一的初始化函数，增强了系统的灵活性，可移植性，也使其层次更明晰。并且，通过这种方式，可以灵活的定义驱动初始化的优先级。

module_init定义于module.h中，如下
```c
typedef int (*initcall_t)(void);

#define __define_initcall(fn, id) \
	static initcall_t __initcall_##fd_##id __used \
	__attribute__ ((__section__(".initcall" #id ".init"))) = fn;
#define device_initcall(x) __define_initcall(x, 6)
#define __initcall(x) device_initcall(x)
#define module_init(x) __initcall(x)
```
如module_init(i2c_init)，预处理之后实际上是
```c
static initcall_t __initcall_i2c_init_6 __used __attribute__((__section(".initcall" #id ".init")))` = fn;
```
其含义就是将__initcall_i2c_init_6这个函数定义到.initcall6.init这个段中。
> 坑1， 看gcc section相关文章

而.initcall6.init段定义include/asm-generic/vmlinux.lds.h
```c
#define INIT_CALLS                          \
        VMLINUX_SYMBOL(__initcall_start) = .;           \
        *(.initcallearly.init)                  \
        INIT_CALLS_LEVEL(0)                 \
        INIT_CALLS_LEVEL(1)                 \
        INIT_CALLS_LEVEL(2)                 \
        INIT_CALLS_LEVEL(3)                 \
        INIT_CALLS_LEVEL(4)                 \
        INIT_CALLS_LEVEL(5)                 \
        INIT_CALLS_LEVEL(rootfs)                \
        INIT_CALLS_LEVEL(6)                 \
        INIT_CALLS_LEVEL(7)                 \
        VMLINUX_SYMBOL(__initcall_end) = .;
```
而在arch/arm/kernel/vmlinux.lds.S中，会调用INIT_CALLS
```c
    .init.data : {
#ifndef CONFIG_XIP_KERNEL
        INIT_DATA
#endif
        INIT_SETUP(16)
        INIT_CALLS
        CON_INITCALL
        SECURITY_INITCALL
        INIT_RAM_FS
    }
#ifndef CONFIG_XIP_KERNEL
    .exit.data : {
        ARM_EXIT_KEEP(EXIT_DATA)
    }
#endif
```

initcall分为多个等级，其他的等级定义宏也都在init.h中定义
```c
#define pure_initcall(fn)       __define_initcall(fn, 0)

#define core_initcall(fn)       __define_initcall(fn, 1)
#define core_initcall_sync(fn)      __define_initcall(fn, 1s)
#define postcore_initcall(fn)       __define_initcall(fn, 2)
#define postcore_initcall_sync(fn)  __define_initcall(fn, 2s)
#define arch_initcall(fn)       __define_initcall(fn, 3)
#define arch_initcall_sync(fn)      __define_initcall(fn, 3s)
#define subsys_initcall(fn)     __define_initcall(fn, 4)
#define subsys_initcall_sync(fn)    __define_initcall(fn, 4s)
#define fs_initcall(fn)         __define_initcall(fn, 5)
#define fs_initcall_sync(fn)        __define_initcall(fn, 5s)
#define rootfs_initcall(fn)     __define_initcall(fn, rootfs)
#define device_initcall(fn)     __define_initcall(fn, 6)
#define device_initcall_sync(fn)    __define_initcall(fn, 6s)
#define late_initcall(fn)       __define_initcall(fn, 7)
#define late_initcall_sync(fn)      __define_initcall(fn, 7s)
```

这些初始化函数都会在do_initcalls中调用，其调用先后顺序取决于initcall中的等级，级别越小，调用越早。

而级别如何确定，do_initcalls处于初始化的哪一个部分，将在分析Linux初始化文章中详细说明。
> 坑2， 初始化系列文章

# What is module?
## module的结构
通过上面的example可以编译得到char.ko.
`$ file char.ko`
输出信息
`char.ko: ELF 64-bit LSB  relocatable, x86-64, version 1 (SYSV), BuildID[sha1]=9d786825c5b731e712f3cff0c78ead53b9351692, not stripped`

可以知道module以ELF的格式存在。

ELF的格式
* header: 信息 + 指向section header table
* section: 
* section header table: 指向section

详情参考《程序员的自我修养-链接、装载与库》

## 模块的动态加载和动态卸载
### 动态加载
切入点当然是`insmod char.ko`，可以通过strace追踪该命令究竟做了什么。

分析方法： strace + insmod的实现（busybox/modutils/insmod.c）

insmod -> init_module -> kernel/module.c: sys_init_module
	copy from user
	load_module

### 动态卸载

EXPORT_SYMBOL

# module and Linux

# 参考
* [编写属于你的第一个Linux内核模块](http://blog.jobbole.com/72115/)
* /Documentation/kbuild/module.txt

# Licence
GPL2
