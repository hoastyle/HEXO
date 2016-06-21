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
从硬件到软件


