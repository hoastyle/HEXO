---
title: git随笔
tags:
---

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


