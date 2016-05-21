#!/bin/bash
if [ "$1" == "-d" ]; then
hexo clean
hexo d -g
elif [ "$1" == "-p" ]; then
git add .
git commit -s -a
git push
fi

