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
# 相关工具
## node.js

## hexo

## next theme

## markdown
[github markdown](https://guides.github.com/features/mastering-markdown/)

## vim and markdown

## 域名
blog文章数超过十篇，考虑申请域名。

# Step
## 安装node.js
下载源码，./configure, make install 

## github
- 注册

- SSH

## hexo
[官方网站](https://hexo.io/)
[指导](http://sunwhut.com/2015/10/30/buildBlog/?hmsr=toutiao.io&utm_medium=toutiao.io&utm_source=toutiao.io)

### 问题
1. Npm速度过慢
由于某些大家都知道的缘故，npm官方源在国内的下载速度极其慢，用官网的npm install hexo-cli -g速度非常感人，所以不推荐这种方式。这里我推荐用淘宝的npm分流——cnpm
安装过程很简单：`npm install -g cnpm --registry=https://registry.npm.taobao.org`
然后等着装完即可，之后的用法和npm一样，无非是把npm install改成cnpm install,但是速度比之前快了不止一个数量级(不过下文为了方便理解，还是会用默认的npm安装，如果你发现速度不好的话，请自行替换成'cnpm')

2. 插件不能使用-g安装
hexo插件安装的时候先cd到blog根目录，并且安装参数不要带-g。 （即不要全局安装，因为全局安装的时候插件会被装到node的根目录下去，而不是blog目录），hexo的插件需要在blog目录下才能工作。

### 本地安装HEXO
    - `npm install hexo-cli -g`
    - `npm install hexo --save`
    - `hexo init`
    - `npm install `

cli是3.0版本，之前的版本是`npm install hexo -g`

### 本地部署HEXO
> 也可以用来预览和调试

`# hexo g`
`# hexo s`

然后可以通过http://0.0.0.0:4000/访问。

### HEXO的基本操作
**init 新建一个网站**
`hexo init [folder]` 
在folder文件夹下建立网站。

**generate** 

**new 新建一篇文章**
`hexo new [layout] <title>`
如果没有指定layout，则使用_config.yml中默认的layout.

### github部署HEXO
- 安装git deployer
npm install hexo-deployer-git --save

- type改为git

- 修改_config.yml
```
deploy:                                                                                                            
  type: git                                                                                                        
  repo: git@github.com:hoastyle/hoastyle.github.io.git                                                             
  branch: master 
```

## 主题
### 主题资源
[github主题站](https://github.com/hexojs/hexo/wiki/Themes)
[hexo 主题站](https://hexo.io/themes/index.html)
[知乎主题帖](https://www.zhihu.com/question/24422335)
[推荐主题next](http://theme-next.iissnan.com/)

### next主题使用
[设置参考](http://www.ezlippi.com/blog/2016/02/jekyll-to-hexo.html)

## Advanced Setting
### 语言设置
在hexo安装目录下的_config.yml中设置。

> language: option

其具体的选择项由themes中language目录下的内容决定。

### 头像设置
> 不确认是否是针对next主题的设置

地址 | 值
--- | ---
互联网地址 | http://example.com/avtar.png
站点地址1　| 将头像放置主题目录下的 source/uploads/, （新建uploads目录若不存在), 配置为：avatar: /uploads/avatar.png
站点地址２ | 放置在 source/images/ 目录下, 配置为：avatar: /images/avatar.png

### 主题风格设置
mist

### 新建page

### tag

### 留言评论
[多说](https://github.com/iissnan/hexo-theme-next/wiki/%E8%AE%BE%E7%BD%AE%E5%A4%9A%E8%AF%B4-DISQUS)

- 创建多说账号
－安装多说
	- 填写自己的站点url
	- 创建duoshuo_shortname
- 在_config.yml中添加`duoshuo_shortname = {shortname}`

> 注意：在page中需要disable留言，通过在page的header处添加comments: false

### 博客访问
#### 不蒜子
[不蒜子](http://service.ibruce.info/)

+ themes/next/layout/_partials/footer.swig
```
<script async src="//dn-lbstatics.qbox.me/busuanzi/2.3/busuanzi.pure.mini.js"></script>

<span id="busuanzi_container_site_pv">
  &nbsp; | &nbsp; 本站总访问量<span id="busuanzi_value_site_pv"></span>次
</span>

<span id="busuanzi_container_site_uv">
  &nbsp; | &nbsp; 本站访客数<span id="busuanzi_value_site_uv"></span>人次
</span> 
```

+ themes/next/layout/_macro/post.swig
在div class="post-meta"结尾添加
```
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


### 其他各种插件

### 文章分类

### 图床
七牛云

## 第三方插件或服务

### 文章分类

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
