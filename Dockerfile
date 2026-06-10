# 腾讯云 AGS「自定义沙箱」镜像。
# 基于腾讯官方 sandbox-code base（自带 envd + 代码运行时 + S6-overlay），叠加 AnalysisSitus + OCP。
# 控制台「自定义沙箱」工具配置：启动命令 = /init；启动参数 = sleep / infinity（两个输入框）。
# 连接方式与 e2b 完全一致：Sandbox(template="step-analyzer") + commands.run / files.* 。
FROM ccr.ccs.tencentyun.com/ags-image/sandbox-code:latest

# 1. AnalysisSitus 运行所需系统库（X11 / Qt5 / XCB / 字体 / GL / xvfb 等）
RUN apt-get update && apt-get install -y \
    xvfb \
    # 核心 X11 交互
    libxt6 libxmu6 libxpm4 libxaw7 libice6 libsm6 libx11-6 libxext6 libxrender1 \
    # Qt5 核心框架
    libqt5widgets5 libqt5gui5 libqt5core5a libqt5x11extras5 libqt5xml5 \
    # XCB 渲染插件（Qt5 启动必需）
    libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
    libxcb-render-util0 libxcb-xinerama0 libxcb-xkb1 libxkbcommon-x11-0 \
    # 字体 / XML / 图像
    libfontconfig1 libfreetype6 libexpat1 libuuid1 libfreeimage3 \
    # 图形加速驱动（headless 也需要）
    libgl1 libglu1-mesa libdrm2 libgbm1 \
    # 其他
    libdbus-1-3 libnss3 libfuse2 libgomp1 libxml2 \
    && rm -rf /var/lib/apt/lists/* && ldconfig

# 2. 提取 AnalysisSitus SDK 到 /app/as_sdk
WORKDIR /app
COPY ./AnalysisSitus.AppImage /app/AS.AppImage
RUN chmod +x AS.AppImage && ./AS.AppImage --appimage-extract \
    && mv squashfs-root as_sdk && chmod -R +x /app/as_sdk && rm -f AS.AppImage

# 3. 运行时环境变量（asi_bridge / OCP 依赖）
ENV QT_QPA_PLATFORM="offscreen"
ENV STEP_AS_USE_XVFB=1
ENV LD_LIBRARY_PATH="/app/as_sdk/usr/lib:/app/as_sdk/usr/bin:${LD_LIBRARY_PATH}"
ENV PYTHONPATH="/app/as_sdk/usr/lib/python3.10/site-packages:${PYTHONPATH}"
ENV CASROOT="/app/as_sdk/usr/share/opencascade/resources"

# 4. 把 AS 的 .so 目录写入 ld 缓存（比 LD_LIBRARY_PATH 更稳：跨 commands.run 会话也生效）
RUN find /app/as_sdk -name "*.so*" -exec dirname {} + | sort -u > /etc/ld.so.conf.d/as_situs.conf && ldconfig

# 5. Python 依赖（OCP 读图 + 绘图）。不再装 e2b-code-interpreter：base 已自带 envd。
#    注意：cadquery-ocp 装进 base 的 python，运行时 _patch_ocp_import() 会探测
#    /usr/local/lib/pythonX.Y/site-packages/OCP（覆盖 3.10/3.11）。若 base 是 3.12，需在
#    step_parser_runtime.py 与沙箱内模板的探测列表里补 3.12 路径。
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install \
    "cadquery-ocp>=7.9.3.1" \
    "numpy>=1.26" \
    "ocp" \
    "matplotlib" \
    "vtk" \
    "contourpy"

# base 的 ENTRYPOINT 为 /init（S6），此处不要覆盖 CMD/ENTRYPOINT。
# 还原工作目录到 e2b 约定的用户家目录。
WORKDIR /home/user
