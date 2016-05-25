---
title: git随笔
tags:
---

# git
## git general process

## github
在hexo博客搭建过程中，曾经一段时间博客发布正常，通过查询repo也确认commit正常提交，但是对应的github网页却迟迟不更新，最后确认是github网站挂了。
通过[github status](https://status.github.com/)网站查询github.com当前的状态。

如果运行`ssh -T git@github.com`
遇到错误`ssh: connect to host github.com port 22: Connection timed out`，应该是22号端口被封了。
.ssh/config
Host github.com
User hao.c.code@gmail.com
Hostname ssh.github.com
PreferredAuthentications publickey
IdentityFile ~/.ssh/id_rsa
Port 443


# FAQ
## SSH设置后为什么还是要输入账户和密码
因为没有使用合适的协议，如果是https，应该将其换为git@github.com:username/repo.git

```shell
# git remote remove origin
# git remote add origin git@github.com:username/repo.git
# git branch --set-upstream-to=/origin/master master
```

## git push中matching和simple模式的区别
不带任何参数的git push，默认只推送当前分支，这叫做simple方式。此外，还有一种matching方式，会推送所有有对应的远程分支的本地分支。Git 2.0版本之前，默认采用matching方法，现在改为默认采用simple方式。如果要修改这个设置，可以采用git config命令。


