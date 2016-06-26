---
title: 'Linux设备驱动模型系列 - 4 bus, device, driver篇'
date: 2016-06-19 23:30:34
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
---

bus, device, driver作为整个系列文章的第四篇，将会介绍Linux设备驱动模型的中层抽象，也就是bus、device、driver.

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
* dev_root
* dev_attrs
* bus_groups, dev_groups, drv_groups
* match
* subsys_private

### dev_root
默认parent device?

### dev_attrs
默认挂载在bus下设备的属性？

### bus_groups, dev_groups, drv_groups

### match
对试图挂载到该总线上的device和driver执行的匹配操作。

什么时候回调用？

### subsys_private
适用于bus和class.
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

### bus的起源buses_init
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
其中以下成员需要关注
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
		really_probe //如果有dev->bus->probe
			dev->bus->probe
			//如果有drv->probe
			drv->probe
```

# driver
## driver数据结构
driver在内核中的数据结构如下：
```c
struct device_driver {
    const char      *name;
    struct bus_type     *bus;

    struct module       *owner;
    const char      *mod_name;  /* used for built-in modules */

    bool suppress_bind_attrs;   /* disables bind/unbind via sysfs */

    const struct of_device_id   *of_match_table;
    const struct acpi_device_id *acpi_match_table;

    int (*probe) (struct device *dev);
    int (*remove) (struct device *dev);
    void (*shutdown) (struct device *dev);
    int (*suspend) (struct device *dev, pm_message_t state);
    int (*resume) (struct device *dev);
    const struct attribute_group **groups;

    const struct dev_pm_ops *pm;

    struct driver_private *p;
};
```

分析其中的四个成员
* struct module *owner
驱动所在的内核模块，该部分在哪里会用到？作用是什么
* const struct of_device_id *of_match_table
* probe
驱动程序的探测函数，当bus中将驱动和对应的设备绑定时(bus_probe_device)，内核会首先调用bus中的probe函数，如果bus没有实现自己的probe函数，内核会调用驱动程序的probe函数。
* struct driver_private *p

## driver的函数
通过driver_reigster向系统注册驱动，其核心代码如下：
```c
<driver/base/driver.c>

int driver_register(struct device_driver *drv)
{
	other = driver_find(drv->name, drv->bus);
	ret = bus_add_driver(drv);
	ret = driver_add_groups(drv, drv->groups);
	object_uevent(&drv->p->kobj, KOBJ_ADD);
}
```

driver_find用来确认driver是否在系统中注册过，通过Bus指名查找的总线，如果成功返回指针，否则返回0.
如果驱动没有被注册，那么通过bus_add_driver(drv)向系统注册。

```c
int bus_add_driver(struct device_driver *drv)
{
    struct bus_type *bus;
    struct driver_private *priv;
    int error = 0;

    bus = bus_get(drv->bus);
    if (!bus)
        return -EINVAL;

    priv = kzalloc(sizeof(*priv), GFP_KERNEL);
	//driver对应的devices?
    klist_init(&priv->klist_devices, NULL, NULL);
    priv->driver = drv;
    drv->p = priv;
	//driver kobj对应的kset是bus的drivers_kset
    priv->kobj.kset = bus->p->drivers_kset;
	//建立的sys目录在/sys/bus/bus_name/drivers/drv->name
    error = kobject_init_and_add(&priv->kobj, &driver_ktype, NULL,
                     "%s", drv->name);

	//将device_driver->driver_private->knode_bus作为节点加入bus->p->klist_drivers中
    klist_add_tail(&priv->knode_bus, &bus->p->klist_drivers);
	//如果drivers_autoprobe置1，则通过driver_attach将driver和device绑定
    if (drv->bus->p->drivers_autoprobe) {
        error = driver_attach(drv);
        if (error)
            goto out_unregister;
    }
    module_add_driver(drv->owner, drv);

    error = driver_create_file(drv, &driver_attr_uevent);
    error = driver_add_groups(drv, bus->drv_groups);
	...
}
```

driver_attach函数用来匹配device和driver
```c
int driver_attach(struct device_driver *drv)
{
    return bus_for_each_dev(drv->bus, NULL, drv, __driver_attach);
}

int bus_for_each_dev(struct bus_type *bus, struct device *start,
             void *data, int (*fn)(struct device *, void *))
{
    struct klist_iter i;
    struct device *dev;
    int error = 0;

    klist_iter_init_node(&bus->p->klist_devices, &i,
                 (start ? &start->p->knode_bus : NULL));
    while ((dev = next_device(&i)) && !error)
        error = fn(dev, data);
    klist_iter_exit(&i);
    return error;
}


