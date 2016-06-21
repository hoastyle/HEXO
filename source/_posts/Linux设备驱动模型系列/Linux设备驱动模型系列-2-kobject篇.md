---
title: Linux设备驱动模型系列 - 2 kobject篇
date: 2016-06-19 23:29:30
categories: [Tech, OS, Linux, Driver, Framework, Linux设备驱动模型]
tags:
---
<blockquote class="blockquote-center"><font size="5">**kobject和kset是整个设备驱动模型的基石。**</font></blockquote>

# kobject

每个kobject对应sysfs中的一个目录，sysfs中的层次结构通过kobject之间的联系确定。

## kobject的意义和存在形式
kobject最早是用来作为引用计数，用来跟踪被嵌入对象（参考kobject的使用方式）生命周期。
而随着kernel的不断升级，kobject承担的任务越来越多。

* 被嵌入对象的引用计数
* sysfs node
* 通过kobject将设备模型实现为一个多层次的体系结构
* 热插拔时间处理（有待商榷，应该和kset有关系吧）

kobject的三个相关文件，分别是
```c
include/linux/kobject.h
lib/kobject.c
Documentation/kobject.txt
```

kobject定义于include/linux/kobject.h中
```c
struct kobject {
    const char      *name;
    struct list_head    entry;
    struct kobject      *parent;
    struct kset     *kset;
    struct kobj_type    *ktype;
    struct sysfs_dirent *sd;
    struct kref     kref;
    unsigned int state_initialized:1;
    unsigned int state_in_sysfs:1;
    unsigned int state_add_uevent_sent:1;
    unsigned int state_remove_uevent_sent:1;
    unsigned int uevent_suppress:1;
};
```

* name: 内核对象的名字，对应的sysfs节点名字也是该name
* entry：可以参考kobject_add一节，entry将作为链表单元，将Kobject加入所属的kset链表中
* parent: 该kobject的上层对象，构建kobject之间的层次化关系
* kset: kobject所属的kset对象，kset可以理解为subsystem
* kobj_type: 该Kobject的sysfs文件系统相关的操作和属性，参考kobject type一节
* sd: 对应目录项的实例
* kref: 引用计数值，追踪被嵌入对象的声明周期，被初始化为1
* state bit field: 

问题：
* 1 kset中提到的subsystem和/dev/char/xx/subsystem是同一个吗？该subsystem是如何建立的？

## kobject的使用方式
kobject的常用方式就是嵌在某一对象的数据结构中(类似于list_head的用法)，比如cdev
```c
struct cdev {
    struct kobject kobj;
    struct module *owner;
    const struct file_operations *ops;
    struct list_head list;
    dev_t dev;
    unsigned int count;
};
```
对应这种用法，一定会有通过container_of实现的获取被嵌入对象的地址函数。

# kobject 函数
本节中会列举一些常用函数

* kobject_set_name: 为kobject设置name
* kobject_init
* kobject_add
* kobject_init_and_add: 合并kobject_init和kobject_add
* kobject_create
* kobject_create_and_add
* kobj_del 

## kobject_init
```c
static void kobject_init_internal(struct kobject *kobj)
{
    if (!kobj)
        return;
    //initialize kref to 1
    kref_init(&kobj->kref);
    INIT_LIST_HEAD(&kobj->entry);
    //initialize state
    kobj->state_in_sysfs = 0;
    kobj->state_add_uevent_sent = 0;
    kobj->state_remove_uevent_sent = 0;
    kobj->state_initialized = 1;
}

void kobject_init(struct kobject *kobj, struct kobj_type *ktype)
{
...
    kobject_init_internal(kobj);
    kobj->ktype = ktype;
    return;

error:
    printk(KERN_ERR "kobject (%p): %s\n", kobj, err_str);
    dump_stack();
}
EXPORT_SYMBOL(kobject_init);
```
> 坑，EXPORT_SYMBOL原理

kobject_init主要做了
* 初始化Kref和list_head entry
* 初始化kobject->state bit field
* 初始化ktype

