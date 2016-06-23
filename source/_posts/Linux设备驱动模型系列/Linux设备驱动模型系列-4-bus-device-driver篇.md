---
title: 'Linux设备驱动模型系列 - 4 bus, device, driver篇'
date: 2016-06-19 23:30:34
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
---

bus, device, driver作为整个系列文章的第四篇，将会介绍Linux设备驱动模型的中层抽象，也就是bus、device、driver.
> 讨论优缺点

# bus
总线(bus)是处理器和一个或者多个设备之间的通道。在设备模型中，所有的设备都通过总线连接。总线既可以是实际物理总线（I2C等）的抽象，也可以是处于Linux设备驱动模型架构需要而虚拟出的”平台总线“。

符合Linux设备驱动模型的**device**和**driver**必须挂载在同一根总线上。

<!--more-->
## bus的抽象结构
总线的抽象数据结构为bus_type
```c
struct bus_type {
    const char      *name;
    const char      *dev_name;
    struct device       *dev_root;
    struct device_attribute *dev_attrs; /* use dev_groups instead */
    const struct attribute_group **bus_groups;
    const struct attribute_group **dev_groups;
    const struct attribute_group **drv_groups;

    int (*match)(struct device *dev, struct device_driver *drv);
    int (*uevent)(struct device *dev, struct kobj_uevent_env *env);
    int (*probe)(struct device *dev);
    int (*remove)(struct device *dev);
    void (*shutdown)(struct device *dev);

    int (*online)(struct device *dev);
    int (*offline)(struct device *dev);

    int (*suspend)(struct device *dev, pm_message_t state);
    int (*resume)(struct device *dev);

    const struct dev_pm_ops *pm;

    const struct iommu_ops *iommu_ops;

    struct subsys_private *p;
    struct lock_class_key lock_key;
};
```
主要的成员介绍如下
* 1 dev_root
* 2 dev_attrs
* 3 bus_groups, dev_groups, drv_groups
* 4 match
* 5 subsys_private

### dev_root
默认parent device?

### dev_attrs
默认挂载在bus下设备的属性？

### bus_groups, dev_groups, drv_groups

## match
对试图挂载到该总线上的device和driver执行的匹配操作。

什么时候回调用？



### subsys_private
该结构用来管理bus, driver, device之间的关系。

```c
struct subsys_private {
	struct kset subsys;
    struct kset *devices_kset;
    struct list_head interfaces;
    struct mutex mutex;

    struct kset *drivers_kset;
    struct klist klist_devices;
    struct klist klist_drivers;
    struct blocking_notifier_head bus_notifier;
    unsigned int drivers_autoprobe:1;
    struct bus_type *bus;

    struct kset glue_dirs;
    struct class *class;
};
```

* kset subsys: 意义是什么？作为一个bus的抽象，其kset是bus_kset。如subsys->name = bus1, 那么将会创建/sys/bus/bus1
* devices_kset: 总线上所有devices的集合
* drivers_kset: 总线上所有drivers的集合
* klist_devices和klist_drivers是devices和drivers的链表
> 什么地方会用到？
* drivers_autoprobe：当注册设备或驱动的时候，是否进行绑定操作
> 什么地方会用到？

## bus的函数

* buses_init
* bus_register

### buses_init
在系列第一篇中，提到了driver_init函数，其中调用了buses_init. 这个函数是系统中所有bus的起源。
```c
	bus_kset = kset_create_and_add("bus", &bus_uevent_ops, NULL);
	system_kset = kset_create_and_add("system", NULL, &devices_kset->kobj);
```
bus_kset是所有bus的源头，将会建立/sys/bus，热插拔操作函数为bus_uevent_ops，当bus有状态变化时，将会通知用户空间uevent消息。
devices_kset是在devices_init中建立的，system_kset的parent是devices_kset，所以将会创建/sys/devices/system。
> 这个文件夹的作用是什么?

bus_uevent_ops中只有一个filter函数，将会对需要提交的消息进行过滤，过滤条件参考代码：
```c
static int bus_uevent_filter(struct kset *kset, struct kobject *kobj)
{
    struct kobj_type *ktype = get_ktype(kobj);

    if (ktype == &bus_ktype)
        return 1;
    return 0;
}
```
表示如果要求发送uevent消息的Kobj的kobj_type类型不是bus_type，那么将不会发送到用户空间。
那么为什么要这么规定呢？bus_type中是什么？

```c
static struct kobj_type bus_ktype = {
	.sysfs_ops  = &bus_sysfs_ops,
	.release    = bus_release,
};
```

### bus_register
* 初始化priv结构体，建立关系网
	* 设置subsys.kobj.kset = bus_kset
	* 设置subsys.kobj.ktype = &bus_ktype
	* 设置drivers_autoprobe = 1
	* kset_register(priv->subsys)
* 创建uevent属性文件，作用是输入对应的kobject_action type，可以用来模拟事件
* 创建devices kset, 同时/sys/bus/bus_name/devices and /sys/bus/bus_name/drivers
* 初始化drivers and devices链表
* add_probe_files，创建probe和autoprobe属性文件，probe文件用来输入device名字进行手动配对，autoprobe用来设置autoprobe变量
* bus_add_groups

以上，sysfs下的总线基本框架结构就全都有了。

> attribute和show, store的关系
比如bus_attribute结构体
```c
struct bus_attribute {
	struct attribute attr;
	ssize_t (*show)(struct bus_type *bus, char *buf);
	ssize_t (*store)(struct bus_type *bus, const char *buf, size_t count);
}

struct attribute {
	const char *name;
	umode_t mode;
}
```
属性是通过sysfs_create_file创建，但是其参数只有attribute，而没有show和store。那么文件是如何和操作函数联系起来的呢？

