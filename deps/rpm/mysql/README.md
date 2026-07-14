# MySQL 离线 RPM 依赖

`scripts/verify-mysql-pitr-baseline.sh` 只会从本目录读取 `mysql-community-client-8.4.10` 及其依赖 RPM。

不要在 Docker build 中配置 `repo.mysql.com` 或执行联网安装；若本目录缺少 RPM，BASE-002 PITR 证据必须失败关闭。
