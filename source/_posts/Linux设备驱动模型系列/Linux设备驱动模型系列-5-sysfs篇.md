---
title: Linux设备驱动模型系列 - 5 sysfs篇
date: 2016-06-19 23:30:53
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
---

# 参考文档
* Documentation/filesystems/sysfs.txt
* Documentation/sysfs-rules.txt
* Linux那些事儿之我是USB

# 什么是sysfs
sysfs是一个基于ram的文件系统。sysfs根据kobject框架，将内核中的数据结构、属性文件、相互关系通过文件系统的方式表现出来，并提供了内核空间和用户空间交互的一种方式。

我们讨论一个文件系统，首先要知道文件系统的信息来源在什么地方。如使用mout挂载一个分区
`mount -t vfat /dev/hda2 /mnt/c`
可以知道挂载在/mnt/c下的是一个vfat类型的文件系统，其信息来源是硬盘的第二个分区。而sysfs的挂载过程如下所示：
`mount -t sysfs sysfs /sys`
上述命令看起来没法理解，其实因为sysfs是一个虚拟文件系统，没有实际存放文件的戒指。其信息来源是设备基于kobject构成的设备层次。
<!--more-->

用户空间如何调用到属性文件的过程(show 和 store)

* sysfs_init_inode
* sysfs_create_link
* sysfs_create_file

seperate out kernfs from sysfs
