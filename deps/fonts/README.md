# 离线字体依赖

本目录用于放置 Web/媒体验证需要的预下载字体文件。

当前 Story 1.3 不直接依赖字体文件本体；字体 payload 不提交到 Git。需要交付时，请按离线物料包提供：

- 字体文件本体，例如 `NotoSerifCJKsc-Regular.otf`
- 对应 `.sha256` checksum
- 字体来源、许可证、查看时间和 owner 审批记录

验证或构建不得在运行时联网下载字体。
