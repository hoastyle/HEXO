---
title: 利用Latex写简历
date: 2016-06-09 10:33:34
categories: [Tech, Tool]
tags:
	- latex
	- mac tex
	- moderncv
	- 简历 resume
---

Word生成的简历总是缺那么点意思，正好最近换工作的事提上了日程，于是开始折腾用Latex写简历。

# 需求
* 中，英文简历
* 美观
* 易维护

综合以上考虑，选择Latex.

<--!more-->
# 环境及所需软件
* 环境：MAC
* 软件
	* [Mac Tex](http://www.tug.org/mactex/)
	* [简历模板moderncv](http://www.ctan.org/tex-archive/macros/latex/contrib/moderncv/)

# 生成简历
* 安装mac tex
* 下载moderncv
moderncv是个zip包，下载解压即可。
解压后，将example文件夹下的template.tex（英文模板）以及template-zh.tex（中文模板）复制到moderncv的根目录。
* 通过Mac tex生成pdf文件
* 使用texshop处理tex模板，点击typeset生成所需的pdf文件

# 参考
* [Latex Templates](http://www.latextemplates.com/cat/curricula-vitae)
* [用Latex写中英文简历](https://zr9558.com/2014/11/26/moderncv/)
* [moderncv官网](https://launchpad.net/moderncv)
* [share latex](https://www.sharelatex.com/)
