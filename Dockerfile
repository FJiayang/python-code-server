# ==============================================================================
# Dockerfile for a professionally architected, optimized code-server environment
#
# Architecture:
# - Installation by 'root': The entire Python/Conda toolchain is installed
#   by the root user into a system-wide location (/opt/conda).
# - Usage by 'coder': The non-root 'coder' user is configured to seamlessly
#   use this immutable, pre-built environment.
#
# Features:
# - Base: code-server (latest)
# - Python: Miniforge (Conda) with a pre-created Python 3.11 environment
# - Package Manager: 'uv' (installed via Conda for consistency)
# - Root & Coder Access: 'python', 'conda', 'uv' are available for all users.
# - Optimization (China):
#   - Timezone: Asia/Shanghai
#   - PyPI Mirror: Alibaba Cloud (configured for the 'coder' user)
# - Pre-installed Libraries: A minimal set (numpy, pandas, matplotlib)
# - Convenience: Auto-activates conda environment for the 'coder' user.
# ==============================================================================

# --- Build Stage ---
# FIX: Use uppercase 'AS' for better style consistency.
FROM codercom/code-server:latest AS builder

# Set arguments for tool versions.
ARG MINIFORGE_VERSION=23.11.0-0
ARG PYTHON_VERSION=3.11

# Define global environment variables for paths and timezone.
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}
ENV TZ=Asia/Shanghai

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
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
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
    # 7. Ensure the 'coder' user home directory exists and has correct ownership.
    && mkdir -p /home/coder && chown -R coder:coder /home/coder \
    \
    # 8. Clean up to reduce image size.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# --- User Configuration Phase (as coder) ---
USER coder

RUN \
    # 1. Create the user-specific mirror configuration for 'uv'.
    mkdir -p ~/.config/uv && \
    printf 'index-url = "https://mirrors.aliyun.com/pypi/simple"\n' > ~/.config/uv/uv.toml && \
    \
    # 2. Configure the user's shell to auto-activate the system-wide environment.
    conda init bash && \
    echo "conda activate py${PYTHON_VERSION}" >> ~/.bashrc


# --- Verification and Final Stage ---
# This stage ensures both root and coder environments are correctly configured.
FROM builder

# Final check as ROOT.
RUN echo "Verifying root environment..." && \
    python --version && \
    conda --version && \
    uv --version && \
    echo "Root environment check PASSED!"

# Final check as CODER.
USER coder
RUN echo "Verifying coder environment..." && \
    ### --- [ THE FINAL FIX IS HERE ] --- ###
    # Use the POSIX-compliant dot ('.') instead of the bash-specific 'source'.
    . ~/.bashrc && \
    python --version && \
    uv --version && \
    echo "Coder environment check PASSED!"

# The base image's CMD is inherited automatically.
