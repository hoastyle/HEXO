---
title: Linux设备驱动模型系列 - 3 kset篇
date: 2016-06-19 23:29:52
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
---

# kset
究竟kset是什么？为什么需要kset？
这是我在最初看Linux设备驱动模型的时候，最困惑的问题。

概括的说，kset是相似类型的kobject的集合，也就是相似类型kobject的容器（这里的相同类型是什么意思？）。
Kset会为挂在下面的kobject提供一些共有的属性文件，并且使用相同的热插拔函数。

```c
struct kset {
    struct list_head list;
    spinlock_t list_lock;
    struct kobject kobj;
    const struct kset_uevent_ops *uevent_ops;
};
```
<!--more-->

* list: 子kobject的链表头，所有的子kobject都会都过entry链表加入该链表
* kobj: kset的kobj，子kobject的parent kobject
* uevent_ops: 所有子kobject的uevent_ops

# kset的函数
kset有以下这些函数

* kset_init
* kset_register
* kset_create_and_add
* kset_unregister

## kset_register
```c
int kset_register(struct kset *k)
{
	kset_init(k);
	kobject_add_internal(&k->kobj);
	kobject_uevent(&k->kobj, KOBJ_ADD);
}
```
前半部分其实就相当于kobj_init_and_add，将kset添加到系统中，并建立相应的目录。同时初始化kset list_head，用于挂载子Kobject.
另外的部分就是kobject_uevent，这部分将在随后的热插拔一节进行说明。

## kset_create_and_add
```c
struct kset *kset_create_and_add(const char *name,
				const struct kset_uevent_ops *uevent_ops,
				struct kobject *parent_kobj)
{
	...
	kset = kset_create(name, uevent_ops, parent_kobj);
	error = kset_register(kset);
	...
}
```
首先通过kset_create动态创建一个kset
```c
static struct kset *kset_create(const char *name,
                 const struct kset_uevent_ops *uevent_ops,
                 struct kobject *parent_kobj)
{
    struct kset *kset;
    int retval;

    kset = kzalloc(sizeof(*kset), GFP_KERNEL);
    if (!kset)
        return NULL;
    retval = kobject_set_name(&kset->kobj, name);
    if (retval) {
        kfree(kset);
        return NULL;
    }
    kset->uevent_ops = uevent_ops;
    kset->kobj.parent = parent_kobj;

    /*
     * The kobject of this kset will have a type of kset_ktype and belong to
     * no kset itself.  That way we can properly free it when it is
     * finished being used.
     */
    kset->kobj.ktype = &kset_ktype;
    kset->kobj.kset = NULL;

    return kset;
}
```
> 坑，uevent_ops的作用是什么？
在kset_create中，采用的是默认的kobj_type
```c
static struct kobj_type kset_ktype = {
	.sysfs_ops  = &kobj_sysfs_ops,
	.release = kset_release,
};
```
其中kset_release通过kobj获取kset，并free kset.
而kobj_sysfs_ops
```c
/* default kobject attribute operations */
static ssize_t kobj_attr_show(struct kobject *kobj, struct attribute *attr,
                  char *buf)
{
    struct kobj_attribute *kattr;
    ssize_t ret = -EIO;

    kattr = container_of(attr, struct kobj_attribute, attr);
    if (kattr->show)
        ret = kattr->show(kobj, kattr, buf);
    return ret;
}

static ssize_t kobj_attr_store(struct kobject *kobj, struct attribute *attr,
                   const char *buf, size_t count)
{
    struct kobj_attribute *kattr;
    ssize_t ret = -EIO;

    kattr = container_of(attr, struct kobj_attribute, attr);
    if (kattr->store)
        ret = kattr->store(kobj, kattr, buf, count);
    return ret;
}

const struct sysfs_ops kobj_sysfs_ops = {
    .show   = kobj_attr_show,
    .store  = kobj_attr_store,
};
```
kobj_attr_show会执行kobj_attribute->show函数, 同理kobj_attr_store会执行kobj_attribute->store函数。
> 坑，kobj_attribute是什么时候定义的？

## kset_unregister
单纯的给kset的引用值减1，如果减为0，会调用release函数。
应该要和sysfs_remove_file搭配使用.

# 热插拔
硬件 -> kobject_uevent -> 用户空间

