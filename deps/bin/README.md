# 离线二进制依赖

`scripts/verify-kubernetes-harness.sh` 需要本目录提供 `kind-v0.32.0` 可执行文件。

验证脚本不得在运行时执行 `go install sigs.k8s.io/kind`；缺少二进制时必须失败关闭。