static int __driver_attach(struct device *dev, void *data)
{
    struct device_driver *drv = data;

    if (!driver_match_device(drv, dev))
        return 0;

    if (dev->parent)    /* Needed for USB */
        device_lock(dev->parent);
    device_lock(dev);
	//实际的绑定函数
    if (!dev->driver)
        driver_probe_device(drv, dev);
    device_unlock(dev);
    if (dev->parent)
        device_unlock(dev->parent);

    return 0;
}
```

在device_add函数中，会通过bus_probe_device调用device_attach函数，而在driver_register中，经过层层调用最后会调用到driver_attach函数。这两个函数最后都会调用really_probe函数。

而在really_probe函数中，如果bus有probe函数，会调用dev->bus->probe。如果bus没有probe，会调用driver的probe函数。

# class
class不同于bus/device/driver，是完全抽象出来的概念。常见的有block, tty, input等。

## class example
class_simple example from ldd3

以input子系统为例。

## class的起源
通过classes_init创建了/sys/class目录(kset_create_and_add)，对应的内核对象为class_kset，所谓系统中所有class内核对象的顶层kset.

## class
```c
struct class {
      const char      *name;
      struct module       *owner;

      struct class_attribute      *class_attrs;
      const struct attribute_group    **dev_groups;
      struct kobject          *dev_kobj;

      int (*dev_uevent)(struct device *dev, struct kobj_uevent_env *env);
      char *(*devnode)(struct device *dev, umode_t *mode);

      void (*class_release)(struct class *class);
      void (*dev_release)(struct device *dev);

      int (*suspend)(struct device *dev, pm_message_t state);
      int (*resume)(struct device *dev);

      const struct kobj_ns_type_operations *ns_type;
      const void *(*namespace)(struct device *dev);

      const struct dev_pm_ops *pm;

      struct subsys_private *p;
  };
```
* owner
* class_attrs
* dev_groups
* subsys_private *p

## class和系统的关系 
和class以及系统相关的函数主要是以下几个
* class注册
    * class_create
    * class_register
* device_create

### class_create && class_register
```c
class_register(class)
    __class_register(class, &__key)

class_create(owner, name)
    __class_create(owner, name, &__key)
        class->name = name;
        class->owner = owner;
        class->release = class_release;

        __class_register(class, &__key)            
```
这两个函数都调用了__class_register
```c
int __class_register(struct class *cls, struct lock_class_key *key)
{
    struct subsys_private *cp;

    cp = kzalloc(sizeof(*cp), GFP_KERNEL);
    klist_init(&cp->klist_devices, klist_class_dev_get, klist_class_dev_put);
    INIT_LIST_HEAD(&cp->interfaces);
    kset_init(&cp->glue_dirs);
    __mutex_init(&cp->mutex, "subsys mutex", key);
    error = kobject_set_name(&cp->subsys.kobj, "%s", cls->name);

    /* set the default /sys/dev directory for devices of this class */
    if (!cls->dev_kobj)
        cls->dev_kobj = sysfs_dev_char_kobj;

    cp->subsys.kobj.kset = class_kset;
    cp->subsys.kobj.ktype = &class_ktype;
    cp->class = cls;
    cls->p = cp;

    error = kset_register(&cp->subsys);
    error = add_class_attrs(class_get(cls));
}
```
目录对应的kobj_type就是class_ktype，也就决定了对该目录的操作最后会调用到class_ktype中的sysfs_ops.
```c
static ssize_t class_attr_show(struct kobject *kobj, struct attribute *attr,
                   char *buf)
{
    struct class_attribute *class_attr = to_class_attr(attr);
    struct subsys_private *cp = to_subsys_private(kobj);
    ssize_t ret = -EIO;

    if (class_attr->show)
        ret = class_attr->show(cp->class, class_attr, buf);
    return ret;
}

static ssize_t class_attr_store(struct kobject *kobj, struct attribute *attr,
                const char *buf, size_t count)
{
    struct class_attribute *class_attr = to_class_attr(attr);
    struct subsys_private *cp = to_subsys_private(kobj);
    ssize_t ret = -EIO;

    if (class_attr->store)
        ret = class_attr->store(cp->class, class_attr, buf, count);
    return ret;
}

static const struct sysfs_ops class_sysfs_ops = {
    .show      = class_attr_show,
    .store     = class_attr_store,
};

static struct kobj_type class_ktype = {
    .sysfs_ops  = &class_sysfs_ops,
    .release    = class_release,
    .child_ns_type  = class_child_ns_type,
};
```
在class对应的sysfs_ops中，show最后会调用class_attribute->show, store会调用class_attribute->store.
cp->subsys通过kset_register加入到系统中，因为subsys.kobj.kset = class_kset，所以对应的目录是/sys/class/cls->name.
最后通过add_class_attrs添加目录下的属性文件，其属性文件通过class->class_attrs指定。

以上是创建class的过程。

## 如何创建一个class?

# 属性文件
属性文件框架的核心是attribute以及sysfs_create_file.

attribute作为嵌入式的结构被嵌入各式各样的xxx_attribute结构体中，xxx_attribute中包含了对应的xxx_show和xxx_store函数。
sysfs_create_file(kobj, attr)会根据kobj确认path，根据attr建立文件。
那么属性文件对应的操作如何确定？
这就需要kobj_type的帮助，在kobj_type->sysfs_ops中的show和store函数中，会通过attr找到被嵌入的xxx_attribute结构体，然后调用相应的show和store函数。

## bus_attribute
```c
struct attribute {
    const char      *name;
    umode_t         mode;
};

