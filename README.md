# MiniMax H3 Windows NVIDIA 一键安装包

> 木子不写代码｜把复杂的本地 AI 部署，做成普通创作者也能完成的几次双击。

分享者与维护者：**木子不写代码**

[设备支持表](COMPATIBILITY.md) · [模型许可说明](MODEL-LICENSE-NOTICE.md) ·
[第三方声明](THIRD-PARTY-NOTICES.md) · [问题反馈要求](SUPPORT.md)

## 这是什么

这是“木子不写代码”为 Windows NVIDIA 电脑整理的 MiniMax H3 本地部署包。

你不需要自己安装 Python，不需要手动配置 CUDA，不需要到处寻找 ComfyUI 节点和
模型路径。把压缩包完整解压，双击 `00-START-HERE.cmd`，安装器会自动完成：

- 检查 Windows、显卡架构、显存、驱动、内存、虚拟内存和磁盘空间；
- 下载固定版本的 ComfyUI Windows Portable；
- 下载约 44.4GB 的 MiniMax H3 模型文件；
- 对下载文件执行大小与 SHA-256 完整性校验；
- 自动放置模型、官方工作流和示例素材；
- 生成适合 Windows NVIDIA 低显存首跑的 T2V、I2V 工作流；
- 验证 Python、PyTorch、CUDA、模型文件和 ComfyUI 服务；
- 提供稳定启动、性能启动、故障诊断和 GPU 监控工具。

它不是一个“能下载文件就算成功”的临时脚本，而是一套包含**安装前预检、固定版本、
断点续传、哈希校验、安装后验证、隐私诊断和失败恢复**的完整交付方案。

## 为什么推荐这个包

### 1. 真正面向不写代码的人

正常情况下，你只需要记住两个文件：

- 第一次安装：双击 `00-START-HERE.cmd`
- 以后启动：双击 `03-LAUNCH-STABLE.cmd`

其余脚本是验证、诊断或进阶工具，不需要先学会命令行。

### 2. 不是“理论上能跑”，而是有真实出片验证

本项目已在下面这台电脑上完成真实安装、CUDA 验证、T2V/I2V 生成、480p 与
1344×768 工作流、原生音频视频输出和 OBS 核显卸载测试：

- HP Victus by HP Gaming Laptop 15-fb3xxx
- Windows 11 x64，build 26200
- AMD Ryzen 5 240，24GB 内存
- NVIDIA GeForce RTX 5050 Laptop GPU，8GB 显存
- NVIDIA 驱动 592.82，compute capability 12.0
- AMD Radeon 760M 核显

五个模型文件共约 44.4GB，已经完成逐文件 SHA-256 全量复核。

### 3. 下载中断不用从头再来

模型下载支持断点续传。网络中断、电脑重启或安装中止后，重新运行
`00-START-HERE.cmd` 即可继续。校验失败的文件不会冒充成功文件，而会被保留为
`.bad-时间戳`，下一次重新下载干净副本。

### 4. 为 8GB 显存准备了稳妥首跑方案

默认工作流不是一上来追求最高参数，而是先用约 864×480、5秒、Turbo 8步验证
整条生成链路。Stable 启动模式会启用低显存与动态卸载，并为 Windows 桌面预留
1.5GB 显存。

这意味着“先成功出片，再逐步提高画质”，比第一次就把分辨率、时长和步数全部拉满
更可靠。

### 5. 每一步都可以检查

脚本、模型清单、下载地址和 SHA-256 都是可读的。仓库不包含 44GB 模型权重、私人
项目、生成视频、运行日志或本机账号信息。开源版本还有自动检查，防止把模型、视频、
EXE、日志、个人路径或疑似密钥误提交到仓库。

## 安装前先确认

满足下面条件再开始，能省下大量无效下载时间：

- Windows 10 或 Windows 11，64位 x64；
- NVIDIA Turing 或更新架构，compute capability 至少 7.5；
- NVIDIA 显存至少约 8GB，`nvidia-smi` 报告值不得低于 7500MiB；
- NVIDIA R580 或更新驱动；
- 系统内存至少 16GB，推荐 24GB 或更多；
- Windows 虚拟内存采用“系统管理”，或手动分配至少 32GiB；
- 安装盘至少空出 65GiB，推荐 90GiB 以上；
- 能访问 GitHub、Hugging Face，必要时还能访问 7-zip.org；
- 安装目录必须短、纯英文、非 OneDrive，例如 `C:\AI\MiniMax-H3`；
- 笔记本安装和生成时应连接电源。

