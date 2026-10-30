#!/bin/bash
# ---------------------------------------------------------
# GPU Research Environment Setup (Miniforge, PyTorch, JupyterLab)
# ---------------------------------------------------------
# Safe to re-run: every step checks current state before changing anything.
#
# Provides the shared base every research project on this machine needs:
# - nvtop for watching the GPU
# - Miniforge (conda + mamba) in ~/miniforge3, hooked into ~/.bashrc
#   (base env is NOT auto-activated)
# - A "research" conda env: scientific Python, JupyterLab, and PyTorch built
#   for CUDA 12.8+. PyTorch wheels bundle their own CUDA runtime, so they only
#   need the driver, not the system CUDA toolkit.
# - research-jupyter: starts JupyterLab in a detached screen session, bound to
#   localhost only (reach it with: ssh -L 8888:localhost:8888 <host>)
# - research-gpu-check: confirms PyTorch can actually compute on the GPU
#
# Project-specific tools (OpenMM, ESM, simglucose, ...) go in per-project envs.
set -e # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if config.env exists
if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

TARGET_USER="${DEV_USER:-$USER}"
TARGET_HOME=$(eval echo "~${TARGET_USER}")
CONDA_DIR="${TARGET_HOME}/miniforge3"
RESEARCH_ENV="${RESEARCH_ENV:-research}"
# PyTorch wheel index; cu128 is the oldest CUDA build that supports Blackwell (RTX 50xx).
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu128}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"

export DEBIAN_FRONTEND=noninteractive

echo "========================================================================"
echo "Setting up GPU research environment for user: ${TARGET_USER}"
echo "========================================================================"

echo "--- Installing system tools ---"
sudo apt-get install -y nvtop screen curl

echo "--- Installing Miniforge ---"
if [ -x "${CONDA_DIR}/bin/conda" ]; then
    echo "Miniforge already installed at ${CONDA_DIR}."
else
    TMP_SH=$(mktemp --suffix=.sh)
    curl -fsSL "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-$(uname -m).sh" -o "${TMP_SH}"
    bash "${TMP_SH}" -b -p "${CONDA_DIR}"
    rm -f "${TMP_SH}"
fi
"${CONDA_DIR}/bin/conda" config --set auto_activate false

if ! grep -q "miniforge3/etc/profile.d/conda.sh" "${TARGET_HOME}/.bashrc"; then
    echo "Adding conda hook to ${TARGET_HOME}/.bashrc"
    cat << 'EOF' >> "${TARGET_HOME}/.bashrc"

# Miniforge (conda/mamba); run "conda activate research" to use the research env
if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniforge3/etc/profile.d/conda.sh"
fi
EOF
fi

echo "--- Creating '${RESEARCH_ENV}' conda env ---"
if [ -d "${CONDA_DIR}/envs/${RESEARCH_ENV}" ]; then
    echo "Env '${RESEARCH_ENV}' already exists."
else
    "${CONDA_DIR}/bin/mamba" create -y -n "${RESEARCH_ENV}" -c conda-forge \
        python=3.12 numpy pandas scipy scikit-learn matplotlib seaborn \
        jupyterlab ipykernel ipywidgets tqdm requests pyarrow
fi
ENV_PY="${CONDA_DIR}/envs/${RESEARCH_ENV}/bin/python"

echo "--- Installing PyTorch (${TORCH_INDEX_URL}) ---"
if "${ENV_PY}" -c "import torch" &> /dev/null; then
    echo "PyTorch $("${ENV_PY}" -c 'import torch; print(torch.__version__)') already installed."
else
    "${ENV_PY}" -m pip install torch torchvision --index-url "${TORCH_INDEX_URL}"
fi

echo "--- Installing helper commands to ${TARGET_HOME}/.local/bin ---"
mkdir -p "${TARGET_HOME}/.local/bin"

cat << EOF > "${TARGET_HOME}/.local/bin/research-jupyter"
#!/bin/bash
# Start JupyterLab in a detached screen session named "jupyter".
# Localhost only; from a laptop: ssh -L ${JUPYTER_PORT}:localhost:${JUPYTER_PORT} \$(hostname)
if screen -list | grep -q "\.jupyter\b"; then
    echo "JupyterLab already running (attach with: screen -r jupyter)"
else
    screen -dmS jupyter "${CONDA_DIR}/envs/${RESEARCH_ENV}/bin/jupyter" lab \\
        --no-browser --ip=127.0.0.1 --port=${JUPYTER_PORT} --notebook-dir="${TARGET_HOME}/projects"
    sleep 3
fi
"${CONDA_DIR}/envs/${RESEARCH_ENV}/bin/jupyter" server list
EOF

cat << EOF > "${TARGET_HOME}/.local/bin/research-gpu-check"
#!/bin/bash
# Confirm PyTorch in the research env can compute on the GPU.
exec "${ENV_PY}" - << 'PYEOF'
import time
import torch

assert torch.cuda.is_available(), "PyTorch cannot see the GPU"
dev = torch.device("cuda")
props = torch.cuda.get_device_properties(dev)
print(f"torch {torch.__version__} (CUDA {torch.version.cuda})")
print(f"{props.name}: {props.total_memory / 2**30:.1f} GiB, compute capability {props.major}.{props.minor}")

x = torch.randn(8192, 8192, device=dev, dtype=torch.bfloat16)
torch.cuda.synchronize()
start = time.time()
for _ in range(10):
    y = x @ x
torch.cuda.synchronize()
tflops = 10 * 2 * 8192**3 / (time.time() - start) / 1e12
print(f"bf16 matmul: {tflops:.1f} TFLOPS")
print("GPU check passed.")
PYEOF
EOF

chmod +x "${TARGET_HOME}/.local/bin/research-jupyter" "${TARGET_HOME}/.local/bin/research-gpu-check"

echo "--- Verifying GPU access ---"
"${TARGET_HOME}/.local/bin/research-gpu-check"

echo "========================================================================"
echo "🎉 GPU Research Environment Setup Complete!"
echo "  conda activate ${RESEARCH_ENV}        # use the env (new shells)"
echo "  research-jupyter                 # start JupyterLab in screen"
echo "  research-gpu-check               # re-test the GPU"
echo "========================================================================"
