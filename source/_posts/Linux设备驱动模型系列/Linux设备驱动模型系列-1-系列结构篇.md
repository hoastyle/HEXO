---
title: Linux设备驱动模型系列 - 1 系列结构篇
date: 2016-06-19 23:22:09
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
	- Linux
	- driver
	- driver model
---

<blockquote class="blockquote-center">
本系列主要介绍讨论Linux设备驱动模型，该模型是个非常复杂的系统。从上而下，其主要由总线、设备、驱动构成。从下而上，为了实现这些组件间的相互关系，定义了kobject以及kset两个底层的数据结构。以上两种底层数据结构和sysfs相交互，通过sysfs向用户空间展示了各个组件间的相互联系以及层次结构，并且以文件的形式向用户空间提供了简单访问双内核的方法。
</blockquote>

为了更容易理解Linux设备驱动模型，整个系列采用由下而上的方式进行分析。
<!--more-->

# 底层
## kobject
最早期是为了计数，其唯一的成员就是kref.

## kset
kset实质上来说是kobject的扩展，和kobject最大的不同就是uevent(热插拔的底层实现).
> 这里的热插拔可以理解为内核空间发生的时间可以实时的通知用户空间。

层次结构上，其作用和Kobject无区别，只是作为一个普通目录。kset相当于一个kobject容器，该容器内所有的kobject的热插拔都通过kset->uevent函数实现。单独的kobject(没有对应的kset)，将会失去热插拔的特性。

# 中层

中层部分的核心就是三个组件，分别是bus、device、type. 驱动程序员主要接触的就是该部分。
问题：
* 1 那么这部分的优缺点分别是什么？

## 初始化
```c
start_kernel
	rest_init
		kernel_init
			do_basic_setup
				driver_init
```
**坑1，这里应该有篇关于Linux内核启动的文章**
**坑2，Linux启动时间优化**
其中
```c
void __init driver_init(void) {
    /* These are the core pieces */
    devtmpfs_init();
    devices_init();
    buses_init();  
    classes_init();
    firmware_init();
    hypervisor_init();

    /* These are also core pieces, but must come after the
     * core core pieces.
     */
    platform_bus_init();
    system_bus_init();
    cpu_dev_init();
    memory_dev_init();
}
```
driver_init中包含了整个设备模型中用到的所有相关模块的初始化。

这些初始化函数中做了什么？

### devices_init
先看代码
```c
devices_kset = kset_create_and_add("devices", &device_uevent_ops, NULL);
dev_kobj = kobject_create_and_add("dev", NULL);
sysfs_dev_block_kobj = kobject_create_and_add("block", dev_kobj);
sysfs_dev_char_kobj = kobject_create_and_add("char", dev_kobj);
```
代码中
* 创建名为devices的kset，会在sysfs的根目录下建立devices目录，并且其uevent_ops被指定为device_uevent_ops.
* 创建名为dev的kobject, 会在sysfs根目录下建立dev目录。
* 创建名为block和char的kobject，它们的parent kobject是dev kobject，所以对应的目录在dev目录下创建，分别是block和char目录。

而具体的kset_create_and_add和kobject_create_and_add请参考代码以及随后的系列文章。

目前，sys下的目录如下：
sys/devices
sys/dev
sys/dev/block
sys/dev/char

### buses_init 和 classes_init
```c
bus_kset = kset_create_and_add("bus", &bus_uevent_ops, NULL);
class_kset = kset_create_and_add("class", NULL, NULL);
```
由上可知
* 通过buses_init函数，创建了bus kset, 又在sysfs目录下建立了bus目录，bus kset的热插拔操作为bus_uevent_ops.
* 通过classes_init函数，创建了class kset，又在sysfs目录下建立了class目录

问题： 
* 1 class为什么没有热插拔函数？
* 2 device和bus的uevent_ops的区别是什么？为什么有这种区别？

目前，sys下的目录如下：
sys/devices
sys/dev
sys/dev/block
sys/dev/char
sys/bus
sys/class

问题：
* 1 为什么没有driver_init？
* 2 sys/devices 和 sys/dev的关系是什么？

### platform_bus_init
在设备驱动模型建立起来之后，通过bus的相关函数将platform_bus注册进系统中。
这其中涉及到两个部分
* bus
* platform_bus的实现

## bus

## device

## driver

# 上层
## class

## sysfs

## 电源管理

## 热插拔

# 参考

* 深入Linux设备驱动程序内核机制
* Linux设备驱动程序 第三版
* [蜗窝科技 统一设备模型](http://www.wowotech.net/sort/device_model)
* [Linux设备模型浅析之uevent篇](http://wenku.baidu.com/view/3f08de275901020207409cd4.html)
* USB那些事儿

# Linux设备驱动模型系列文章
* [Linux设备驱动模型系列 - 1 系列结构篇]()
* [Linux设备驱动模型系列 - 2 kobject篇]
* [Linux设备驱动模型系列 - 3 kset篇]
* [Linux设备驱动模型系列 - 4 bus device driver篇]()
* [Linux设备驱动模型系列 - 5 sysfs篇]()
