---
title: ASoC
tags:
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

主要结构：

* snd_soc_card

主要函数：

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