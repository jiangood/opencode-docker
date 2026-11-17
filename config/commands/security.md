---
description: 对当前更改做安全审查
agent: plan
---
对以下更改做安全审查：

!`git diff --stat && git diff`

检查：注入（SQL/命令/路径遍历）、硬编码密钥凭据、不安全的反序列化、权限校验缺失、敏感信息日志泄露、依赖风险。只报告真实可利用的问题，给出修复方案。$ARGUMENTS
