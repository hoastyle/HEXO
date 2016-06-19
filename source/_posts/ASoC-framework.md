---
title: ASoC framework
date: 2016-05-25 15:08:03
categories: [Tech, OS, Linux, Driver, Audio]
tags:
	- ALSA
	- ASoC
	- linux
	- driver
---

# ASoC Overview
ALSA System on Chip(ASoC) layer 的目的是为嵌入式处理器以及各种codec提供更好的ALSA支持。在ASoC之前，linux已经对SoC audio提供了相应的支持，但是有如下的缺点。

* codec driver 和 cpu 的代码之间耦合性太强，导致难移植以及代码的重复。
* 没有标准的方法处理用户audio相关行为的通知。在移动场景下，相关行为越发频繁，所以需要专门的机制。
> 原来的方案？现在的方案？
* 在原来的架构上，往往不需要考虑省点的问题。但是对于嵌入式设备，这是一个关键点，所以需要有相关的机制。
> DAPM

ASoC就是为了解决上述问题而设计出来的新的架构。其优点如下：

* 独立codec驱动，降低其和cpu的耦合性
* 更方便的配置cpu和codec之间的音频数据接口
* Dynamic Audio Power Management(DAPM)，动态控制功耗
* 降低pop和click, 增加平台相关的控制

<!--more-->

为实现上面提到的种种特性，ASoC将嵌入式音频系统分为三个可以重用的component driver，分别是machine class, platform class, codec class。其中，platform & codec是跨平台的，而machine是板级相关。

# ASoC和ALSA的关系

为了弄清楚ASoC的整个框架，将会从以下两个角度探讨ASoC

* 各个部分之间的关系
* 音频初始化流程以及运行流程

# Component in ASoC
以sc58x 以及 samsung为例，解释其框架结构。

## machine class
> 概述: 是将各个组件绑定成一个"sound card device"，它可以处理平台级别的控制操作以及相关事件。

machine driver的命名往往是platform_codec.c的形式。  
如在sc58x中，sc58x-adau1962.c为adau1962在sc58x上的machine driver.  
在samsung中，smdk_wm8994.c位wm8994在smdk上的machine driver

主要结构：

* snd_soc_card

主要函数：
* snd_soc_register_card

## platform class
> 概述：主要是负责数据的传输，而在音频中都是通过DMA传输数据。所以该部分包括DMA的控制以及{DAI}.

主要结构体：

* snd_soc_platform
* snd_soc_platform_driver

主要函数：

* snd_soc_register_platform

## codec class
> 概述：负责(A/D,D/A)转换，通路控制(音乐播放, fm, ...)，音频信号的处理(放大，格式转换, ...)

主要结构：

* snd_soc_codec
* snd_soc_codec_driver

主要函数：

* snd_soc_register_codec
另外，还有DAI，分为cpu dai和codec dai.   
两种存在方式:
 
* 单独存在  
作为一个platform driver独立存在。  
* (platform & cpu dai) and (codec dai & codec)  
和platform或者codec在同一个platform driver中进行注册和初始化。

## DAI

> 概述：

主要结构：

* snd_soc_dai
* snd_soc_dai_driver
* snd_soc_dai_ops

cpu dai  
cpu dai对应的是cpu测的一个或者几个数字音频接口（i2s & pcm & ...），cpu dai driver的作用是完成cpu测dai的参数配置，使其可以进行数据传输。  

codec dai  

component_list

dai_list

## 代码分析
### machine
旅程从machine driver开始。
以samsung中的smdk_wm8994.c为例，该machine driver作为platform driver挂载在系统中。

对应的，board文件中的初始化函数会定义一个名字和platform driver相同的platform_device，并通过platform_add_devices添加到系统中。

该platform device用于和machine platform driver匹配，匹配后会调用driver中的probe函数。
其调用流程如下：
```c
platform_driver_register
    driver_register
    	bus_add_driver
        	driver_attach
            	bus_for_each_dev
                	__driver_attach
                    	driver_probe_device
                        	really_probe
                            	drv->probe : 这个函数指针就指向我们真正填写的device+driver下的probe)
```
> **注意**
> platform device的添加，其所属的初始化函数的初始化级别是arch_initcall
> 而platform driver的初始化函数的级别是module_init，arch_initcall的级别高于module_init，所以platform_device比driver要先初始化。

当machine以platform driver的形式通过platform_driver_register加入到系统中时，如果匹配到board中的platform device, 将会运行probe函数。

以上部分有两个点可以另外分析
* linux中的初始化级别
* platform的框架

