---
description: 审查当前未提交的代码更改
agent: plan
---
审查以下未提交的更改，重点找 bug、边界条件遗漏、安全隐患和缺失的测试：

!`git diff --stat && git diff`

按严重程度排序输出问题清单，每个问题给出文件位置、原因和修复建议。$ARGUMENTS
