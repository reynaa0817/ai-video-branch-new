#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
FIXTURE="$ROOT/tests/acceptance/baseline/fixtures/media"
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
IMAGE=ai-video/ffmpeg-baseline:8.1.2-noto-serif-cjk-2.003
WORK="$ROOT/.base-002-media.$$"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$WORK" "$EVIDENCE/media"

docker build --pull=false --no-cache -t "$IMAGE" -f "$FIXTURE/Dockerfile" "$FIXTURE" >"$EVIDENCE/media-build.log" 2>&1
docker image inspect "$IMAGE" --format '{{.Id}}' >"$EVIDENCE/media-image-digest.txt"
docker image inspect "$IMAGE" --format '{{json .Config.Labels}}' >"$EVIDENCE/media-image-labels.json"

cp "$FIXTURE/subtitles.ass" "$WORK/subtitles.ass"
docker run --rm --entrypoint /bin/sh -v "$WORK:/work" "$IMAGE" -c '
  set -eu
  test "$(sha256sum /usr/share/fonts/opentype/noto/NotoSerifCJKsc-Regular.otf | cut -d" " -f1)" = 2a2eae2628df83556c54018c41e20fa532c1b862c5256ae8b3f23feb918d12ca
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=0x243047:s=1080x1920:r=30:d=1" \
    -f lavfi -i "sine=frequency=880:sample_rate=48000:duration=1" \
    -vf "subtitles=/work/subtitles.ass:fontsdir=/usr/share/fonts/opentype/noto" \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p -r 30 \
    -c:a aac -ar 48000 -metadata comment=ai_generated=true \
    -movflags +faststart -shortest /work/golden.mp4
  ffmpeg -hide_banner -loglevel error -y -i /work/golden.mp4 -frames:v 1 /work/frame.png
  ffprobe -v error -show_streams -show_format -of json /work/golden.mp4 >/work/ffprobe.json
'

cp "$WORK/golden.mp4" "$EVIDENCE/media/golden.mp4"
cp "$WORK/frame.png" "$EVIDENCE/media/frame.png"
cp "$WORK/ffprobe.json" "$EVIDENCE/media/ffprobe.json"
cp "$WORK/subtitles.ass" "$EVIDENCE/media/subtitles.ass"

width=$(jq -r '.streams[] | select(.codec_type=="video") | .width' "$WORK/ffprobe.json")
height=$(jq -r '.streams[] | select(.codec_type=="video") | .height' "$WORK/ffprobe.json")
fps=$(jq -r '.streams[] | select(.codec_type=="video") | .r_frame_rate' "$WORK/ffprobe.json")
video_codec=$(jq -r '.streams[] | select(.codec_type=="video") | .codec_name' "$WORK/ffprobe.json")
audio_codec=$(jq -r '.streams[] | select(.codec_type=="audio") | .codec_name' "$WORK/ffprobe.json")
audio_hz=$(jq -r '.streams[] | select(.codec_type=="audio") | .sample_rate' "$WORK/ffprobe.json")
container=$(jq -r '.format.format_name' "$WORK/ffprobe.json")
metadata=$(jq -r '.format.tags.comment // ""' "$WORK/ffprobe.json")

[ "$width" = 1080 ] && [ "$height" = 1920 ] && [ "$fps" = 30/1 ]
[ "$video_codec" = h264 ] && [ "$audio_codec" = aac ] && [ "$audio_hz" = 48000 ]
printf '%s' "$container" | grep -q mp4
[ "$metadata" = ai_generated=true ]
grep -q '全栈技术基线媒体金样' "$WORK/subtitles.ass"
grep -q 'AI 生成' "$WORK/subtitles.ass"

{
  printf 'field\tvalue\n'
  printf 'playable\ttrue\n'
  printf 'width\t%s\n' "$width"
  printf 'height\t%s\n' "$height"
  printf 'fps\t30\n'
  printf 'container\tmp4\n'
  printf 'video_codec\t%s\n' "$video_codec"
  printf 'audio_codec\t%s\n' "$audio_codec"
  printf 'audio_hz\t%s\n' "$audio_hz"
  printf 'subtitle_burned\ttrue\n'
  printf 'subtitle_file\ttrue\n'
  printf 'chinese_font\ttrue\n'
  printf 'ai_label\ttrue\n'
  printf 'metadata\ttrue\n'
} >"$EVIDENCE/media-report.tsv"

shasum -a 256 "$EVIDENCE/media/golden.mp4" "$EVIDENCE/media/frame.png" "$EVIDENCE/media/subtitles.ass" >"$EVIDENCE/media-sha256.txt"
printf 'BASE-002 media PASS image=%s\n' "$(cat "$EVIDENCE/media-image-digest.txt")"
