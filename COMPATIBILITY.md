# Compatibility and support matrix

## Support levels

`Verified baseline` means a complete installation, CUDA probe, native MiniMax
H3 load, and real video generation were observed on that exact configuration.
`Supported` means the NVIDIA RTX model tier is at least the verified RTX 5050
Laptop GPU 8 GB baseline and all hard requirements are met. `Untested` covers
lower NVIDIA tiers that may pass preflight but have no project evidence.
`Unsupported` means this installer intentionally rejects or does not configure
that platform; it does not mean ComfyUI itself cannot run there by another
installation method.

| Platform or device | Status | Exact scope |
|---|---|---|
| HP Victus by HP Gaming Laptop 15-fb3xxx (Ryzen 5 240, **RTX 5050 Laptop GPU 8 GB**, Radeon 760M, 24 GB RAM), Windows 11 x64 build 26200 | Verified baseline | Driver 592.82, compute capability 12.0. Install, SHA-256 verification, CUDA, T2V/I2V, 480p and 1344x768 workflows, and concurrent OBS offload were exercised. |
| Windows 10/11 x64 laptops with an NVIDIA RTX Laptop GPU at or above the RTX 5050 Laptop GPU 8 GB tier | Supported | Must still have at least 8 GB VRAM, R580+ driver, 24 GB recommended RAM, adequate page file and disk space. Laptop power limits and cooling affect speed. |
| Windows 10/11 x64 desktops with an RTX GPU equivalent to or above the RTX 5050 baseline | Supported | Must meet the same VRAM, driver, RAM, page-file and disk requirements. |
| NVIDIA GPU below the RTX 5050 Laptop baseline but still Turing-or-newer with at least 8 GB VRAM | Untested | Preflight may allow installation, but this project currently makes no speed or stability commitment for lower tiers. |
| NVIDIA GPU with less than 8 GB VRAM | Unsupported by this installer | Preflight stops. No successful H3 generation has been established for this package. |
| NVIDIA GTX 10 series and older; Volta | Unsupported by this build | The pinned CUDA 13 Windows build requires Turing (compute capability 7.5) or newer. A different CUDA 12.6/manual ComfyUI installation is a separate project. |
| AMD discrete GPU or AMD-only APU | Unsupported | This package downloads the NVIDIA Windows Portable runtime and requires `nvidia-smi`. Radeon 760M is used only as an optional OBS/display offload device. |
| Intel Arc / Intel-only graphics | Unsupported | No XPU runtime or Intel workflow is installed. |
| Apple Silicon or Intel Mac | Unsupported | The entry points are Windows CMD/PowerShell and the runtime is Windows NVIDIA Portable. |
| Linux, WSL, containers | Unsupported | No Linux Python, CUDA, path, service, or package-management flow is provided or tested. |
| CPU-only | Unsupported | Although ComfyUI has CPU mode, this installer requires CUDA and the H3 workflow has not been validated on CPU. |
| Phones, tablets, consoles, NAS devices | Unsupported | There is no native package or remote-server setup for these devices. |

## Hard requirements enforced by preflight

- Windows 10 or 11, 64-bit. Only Windows 11 has been verified by this project.
- NVIDIA GPU with compute capability 7.5 or newer and at least 7,500 MiB as
  reported by `nvidia-smi` (marketed 8 GB class or higher).
- NVIDIA driver branch R580 or newer for the pinned CUDA 13 runtime.
- At least 16 GB system RAM to pass; 24 GB or more is the supported target.
  A 16-23 GB machine receives a warning and is not a verified configuration.
- System-managed page file, or a manually allocated page file of at least
  32 GiB.
- At least 65 GiB free disk space; 90 GiB or more recommended.
- Short, ASCII-only installation path, for example `C:\AI\MiniMax-H3`.
- Network access to GitHub and Hugging Face during installation.

On a multi-NVIDIA-GPU system, preflight selects the compatible GPU with the
most VRAM and writes its physical index to `runtime\selected-gpu.txt`.
Launchers expose that device through `CUDA_VISIBLE_DEVICES`; verification uses
the same selection.

The integrated GPU is not an H3 requirement. It is only useful for moving OBS
encoding and desktop rendering away from the NVIDIA GPU. Supported NVIDIA-only
laptops and desktops can run without an AMD iGPU, but simultaneous recording
may reduce available VRAM.

## Evidence boundary

The exact measured reference machine is the RTX 5050 Laptop GPU 8 GB system
listed above. Higher-tier supported devices are expected to meet or exceed the
GPU baseline, while real speed still varies with VRAM, laptop TGP, cooling,
system RAM and storage. New measured configurations can be added to the table
after a saved 5-second H3 MP4 and clean diagnostics report are provided.
