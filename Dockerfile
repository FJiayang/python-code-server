#
# Dockerfile for a feature-rich code-server with Conda and UV
# Pre-configured for Asia/Shanghai timezone and Alibaba Cloud PyPI mirror.
#

# Step 1: Start from the official code-server base image.
FROM codercom/code-server:latest

# Step 2: Set arguments for tool versions.
ARG MINIFORGE_VERSION=23.11.0-0
ARG PYTHON_VERSION=3.11

# Step 3: Define environment variables for tool paths and configurations.
ENV CONDA_DIR=/opt/conda
ENV UV_DIR=/home/coder/.local
# Add bin directories to the system PATH.
ENV PATH=${CONDA_DIR}/bin:${UV_DIR}/bin:${PATH}
# CRITICAL: Set the timezone environment variable.
ENV TZ=Asia/Shanghai
# CRITICAL: Configure UV to use the Alibaba Cloud mirror by default.
ENV UV_INDEX_URL=https://mirrors.aliyun.com/pypi/simple

# Step 4: Switch to the ROOT user for system-level installations.
USER root

# Step 5: Install system dependencies, set timezone, and install Miniforge.
RUN \
    # Update package lists and install necessary tools
    apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        git \
        build-essential \
        tzdata \
    # Set the timezone non-interactively
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # Download and install Miniforge
    && wget "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" -O miniforge.sh \
    && /bin/bash miniforge.sh -b -p ${CONDA_DIR} \
    && rm miniforge.sh \
    # Give the 'coder' user ownership of the conda directory
    && chown -R coder:coder ${CONDA_DIR} \
    # Clean up apt cache to keep the image size down
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Step 6: Switch back to the standard, non-root 'coder' user.
USER coder

# Step 7: As the 'coder' user, install user-specific tools and set up the default environment.
RUN \
    # Install 'uv' using its official script
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # Create a default conda environment
    conda create -n py${PYTHON_VERSION} python=${PYTHON_VERSION} -y && \
    \
    # Pre-install common packages into the new environment using 'uv'.
    # This will now automatically use the Alibaba Cloud mirror due to the ENV var.
    uv pip install --python=${CONDA_DIR}/envs/py${PYTHON_VERSION}/bin/python \
        numpy \
        pandas \
        matplotlib \
        scikit-learn \
        jupyterlab && \
    \
    # Configure the shell to automatically activate this environment on login
    echo "conda activate py${PYTHON_VERSION}" >> ~/.bashrc

# Step 8: The base image's entrypoint will start code-server.
# All environment variables (TZ, UV_INDEX_URL, PATH) will be inherited.
