# Code-Server: 你的专业级 Python 云端 IDE

![Docker Build](https://img.shields.io/docker/v/codercom/code-server?label=code-server&style=for-the-badge) ![Python Version](https://img.shields.io/badge/Python-3.11-blue?style=for-the-badge&logo=python) ![Conda](https://img.shields.io/badge/Conda-Miniforge-green?style=for-the-badge&logo=conda-forge) ![uv](https://img.shields.io/badge/uv-极速安装器-purple?style=for-the-badge)

本项目提供了一个专业、开箱即用的 Docker 配置，用于构建一个私有的、基于 Web 的 Python 开发环境。它使用 `code-server`，让你在浏览器中即可获得功能齐全的 IDE 体验，是大型项目中替代 JupyterLab 的强大选择。

最终生成的 Docker 镜像轻量、快速，并为国内用户进行了网络优化。其清晰的架构设计将系统管理与日常开发任务分离，保证了环境的稳定与安全。

## 🌟 核心特性

-   **浏览器中的全功能 IDE**：获得完整的 VS Code 体验，包括文件浏览器、终端、调试器和扩展商店，随时随地访问。
-   **专业的架构设计**：
    -   **不可变的基础环境**：整个 Python 工具链（Conda、uv、核心库）由 `root` 用户安装，创建了一个稳定、系统级的环境。
    -   **安全的用户隔离**：你将以一个非 `root` 的 `coder` 用户身份工作，防止意外修改基础环境，增强了安全性。
-   **性能与网络优化**：
    -   **`uv` 极速安装**：使用 `uv`——一个用 Rust 编写的极速 Python 包安装器——来管理所有软件包。
    -   **为中国大陆优化**：
        -   **PyPI 镜像**：`uv` 已预先配置为使用阿里云 PyPI 镜像，极大地加速了包的下载速度。
        -   **时区**：容器的默认时区已设置为 `Asia/Shanghai`（北京时间）。
-   **Conda 驱动**：
    -   使用 `Miniforge` 作为最小化的、`conda-forge` 优先的 Conda 发行版。
    -   一个名为 `py3.11` 的 Conda 环境已被预先创建，并在终端中自动激活。
-   **轻量且即用**：
    -   仅预装了最核心的数据科学库（`numpy`、`pandas`、`matplotlib`），以保持镜像的轻量。
    -   你可以随时使用 `uv pip install` 轻松添加更多库。
-   **内置验证**：`Dockerfile` 包含一个带有自动化检查的多阶段构建流程，确保 `root` 和 `coder` 用户的环境都配置正确，保证了最终镜像的可靠性。

## 🚀 快速开始

本配置推荐使用 `docker-compose` 进行部署，以便于管理和数据持久化。

### 先决条件

-   [Docker](https://www.docker.com/get-started)
-   [Docker Compose](https://docs.docker.com/compose/install/)

### 1. 准备项目文件

为你的项目创建一个目录，并将提供的 `Dockerfile` 和下面的 `docker-compose.yml` 文件放入其中。

```bash
mkdir my-cloud-ide
cd my-cloud-ide
# 在这里创建 Dockerfile 和 docker-compose.yml
```

### 2. `docker-compose.yml`

创建一个名为 `docker-compose.yml` 的文件，并填入以下内容。

```yaml
version: '3.8'

services:
  code-server:
    # 从本地的 Dockerfile 构建镜像
    build: .
    # 为生成的镜像命名
    image: my-dev-server:latest
    container_name: vscode-server
    
    # 设置你的登录密码。请务必修改！
    environment:
      - PASSWORD=your_super_strong_password
      
    # 用于数据持久化的卷
    volumes:
      # 持久化 IDE 的设置和插件
      - ./config:/home/coder/.local/share/code-server
      # 持久化你的项目文件
      - ./projects:/home/coder/project
      
    # 端口映射: <宿主机端口>:<容器端口>
    ports:
      - "8080:8080"
      
    # 确保容器在退出后能自动重启
    restart: always
    
    # (推荐) 避免挂载卷时的文件权限问题
    user: "${UID}:${GID}"
```

### 3. 构建并启动

在你的 `my-cloud-ide` 目录下，运行以下命令：

```bash
docker-compose up -d --build
```

-   `--build`：告诉 Docker Compose 首次运行时从你的 `Dockerfile` 构建镜像。
-   `-d`：在后台（分离模式）运行容器。

构建过程可能需要几分钟，因为它需要下载和安装所有环境。

### 4. 访问你的 IDE

-   打开你的浏览器，访问 `http://<你的服务器IP>:8080`。
-   使用你在 `docker-compose.yml` 文件中设置的密码登录。
-   大功告成！你会在左侧文件浏览器中看到一个名为 `project` 的文件夹，它已链接到你宿主机上的 `projects` 目录。

## 🛠️ 使用与自定义

### 安装新的 Python 包

这个环境被设计为最小化。要安装新的包，只需在 `code-server` 的集成终端中执行 `uv` 命令：

```bash
# py3.11 环境已被自动激活
uv pip install scikit-learn jupyterlab
```
得益于预先配置的镜像源，安装过程将会非常迅速。

### 以 `root` 用户身份进入容器

如果需要进行调试或系统管理，你可以以 `root` 用户的身份进入容器。环境已被配置，`root` 用户同样可以访问所有 Python 工具。

```bash
docker exec -it vscode-server /bin/bash
```

你将会进入一个 `root` 用户的 Shell，在这里 `python`、`conda` 和 `uv` 命令都已可用。

### 自定义 `Dockerfile`

提供的 `Dockerfile` 具有详细的注释，易于修改。

-   **更改 Python 版本**：修改 `PYTHON_VERSION` 参数。
-   **预装更多库**：在 `Dockerfile` 的 `uv pip install` 命令中添加更多的包。
-   **添加系统依赖**：在 `apt-get install` 命令中添加新的系统包。

修改完成后，只需再次运行 `docker-compose up -d --build`，即可用新的配置重新构建你的镜像。