如果预检显示红色 `[FAIL]`，先解决对应问题，不要强行跳过。黄色 `[WARN]` 表示可以
继续测试，但不属于当前完整验证范围。

## 三分钟看懂安装

### 第一步：完整解压

下载 Release ZIP 后，右键选择“全部解压”，把**整个文件夹**解压到：

```text
C:\AI\MiniMax-H3
```

不要在 ZIP 压缩包窗口里直接双击脚本；Windows 可能只临时解出一个 CMD，旁边没有
安装所需文件。也不要只复制 `03-LAUNCH-STABLE.cmd` 到桌面。

### 第二步：更新 NVIDIA 驱动

安装 R580 或更新的 NVIDIA Studio Driver / Game Ready Driver，然后重启电脑。

### 第三步：开始一键安装

双击：

```text
00-START-HERE.cmd
```

安装器会先显示 MiniMax H3 模型许可提醒。只有在你已经阅读许可，并确认自己在所在
地区有权下载和使用模型时，才选择 `Y` 继续。

随后脚本会自动完成预检、下载、解压、模型放置、工作流生成和 CUDA 验证。模型约
44.4GB，耗时取决于网络速度和硬盘速度。安装过程中不要删除 `.part` 文件。

### 第四步：看到安装完成

最终应看到类似提示：

```text
Installation, model files and PyTorch CUDA checks passed.
```

如果安装中断，重新运行 `00-START-HERE.cmd`，安装器会校验已有文件并从中断处继续。

## 第一次使用

### 1. 启动 ComfyUI

双击安装目录里的：

```text
03-LAUNCH-STABLE.cmd
```

请保留黑色 CMD 窗口。浏览器会自动打开：

```text
http://127.0.0.1:8188
```

如果 ComfyUI 已经在运行，新版启动器会直接打开现有页面，不会再启动第二个进程。

### 2. 打开首跑工作流

在 ComfyUI 中选择 `Workflow → Open`，打开：

```text
workflows\generated\NVIDIA-H3-T2V-480P-5s-Turbo8.json
```

安装器也会把工作流复制到 ComfyUI 的用户工作流目录，因此通常可以直接从工作流菜单
找到。

### 3. 只修改提示词

第一次不要改模型、分辨率、时长、步数或节点连接。只修改提示词，然后点击 `Queue`。

示例提示词：

```text
A cinematic wide shot of a small wooden boat crossing a glowing blue lake at
sunrise, soft mist, realistic water reflections, slow camera movement, native
ambient wind and water audio, no text, no subtitles, no watermark.
```

### 4. 等待真实 MP4 保存

RTX 5050 Laptop GPU 8GB 运行 H3 不是实时生成。模型会在显存、内存和 Windows 页面文件之间
动态装卸，生成期间电脑变慢属于正常现象。只有看到 MP4 正式保存，才算首跑通过。

默认输出目录：

```text
runtime\ComfyUI_windows_portable\ComfyUI\output\video\MiniMax_H3_WindowsNVIDIA
```

### 5. 正确关闭

关闭浏览器标签不会关闭 ComfyUI。要完全退出，请回到启动 CMD 窗口按 `Ctrl+C`，或
关闭该 CMD 窗口。

## 图生视频怎么用

Stable 模式首跑成功后，打开：

```text
workflows\generated\NVIDIA-H3-I2V-480P-5s-Turbo8.json
```

在加载图片节点中选择输入图片，修改提示词，再点击 `Queue`。第一次 I2V 同样保持
480p、5秒和 Turbo 8步，不要同时增加多个参数。

## 如何逐步提高画质

确认默认 5秒 MP4 成功后，按下面顺序一次只改一项：

1. 保持 480p 和5秒，关闭 Turbo 或提高采样步数，比较质量；
2. 保持5秒，把分辨率提高到 0.5MP 或 0.6MP；
3. 最后尝试 H3 原生 0.98MP，也就是约 1344×768；
4. 只有 Stable 长时间稳定后，再尝试 `04-LAUNCH-BALANCED.cmd`。

不要第一次就同时提高分辨率、时长和步数。更高参数会明显增加显存、系统内存、页面
文件、耗时和失败概率。

## 支持哪些电脑

本安装包以 **RTX 5050 Laptop GPU 8GB（笔记本版）**作为最低正式支持基准。
型号级别不低于它、并同时满足显存、驱动、内存和系统要求的 NVIDIA RTX 笔记本或
台式设备，纳入正式支持范围。比它低的 NVIDIA 设备因为没有实测，列为“未测试”，
而不是直接判定不能运行。

