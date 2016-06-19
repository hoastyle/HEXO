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
kset实质上来说是kobject的扩展，和kobject最重要的不同就是uevent（热插拔的底层实现）。这里的热插拔可以理解为内核空间发生的时间可以实时的通知用户空间。

层次结构上，其作用和Kobject无区别，只是作为一个普通目录。kset相当于一个kobject容器，该容器内所有的kobject的热插拔都通过kset->uevent函数实现。单独的kobject(没有对应的kset)，将会失去热插拔的特性。

# 中层
## 初始化
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
* [蜗窝科技 同一设备模型](http://www.wowotech.net/sort/device_model)
[Linux设备模型浅析之uevent篇](http://wenku.baidu.com/view/3f08de275901020207409cd4.html)
