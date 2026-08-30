# RTX 5050 Laptop GPU（笔记本版）实机验收单

Mac 上打包成功不等于 RTX 5050 Laptop GPU 已跑通。以下 6 项全部通过，才可以在视频里说“这台笔记本本地部署并成功生成”。

## A. 安装验收

- [ ] `01-PREFLIGHT.ps1` 显示 RTX 5050 Laptop GPU、约 8GB 显存、约 24GB 内存、Radeon 核显。
- [ ] `00-START-HERE.cmd` 完成，没有 SHA-256 错误。
- [ ] `05-VERIFY.ps1 -FullHash` 的 5 个模型全部为 `[OK]`。

## B. 首条视频验收

- [ ] 用 `03-LAUNCH-STABLE.cmd` 启动，无 CUDA、缺节点或模型加载错误。
- [ ] 导入 `NVIDIA-H3-T2V-480P-5s-Turbo8.json`，保持 0.4MP / 5秒 / Turbo 8步。
- [ ] Queue 后成功得到可播放 MP4，画面和立体声音轨都存在。
- [ ] 生成前运行 `09-MONITOR-GPU.ps1`，记录从 Queue 到文件落盘的真实耗时，不用估算值代替。
- [ ] 记录任务管理器或 `nvidia-smi` 的峰值显存、系统内存和页面文件占用。

## C. OBS 并行验收

- [ ] 运行 `06-CONFIGURE-OBS-IGPU.ps1` 并重启 OBS。
- [ ] OBS 使用 AMD 硬件编码器，任务管理器能看到 Radeon `Video Encode` 负载。
- [ ] 1080p30 录屏时重复同一工作流，仍能出片且没有 OOM。
- [ ] 对比不开 OBS / 开 OBS 的两次耗时，写入脚本或视频素材备注。

## 失败时保留这些证据

不要只拍错误弹窗。保存：

1. ComfyUI 黑色终端最后 50 行。
2. `nvidia-smi` 截图。
3. 任务管理器“性能”页的 GPU、内存和磁盘截图。
4. 工作流 JSON 和 Queue 时的参数截图。
5. `runtime\ComfyUI_windows_portable\ComfyUI\output\` 是否生成了文件。

这些信息足以判断是驱动、显存、系统内存、模型损坏还是工作流版本问题。