### 已完整验证

| 设备 | 状态 | 验证内容 |
|---|---|---|
| HP Victus 15-fb3xxx，**RTX 5050 Laptop GPU 8GB（笔记本版）**，Ryzen 5 240，Radeon 760M，24GB RAM，Windows 11 x64 build 26200 | 已验证基准机 | 安装、完整哈希、CUDA、T2V、I2V、480p、1344×768、原生音频视频、OBS 核显卸载 |

### 正式支持范围

下面设备属于本安装包的正式支持范围：

- Windows 10/11 x64 台式机或笔记本；
- **RTX 5050 Laptop GPU 8GB，以及型号级别更高的 NVIDIA RTX Laptop GPU**；
- **RTX 5050 同等级或更高等级的 NVIDIA RTX 台式显卡**；
- 上述设备仍须具备至少8GB显存、compute capability 7.5+ 和 R580+ 驱动；
- 24GB 或更多系统内存，系统管理页面文件，90GB 或更多可用磁盘。

高于基准机的设备拥有不低于本项目目标的 GPU 等级，但不同笔记本的功耗释放、散热、
系统内存和厂商驱动会影响生成速度。安装器会在安装前检查真正影响运行的硬条件，不能
只看显卡名称。

16–23GB 内存的机器预检会警告。它可能依靠大量页面文件运行，但速度和稳定性不属于
当前推荐范围。

### 低于基准机的 NVIDIA 设备：未测试

RTX 5050 Laptop GPU 8GB 以下等级的 NVIDIA 显卡，本项目没有做完整实机测试。
如果仍满足 Turing 或更新架构、显存至少8GB和 R580+ 驱动，预检可能允许继续，但木子
不写代码目前不承诺生成速度和稳定性。显存低于8GB的设备会被安装器停止。

### 当前明确不支持的平台

| 设备或系统 | 原因 |
|---|---|
| NVIDIA 显存低于约8GB | 安装器会停止；不满足本包最低显存条件 |
| GTX 10 系列及更老显卡、Volta | 当前固定 CUDA 13 Windows 构建要求 Turing 或更新架构 |
| AMD 独显、只有 AMD 核显的电脑 | 本包下载 NVIDIA Portable，并依赖 `nvidia-smi`；Radeon 760M 仅用于 OBS/桌面卸载 |
| Intel Arc、Intel 核显 | 本包没有安装 XPU 运行时 |
| Apple Silicon Mac、Intel Mac | 本包是 Windows CMD/PowerShell 与 NVIDIA CUDA 方案 |
| Linux、WSL、Docker、NAS 系统 | 没有提供或验证对应的 Python、CUDA、服务和路径方案 |
| 纯 CPU | H3 未完成 CPU 验证，且安装器明确要求 CUDA |
| Windows 7/8.1、Windows ARM | 不满足固定运行时的 Windows x64 范围 |
| 手机、平板、游戏机 | 没有原生安装包或远程服务器配置 |

完整技术边界见 [COMPATIBILITY.md](COMPATIBILITY.md)。

## OBS 录屏

如果电脑同时有 AMD Radeon 核显，可以运行：

```text
06-CONFIGURE-OBS-IGPU.ps1
```

然后在 OBS 中选择 AMD 硬件 H.264 或 AV1 编码，让 RTX 尽量留给 H3。推荐第一次
录制使用 1920×1080、30fps，不要边首测 H3 边录 4K60。

只有 NVIDIA 显卡、没有 AMD 核显的电脑仍可正常使用本安装包，但 OBS 与 H3 可能
争用 RTX 显存和编码资源。

## 常见问题

### 双击 03，提示 ComfyUI is not installed

这通常不是 CUDA 故障，而是你运行了错误位置的 `03-LAUNCH-STABLE.cmd`。

启动器只会在自己旁边寻找：

```text
runtime\ComfyUI_windows_portable\python_embeded\python.exe
```

请确认：

1. 没有在 ZIP 压缩包窗口里直接运行；
2. 没有运行 `projects\...\00-Backups` 或其他备份目录里的同名文件；
3. 没有把 CMD 单独复制到桌面；
4. 使用的是完成安装的同一目录里的 `03-LAUNCH-STABLE.cmd`。

新版启动器会显示自己的完整路径和它期望找到的 Python 路径。

### 提示 8188 端口被占用