probe主要通过两个方面进行分析
* 主要结构体
* probe的流程

#### 主要结构体
**Example code**
```c
static struct snd_soc_dai_link smdk_dai[] = {
    { /* Primary DAI i/f */
	.name = "WM8994 AIF1",
	.stream_name = "Pri_Dai",
	.cpu_dai_name = "samsung-i2s.0",
	.codec_dai_name = "wm8994-aif1",
	.platform_name = "samsung-i2s.0",
	.codec_name = "wm8994-codec",
	.init = smdk_wm8994_init_paiftx,
	.dai_fmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF |
            SND_SOC_DAIFMT_CBM_CFM,
	.ops = &smdk_ops,
    }, { /* Sec_Fifo Playback i/f */
	.name = "Sec_FIFO TX",
	.stream_name = "Sec_Dai",
	.cpu_dai_name = "samsung-i2s-sec",
	.codec_dai_name = "wm8994-aif1",
	.platform_name = "samsung-i2s-sec",
	.codec_name = "wm8994-codec",
	.dai_fmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF |
	    SND_SOC_DAIFMT_CBM_CFM,
	.ops = &smdk_ops,
    },
};

static struct snd_soc_card smdk = {
    .name = "SMDK-I2S",
    .owner = THIS_MODULE,
    .dai_link = smdk_dai,
    .num_links = ARRAY_SIZE(smdk_dai),
}; 
```
简化一下
```
snd_soc_dai_link {
	dai_link_name,
    stream name,
    component name,
    dai_fmt,
    ops
}
```

问题：
* 1 每个dai_link对应的实际概念是什么？
* 2 init在哪个函数中调用？
* 3 dai_fmt的作用是什么，什么地方调用？
* 4 ops的作用是什么，什么地方调用？

1. snd_soc_dai_link
指定了音频系统中各个子设备(platform, cpu dai, codec dai, codec)的名字用于匹配.

4. snd_soc_ops 
其定义为
```c
 /* SoC audio ops */
struct snd_soc_ops {
    int (*startup)(struct snd_pcm_substream *);
    void (*shutdown)(struct snd_pcm_substream *);
    int (*hw_params)(struct snd_pcm_substream *, struct snd_pcm_hw_params *);
    int (*hw_free)(struct snd_pcm_substream *);
    int (*prepare)(struct snd_pcm_substream *);
    int (*trigger)(struct snd_pcm_substream *, int);
};
```
主要对象是snd_pcm_substream, 这些函数会在substream->ops对应的函数中依次调用。

#### probe的流程
Probe函数的主要目的是注册snd_soc_card结构体。
```c
ret = devm_snd_soc_register_card(&pdev->dev, card);
```
其主要部分是card的register, snd_soc_register_card函数，下面是简化版的实现
```c
//初始化struct snd_soc_dai_link_component dai_link->codecs，包括name, of_node, dai_name
snd_soc_init_multicodec(card, link)
card->dev->driver_data = card
//初始化snd_soc_pcm_runtime
card->rtd = alloc;
card->rtd.card = card
card->rtd.dai_link = dai_link
//snd_soc_dai
card->rtd.codec_dais = alloc;
//实例化card
snd_soc_instantiate_card
...
```
其重点是初始化rtd，建立rtd, card, dai_link之间的联系，然后通过snd_soc_instantiate_card将card实例化。
```c
snd_bind_dai_link
//SNDRV_DEFAULT_STR1是card identification
snd_card_new(card->dev, SNDRV_DEFAULT_IDX1, SNDRV_DEFAULT_STR1, 
	card->owner, 0, &card->snd_card);) 
soc_probe_link_components
soc_probe_link_dais
snd_soc_runtime_set_dai_fmt(&card->rtd[i], card->dai_link[i].dai_fmt)
snd_card_register
...
```

**此处应该有函数序列图**

下面具体分析snd_soc_instantiate_card中的重要函数

##### 1) snd_bind_dai_link
> 遍历每一个dai_link，轮询codec_list & platform_list & dai_list（参考对应章节）, 对codec, platform, dai进行绑定，其中关系存储在card->rtd中。

