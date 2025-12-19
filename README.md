# SCAC - 屏幕颜色自动校准 / Screen Colour Automatic Calibration

<div align="center">
  <a href="#中文">中文</a> | 
  <a href="#english">English</a>
</div>

---

<a id="中文"></a>
## 中文文档

SCAC（Screen Colour Automatic Calibration）是一个ReShade着色器，用于自动校准屏幕颜色，优化游戏画面显示效果。

### 功能特性

#### 核心功能
- **自动颜色校准**：实时分析屏幕内容并自动调整黑位和白位
- **屏幕校准工具**：提供黑位和白位校准图案，用于手动校准
- **UI过滤**：智能排除UI元素对亮度统计的影响
- **历史平滑**：支持多种历史平滑算法，避免画面闪烁

#### 高级特性
- **自定义采样区域**：支持全屏或自定义区域采样
- **HDR/scRGB支持**：兼容高动态范围显示
- **调试视图**：可视化显示所有规约纹理和历史数据
- **实时统计**：显示当前帧的最小/最大亮度值

### 安装方法

1. 确保已安装 [ReShade](https://reshade.me/)
2. 将 `SCAC.fx` 文件复制到 ReShade 的 Shaders 目录
3. 在游戏中启用 ReShade，添加 SCAC 效果

### 使用方法

#### 基本设置
1. **启用自动校正**：在"自动校正"分类中开启"开启自动校正"
2. **调整限制器**：
   - 最小白位限制：防止阴暗画面过亮（建议0.95）
   - 最大黑位限制：避免将灰色校准成黑色（建议0.10）

#### 屏幕校准
1. **黑位校准**：
   - 选择"黑位校准"模式
   - 调整"屏幕黑位"滑块，使矩形区域刚好变为纯黑

2. **白位校准**：
   - 选择"白位校准"模式
   - 调整"屏幕白位"滑块，使矩形区域刚好变为纯白

#### UI过滤
- **启用UI过滤**：排除UI元素对亮度统计的影响
- **显示过滤效果**：可视化显示被滤除的像素（红色=过亮，蓝色=过暗）
- **调整过滤阈值**：根据UI亮度调整暗色和亮色过滤阈值

#### 高级设置
- **采样区域**：选择全屏或自定义区域采样
- **历史平滑算法**：
  - Off：不使用历史平滑
  - Preserve (Min/Max)：保留历史极值
  - Average (17-frame mean)：17帧平均值平滑
- **调试视图**：启用后显示所有规约纹理和历史数据

### 技术细节

#### 工作原理
1. **亮度计算**：使用 `min(min(r,g),b)` 公式计算像素亮度
2. **多级规约**：通过5次4x4规约将1024x1024采样降至1x1统计
3. **历史缓冲**：使用4x4纹理作为16帧循环缓冲区
4. **颜色校准**：将原始画面映射到屏幕可显示范围

#### 规约流程
```
1024x1024 → 256x256 → 64x64 → 16x16 → 4x4 → 1x1
```

#### 纹理用途
- **TextureMip0-5**：多级规约纹理
- **TextureMip4_History**：16帧历史缓冲区

### 参数说明

#### 屏幕校准
- **屏幕校准图像**：选择校准模式（关闭/黑位校准/白位校准）
- **屏幕黑位**：黑位校准值
- **屏幕白位**：白位校准值

#### 自动校正
- **开启自动校正**：启用/禁用自动校准
- **最小白位限制**：限制检测到的最高亮度
- **最大黑位限制**：限制检测到的最低亮度

#### UI过滤
- **开启UI过滤**：启用/禁用UI过滤
- **显示过滤效果**：显示被滤除的像素
- **ui暗色过滤**：滤除过暗UI像素的阈值
- **ui亮色过滤**：滤除过亮UI像素的阈值

#### 采样
- **显示采样边界**：显示采样区域边界
- **采样区域**：选择采样区域（全屏/自定义）
- **采样区域位置**：自定义采样区域中心
- **采样区域大小**：自定义采样区域大小

#### 高级设置
- **历史平滑算法**：选择历史平滑算法
- **启用调试视图**：显示所有规约纹理

### 版本历史

#### v0.04 (2025/12/18)
- 添加亮度极值平滑系统
- 添加UI过滤功能
- 调整UI界面

#### v0.01 (2025/12/13)
- 初始版本创建

### 许可证

MIT License
Copyright (C) 2025 灰灰蓝（948689673@qq.com）

### 联系方式

- 作者：灰灰蓝
- 邮箱：948689673@qq.com
- WeChat：Rs200215

### 注意事项

1. 本着色器旨在改善游戏画面，但效果因游戏和显示器而异
2. 建议先使用校准模式进行手动校准，再启用自动校正
3. 对于HDR内容，可能需要调整白位限制
4. 如果画面闪烁，尝试调整历史平滑算法

### 贡献

欢迎提交问题和改进建议。请确保遵循MIT许可证条款。

---

<a id="english"></a>
## English Documentation

SCAC (Screen Colour Automatic Calibration) is a ReShade shader for automatic screen color calibration, optimizing game display quality.

### Features

#### Core Features
- **Automatic Color Calibration**: Real-time screen analysis with automatic black and white level adjustment
- **Screen Calibration Tools**: Provides black and white level calibration patterns for manual calibration
- **UI Filtering**: Intelligently excludes UI elements from luminance statistics
- **History Smoothing**: Multiple history smoothing algorithms to prevent flickering

#### Advanced Features
- **Custom Sampling Area**: Supports full-screen or custom area sampling
- **HDR/scRGB Support**: Compatible with high dynamic range displays
- **Debug View**: Visualizes all reduction textures and historical data
- **Real-time Statistics**: Displays current frame's minimum/maximum luminance values

### Installation

1. Ensure [ReShade](https://reshade.me/) is installed
2. Copy the `SCAC.fx` file to ReShade's Shaders directory
3. Enable ReShade in-game and add the SCAC effect

### Usage

#### Basic Settings
1. **Enable Auto Calibration**: Turn on "Enable Auto calibration" in the "Auto calibration" category
2. **Adjust Limiters**:
   - Min White Limiter: Prevents overly bright dim scenes (recommended: 0.95)
   - Max Black Limiter: Avoids calibrating grey as black (recommended: 0.10)

#### Screen Calibration
1. **Black Level Calibration**:
   - Select "Black Level Calibration" mode
   - Adjust the "Black Level" slider until the rectangle area becomes pure black

2. **White Level Calibration**:
   - Select "White Level Calibration" mode
   - Adjust the "White Level" slider until the rectangle area becomes pure white

#### UI Filtering
- **Enable UI Filter**: Excludes UI elements from luminance statistics
- **Show Filter Effect**: Visualizes filtered pixels (red=too bright, blue=too dark)
- **Adjust Filter Thresholds**: Modify dark and light filter thresholds based on UI brightness

#### Advanced Settings
- **Sampling Area**: Choose full-screen or custom area sampling
- **History Smoothing Algorithm**:
  - Off: No history smoothing
  - Preserve (Min/Max): Preserves historical extremes
  - Average (17-frame mean): 17-frame average smoothing
- **Debug View**: Enables display of all reduction textures and historical data

### Technical Details

#### How It Works
1. **Luminance Calculation**: Uses `max(max(r,g),b)` formula to calculate pixel luminance
2. **Multi-level Reduction**: Reduces 1024x1024 sampling to 1x1 statistics through 5 stages of 4x4 reduction
3. **History Buffer**: Uses 4x4 texture as a 16-frame circular buffer
4. **Color Calibration**: Maps original image to screen displayable range

#### Reduction Pipeline
```
1024x1024 → 256x256 → 64x64 → 16x16 → 4x4 → 1x1
```

#### Texture Usage
- **TextureMip0-5**: Multi-level reduction textures
- **TextureMip4_History**: 16-frame history buffer

### Parameter Description

#### Screen Calibration
- **Calibration View**: Select calibration mode (Off/Black Level Calibration/White Level Calibration)
- **Black Level**: Black level calibration value
- **White Level**: White level calibration value

#### Auto Calibration
- **Enable Auto calibration**: Enable/disable automatic calibration
- **Min White Limiter**: Limits detected maximum raw brightness
- **Max Black Limiter**: Limits detected raw minimum brightness

#### UI Filtering
- **Enable UI Filter**: Enable/disable UI filtering
- **Show Filter Effect**: Display filtered pixels
- **UI Filter Black Level**: Threshold for filtering overly dark UI pixels
- **UI Filter White Level**: Threshold for filtering overly light UI pixels

#### Sampling
- **Show Sampling Border**: Display sampling area border
- **Sampling Area**: Select sampling area (Full Screen/Custom Area)
- **Custom Area Center**: Center position of custom sampling area
- **Custom Area Size**: Size of custom sampling area

#### Advanced Settings
- **History Smoothing Algorithm**: Select history smoothing algorithm
- **Enable Debug View**: Display all reduction textures

### Version History

#### v0.04 (2025/12/18)
- Added brightness extreme smoothing system
- Added UI filtering functionality
- Adjusted UI interface

#### v0.01 (2025/12/13)
- Initial version created

### License

MIT License
Copyright (C) 2025 灰灰蓝（948689673@qq.com）

### Contact

- Author: 灰灰蓝
- Email: 948689673@qq.com
- WeChat: Rs200215

### Notes

1. This shader aims to improve game visuals, but results may vary depending on the game and display
2. It's recommended to use calibration mode for manual calibration before enabling auto calibration
3. For HDR content, white level limits may need adjustment
4. If screen flickering occurs, try adjusting the history smoothing algorithm

### Contributing

Issues and improvement suggestions are welcome. Please ensure compliance with MIT license terms.

---

<div align="center">
  <a href="#中文">中文</a> | 
  <a href="#english">English</a>
</div>
