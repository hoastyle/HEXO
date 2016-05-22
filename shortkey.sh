#!/bin/bash
if [ "$1" == "d" ]; then
hexo clean
hexo d -g
elif [ "$1" == "p" ]; then
git add .
git commit -s -a
git push
elif [ "$1" == "a" ]; then
hexo clean
git add -A
git commit -s -a
git push
hexo d -g
fi