```c
//snd_soc_dai_link_component结构体，用于匹配
//定义并初始化cpu_dai_component，codecs已在在snd_soc_register_card中初始化
snd_soc_dai_link_component cpu_dai_component;
cpu_dai_component.name;
cpu_dai_component.of_node;
cpu_dai_component.dai_name； 

//查找component_list以及component->dai_list，获取snd_soc_dai cpu_dai
//问题: 各个component之间的关系是什么？
snd_soc_find_dai(&cpu_dai_component);
rtd->cpu_dai;

//查找component_list以及component->dai_list，获取snd_soc_dai codec_dais
snd_soc_find_dai(&codecs[i])
rtd->codec_dai;
rtd->codec; //codec和codec_dai同时在codec driver中初始化，codec_dai->codec == codec

//查找platform_list，获取snd_soc_platform
rtd->platform = platform;
```

问题：
* component什么时候定义？
* component的意义是什么？

1. component什么时候定义？
在cpu dai driver以及codec driver中，会通过调用snd_soc_register_component函数新建component
```c
int snd_soc_register_component(device, snd_soc_component_driver, snd_soc_dai_driver, num_dai) {
	struct snd_soc_component *comp;
    ret = snd_soc_component_initialize(comp, component_driver);
    snd_soc_register_dais(comp, dai_driver, num_dai, true)
    snd_soc_component_add(comp)

}
```
2. componnet的意义是什么？

##### 2) snd_card_new
> 分配初始化card的核心设备结构snd_card(snd_soc_card->snd_card)

新建ctrl sub device, **作用是什么？**
又为card建立了proc file.
```
snd_card_new {
	...
	snd_ctl_create(card);
	snd_info_card_create(card);
	...
```

card作为一个设备，其和内核设备模型相关的部分在该函数中完成。

##### 3) snd_probe_link_components
> 按照参数order的先后顺序对component进行初始化

```c
struct snd_soc_component *component;

component rtd->cpu_dai->component;
ret = soc_probe_component(card, component)

component = rtd->codec_dais[i]->component;
ret = soc_probe_component(card, component);

struct snd_soc_platform *platform = rtd->platform;
ret = soc_probe_component(card, &platform->component);
```
soc_probe_component和snd_soc_component是其中两个主要部分。

**soc_probe_component**
dapm和control相关的初始化以及运行component->probe(component).

**snd_soc_component**，ASoC的核心组件cpu_dai, codec_dai, platform都有对应的component，且应该有component->probe，那么这些component和probe是什么时候建立和初始化的呢？

**component的初始化**
soc_probe_component的核心是调用component->probe(component)函数。
而component->probe的初始化发生在snd_soc_component_initialize中(由snd_soc_register_component调用)。

snd_soc_register_component(dev, component_driver, dai_driver, num_dai)
```c
struct snd_soc_component component;
component = alloc
//init component->dev, driver, probe, remote, dapm, control
//init component->dai_list list_head
ret = snd_soc_component_initialize(component, component_driver, dev)
//分配snd_soc_dai, 初始化snd_soc_dai，并将其添加到component->dai_list
ret = snd_soc_register_dais(component, dai_driver, num_dai, true)
//将component->list加入component_list
snd_soc_component_add(component)
```

问题：
* component的作用是什么？
* 为什么dai需要component?

##### 4) soc_probe_link_dais
```c
//cpu dai->driver->probe
ret = soc_probe_dai(cpu_dai, order)
//codec dai->driver->probe
ret = soc_probe_dai(rtd->codec_dais[i], order)
//运行machine init
dai_link->init(rtd)
//将rtd加入到设备模型中
soc_post_component_init
//判断cpu_dai是compress dai还是pcm
//如果是compress
soc_new_compress
//如果不是
soc_new_pcm(rtd, num)
```
soc_new_pcm
```c
待定
```

问题：
* soc_new_pcm做了什么？
* 什么是compress device，和pcm的区别是什么？

##### 5) snd_card_register
```c
device_add(&card->card_dev)
//遍历snd_card->devices链表注册其中所有的device
//调用dev->ops->dev_register
snd_device_register_all(card)
```

### platform

### codec
四个部分
* codec driver
* dai driver
* platform driver
* component driver 

## 结构体所对应的具象意义

## 音频流程
以上描述了各个部分的作用以及各个部分之间的联系。而在alsa框架中，整个音频流程是怎么样的？
如何构建一个完整的音频流？

* PCM play
* PCM record

描述完框架性的结构，可以探讨ASoC中的一些其他有趣的部分，比如DMA.

# Other
## DPAM
## DMA in ALSA


## Debug in ALSA
* debugfs
* ftrace

## regmap-io

# Reference

* ALSA documentation: 
* ASoC documentation: Documentation/sound/alsa/soc
* [内核ALSA之ASoC](https://www.douban.com/group/topic/48402241/?type=like)
* [ALSA子系统](http://blog.csdn.net/DroidPhone/article/category/1118446)
