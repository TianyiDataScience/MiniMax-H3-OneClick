# OBS 使用 Radeon 760M 核显录屏

## 目标

让 RTX 5050 尽量只负责 MiniMax H3，把 OBS 的界面渲染和视频编码交给 Ryzen 5 240 自带的 Radeon 760M。这样不能让 H3 变成实时生成，但能减少 OBS 对 8GB 独显显存的争抢。

## 设置

1. 安装最新版 OBS Studio。
2. 右键 `06-CONFIGURE-OBS-IGPU.ps1`，选择“使用 PowerShell 运行”。脚本会把 `obs64.exe` 的 Windows 图形偏好设为“节能 GPU”。
3. 完全退出并重启 OBS。
4. OBS -> 设置 -> 输出 -> 输出模式选择“高级”。
5. 录制编码器选择 `AMD HW H.264 (AVC)`；若剪辑链路完整支持 AV1，也可选 `AMD HW AV1`。
6. 设置 -> 视频：基础画布 `1920×1080`，输出 `1920×1080`，30fps。
7. 任务管理器 -> 性能：确认 H3 生成时 RTX 5050 的 CUDA/计算负载高，OBS 录制时 Radeon 760M 的 `Video Encode` 有负载。

如果 OBS 的编码器列表里只有 `NVIDIA NVENC` 和软件 `x264`，说明 AMD 编码器没有被 OBS 正确识别。先更新 AMD 核显驱动，再重启；不要在 8GB 显存首测时用 NVENC 录 4K。

## 推荐录制顺序

1. 不开 OBS，先生成一条 480p / 5秒 / Turbo 8步视频，记录总耗时与峰值显存。
2. 运行核显配置并启动 OBS，录制 ComfyUI 操作，再生成同一条视频。
3. 对比两个耗时。如果第二次明显变慢或报内存错误，先把 OBS 降到 1080p30，并关闭浏览器多余标签。