struct bus_attribute {
    struct attribute    attr;
    ssize_t (*show)(struct bus_type *bus, char *buf);
    ssize_t (*store)(struct bus_type *bus, const char *buf, size_t count);
};
```

该结构体通过BUS_ATTR(_name, _mode, _show, _store)构建，会初始化结构为bus_attribute的bus_attr_name的变量。
并通过bus_create_file建立属性文件。对于bus来说，属性文件的目录层级通过bus_type决定。
```c
int bus_create_file(struct bus_type *bus, struct bus_attribute *attr)
{
    int error;
    if (bus_get(bus)) {
        error = sysfs_create_file(&bus->p->subsys.kobj, &attr->attr);
        bus_put(bus);
    } else
        error = -EINVAL;
    return error;
}
```
其文件对应的操作方式由bus_ktype中的bus_sysfs_ops决定：
```c
static ssize_t bus_attr_show(struct kobject *kobj, struct attribute *attr,
                 char *buf)
{
    struct bus_attribute *bus_attr = to_bus_attr(attr);
    struct subsys_private *subsys_priv = to_subsys_private(kobj);
    ssize_t ret = 0;

    if (bus_attr->show)
        ret = bus_attr->show(subsys_priv->bus, buf);
    return ret;
}

static ssize_t bus_attr_store(struct kobject *kobj, struct attribute *attr,
                  const char *buf, size_t count)
{
    struct bus_attribute *bus_attr = to_bus_attr(attr);
    struct subsys_private *subsys_priv = to_subsys_private(kobj);
    ssize_t ret = 0;

    if (bus_attr->store)
        ret = bus_attr->store(subsys_priv->bus, buf, count);
    return ret;
}

static const struct sysfs_ops bus_sysfs_ops = {
    .show   = bus_attr_show,
    .store  = bus_attr_store,
};

static struct kobj_type bus_ktype = {
    .sysfs_ops  = &bus_sysfs_ops,
    .release    = bus_release,
};
```

## device_attribute
## driver_attribute
以上两部分和bus_attribute相似，就略过了。

## attribute_group
attribute_group的作用就是将多个attr放在一个group中，方便管理。

以i2c为例
```c
<driver/i2c/i2c-core.c>

static struct attribute *i2c_dev_attrs[] = {
    &dev_attr_name.attr,
    /* modalias helps coldplug:  modprobe $(cat .../modalias) */
    &dev_attr_modalias.attr,
    NULL
};
//生成i2c_dev_groups
ATTRIBUTE_GROUPS(i2c_dev);

static struct device_type i2c_client_type = {
    .groups     = i2c_dev_groups,
    .uevent     = i2c_device_uevent,
    .release    = i2c_client_dev_release,
};
```
其中ATTRIBUTE_GROUPS在include/linux/sysfs.h中定义
```c
#define ATTRIBUTE_GROUPS(_name)                 \
static const struct attribute_group _name##_group = {       \
    .attrs = _name##_attrs,                 \
};                              \
__ATTRIBUTE_GROUPS(_name)
```
整个device_type会赋值给device.type，然后device_register会生成属性文件。

如果group赋值给class->dev_groups或者device_type->groups或者dev->groups, 那么将在bus_add_device中通过device_register->device_add->device_add_attrs中

```c
<drivers/base/core.c>

static int device_add_attrs(struct device *dev)
{
    struct class *class = dev->class;
    const struct device_type *type = dev->type;
    int error;

    error = device_add_groups(dev, class->dev_groups);

    error = device_add_groups(dev, type->groups);

    error = device_add_groups(dev, dev->groups);
	...
}
```

## 默认属性文件
* uevent
* probe
* autoprobe

### uevent属性文件
该部分的实现在driver/base/core.c中。
uevent的读取：会输出uevent env
uevent的写入：会根据写入的action，引起kobject_uevent的操作

### probe 和 autoprobe
该部分你的实现在driver/base/bus.c中。
```c
static BUS_ATTR(drivers_probe, S_IWUSR, NULL, store_drivers_probe);
static BUS_ATTR(drivers_autoprobe, S_IWUSR | S_IRUGO,
        show_drivers_autoprobe, store_drivers_autoprobe);
```
autoprobe文件用来改变autoprobe变量的值。
probe文件是只写，用来手动启动一次probe.