通常表示另一份 ComfyUI 已经在运行。新版启动器会先检查
`http://127.0.0.1:8188/system_stats`，确认是 ComfyUI 后直接打开页面。

### 可以暂停下载吗

可以。关闭安装窗口后，稍后重新运行 `00-START-HERE.cmd`。不要手动删除 `.part`
文件，否则会失去断点进度。

### 为什么需要这么多内存和硬盘

模型文件约 44.4GB，并且 8GB 显存无法同时容纳所有模型。生成时需要在显存、系统
内存和页面文件之间换入换出，所以硬盘可用空间、页面文件和内存都很重要。

### 能不能商用

安装器源码采用 MIT 许可证，但 MiniMax H3 模型和输出受单独的模型许可约束。是否
可以商用取决于你的地区、主体、收入规模、用途及获得的授权，不能只看本仓库 MIT。
请阅读 [模型许可说明](MODEL-LICENSE-NOTICE.md)和
[MiniMax H3 上游完整许可](https://huggingface.co/MiniMaxAI/MiniMax-H3/blob/main/LICENSE)。

### 这是破解包吗

不是。本仓库不包含破解程序，不绕过模型许可，也不内置模型权重。ComfyUI、模型、
工作流和 7-Zip 均来自清单中声明的上游地址，并按固定 SHA-256 校验。

### 会不会上传我的提示词或视频

安装器本身不发送项目遥测，也不会自动上传诊断包。模型下载会连接 GitHub、Hugging
Face 和可选的 7-zip.org。诊断脚本默认不收集日志；任何诊断 ZIP 在分享前仍应人工
检查。详见 [PRIVACY.md](PRIVACY.md)。

### 能不能随便更新 ComfyUI

不建议在稳定项目中盲目更新。本安装包固定 ComfyUI 0.34.0 和对应哈希，是为了让
安装结果可复现。更新 ComfyUI、PyTorch 或模型文件都可能改变兼容性，应先备份并作为
新版本重新验证。

## 文件说明

- `00-START-HERE.cmd`：唯一推荐安装入口；
- `01-PREFLIGHT.ps1`：系统、GPU、内存、页面文件、磁盘和网络预检；
- `02-INSTALL.ps1`：断点下载、哈希校验、解压和工作流生成；
- `03-LAUNCH-STABLE.cmd`：日常首选启动模式；
- `04-LAUNCH-BALANCED.cmd`：Stable 成功后的进阶性能模式；
- `05-VERIFY.ps1`：模型、PyTorch CUDA 和 ComfyUI 验证；
- `06-CONFIGURE-OBS-IGPU.ps1`：可选的 AMD 核显 OBS 配置；
- `07-OPEN-PAGEFILE-SETTINGS.cmd`：打开 Windows 虚拟内存设置；
- `08-COLLECT-DIAGNOSTICS.ps1`：生成本地、需人工检查的诊断包；
- `09-MONITOR-GPU.ps1`：记录生成时的显存、利用率、温度和功耗；
- `models-manifest.json`：模型 URL、大小、SHA-256 和存放路径；
- `assets-manifest.json`：ComfyUI、7-Zip、官方工作流和示例素材清单。

## 开源与模型许可边界

本仓库原创安装器代码和文档采用 [MIT License](LICENSE)。这不代表 MiniMax H3
模型权重也采用 MIT。

MiniMax H3 使用单独的 Community License。2026-08-02 版本包含地区、用途、公开
内容披露、再分发和商业条件，并把欧盟、英国、美国和韩国列为排除地区，除非用户另有
授权。安装器只要求用户确认，不会替用户判断所在地或授予任何模型权利。

因此，严谨的描述是：

> “木子不写代码开源了 MiniMax H3 Windows NVIDIA 一键安装器的源码；模型权重不
> 随仓库分发，并继续受 MiniMax H3 上游许可约束。”

不要宣传成“MiniMax H3 模型已经 MIT 开源”或“全球任何地区都能无条件商用”。

## 给大家的一句话

木子不写代码做这个包，不是为了把复杂术语换一种方式堆给大家，而是希望普通创作者
也能用一套可检查、可恢复、可验证的方法，把 MiniMax H3 真正跑在自己的电脑上。

如果你的设备是 RTX 5050 Laptop GPU 8GB 或更高等级，并满足其余硬件要求，就可以
按步骤安装。低于这个基准的 NVIDIA 设备目前属于未测试范围，也欢迎带着完整、已脱敏
的真实出片证据反馈。我们会继续扩大实测设备名单。