## 硬件 -> kobject_uevent
硬件插入到kobject_uevent这一段是如何发生的？
硬件的热插拔会引起中断，而中断函数中会根据硬件事件决定具体的行为，相对于热插拔事件，会添加新的device。
以dw系列的sd控制器为例：
```
static irqreturn_t dw_mci_interrupt(int irq, void *dev_id)
{
	...
	if (pending & SDMMC_INT_CD) {
		mci_writel(host, RINTSTS, SDMMC_INT_CD);
		dw_mci_handle_cd(host);
	}
	...
}
```
而dw_mci_handle_cd函数中会调用mmc_detect_change函数
```c
static void _mmc_detect_change(struct mmc_host *host, unsigned long delay, bool cd_irq)
{
	...
	host->detect_change = 1;
	mmc_schedule_delayed_work(&host->detect, delay);
}
```
host->detect是个delayed_work，其func是mmc_rescan，在mmc_alloc_host中定义。
> 坑，工作队列，又忘了。。。
```c
mmc_rescan
	mmc_rescan_try_reload
//将根据mmc的协议类型，选择不同的attach函数，如果是sd
	mmc_attach_sd
//最后将会调用
	device_add
//其中调用了关键函数kobject_uevent
```
关于device和driver配对的问题在[Linux设备驱动模型系列 - 4 bus, device, driver篇](http://hoastyle.github.io/2016/06/19/Linux%E8%AE%BE%E5%A4%87%E9%A9%B1%E5%8A%A8%E6%A8%A1%E5%9E%8B%E7%B3%BB%E5%88%97/Linux%E8%AE%BE%E5%A4%87%E9%A9%B1%E5%8A%A8%E6%A8%A1%E5%9E%8B%E7%B3%BB%E5%88%97-4-bus-device-driver%E7%AF%87/)中说明。

## kobject_uevent -> 用户空间
uevent的作用是将内核发生的一些事件通知到用户空间，同时运行特定的用户空间程序
* hotplug
* udev
* mdev busybox
以上的程序（大部分是一些脚本）会根据内核空间的事件进行操作，包括新建设备节点等。

由上可以知道，kobject_uevent是内核热插拔机制的入口，入则发送uevent到用户空间。
```c
int kobject_uevent(struct kobject *kobj, enum kobject_action action)
{
    return kobject_uevent_env(kobj, action, NULL);
}
```
action是个枚举型变量，定义如下
```c
enum kobject_action {
    KOBJ_ADD,
    KOBJ_REMOVE,
    KOBJ_CHANGE,
    KOBJ_MOVE,
    KOBJ_ONLINE,
    KOBJ_OFFLINE,
    KOBJ_MAX
};
```
> 坑，该变量的作用？
应该是作为数组索引，对应了action_string，action_string的作用呢？
```c
int kobject_uevent_env(struct kobject *kobj, enum kobject_action action, char *envp_ext[])
{
	//查找所属的kset
	kset = top_kobj->kset;
	//获取uevent_ops
	uevent_ops = kset->uevent_ops;

	//获取uevent_ops之后，依次执行uevent_ops之中的函数
	//filter决定消息是否要发送给用户空间
	uevent_ops->filter(kset, kobj)

	//uevent_ops->name
	//分配并初始化environment buffer
	env = kzalloc(sizeof(struct kobj_uevent_env), GFP_KERNEL);
	
	/* complete object path */
	devpath = kobject_get_path(kobj, GFP_KERNEL);
	
	/* default keys */
	retval = add_uevent_var(env, "ACTION=%s", action_string);
	retval = add_uevent_var(env, "DEVPATH=%s", devpath);
	retval = add_uevent_var(env, "SUBSYSTEM=%s", subsystem);
	
	/* keys passed in from the caller */
	if (envp_ext) {
	    for (i = 0; envp_ext[i]; i++) {
	        retval = add_uevent_var(env, "%s", envp_ext[i]);
	        if (retval)
	            goto exit;
	    }
	}

	//运行uevent_ops->uevent

	//两种通知用户空间的方式
	//* 1 通过netlink方式向用户空间广播当前kset对象的uevent消息	
	//* 2 uevent_helper方式调用call_usermodehelper达到从内核空间运行用户空间进程的目的。
	//该进程的路径由uevent_helper提供，来源于内核的配置宏CONFIG_UEVENT_HELPER_PATH
}
```
