FROM linuxserver/ffmpeg@sha256:e6b338a3a9d7ca2a33d345fa683d68767f799f2c13694542ba5bfb4f63dff585

ARG NOTO_COMMIT=9b0f1436e455d902de067a2501422e5dc71ad16b
ARG NOTO_SHA256=2a2eae2628df83556c54018c41e20fa532c1b862c5256ae8b3f23feb918d12ca
RUN set -eu; \
    mkdir -p /usr/share/fonts/opentype/noto; \
    curl -fsSL "https://raw.githubusercontent.com/notofonts/noto-cjk/${NOTO_COMMIT}/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf" \
      -o /usr/share/fonts/opentype/noto/NotoSerifCJKsc-Regular.otf; \
    printf '%s  %s\n' "${NOTO_SHA256}" /usr/share/fonts/opentype/noto/NotoSerifCJKsc-Regular.otf | sha256sum -c -

LABEL org.opencontainers.image.title="ai-video BASE-002 FFmpeg fixture" \
      org.opencontainers.image.version="8.1.2-noto-serif-cjk-2.003" \
      org.opencontainers.image.source="https://github.com/aif-go/ai-video" \
      org.opencontainers.image.licenses="GPL-3.0-and-later AND OFL-1.1"
