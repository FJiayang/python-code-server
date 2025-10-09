# ==============================================================================
# Dockerfile for a "Batteries-Included", professional, and optimized code-server environment
#
# Architecture:
# - Installation by 'root': The entire Python/Conda toolchain is installed system-wide.
# - Usage by 'coder': The non-root 'coder' user uses this immutable environment.
#
# Features:
# - Base: code-server (latest)
# - IDE Enhancement: Pre-installs essential Python VS Code extensions.
# - Python: Miniforge (Conda) with a pre-created Python 3.11 environment.
# - Package Manager: 'uv' (installed via Conda).
# - Root & Coder Access: All tools are available for all users.
# - Optimization (China): Timezone set to Asia/Shanghai, PyPI mirror configured.
# - Pre-installed Libraries: A minimal set (numpy, pandas, matplotlib).
# - Extensions Persistence: Extensions installed to system-wide location.
# ==============================================================================

# --- Build Stage ---
FROM codercom/code-server:latest AS builder

# Set arguments for tool versions.
ARG MINIFORGE_VERSION=23.11.0-0
ARG PYTHON_VERSION=3.11
ARG NODE_VERSION=20

# Define global environment variables for paths and timezone.
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}
ENV TZ=Asia/Shanghai
# 设置扩展安装到系统目录
ENV VSCODE_EXTENSIONS_DIR=/opt/code-server/extensions

# --- Installation Phase (as root) ---
USER root

RUN \
    # 1. Install system dependencies.
    apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        git \
        build-essential \
        tzdata \
        ca-certificates \
        gnupg \
    \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    \
    # Install Node.js from official repository.
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    \
    # 2. Install Miniforge (Conda).
    && wget "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" -O miniforge.sh \
    && /bin/bash miniforge.sh -b -p ${CONDA_DIR} \
    && rm miniforge.sh \
    \
    # 3. Initialize Conda for the root's shell.
    && conda init bash && . /root/.bashrc \
    \
    # 4. Install 'uv' into the base conda environment.
    && conda install -n base uv -c conda-forge -y \
    \
    # 5. Create the target Python environment.
    && conda create -n py${PYTHON_VERSION} python=${PYTHON_VERSION} -y \
    \
    # 6. Install core libraries into the new environment.
    && uv pip install --python=${CONDA_DIR}/envs/py${PYTHON_VERSION}/bin/python \
        numpy \
        pandas \
        matplotlib \
    \
    # 7. Create system-wide extensions directory
    && mkdir -p ${VSCODE_EXTENSIONS_DIR} \
    && chmod 755 ${VSCODE_EXTENSIONS_DIR} \
    \
    # 8. Ensure the 'coder' user home directory exists and has correct ownership.
    && mkdir -p /home/coder && chown -R coder:coder /home/coder \
    \
    # 9. Clean up to reduce image size.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Extensions Installation Phase (as root) ---
# 以 root 身份安装扩展到系统目录
RUN \
    # 安装 Python 相关扩展到系统目录
    code-server --extensions-dir=${VSCODE_EXTENSIONS_DIR} \
                --install-extension ms-python.python \
                --install-extension detachhead.basedpyright \
                --install-extension ms-python.autopep8 \
                --install-extension ms-python.flake8 \
    \
    # 设置扩展目录权限，让 coder 用户也能读取
    && chown -R root:root ${VSCODE_EXTENSIONS_DIR} \
    && chmod -R 755 ${VSCODE_EXTENSIONS_DIR}

# --- User Configuration Phase (as coder) ---
USER coder

RUN \
    # 1. Create the user-specific mirror configuration for 'uv'.
    mkdir -p ~/.config/uv && \
    printf 'index-url = "https://mirrors.aliyun.com/pypi/simple"\n' > ~/.config/uv/uv.toml && \
    \
    # 2. 创建 code-server 配置目录和配置文件
    mkdir -p ~/.config/code-server && \
    printf 'bind-addr: 0.0.0.0:8080\nauth: none\ncert: false\nextensions-dir: %s\n' "${VSCODE_EXTENSIONS_DIR}" > ~/.config/code-server/config.yaml && \
    \
    # 3. Configure the user's shell to auto-activate the system-wide environment.
    conda init bash && \
    echo "conda activate py${PYTHON_VERSION}" >> ~/.bashrc

# --- Verification and Final Stage ---
FROM builder

# Final check as ROOT.
RUN echo "Verifying root environment..." && \
    python --version && \
    conda --version && \
    uv --version && \
    npm -v && \
    node -v && \
    echo "Installed extensions:" && \
    ls -la ${VSCODE_EXTENSIONS_DIR} && \
    echo "Root environment check PASSED!"

# Final check as CODER.
USER coder
RUN echo "Verifying coder environment..." && \
    . ~/.bashrc && \
    python --version && \
    uv --version && \
    echo "Extensions directory accessible:" && \
    ls -l ${VSCODE_EXTENSIONS_DIR} && \
    echo "Code-server config:" && \
    cat ~/.config/code-server/config.yaml && \
    echo "Coder environment check PASSED!"

# The base image's CMD is inherited automatically.
