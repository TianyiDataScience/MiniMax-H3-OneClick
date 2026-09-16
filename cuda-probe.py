"""Small real CUDA check, not a substitute for a successful H3 generation."""
import json
import os

import torch

if not torch.cuda.is_available():
    raise RuntimeError("Embedded PyTorch cannot access CUDA")
properties = torch.cuda.get_device_properties(0)
selected = os.environ.get("CUDA_VISIBLE_DEVICES", "")
actual_uuid = str(properties.uuid)
if selected.removeprefix("GPU-").lower() != actual_uuid.removeprefix("GPU-").lower():
    raise RuntimeError(f"CUDA selected an unexpected GPU: {actual_uuid}")
tested = []
dtypes = [torch.float32, torch.float16]
if properties.major >= 8:
    dtypes.append(torch.bfloat16)
with torch.inference_mode():
    for dtype in dtypes:
        value = torch.ones((32, 32), device="cuda:0", dtype=dtype)
        result = value @ value
        torch.cuda.synchronize()
        if not torch.allclose(result.float(), torch.full_like(result, 32).float()):
            raise RuntimeError(f"CUDA calculation failed for {dtype}")
        tested.append(str(dtype))
print(json.dumps({"torch": torch.__version__, "cuda_runtime": torch.version.cuda,
                  "cuda_available": True, "kernel_ok": True,
                  "device": properties.name, "uuid": actual_uuid,
                  "vram_bytes": properties.total_memory, "tested_dtypes": tested}))
