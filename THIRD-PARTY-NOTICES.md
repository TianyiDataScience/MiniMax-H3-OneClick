# Third-party notices

The repository's MIT license applies only to the original installer code and
documentation. Each downloaded or bundled third-party component retains its
own license.

## Downloaded during installation

- **MiniMax H3 model weights** — MiniMax H3 Community License Agreement.
  The weights are not included in this repository. Read
  [MODEL-LICENSE-NOTICE.md](MODEL-LICENSE-NOTICE.md) before use.
- **ComfyUI Windows Portable 0.34.0** — downloaded from the official
  Comfy-Org release. ComfyUI is GPL-3.0; the portable archive also contains
  separately licensed dependencies. Its upstream distribution supplies the
  corresponding notices and source links.
- **7-Zip standalone extractor (`7zr.exe`)** — downloaded unmodified from
  7-zip.org when no installed 7-Zip is found. 7-Zip states that most source is
  GNU LGPL with unRAR restrictions for some code. See the
  [official 7-Zip license](https://www.7-zip.org/license.txt).

## Bundled in this repository

- Two unmodified MiniMax H3 workflow JSON files and the example mouse image
  come from [Comfy-Org/workflow_templates](https://github.com/Comfy-Org/workflow_templates),
  licensed under MIT. The upstream MIT license is reproduced in
  [licenses/WORKFLOW-TEMPLATES-MIT.txt](licenses/WORKFLOW-TEMPLATES-MIT.txt).

## Referenced by the model workflow

- The Qwen3-VL encoder is identified by the MiniMax H3 license as Apache-2.0.
- The LightX2V MiniMax H3 Turbo LoRA repository identifies its license as
  Apache-2.0. This does not replace the base MiniMax H3 model license.

This notice is informational, not legal advice. Review upstream licenses at
the pinned versions before publishing a release.
