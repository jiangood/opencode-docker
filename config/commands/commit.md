---
description: 生成 Conventional Commit 并提交暂存的更改
---
当前暂存的更改：

!`git diff --cached --stat && git diff --cached`

根据这些更改生成 Conventional Commits 格式的提交信息（type 用 feat/fix/docs/refactor/test/chore，主题用中文、不超过 50 字），然后执行 git commit。

如果没有暂存的更改，先查看 git status 和 git diff，把相关更改暂存后再提交。不要执行 git push。$ARGUMENTS
