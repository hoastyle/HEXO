---
title: Hexo搭建博客
date: 2016-05-21 18:36:21
categories: [Tech, Tool]
tags:
	- blog
	- hexo
	- node.js
	- html
---

# 概述
hexo是一种快速、简洁且高效的博客框架。
> 超快速度  
> 支持markdown  
> 一键部署  
> 丰富的插件  

**主要部分**
> node.js
> NEXT theme
> [github markdown](https://guides.github.com/features/mastering-markdown/)

<!--more-->
# 搭建blog
## 安装node.js
安装node.js有以下几种方式：	
* 源码	
* brew	
`# brew install node`
* pkg包	
[pkg release](https://nodejs.org/download/release/latest/)

## github
* 注册
* SSH生成及上传github

## 安装hexo
> [官方网站](https://hexo.io/)

### 本地安装hexo
```sh
npm install hexo-cli -g
npm install hexo --save
hexo init
npm install
```

cli是3.0版本，之前的版本安装通过命令`npm install hexo -g`.

### 本地部署HEXO
> 也可以用来预览和调试

`# hexo g`
`# hexo s`

然后可以通过http://0.0.0.0:4000/或者localhost:4000访问.

hexo工作目录也可以通过github同步，方便在另一台机器上部署hexo, 主要步骤分为以下几个部分:
* install node.js and hexo app
* git clone hexo文件夹
* npm install下载node_modules
* git clone next theme

### github部署hexo
**安装git deployer**
npm install hexo-deployer-git --save

**修改_config.yml**
```sh
deploy:
  type: git
  repo: git@github.com:hoastyle/hoastyle.github.io.git
  branch: master
```

### hexo的使用
#### init
新建一个网站
`# hexo init [folder]` 
在folder文件夹下建立网站。

#### generate
新建一篇page
`# hexo new page <title>`

#### new
新建一篇文章
`# hexo new [layout] <title>`
如果没有指定layout，则使用_config.yml中默认的layout.

#### deploy

#### 文章编辑
文章分为两个部分，头部和正文。

**头部**
```
title:
date:
categories:
tags:
```
多级分类语法格式如下：
```
# 第一种
categories:
	- 一级分类
	- 二级分类
	- etc

# 第二种
categories: [一级，二级， etc]
```
**首页文章预览添加图片**
```
photos:
	- url
```
**设置文章摘要**
文章摘要就是在主页中能够看到的部分, 通过`<!--more>`设置.
```
以上是摘要
<!--more-->
以下是正文
```

### 问题
1. Npm速度过慢
由于某些大家都知道的缘故，npm官方源在国内的下载速度极其慢，用官网的npm install hexo-cli -g速度非常感人，所以不推荐这种方式。这里我推荐用淘宝的npm分流——cnpm
安装过程很简单：`npm install -g cnpm --registry=https://registry.npm.taobao.org`
然后等着装完即可，之后的用法和npm一样，无非是把npm install改成cnpm install,但是速度比之前快了不止一个数量级(不过下文为了方便理解，还是会用默认的npm安装，如果你发现速度不好的话，请自行替换成'cnpm')
或者设置
`npm config set registry http://registry.npm.taobao.org/`

2. 插件不能使用-g安装
hexo插件安装的时候先cd到blog根目录，并且安装参数不要带-g。 （即不要全局安装，因为全局安装的时候插件会被装到node的根目录下去，而不是blog目录），hexo的插件需要在blog目录下才能工作。

## 博客设置
### 主题
#### 主题资源
[github主题站](https://github.com/hexojs/hexo/wiki/Themes)
[hexo 主题站](https://hexo.io/themes/index.html)
[知乎主题帖](https://www.zhihu.com/question/24422335)
[推荐主题next](http://theme-next.iissnan.com/)

#### next主题使用
[设置参考](http://www.ezlippi.com/blog/2016/02/jekyll-to-hexo.html)

### 语言设置
在hexo安装目录下的_config.yml中设置。

> language: option

其具体的选择项由themes中language目录下的内容决定。

### 新建page
`# hexo new page <page name>`
about, categories, tags都属于page.
在新建page之后，需要在主题配置文件中添加：
```sh
menu:
  home: /
  categories: /categories
  archives: /archives
  tags: /tags
```

### 文章分类


## 第三方插件或服务
简单的插件或者服务设置可以参考[next doc](http://theme-next.iissnan.com/getting-started.html).

### sitemap插件
提高网站被搜索引擎收录的可能性(网站的SEO有关系). 大部分内容参考[hexo提交搜索引擎](http://www.jianshu.com/p/619dab2d3c08)这篇文章，另外还有[这篇](http://lukang.me/2015/optimization-of-hexo-2.html)可供参考.

1. 安装sitemap插件
```
$ npm install hexo-generator-sitemap --save
$ npm install hexo-generator-baidu-sitemap --save
```
2. 修改配置文件_config.yml
```sh
sitemap:
	path: sitemap.xml
baidusitemap:
	path: baidusitemap.xml

# 或者

plugins:
	- hexo-generator-sitemap
	- hexo-generator-baidu-sitemap
```
	在经过上述操作后，重新部署blog，应该可以通过yousite/sitemap.xml 和 yousite/baidusitemap.xml访问到对应的xml文件.
3. 验证网站
	* 百度
	登陆[百度站长管理网站](http://zhanzhang.baidu.com/dashboard/index), 新建站点，选择html tag方式验证.
	添加方法：在themes/next/layout/layout/_partials/head.swig开始出添加需要添加的代码.
	* google
	登陆[google站点管理网站](https://www.google.com/webmasters/tools)，具体操作方法同上.
4. 提交sitemap


### 站内搜索

### 域名
blog文章数超过十篇，考虑申请域名。

### 留言评论
网址 : [多说](https://github.com/iissnan/hexo-theme-next/wiki/%E8%AE%BE%E7%BD%AE%E5%A4%9A%E8%AF%B4-DISQUS)

* 创建多说账号
* 安装多说
	* 填写自己的站点url
	* 创建duoshuo_shortname
* 在_config.yml中添加`duoshuo_shortname = {shortname}`

> 注意：在page中需要disable留言，通过在page的header处添加comments: false

### 博客访问
#### 不蒜子
网址 : [不蒜子](http://service.ibruce.info/)
\+ themes/next/layout/_partials/footer.swig
```html
<script async src="//dn-lbstatics.qbox.me/busuanzi/2.3/busuanzi.pure.mini.js"></script>

<span id="busuanzi_container_site_pv">
  &nbsp; | &nbsp; 本站总访问量<span id="busuanzi_value_site_pv"></span>次
</span>

<span id="busuanzi_container_site_uv">
  &nbsp; | &nbsp; 本站访客数<span id="busuanzi_value_site_uv"></span>人次
</span> 
```
\+ themes/next/layout/_macro/post.swig
在div class="post-meta"结尾添加
```html
{% if not is_index and theme.busuanzi_count.enable and theme.busuanzi_count.page_pv %}                   
	&nbsp; | &nbsp;                                                                                      
	<span class="page-pv">{{ theme.busuanzi_count.page_pv_header }}                                      
	<span class="busuanzi-value" id="busuanzi_value_page_pv" ></span>{{ theme.busuanzi_count.page_pv_footer }}
	</span>
{% endif %}
{% if not is_index %}
    <span id="busuanzi_container_page_pv">  |  阅读量 <span id="busuanzi_value_page_pv"></span> 次</span>
{% endif %}
```

> 注意："&nbsp;"是html中空格的意思

### 图床
七牛云

图片自动上传并返回link脚本，参考: [拖曳文件上传到七牛的Python脚本](http://lovenight.github.io/2015/11/17/%E6%8B%96%E6%9B%B3%E6%96%87%E4%BB%B6%E4%B8%8A%E4%BC%A0%E5%88%B0%E4%B8%83%E7%89%9B%E7%9A%84%E8%84%9A%E6%9C%AC/)

# 参考

## 官方
[HEXO官方网站](https://hexo.io/)

## blog
[知乎汇总页](https://www.zhihu.com/question/20962496)
[github官方 jekyII](https://help.github.com/articles/using-jekyll-as-a-static-site-generator-with-github-pages/)
[为project创建github pages](https://help.github.com/articles/creating-project-pages-manually/)
[github官方 none jekyII](https://help.github.com/articles/using-a-static-site-generator-other-than-jekyll/)
[User, Organization, and Project Pages](https://help.github.com/articles/user-organization-and-project-pages/#user--organization-pages)
[custom domain redirect](https://help.github.com/articles/custom-domain-redirects-for-github-pages-sites/)
[automate deploy keys](https://developer.github.com/guides/managing-deploy-keys/#deploy-keys)
[using a custom domain with github pages](https://help.github.com/articles/using-a-custom-domain-with-github-pages/)
[example](http://beiyuu.com/github-pages/)
[hexo博客搭建遇到的一些问题](https://segmentfault.com/a/1190000003710962?_ea=336354) -- 速度，部署等等
[Hexo静态博客搭建指南](http://lovenight.github.io/2015/11/10/Hexo-3-1-1-%E9%9D%99%E6%80%81%E5%8D%9A%E5%AE%A2%E6%90%AD%E5%BB%BA%E6%8C%87%E5%8D%97/)

## hexo & next development
[ARAO'S Blog](http://www.arao.me/)
[next author's blog](http://notes.iissnan.com/)
[hexo 插件分析](http://kyfxbl.iteye.com/blog/2237538)
[test](test)

<center> <iframe frameborder="no" border="0" marginwidth="0" marginheight="0" width=298 height=52 src="http://music.163.com/outchain/player?type=2&id=32944727&auto=1&height=32"></iframe> </center>