# ==============================================================================
# Dockerfile for a LIGHTWEIGHT, professional, and optimized code-server environment
#
# Features:
# - Base: code-server (latest)
# - Python: Miniforge (Conda) with a pre-created Python 3.11 environment
# - Package Manager: 'uv' (ultra-fast) and 'conda'
# - Optimization (China):
#   - Timezone: Asia/Shanghai
#   - PyPI Mirror: Alibaba Cloud (configured via uv.toml - BEST PRACTICE)
# - Pre-installed Libraries: A minimal set (numpy, pandas, matplotlib)
# - Convenience: Auto-activates conda environment in the terminal
# ==============================================================================

# Step 1: Start from the official code-server base image.
FROM codercom/code-server:latest

# Step 2: Set arguments for tool versions for easy updates.
ARG MINIFORGE_VERSION=23.11.0-0
ARG PYTHON_VERSION=3.11

# Step 3: Define environment variables for paths and timezone.
ENV CONDA_DIR=/opt/conda
ENV UV_DIR=/home/coder/.local
ENV PATH=${CONDA_DIR}/bin:${UV_DIR}/bin:${PATH}
ENV TZ=Asia/Shanghai

# Step 4: Switch to the ROOT user for system-level installations.
USER root

# Step 5: Install system dependencies, set timezone, and install Miniforge.
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
    # Create symbolic links for 'conda' and 'python3' for easier root access (debugging).
    && ln -s ${CONDA_DIR}/bin/conda /usr/local/bin/conda \
    && ln -s ${CONDA_DIR}/bin/python /usr/local/bin/python3 \
    # Clean up apt cache to reduce image size.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Step 6: Switch back to the standard, non-root 'coder' user.
USER coder

# Step 7: As the 'coder' user, install 'uv', configure it, and create the environment.
RUN \
    # Install 'uv' (the fast Python package manager).
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # Create the configuration directory for uv.
    mkdir -p ~/.config/uv && \
    \
    ### --- [ THE FIX IS HERE - Using a more robust method ] --- ###
    # Create the uv.toml file using a "here document", which is reliable across all shells.
    cat <<EOF > ~/.config/uv/uv.toml && \
[tool.uv]
index-url = "https://mirrors.aliyun.com/pypi/simple"
EOF
    \
    # Create the default conda environment.
    conda create -n py${PYTHON_VERSION} python=${PYTHON_VERSION} -y && \
    \
    # Pre-install a minimal set of core data science libraries.
    uv pip install --python=${CONDA_DIR}/envs/py${PYTHON_VERSION}/bin/python \
        numpy \
        pandas \
        matplotlib && \
    \
    # Configure the shell to automatically activate this environment on login.
    echo "conda activate py${PYTHON_VERSION}" >> ~/.bashrc

# Step 8: The base image's entrypoint will start code-server.
