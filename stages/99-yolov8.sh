#!/usr/bin/env -S bash -euo pipefail

echo "Download yolov8 model..."

mkdir -p "$OUT"/{models,licenses}
curl -o "${OUT}/models/yolov8s.onnx" "https://github.com/spacedriveapp/native-deps/releases/download/yolo-2023-12-04/yolov8s.onnx"
curl -o "${OUT}/licenses/yolov8s.LICENSE" 'https://raw.githubusercontent.com/ultralytics/assets/main/LICENSE'
