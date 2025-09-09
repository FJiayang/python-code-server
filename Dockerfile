# ==============================================================================
# Dockerfile for a feature-rich, optimized code-server development environment
#
# Features:
# - Base: code-server (latest)
# - Python: Miniforge (Conda) with a pre-created Python 3.11 environment
# - Package Manager: 'uv' (ultra-fast) and 'conda'
# - Optimization (China):
#   - Timezone: Asia/Shanghai
#   - PyPI Mirror: Alibaba Cloud (for uv/pip)
#   - Conda Mirror: TUNA (Tsinghua University)
# - Convenience: Auto-activates conda environment in the terminal
# ==============================================================================

# Step 1: Start from the official code-server base image.
FROM codercom/code-server:latest

# Step 2: Set arguments for tool versions for easy updates.
ARG MINIFORGE_VERSION=23.11.0-0
ARG PYTHON_VERSION=3.11

# Step 3: Define environment variables for paths and configurations.
ENV CONDA_DIR=/opt/conda
ENV UV_DIR=/home/coder/.local
# Add bin directories of Conda and UV to the system's PATH.
ENV PATH=${CONDA_DIR}/bin:${UV_DIR}/bin:${PATH}
# Set the timezone.
ENV TZ=Asia/Shanghai
# Configure UV/pip to use the Alibaba Cloud mirror.
ENV UV_INDEX_URL=https://mirrors.aliyun.com/pypi/simple

# Step 4: Switch to the ROOT user for system-level installations.
USER root

# Step 5: Install system dependencies, set timezone, install and configure Conda.
RUN \
    # Update package lists and install necessary tools.
    apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        git \
        build-essential \
        tzdata \
    # Set the timezone non-interactively.
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # Download and install Miniforge.
    && wget "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" -O miniforge.sh \
    && /bin/bash miniforge.sh -b -p ${CONDA_DIR} \
    && rm miniforge.sh \
    # Give the 'coder' user ownership of the conda directory.
    && chown -R coder:coder ${CONDA_DIR} \
    # Create symbolic links for 'conda' and 'python3' to be accessible by root for debugging.
    && ln -s ${CONDA_DIR}/bin/conda /usr/local/bin/conda \
    && ln -s ${CONDA_DIR}/bin/python /usr/local/bin/python3 \
    # Clean up apt cache to reduce image size.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Step 6: Switch back to the standard, non-root 'coder' user.
USER coder

# Step 7: As the 'coder' user, configure tools and create the development environment.
RUN \
    # Install 'uv' (the fast Python package manager).
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # Configure Conda to use Tsinghua University mirrors for faster package downloads.
    # We add our desired channels first.
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/conda-forge/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r/ && \
    conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2/ && \
    # --- [ THE FIX IS HERE ] ---
    # Then, we tell conda to NOT use the built-in 'defaults' channels.
    conda config --set nodefaults true && \
    # (Optional) We can verify the channel configuration.
    conda config --set show_channel_urls true && \
    \
    # Create the default conda environment. This will be fast due to the mirror.
    conda create -n py${PYTHON_VERSION} python=${PYTHON_VERSION} -y && \
    \
    # Pre-install common Python packages into the new environment using 'uv'.
    # This will use the Alibaba Cloud PyPI mirror configured via ENV var.
    uv pip install --python=${CONDA_DIR}/envs/py${PYTHON_VERSION}/bin/python \
        numpy \
        pandas \
        matplotlib \
        scikit-learn \
        jupyterlab \
        requests && \
    \
    # Configure the shell to automatically activate this environment on login.
    echo "conda activate py${PYTHON_VERSION}" >> ~/.bashrc

# Step 8: The base image's entrypoint will automatically start code-server.
# All our PATH and environment variable configurations will be inherited by the application.