在3.0以前的版本中，sysfs_open_file函数会根据file找到对应sysfs_dirent, 再根据sysfs_dirent找到kobj, 将kobj->ktype->sysfs_ops赋值给打开的属性文件。
这时候，对文件的write和open实质上是sysfs_ops中的store和show。sysfs_ops决定于kobj_type。

在3.0之后的版本中，由于kernfs从sysfs中分离出来，暂时还不知道具体的过程。

# device和driver的绑定
每个device应该有对应的driver，将device和driver联系起来的过程叫做绑定。在Linux设备驱动模型中，通过总线实现绑定(所有的device和driver都挂载在bus下)。那么绑定的过程是如何发生的呢？

既然绑定是双方共同的行为，那么双方都有触发绑定的权利。在device端，device_reigster向bus注册设备时会触发绑定。在driver端，driver_register向bus注册驱动时会触发绑定。具体的绑定代码分析，留到后面的deivce和driver章节。

# device
在Linux系统中，所有的对象都被抽象为kobject.
在Linux系统中，所有的硬件设备被抽象为device。其结构如下：
```c
struct device {
    struct device       *parent;

    struct device_private   *p;

    struct kobject kobj;
    const char      *init_name; /* initial name of the device */
    struct device_type  *type;

    struct mutex        mutex;  /* mutex to synchronize calls to
                     * its driver.
                     */

    struct bus_type *bus;       /* type of bus device is on */
    struct device_driver *driver;   /* which driver has allocated this
                       device */
    void        *platform_data; /* Platform specific data, device
                       core doesn't touch it */
    struct dev_pm_info  power;
    struct dev_power_domain *pwr_domain;

#ifdef CONFIG_NUMA
    int     numa_node;  /* NUMA node this device is close to */
#endif
    u64     *dma_mask;  /* dma mask (if dma'able device) */
    u64     coherent_dma_mask;/* Like dma_mask, but for
                         alloc_coherent mappings as
                         not all hardware supports
                         64 bit addresses for consistent
                         allocations such descriptors. */

    struct device_dma_parameters *dma_parms;

    struct list_head    dma_pools;  /* dma pools (if dma'ble) */

    struct dma_coherent_mem *dma_mem; /* internal for coherent mem
                         override */
    /* arch specific additions */
    struct dev_archdata archdata;

    struct device_node  *of_node; /* associated device tree node */

    dev_t           devt;   /* dev_t, creates the sysfs "dev" */

    spinlock_t      devres_lock;
    struct list_head    devres_head;

    struct klist_node   knode_class;
    struct class        *class;
    const struct attribute_group **groups;  /* optional groups */

    void    (*release)(struct device *dev);
};
```
其中以下成员值得关注
* struct device *parent
> 当前device的父设备，作用是什么？层次关系在kobject中不是已经表明了么？
* struct device_private *p
* struct kobject kobj
* struct device_type *type
* struct bus_type *bus
* struct device_driver *driver
> device对应的driver，没绑定时为NULL
* device_node *of_node
* struct class *class
* struct attribute_grout **groups

## device的相关函数
* devices_init: device系统的初始化
* device_initialize
* device_register
* device_add


### device_init
在driver_init中被调用。
```c
int __init devices_init(void)
{
    devices_kset = kset_create_and_add("devices", &device_uevent_ops, NULL);
    dev_kobj = kobject_create_and_add("dev", NULL);
    sysfs_dev_block_kobj = kobject_create_and_add("block", dev_kobj);
    sysfs_dev_char_kobj = kobject_create_and_add("char", dev_kobj);
}
```
在/sys下创建devices, dev, 在/sys/dev下面创建block和char文件夹。

问题：为什么dev, block, char没有用kset？

### device_initialize
```c
void device_initialize(struct device *dev)
{
    dev->kobj.kset = devices_kset;
    kobject_init(&dev->kobj, &device_ktype);
    INIT_LIST_HEAD(&dev->dma_pools);
    mutex_init(&dev->mutex);
    lockdep_set_novalidate_class(&dev->mutex);
    spin_lock_init(&dev->devres_lock);
    INIT_LIST_HEAD(&dev->devres_head);
    device_pm_init(dev);
    set_dev_node(dev, -1);
}
```
需要注意的是device->kobj的kset是devices_kset，那么该kobj对应的目录将会建立在/sys/devices下面

### device_register
```c
int device_register(struct device *dev)
{
	device_initialize(dev);
	return device_add(dev);
}
```
重点是device_add.

### device_add
位于drivers/base/core.c中，API为
int device_add(struct device *dev)

device_add做了什么？
> 坑，devtmpfs，动态生成设备节点

#### 建立系统硬件拓扑关系图

#### 为dev建立属性文件

#### bus_probe_device
```c
void bus_probe_device(struct device *dev)
{
	...
	if (bus->p->drivers_autoprobe) {
		ret = device_attach(dev);
	}
	...
}
```
在autoprobe为1的情况下，执行device_attach.
```c
__device_attach
	__device_match_device	//根据drv->bus->match判断是否匹配
	driver_probe_device
		really_probe
			//如果有dev->bus->probe
			dev->bus->probe
			//如果有drv->probe
			drv->probe
```

#### device_unregister

# driver

从三个结合起来的角度，讨论各个部分的关系和每个部分设计的原因
