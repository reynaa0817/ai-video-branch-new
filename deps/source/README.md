# 离线源码快照依赖

BASE-002 Kubernetes harness 需要以下预下载源码快照，并保留 `.git` 元数据用于提交 SHA 取证：

- `kind-v0.32.0`
- `csi-driver-host-path-v1.17.0`
- `external-provisioner-v5.2.0`
- `ingress-nginx-controller-v1.15.1`

验证脚本不得在运行时 `git clone` GitHub；缺少快照时必须失败关闭。