## kobject_add
```c
int kobject_add(struct kobject *kobj, struct kobject *parent, const char *fmt, ...)
{
	...
	etval = kobject_add_varg(kobj, parent, fmt, args);
	...
}

static int kobject_add_varg(struct kobject *kobj, struct kobject *parent, const char *fmt, va_list vargs)
{
	etval = kobject_set_name_vargs(kobj, fmt, vargs);
	kobj->parent = parent;
	kobject_add_internal(kobj);
}
```
以上做了kobj->parent = parent，设置了两个kobject之间的层次关系，重要的部分在kobject_add_internal(kobj)中。
```c
static int kobject_add_internal(struct kobject *kobj)
{
	//这里为什么将parent kobject的kref + 1
	parent = kobject_get(kobj->parent);

	if (kobj->kset) {
		if (!parent)
			parent = kobject_get(&kobj->kset->kobj);
		kobj_kset_join(kobj);
		kobj->parent = parent;
	}

	error = create_dir(kobj);

	kobj->state_in_sysfs = 1;
}
```
上部分代码其实主要做了四件事

* 1 增加parent计数
* 2 为kobj->parent赋值
* 3 create sysfs dir for kobject
* 4 设置state_in_sfsfs为1表示sysfs中已经添加好

关于2， 如果有parent参数传入，那么kobject->parent = parent. 如果没有，那么kobject->parent只能依靠kset->kobject，如果kset存在，kset->kobj就是kobject的parent，并且将kobject加入kset的kobject链表中。
**这里就解释了kobject->entry的作用，作为链表单位，将会加入kset的链表中**

关于3，create_dir位于lib/kobject.c中，主要是
```c
sysfs_create_dir
populate_dir
```
在sysfs_create_dir中，如果kobject有parent，则根据kobj->parent, kobj创建sysfs_dirent，并赋值给kobj->sd.
sysfs中具体如何新建sysfs_dirent，会在[Linux设备驱动模型系列-5-sysfs篇.md]()中详细说明。

在populate_dir函数中，将根据kobject的ktype->attribute建立sysfs文件。
首先，ktype是这样的：
```c
struct kobj_type {
    void (*release)(struct kobject *kobj);
    const struct sysfs_ops *sysfs_ops;
    struct attribute **default_attrs;
    const struct kobj_ns_type_operations *(*child_ns_type)(struct kobject *kobj);
    const void *(*namespace)(struct kobject *kobj);
};
```
> 坑，kobj_type需要解释
而populate_dir是这样的：
```c
static int populate_dir(struct kobject *kobj)
{
	struct kobj_type *t = get_ktype(kobj);
	...
	if (t && t->default_attrs) {
		for (i = 0; (attr = t->default_attrs[i]) != NULL; i++) {
			error = sysfs_create_file(kobj, attr);
	...
		}
	}
}
```
将根据attr在kobj->sd对应的sfsfs目录下建立属性文件。
> 坑，这里建立的是属性文件吗？
> 坑，详细的分析attribute和属性文件的关系。

## kobject_create
主要部分是Kobject_init，而区别在于采用默认kobj_type，也就是dynamic_kobj_ktype.
```
static struct kobj_type dynamic_kobj_ktype = {
	.release    = dynamic_kobj_release,
	.sysfs_ops  = &kobj_sysfs_ops,
};
```

## kobject_del
直接上代码
```c
void kobject_del(struct kobject *kobj)
{
    if (!kobj)
        return;

    sysfs_remove_dir(kobj);
    kobj->state_in_sysfs = 0;
    kobj_kset_leave(kobj);
    kobject_put(kobj->parent);
    kobj->parent = NULL;
}
```
> 坑，为什么没有kfree(kobject)，为什么要kobject_put(parent)?
> 对应于kobject_add_internal，为什么将kobject_get(parent)

## kobject type
```c
struct kobj_type {
    void (*release)(struct kobject *kobj);
    const struct sysfs_ops *sysfs_ops;
    struct attribute **default_attrs;
    const struct kobj_ns_type_operations *(*child_ns_type)(struct kobject *kobj);
    const void *(*namespace)(struct kobject *kobj);
};
```
在通过kobject_init初始化kobject时，会传入kobj_type函数。


# kobject和sysfs的关系

# kobject和kset的关系

# Example Code
上述只是讲述原理，因为是Linux设备驱动模型的基础部分，所以一般场合也很难看到其应用。
应该有两个Example code, 一个是内核中的code，另外一部分是example code, 用来做更加直观的展示用。
