# Qualcomm Device Tree Extraction Tool

一个用于提取和分析高通设备设备树（Device Tree）的自动化脚本工具。

## 功能概述

这个脚本自动化了从高通设备的安卓启动镜像 `boot.img` 文件中提取设备树的过程，并提供了设备信息的可视化展示，方便开发者进行设备树的分析和比对。

## 主要功能

* ✅ 自动检查并安装所需依赖（git, python3, pip3, dtc, make, hexdump）
* ✅ 克隆并编译 `android-unpackbootimg` 工具
* ✅ 解压 `boot.img` 文件
* ✅ 提取设备树二进制文件（DTB）
* ✅ 反编译设备树为可读的 DTS 格式
* ✅ 读取并显示设备的 MSM-ID、Board-ID 和 Model 信息
* ✅ 可视化展示所有设备树文件的信息
* ✅ 生成详细的设备树信息汇总报告

## 使用方法

### 1\. 准备工作

将以下文件放置在脚本同一目录下：

* **必需文件**: `boot.img`
* **可选文件（位于设备的/proc/device-tree文件夹下）**:

  * `qcom,msm-id`
  * `qcom,board-id`
  * `model`

### 2\. 运行脚本

```bash
# 下载脚本
git clone https://github.com/550Cool/Qualcomm-Device-Tree-Extraction-Tool.git
cd Qualcomm-Device-Tree-Extraction-Tool

# 添加执行权限
chmod +x extract_dt.sh

# 运行脚本
./extract_dt.sh


