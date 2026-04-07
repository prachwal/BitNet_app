FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    software-properties-common \
    wget \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh && \
    bash /tmp/llvm.sh 18 all && \
    rm -f /tmp/llvm.sh

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 180 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 180

WORKDIR /opt
RUN git clone --recursive https://github.com/microsoft/BitNet.git
WORKDIR /opt/BitNet

RUN perl -0pi -e 's/@Model\.register\("BitnetForCausalLM"\)/@Model.register("BitnetForCausalLM", "BitNetForCausalLM")/' utils/convert-hf-to-gguf-bitnet.py
RUN python3 - <<'PY'
from pathlib import Path

path = Path("/opt/BitNet/utils/convert-hf-to-gguf-bitnet.py")
text = path.read_text()
old = """    def set_vocab(self):\n        self._set_vocab_sentencepiece()\n"""
new = """    def set_vocab(self):\n        try:\n            self._set_vocab_sentencepiece()\n        except FileNotFoundError:\n            try:\n                self._set_vocab_llama_hf()\n            except (FileNotFoundError, TypeError):\n                self._set_vocab_gpt2()\n"""
if old not in text:
    raise SystemExit("expected BitnetModel.set_vocab block not found")
path.write_text(text.replace(old, new, 1))
PY
RUN python3 - <<'PY'
from pathlib import Path

path = Path("/opt/BitNet/utils/convert-hf-to-gguf-bitnet.py")
text = path.read_text()
old = """    def write_tensors(self):\n        max_name_len = max(len(s) for _, s in self.tensor_map.mapping.values()) + len(\".weight,\")\n\n        for name, data_torch in self.get_tensors():\n"""
new = """    def write_tensors(self):\n        max_name_len = max(len(s) for _, s in self.tensor_map.mapping.values()) + len(\".weight,\")\n\n        scale_map = dict()\n\n        for name, data_torch in self.get_tensors():\n            if name.endswith((\"weight_scale\")):\n                data_torch = data_torch.to(torch.float32)\n                name = name.replace(\".weight_scale\", \"\")\n                scale_map[name] = data_torch\n\n        for name, data_torch in self.get_tensors():\n            if name.endswith((\"weight_scale\")):\n                continue\n"""
if old not in text:
    raise SystemExit("expected BitnetModel.write_tensors header not found")
path.write_text(text.replace(old, new, 1))
PY
RUN python3 - <<'PY'
from pathlib import Path

path = Path("/opt/BitNet/utils/convert-hf-to-gguf-bitnet.py")
text = path.read_text()
old = """            # use the first number-like part of the tensor name as the block id\n            bid = None\n"""
new = """            if name.replace(\".weight\", \"\") in scale_map:\n                data_torch = data_torch.to(torch.uint8)\n                origin_shape = data_torch.shape\n                shift = torch.tensor([0, 2, 4, 6], dtype=torch.uint8).reshape((4, *(1 for _ in range(len(origin_shape)))))\n                data_torch = data_torch.unsqueeze(0).expand((4, *origin_shape)) >> shift\n                data_torch = data_torch & 3\n                data_torch = (data_torch.float() - 1).reshape((origin_shape[0] * 4, *origin_shape[1:]))\n                data_torch = data_torch / scale_map[name.replace(\".weight\", \"\")].float()\n\n            # use the first number-like part of the tensor name as the block id\n            bid = None\n"""
if old not in text:
    raise SystemExit("expected BitnetModel scale insertion point not found")
path.write_text(text.replace(old, new, 1))
PY
RUN perl -0pi -e 's/^(\s*)int8_t \* y_col = y \+ col \* by;/$1const int8_t * y_col = y + col * by;/m' src/ggml-bitnet-mad.cpp

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
RUN pip install --upgrade pip && \
    pip install -r requirements.txt
RUN python3 - <<'PY'
import argparse
from pathlib import Path
import setup_env

setup_env.args = argparse.Namespace(
    hf_repo="microsoft/BitNet-b1.58-2B-4T",
    model_dir="/models/bitnet",
    log_dir="logs",
    quant_type="i2_s",
    quant_embd=False,
    use_pretuned=False,
)
Path(setup_env.args.log_dir).mkdir(parents=True, exist_ok=True)
setup_env.logging.basicConfig(level=setup_env.logging.INFO)
setup_env.setup_gguf()
setup_env.gen_code()
setup_env.compile()
PY

COPY docker-entrypoint.sh /usr/local/bin/bitnet-entrypoint.sh
RUN chmod +x /usr/local/bin/bitnet-entrypoint.sh

ENV BITNET_REPO=/opt/BitNet
ENV BITNET_MODEL_REPO=microsoft/bitnet-b1.58-2B-4T-gguf
ENV BITNET_MODEL_DIR=/models/bitnet
ENV BITNET_PROMPT="You are a helpful assistant."
ENV BITNET_CTX_SIZE=2048
ENV BITNET_THREADS=4
ENV BITNET_N_PREDICT=512
ENV BITNET_TEMPERATURE=0.8
ENV BITNET_HOST=0.0.0.0
ENV BITNET_PORT=8080
ENV BITNET_HEALTH_PORT=8081
ENV BITNET_MODE=server
ENV BITNET_QUANT_TYPE=i2_s

VOLUME ["/models"]
EXPOSE 8080 8081

ENTRYPOINT ["/usr/local/bin/bitnet-entrypoint.sh"]
