---
title: ALSA
date: 2016-05-25 15:08:03
categories: [Tech, OS, Linux, Driver, Audio]
tags:
	- ALSA
	- ASoC
	- linux
	- driver
---

# ALSA
## ALSA概述
ALSA

ALSA的框架

## ALSA设备文件结构

## ALSA代码文件结构

以上是宏观角度
---
以下是微观角度

<!--more-->

# ASoC
## ASoC Overview
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

最后一项什么意思？

为实现上面提到的种种特性，ASoC将嵌入式音频系统分为三个可以重用的component driver，分别是machine class, platform class, codec class。其中，platform & codec是跨平台的，而machine是板级相关。

### ASoC和ALSA的关系

## Component in ASoC
以sc58x 以及 samsung为例，解释其框架结构。

### machine class
> 概述: 是将各个组件绑定成一个"sound card device"，它可以处理平台级别的控制操作以及相关事件。

machine driver的命名往往是platform_codec.c的形式。  
如在sc58x中，sc58x-adau1962.c为adau1962在sc58x上的machine driver.  
在samsung中，smdk_wm8994.c位wm8994在smdk上的machine driver

主要结构：

* snd_soc_card

主要函数：
* snd_soc_register_card

### platform
> 概述：主要是负责数据的传输，而在音频中都是通过DMA传输数据。所以该部分包括DMA的控制以及{DAI}.

主要结构体：

* snd_soc_platform
* snd_soc_platform_driver

主要函数：

* snd_soc_register_platform

### codec
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

### DAI

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

### 代码分析
#### machine
以samsung为例，分析smdk_wm8994.c
machine driver实现为一个platform driver，该driver的probe函数的主要目的是注册snd_soc_card结构体。
```c
ret = devm_snd_soc_register_card(&pdev->dev, card);
```
首先对card做了初步的初始化，并定义了snd_soc_dai_link结构。
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
其中引出了两个比较重要的结构，snd_soc_dai_link和snd_soc_ops.
其中snd_soc_dai_link指定了音频系统中各个子设备(platform, cpu dai, codec dai, codec)的名字用于匹配.

snd_soc_ops的作用是什么？

最主要的就是card的register, snd_soc_register_card函数，下面是简化版的实现
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
引出snd_soc_instantiate_card
```c
	snd_bind_dai_link
	//SNDRV_DEFAULT_STR1是card identification
	snd_card_new(card->dev, SNDRV_DEFAULT_IDX1, SNDRV_DEFAULT_STR1, 
		card->owner, 0, &card->snd_card);) 
	soc_probe_link_components
	soc_probe_link_dais
	snd_soc_runtime_set_dai_fmt
	snd_card_register
	...
```
以上每个部分都很重要，分开来描述

##### snd_bind_dai_link
> 遍历每一个dai_link，轮询codec_list & platform_list & dai_list, 对codec, platform, dai进行绑定.

```c
	//定义并初始化cpu_dai_component，codecs在snd_soc_register_card中初始化
	snd_soc_dai_link_component cpu_dai_component;
	cpu_dai_component.name = 
	cpu_dai_component.of_node
	cpu_dai_component.dai_name = 

	//查找component_list以及component->dai_list，获取snd_soc_dai cpu_dai
	//问题: 各个component之间的关系是什么？
	snd_soc_find_dai(&cpu_dai_component)
	rtd->cpu_dai

	//查找component_list以及component->dai_list，获取snd_soc_dai codec_dais
	snd_soc_find_dai(&codecs[i])
	rtd->codec_dai
	rtd->codec

	//查找platform_list，获取snd_soc_platform
	rtd->platform = platform;
```

##### snd_card_new
> 分配初始化card的核心设备结构snd_card

card作为一个设备，其和内核设备模型相关的部分在该函数中完成。

##### snd_probe_link_components
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

**问题**
* snd_soc_component是什么时候建立的？

##### snd_probe_link_dais

##### snd_soc_ru 

#### platform

#### codec


### 音频流程
以上描述了各个部分的作用以及各个部分之间的联系。而在alsa框架中，整个音频流程是怎么样的？

* PCM play
* PCM record

描述完框架性的结构，可以探讨ASoC中的一些其他有趣的部分，比如DMA.

## Other
### DPAM
### DMA in ALSA


### Debug in ALSA
* debugfs
* ftrace

### regmap-io

# Reference

* ALSA documentation: 
* ASoC documentation: Documentation/sound/alsa/soc
* [内核ALSA之ASoC](https://www.douban.com/group/topic/48402241/?type=like)
* [ALSA子系统](http://blog.csdn.net/DroidPhone/article/category/1118446)
