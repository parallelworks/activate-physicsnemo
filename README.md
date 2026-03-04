# ACTIVATE PhysicsNemo

Run NVIDIA PhysicsNemo examples on GPU clusters via the ACTIVATE platform.

## Features

- **Curated examples** tuned for A30 24GB GPUs - works out-of-the-box
- **Custom script mode** for advanced users
- **Pre-flight checks** - GPU memory, Docker daemon, disk space
- **Output collection** - plots, metrics, and training summaries
- **SLURM/PBS support** via `job_runner` marketplace action

## Curated Examples

| Example | Method | Data | Runtime (A30) |
|---------|--------|------|---------------|
| Darcy Flow (FNO) | Fourier Neural Operator | Generated on-the-fly | ~10 min |
| Lid-Driven Cavity (PINNs) | Physics-Informed NN | None (physics-only) | ~15 min |
| Gray-Scott RNN | Recurrent NN | Generated | ~20 min |
| Darcy Flow (PINO) | Physics-Informed NO | Generated + physics | ~15 min |
| Vortex Shedding (MeshGraphNet) | Graph Neural Network | Included | ~25 min |

## Usage

1. Select a GPU cluster resource
2. Choose a curated example or paste a custom script
3. (Optional) Override training epochs or batch size
4. Run the workflow

Outputs (plots, metrics) are collected to the `outputs/` directory.

## Custom Script Mode

Write any bash script to run inside the PhysicsNemo container. The working directory is `/workspace`. Example:

```bash
#!/bin/bash
git clone --depth 1 https://github.com/NVIDIA/PhysicsNemo.git /workspace/PhysicsNemo
cd /workspace/PhysicsNemo/examples/cfd/ldc_pinns
python -u train.py
```

## Container

Default image: `nvcr.io/nvidia/physicsnemo/physicsnemo:25.11`

Supports both sudo Docker and rootless Docker modes.
