#!/usr/bin/env -S bash -euo pipefail

echo "Download yolov8 model..."

_tag='yolo-2023-12-04'
case "$TARGET" in
  *windows*)
    _name='yolov8s_win.onnx'
    ;;
  *linux* | *darwin*)
    _name='yolov8s.onnx'
    ;;
esac

mkdir -p "${OUT}/models"
curl -LSsO "${OUT}/models/yolov8s.onnx" "https://github.com/spacedriveapp/native-deps/releases/download/${_tag}/${_name}"
