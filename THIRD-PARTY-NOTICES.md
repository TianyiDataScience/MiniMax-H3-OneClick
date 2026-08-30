# 第三方组件与许可声明

本仓库的 MIT 许可证只适用于本项目原创的一键安装器代码和文档。下载或随仓库提供的第三方组件，继续适用各自原有的许可证；本项目不会把它们重新许可为 MIT。

## 安装过程中下载的第三方内容

- **MiniMax H3 模型权重**：适用 MiniMax H3 Community License Agreement（MiniMax H3 社区许可协议）。模型权重不包含在本仓库中。使用前必须阅读[模型许可特别说明](MODEL-LICENSE-NOTICE.md)。
- **ComfyUI Windows Portable 0.34.0**：从 Comfy-Org 官方发布页面下载。ComfyUI 采用 GPL-3.0 许可证；便携压缩包还包含分别采用其他许可证的依赖项。相应声明和源码链接由上游发行包提供。
- **7-Zip 独立解压程序 `7zr.exe`**：当电脑没有安装 7-Zip 时，本安装器会从 7-zip.org 原样下载。7-Zip 官方说明其大部分源码采用 GNU LGPL，部分代码受到 unRAR 限制。详情请阅读[7-Zip 官方许可文件](https://www.7-zip.org/license.txt)。

## 随本仓库提供的第三方内容

- 两个未经修改的 MiniMax H3 工作流 JSON 文件和鼠标示例图片来自 [Comfy-Org/workflow_templates](https://github.com/Comfy-Org/workflow_templates)，采用 MIT 许可证。上游 MIT 许可证原文保存在 [licenses/WORKFLOW-TEMPLATES-MIT.txt](licenses/WORKFLOW-TEMPLATES-MIT.txt)。

## 模型工作流引用的第三方项目

- MiniMax H3 许可文件将 Qwen3-VL 编码器标记为 Apache-2.0 许可。
- LightX2V MiniMax H3 Turbo LoRA 仓库标记为 Apache-2.0 许可。这个许可不会取代 MiniMax H3 基础模型自身的许可。

## 使用者需要注意

本声明只用于帮助识别第三方组件，不构成法律意见。发布安装包、模型或生成内容前，请按本项目固定的版本重新检查所有上游许可证；许可证要求发生变化时，以上游最新正式文本为准。
