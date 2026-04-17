/*
 * MIT License
 * Copyright (C) 2025 灰灰蓝（948689673@qq.com）
 * 本程序是自由软件：你可以随意再分发和/或依照MIT通用公共许可证修改。
 * 如果其作为模块使用在其他软件上，应当标注着色器或功能名为SCAC。
 * 我希望这个着色器可以改善现在的游戏画面，
 * 所以任何人都可以随意提取和修改这个着色器并将其作为模块使用。
 * 发布该程序是希望它能有用，但是并无保障；
 * 甚至连可销售和符合某个特定的目的都不保证。
 * 作者对本软件的使用和分发无任何约束力，故不承担任何相关的法律责任！
 * SCAC
 * 屏幕颜色自动校准
 * Screen Colour Automatic Calibration
 * by 灰灰蓝 948689673@qq.com WeChat Rs200215
 * version 0.08
 * version 0.01 Create at 2025/12/13
 * TODO 添加亮度极值平滑系统。√
 * TODO 添加ui过滤。√
 * TODO 调整ui。√
 * version 0.04 Create at 2025/12/18
 * TODO 改进亮度极值平滑，使其不依赖历史值。√
 * version 0.05 修复了UIFilter不生效的问题。
 * version 0.06 改进了亮度计算的算法。
 * version 0.07 添加了GAMMA调整。
 * version 0.08 删除了历史帧平滑算法，改为单帧平滑算法。
 * version 0.08 Crate at 2025/12/19
 * version 0.09 修改一些默认值和ui布局。
 * version 0.0.10 改进了亮度计算算法，最大值和最小值分开获得亮度
 * version 0.1.0 添加了反应更快的平滑算法
 * version 0.1.0 Create at 2026/04/15
 * version 0.1.1 添加额外ui过滤矩形，修复代码依靠bug运行的问题
  * TODO 改进检测算法，使用单纹理或计算着色器以提高性能。√
 * version 0.2.0 重写了核心算法，性能提升5%左右。

 */

#include "ReShadeUI.fxh"

uniform float3 RGBGamma <
	ui_text = "明暗调整";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0;
	ui_step = 0.001f;
	ui_label = "Gamma";
	ui_tooltip = "调整画面整体明暗/Adjust the overall brightness and contrast of the image.";
> = 1.0;

uniform int CalibrationMode <
	ui_category = "屏幕校准/Screen calibration";
	ui_text = "屏幕校准图像";
	ui_type = "combo";
	ui_label = "Calibration View";
	ui_tooltip = "选择校准图像/Select the calibration mode.";
	ui_items = "不显示/Off\0黑位校准/Black Level Calibration\0白位校准/White Level Calibration\0";
> = 0;

uniform float ScreenMin <
	ui_category = "屏幕校准/Screen calibration";
	ui_text = "屏幕黑位";
	ui_label = "Black Level";
	ui_tooltip = "选择黑位校准，调整此控件，使画面刚好纯黑/Select black level calibration and adjust this control so that the picture is just pure black.";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.00001f;
> = 0.0;

uniform float ScreenMax <
	ui_category = "屏幕校准/Screen calibration";
	ui_text = "屏幕白位";
	ui_label = "White Level";
	ui_tooltip = "选择白位校准，调整此控件，使画面刚好纯白/Select white level calibration and adjust this control so that the picture is just pure white.";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 50.0;
	ui_step = 0.001f;
> = 1.0;

uniform bool EnableAutoStats <
	ui_category = "自动校正/Auto calibration";
	ui_label = "开启自动校正/Enable Auto calibration";
	ui_tooltip = "将原始画面映射到屏幕范围/Map the original image to the screen range";
> = true;

uniform float WhiteLimiter <
	ui_text = "最小白位限制（为0时无限制/Unlimited for 0）";
	ui_category = "自动校正/Auto calibration";
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.0;
	ui_step = 0.01f;
	ui_label = "Min White Limiter";
	ui_tooltip = "限制检测到的原始最高亮度，避免阴暗画面过亮/Limit the detected maximum raw brightness to prevent overly bright in dim image";
> = 0.85;

uniform float BlackLimiter <
	ui_text = "最大黑位限制（为1时无限制/Unlimited for 1）";
	ui_category = "自动校正/Auto calibration";
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.0;
	ui_step = 0.01f;
	ui_label = "Max Black Limiter";
	ui_tooltip = "限制检测到的原始最低亮度，避免将灰色校准成黑色/Limit the detected raw minimum brightness to avoid calibrating grey as black";
> = 0.15;

uniform bool EnableUIFilter <
	ui_category = "UI过滤/UI filter";
	ui_label = "开启UI过滤/Enable UI Filter";
	ui_tooltip = "启用UI滤除功能，排除UI元素对亮度统计的影响/Enable UI filtering to exclude UI elements from luminance statistics.";
> = true;

uniform bool ShowFilterEffect <
	ui_category = "UI过滤/UI filter";
	ui_label = "显示过滤效果/Show Filter Effect";
	ui_tooltip = "显示滤除效果：确保纯红和纯蓝不在游戏画面中出现，只在ui出现/Show filtering effect: ensure pure red and pure blue do not appear in the game screen, only in the UI";
> = true;

uniform float UiFilterBlack <
	ui_text = "ui暗色过滤";
	ui_category = "UI过滤/UI filter";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.02;
	ui_step = 0.000001f;
	ui_label = "UI Filter Black Level";
	ui_tooltip = "滤除UI过暗像素的阈值/Threshold for filtering overly dark UI pixels.";
> = 0.00001;

uniform float UiFilterWhite <
	ui_text = "ui亮色过滤";
	ui_category = "UI过滤/UI filter";
	ui_type = "drag";
	ui_min = 0.5; ui_max = 100.0;
	ui_step = 0.001f;
	ui_label = "UI Filter White Level";
	ui_tooltip = "滤除UI过亮像素的阈值/Threshold for filtering overly light UI pixels.";
> = 100.0;

// ============================================================================
// UI剔除矩形
// ============================================================================

uniform bool ShowRectBorder <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "显示矩形边框/Show Rectangle Borders";
	ui_tooltip = "在屏幕上显示UI剔除矩形的边框/Display UI exclusion rectangle borders on screen.";
> = false;

// 矩形0
uniform bool RectEnable0 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形0 启用/Rectangle 0 Enable";
	ui_tooltip = "启用矩形0的UI剔除/Enable UI exclusion for rectangle 0.";
> = false;

uniform float2 RectPos0 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形0 位置/Rectangle 0 Position";
	ui_tooltip = "矩形0的左上角位置（归一化坐标）/Top-left position of rectangle 0 (normalized coordinates).";
> = float2(0.45, 0.45);

uniform float2 RectSize0 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形0 大小/Rectangle 0 Size";
	ui_tooltip = "矩形0的大小（归一化尺寸）/Size of rectangle 0 (normalized size).";
> = float2(0.1, 0.1);

// 矩形1
uniform bool RectEnable1 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形1 启用/Rectangle 1 Enable";
	ui_tooltip = "启用矩形1的UI剔除/Enable UI exclusion for rectangle 1.";
> = false;

uniform float2 RectPos1 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形1 位置/Rectangle 1 Position";
	ui_tooltip = "矩形1的左上角位置（归一化坐标）/Top-left position of rectangle 1 (normalized coordinates).";
> = float2(0.25, 0.25);

uniform float2 RectSize1 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形1 大小/Rectangle 1 Size";
	ui_tooltip = "矩形1的大小（归一化尺寸）/Size of rectangle 1 (normalized size).";
> = float2(0.1, 0.1);

// 矩形2
uniform bool RectEnable2 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形2 启用/Rectangle 2 Enable";
	ui_tooltip = "启用矩形2的UI剔除/Enable UI exclusion for rectangle 2.";
> = false;

uniform float2 RectPos2 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形2 位置/Rectangle 2 Position";
	ui_tooltip = "矩形2的左上角位置（归一化坐标）/Top-left position of rectangle 2 (normalized coordinates).";
> = float2(0.65, 0.25);

uniform float2 RectSize2 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形2 大小/Rectangle 2 Size";
	ui_tooltip = "矩形2的大小（归一化尺寸）/Size of rectangle 2 (normalized size).";
> = float2(0.1, 0.1);

// 矩形3
uniform bool RectEnable3 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形3 启用/Rectangle 3 Enable";
	ui_tooltip = "启用矩形3的UI剔除/Enable UI exclusion for rectangle 3.";
> = false;

uniform float2 RectPos3 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形3 位置/Rectangle 3 Position";
	ui_tooltip = "矩形3的左上角位置（归一化坐标）/Top-left position of rectangle 3 (normalized coordinates).";
> = float2(0.25, 0.65);

uniform float2 RectSize3 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形3 大小/Rectangle 3 Size";
	ui_tooltip = "矩形3的大小（归一化尺寸）/Size of rectangle 3 (normalized size).";
> = float2(0.1, 0.1);

// 矩形4
uniform bool RectEnable4 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形4 启用/Rectangle 4 Enable";
	ui_tooltip = "启用矩形4的UI剔除/Enable UI exclusion for rectangle 4.";
> = false;

uniform float2 RectPos4 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形4 位置/Rectangle 4 Position";
	ui_tooltip = "矩形4的左上角位置（归一化坐标）/Top-left position of rectangle 4 (normalized coordinates).";
> = float2(0.65, 0.65);

uniform float2 RectSize4 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形4 大小/Rectangle 4 Size";
	ui_tooltip = "矩形4的大小（归一化尺寸）/Size of rectangle 4 (normalized size).";
> = float2(0.1, 0.1);

// 矩形5
uniform bool RectEnable5 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形5 启用/Rectangle 5 Enable";
	ui_tooltip = "启用矩形5的UI剔除/Enable UI exclusion for rectangle 5.";
> = false;

uniform float2 RectPos5 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形5 位置/Rectangle 5 Position";
	ui_tooltip = "矩形5的左上角位置（归一化坐标）/Top-left position of rectangle 5 (normalized coordinates).";
> = float2(0.15, 0.45);

uniform float2 RectSize5 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形5 大小/Rectangle 5 Size";
	ui_tooltip = "矩形5的大小（归一化尺寸）/Size of rectangle 5 (normalized size).";
> = float2(0.1, 0.1);

// 矩形6
uniform bool RectEnable6 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形6 启用/Rectangle 6 Enable";
	ui_tooltip = "启用矩形6的UI剔除/Enable UI exclusion for rectangle 6.";
> = false;

uniform float2 RectPos6 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形6 位置/Rectangle 6 Position";
	ui_tooltip = "矩形6的左上角位置（归一化坐标）/Top-left position of rectangle 6 (normalized coordinates).";
> = float2(0.45, 0.15);

uniform float2 RectSize6 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形6 大小/Rectangle 6 Size";
	ui_tooltip = "矩形6的大小（归一化尺寸）/Size of rectangle 6 (normalized size).";
> = float2(0.1, 0.1);

// 矩形7
uniform bool RectEnable7 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_label = "矩形7 启用/Rectangle 7 Enable";
	ui_tooltip = "启用矩形7的UI剔除/Enable UI exclusion for rectangle 7.";
> = false;

uniform float2 RectPos7 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形7 位置/Rectangle 7 Position";
	ui_tooltip = "矩形7的左上角位置（归一化坐标）/Top-left position of rectangle 7 (normalized coordinates).";
> = float2(0.45, 0.75);

uniform float2 RectSize7 <
	ui_category = "UI剔除矩形/UI Exclusion Rectangles";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "矩形7 大小/Rectangle 7 Size";
	ui_tooltip = "矩形7的大小（归一化尺寸）/Size of rectangle 7 (normalized size).";
> = float2(0.1, 0.1);

uniform bool ShowSamplingBorder <
    ui_category = "采样/Sampling";
	ui_label = "Show Sampling Border";
	ui_tooltip = "显示采样区域的边界/Show sampling area border.";
> = false;

uniform int SamplingAera <
    ui_category = "采样/Sampling";
	ui_type = "combo";
	ui_label = "Sampling Aera";
	ui_tooltip = "选择采样区域/Select sampling aera.";
	ui_items = "Full Screen\0Custom Area\0";
> = 0;

uniform float2 CustomAreaCenter <
	ui_text = "采样区域位置";
    ui_category = "采样/Sampling";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Custom Area Center";
	ui_tooltip = "自定义采样区域的中心位置/Center position of custom sampling area. 1.0 = default center.";
> = float2(0.5, 0.5);

uniform float2 CustomAreaSize <
	ui_text = "采样区域大小";
    ui_category = "采样/Sampling";
	ui_type = "slider";
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Custom Area Size";
	ui_tooltip = "自定义采样区域的大小/Size of custom sampling area. 1.0 = default size (1024x1024 pixels).";
> = float2(1.0, 1.0);

uniform float SmoothStep <
    ui_text = "平滑步长";
	ui_category = "Advance";
	ui_type = "slider";
	ui_label = "Smooth Step";
	ui_tooltip = "平滑步长控制，值越大变化越不平滑/Smooth step control, larger value means less smooth change.";
	ui_min = 0.0005; ui_max = 1.0;
	ui_step = 0.0001f;
> = 0.0005;

uniform int SmoothFram <
    ui_text = "曝光响应时间";
	ui_category = "Advance";
	ui_type = "slider";
	ui_label = "Exposure Response Time";
	ui_tooltip = "影响平滑算法中慢速响应部分的速度。值越大，曝光变化越慢/Affects the speed of the slow response part in the smoothing algorithm. Larger value means slower exposure change.";
	ui_min = 1; ui_max = 60;
	ui_step = 1;
> = 20;

uniform float SmoothMult <
    ui_text = "曝光速度";
	ui_category = "Advance";
	ui_type = "slider";
	ui_label = "exposure speed";
	ui_tooltip = "影响平滑算法中快速响应部分的速度。值越大，曝光变化越快/Affects the speed of the fast response part in the smoothing algorithm. Larger value means faster exposure change.";
	ui_min = 0.0; ui_max = 0.1;
	ui_step = 0.001f;
> = 0.015;

uniform bool EnableDebug <
	ui_category = "Advance";
	ui_label = "Enable Debug View";
	ui_tooltip = "启用调试视图，显示所有规约纹理/Enable debug view to display all shader textures.";
> = false;

#include "ReShade.fxh"

// ============================================================================
// 辅助函数
// ============================================================================

// 计算像素亮度：min(min(r,g),b) - 单通道简化,min确保亮处稳定，max确保黑位准确。
float MinLuminance(float3 color)
{
	return min(min(color.r, color.g), color.b);
}

float MaxLuminance(float3 color)
{
	return max(max(color.r, color.g), color.b);
}

// 检查是否在矩形边框内
bool IsInRectBorder(float2 normalizedCoord, float2 rectPos, float2 rectSize, float borderWidthX, float borderWidthY)
{
	float2 rectMin = rectPos; // 左上角位置
	float2 rectMax = rectPos + rectSize; // 右下角位置
	
	// 检查左边界
	if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMin.x + borderWidthX &&
		normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
	{
		return true;
	}
	// 检查右边界
	if (normalizedCoord.x >= rectMax.x - borderWidthX && normalizedCoord.x <= rectMax.x &&
		normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
	{
		return true;
	}
	// 检查上边界
	if (normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMin.y + borderWidthY &&
		normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x)
	{
		return true;
	}
	// 检查下边界
	if (normalizedCoord.y >= rectMax.y - borderWidthY && normalizedCoord.y <= rectMax.y &&
		normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x)
	{
		return true;
	}
	
	return false;
}

// 检查点是否在任何启用的矩形内，并返回左边缘坐标（优化版：减少代码重复）
bool IsInAnyExclusionRect(float2 normalizedCoord, out float2 leftEdgeCoord)
{
	leftEdgeCoord = float2(0, 0);
	
	// 使用循环检查8个矩形，但保留分支结构
	// 注意：由于性能考虑，我们保留显式的if语句而不是使用数组循环
	// 但为了代码简洁，我们使用更结构化的方式
	
	// 矩形0
	[branch]
	if (RectEnable0)
	{
		float2 rectMin = RectPos0;
		float2 rectMax = RectPos0 + RectSize0;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形1
	[branch]
	if (RectEnable1)
	{
		float2 rectMin = RectPos1;
		float2 rectMax = RectPos1 + RectSize1;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形2
	[branch]
	if (RectEnable2)
	{
		float2 rectMin = RectPos2;
		float2 rectMax = RectPos2 + RectSize2;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形3
	[branch]
	if (RectEnable3)
	{
		float2 rectMin = RectPos3;
		float2 rectMax = RectPos3 + RectSize3;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形4
	[branch]
	if (RectEnable4)
	{
		float2 rectMin = RectPos4;
		float2 rectMax = RectPos4 + RectSize4;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形5
	[branch]
	if (RectEnable5)
	{
		float2 rectMin = RectPos5;
		float2 rectMax = RectPos5 + RectSize5;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形6
	[branch]
	if (RectEnable6)
	{
		float2 rectMin = RectPos6;
		float2 rectMax = RectPos6 + RectSize6;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	// 矩形7
	[branch]
	if (RectEnable7)
	{
		float2 rectMin = RectPos7;
		float2 rectMax = RectPos7 + RectSize7;
		if (normalizedCoord.x >= rectMin.x && normalizedCoord.x <= rectMax.x &&
			normalizedCoord.y >= rectMin.y && normalizedCoord.y <= rectMax.y)
		{
			leftEdgeCoord = float2(rectMin.x, normalizedCoord.y);
			return true;
		}
	}
	
	return false;
}

// 检查点是否在任何启用的矩形边框内（优化版：更简洁的条件检查）
bool IsInAnyRectBorder(float2 normalizedCoord, float borderWidthX, float borderWidthY)
{
	// 检查8个矩形，使用更简洁的条件链
	// 注意：保留分支结构以确保性能
	
	// 矩形0
	if (RectEnable0 && IsInRectBorder(normalizedCoord, RectPos0, RectSize0, borderWidthX, borderWidthY))
		return true;
	
	// 矩形1
	if (RectEnable1 && IsInRectBorder(normalizedCoord, RectPos1, RectSize1, borderWidthX, borderWidthY))
		return true;
	
	// 矩形2
	if (RectEnable2 && IsInRectBorder(normalizedCoord, RectPos2, RectSize2, borderWidthX, borderWidthY))
		return true;
	
	// 矩形3
	if (RectEnable3 && IsInRectBorder(normalizedCoord, RectPos3, RectSize3, borderWidthX, borderWidthY))
		return true;
	
	// 矩形4
	if (RectEnable4 && IsInRectBorder(normalizedCoord, RectPos4, RectSize4, borderWidthX, borderWidthY))
		return true;
	
	// 矩形5
	if (RectEnable5 && IsInRectBorder(normalizedCoord, RectPos5, RectSize5, borderWidthX, borderWidthY))
		return true;
	
	// 矩形6
	if (RectEnable6 && IsInRectBorder(normalizedCoord, RectPos6, RectSize6, borderWidthX, borderWidthY))
		return true;
	
	// 矩形7
	if (RectEnable7 && IsInRectBorder(normalizedCoord, RectPos7, RectSize7, borderWidthX, borderWidthY))
		return true;
	
	return false;
}

// 颜色校准函数 - 支持scRGB/HDR
float3 ColorCalibration(float3 color,
						float3 minColor,
						float3 maxColor,
						float3 usingMinColor,
						float3 usingMaxColor)
{
	// 应用自动调整限制
    usingMaxColor = max(usingMaxColor, ScreenMax * WhiteLimiter);
	usingMinColor = min(usingMinColor, ScreenMin + BlackLimiter);
	color = clamp(color,UiFilterBlack,UiFilterWhite);

	// 归一化color并应用gamma调整
	color = (color - usingMinColor) / (usingMaxColor - usingMinColor);
	color = clamp(color,0,1);
	color = pow(color, 1.0 / RGBGamma);
	color = color * (usingMaxColor - usingMinColor) + usingMinColor;

	// 校准黑位和白位（合并为一步）
	color = ScreenMin + (color - usingMinColor)* (ScreenMax - ScreenMin)
			/ (usingMaxColor - usingMinColor);

    return color;
}

// 绘制校准图案函数
float3 DrawCalibrationPattern(float2 texcoord, int mode)
{
	// 计算4x4网格的单元格大小
	float cellWidth = 1.0 / 4.0;  // 每个单元格占屏幕宽度的1/4
	float cellHeight = 1.0 / 4.0; // 每个单元格占屏幕高度的1/4
	
	// 矩形占单元格面积的75%，所以矩形大小为单元格大小的sqrt(0.75) ≈ 0.866
	float rectSize = 0.866; // sqrt(0.75)
	
	// 矩形在单元格内的偏移量，使其居中
	float rectOffset = (1.0 - rectSize) * 0.5;
	
	// 确定当前像素属于哪个网格单元格
	int cellX = floor(texcoord.x / cellWidth);
	int cellY = floor(texcoord.y / cellHeight);
	
	// 计算在单元格内的归一化坐标
	float cellLocalX = (texcoord.x - cellX * cellWidth) / cellWidth;
	float cellLocalY = (texcoord.y - cellY * cellHeight) / cellHeight;
	
	// 检查当前像素是否在矩形区域内
	bool inRect = (cellLocalX >= rectOffset && cellLocalX <= rectOffset + rectSize &&
				   cellLocalY >= rectOffset && cellLocalY <= rectOffset + rectSize);
	
	// 根据校准模式返回颜色
	if (mode == 1) // 黑位校准
	{
		// 背景：纯黑，矩形：ScreenMin
		return inRect ? ScreenMin : float3(0.0, 0.0, 0.0);
	}
	else if (mode == 2) // 白位校准
	{
		// 背景：1e6（高亮度白色），矩形：ScreenMax
		float3 whiteBackground = float3(1e6, 1e6, 1e6);
		return inRect ? ScreenMax : whiteBackground;
	}
	
	// 如果不是校准模式，返回黑色（不应该到达这里）
	return float3(0.0, 0.0, 0.0);
}

// ============================================================================
// 纹理定义 - 简化一维坐标算法
// 纹理A：1024x1024（0-1048575） - RG通道存储亮度，BA通道存储规约结果
// 纹理B：256x256（0-65535） - RG通道存储256x256规约，BA通道存储历史数据
// ============================================================================

// 纹理A：1024x1024 - 主纹理
texture2D TextureA <
	pooled = true;
>
{
	Width = 1024;
	Height = 1024;
	Format = RGBA16F;
};
sampler2D SamplerA {
	Texture = TextureA;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理B：256x256 - 历史缓冲区纹理
texture2D TextureB <
	pooled = true;
>
{
	Width = 256;
	Height = 256;
	Format = RGBA16F;
};
sampler2D SamplerB {
	Texture = TextureB;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 历史缓冲区定义（在纹理B的BA通道中，使用一维索引）
// 0-4095: 上一帧的256→64规约结果（64x64=4096像素）
// 4096-4351: 上上帧的64→16规约结果（16x16=256像素）
// 4352-4367: 上上上帧的16→4规约结果（4x4=16像素）
// 4368: 往前第4帧的最终1x1结果
// 4369: 平滑历史数据

// ============================================================================
// 坐标转换函数（一维索引到二维纹理坐标）
// ============================================================================

// 将一维索引转换为纹理A的二维坐标（1024x1024）
float2 IndexToCoordA(uint index)
{
	uint width = 1024;
	uint height = 1024;
	uint y = index / width;
	uint x = index % width;
	return float2((float(x) + 0.5) / float(width), (float(y) + 0.5) / float(height));
}

// 将一维索引转换为纹理B的二维坐标（256x256）
float2 IndexToCoordB(uint index)
{
	uint width = 256;
	uint height = 256;
	uint y = index / width;
	uint x = index % width;
	return float2((float(x) + 0.5) / float(width), (float(y) + 0.5) / float(height));
}

// 缓冲区索引常量
#define FINAL_INDEX 4368   // 最终结果索引
#define SMOOTH_INDEX 4369  // 平滑历史数据索引

// ============================================================================
// Pass着色器
// ============================================================================

// Pass 1：将后缓冲区采样到1024x1024并计算亮度，并保存历史数据
float4 pass0_DownsampleAndSaveHistory(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 计算像素大小（用于边界检查）
	float2 pixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
	
	// 根据采样模式计算采样坐标
	float2 sampleCoord;
	[branch]
	if (SamplingAera == 0) // 全屏模式
	{
		// 直接使用texcoord作为采样坐标
		sampleCoord = texcoord;
	}
	else // 自定义模式 (SamplingAera == 1)
	{
        // 采样区域的尺寸（以屏幕像素为单位）
        float2 sampleSizePixels = float2(1024.0 * CustomAreaSize.x, 1024.0 * CustomAreaSize.y);
		
        // 采样区域的中心（以屏幕UV为单位，[0,1]范围）
        float2 sampleCenterUV = CustomAreaCenter;
		
		// 将1024x1024纹理坐标映射到自定义区域
        // 计算当前输出纹素在区域内的归一化位置 [0,1]
        float2 localUV = texcoord; // texcoord 在 0~1 之间
        
        // 计算该纹素对应的屏幕像素索引（浮点，可能带小数）
        float2 pixelIndexFloat = (sampleCenterUV - 0.5 * sampleSizePixels * pixelSize) + localUV * sampleSizePixels * pixelSize;
        pixelIndexFloat /= pixelSize; // 现在单位是像素索引
        
        // 对齐到最近的像素中心：取整后加0.5得到像素中心坐标
        int2 pixelIndex = int2(floor(pixelIndexFloat + 0.5)); // 四舍五入取整
        // 转换为像素中心UV坐标
        sampleCoord = (float2(pixelIndex) + 0.5) * pixelSize;
	}
	
	// 注意：这里不需要clamp，因为AddressU = Border; AddressV = Border;
	// 允许采样坐标超过[0,1]范围，边缘模式会返回边界颜色
	
	// 从后缓冲区采样RGB值（使用Point过滤直接采样）
	float3 color = tex2D(ReShade::BackBuffer, sampleCoord).rgb;
	
	// 检查当前采样点是否在UI剔除矩形内
	// 使用归一化坐标进行检查
	float2 normalizedCoord = sampleCoord;
	
	// 检查是否在任何启用的矩形内
	float2 leftEdgeCoord;
	bool inExclusionRect = IsInAnyExclusionRect(normalizedCoord, leftEdgeCoord);
	
	// 如果在UI剔除矩形内，使用左边缘颜色
	if (inExclusionRect)
	{
		// 亚像素对齐：将左边缘坐标对齐到最近的像素中心
		float2 bufferSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
		float2 pixelIndex = floor(leftEdgeCoord * bufferSize + 0.5);
		float2 alignedCoord = (pixelIndex + 0.5) / bufferSize;
		
		// 采样左边缘颜色
		color = tex2D(ReShade::BackBuffer, alignedCoord).rgb;
	}
	
	// 计算亮度（单通道）
	float minLuminance = MinLuminance(color);// 用于最大值校准
	float maxLuminance = MaxLuminance(color);// 用于最小值校准
	
	// 从纹理B的BA通道读取历史数据，防止被覆盖
	// 根据输出位置计算一维索引
	uint2 outputCoord = uint2(texcoord.x * 1024.0, texcoord.y * 1024.0);
	uint index = outputCoord.y * 1024 + outputCoord.x;
	
	// 如果这个位置在历史数据范围内，读取历史数据
	float4 historyData = float4(0.0, 0.0, 0.0, 0.0);
	if (index <= SMOOTH_INDEX)
	{
		// 将索引转换为纹理B坐标
		float2 historyCoord = IndexToCoordB(index);
		historyData = tex2D(SamplerB, historyCoord);
	}
	
	// 存储到纹理A：
	// RG通道：当前帧亮度值
	// BA通道：历史数据（防止被覆盖）
	return float4(maxLuminance, minLuminance, historyData.b, historyData.a);
}

// Pass 2：第一次4x4归约（1024x1024 -> 256x256）和历史恢复
float4 Pass1_ReductionAndRestoreHistory(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 对纹理A的RG通道进行4x4规约（1024x1024 -> 256x256）
	float2 pixelSize = 1.0 / 1024.0;
	float2 startCoord = texcoord - float2(1.5 * pixelSize.x, 1.5 * pixelSize.y);
	
	float minVal = 1e6;
	float maxVal = 0.0;
	
	for (int y = 0; y < 4; y++)
	{
		for (int x = 0; x < 4; x++)
		{
			float2 sampleCoord = startCoord + float2(x * pixelSize.x, y * pixelSize.y);
			float4 sampleVal = tex2D(SamplerA, sampleCoord);
			
			// 从RG通道读取亮度值
			minVal = min(minVal, sampleVal.r);  // R通道存最小值
			maxVal = max(maxVal, sampleVal.g);  // G通道存最大值
		}
	}
	
	// 从纹理A的BA通道读取历史数据，防止被覆盖
	// 根据输出位置计算一维索引（256x256纹理）
	uint2 outputCoord = uint2(texcoord.x * 256.0, texcoord.y * 256.0);
	uint index = outputCoord.y * 256 + outputCoord.x;
	
	// 如果这个位置在历史数据范围内，读取历史数据
	float4 historyData = float4(0.0, 0.0, 0.0, 0.0);
	if (index <= SMOOTH_INDEX)
	{
		// 将索引转换为纹理A坐标（从BA通道读取）
		float2 historyCoord = IndexToCoordA(index);
		historyData = tex2D(SamplerA, historyCoord);
	}
	
	// 存储到纹理B：
	// RG通道：当前帧256x256规约结果
	// BA通道：历史数据（防止被覆盖）
	return float4(minVal, maxVal, historyData.b, historyData.a);
}

// Pass 3：时间流水线规约 - 使用一维坐标对纹理B的RGBA通道有效数据进行4x4规约（优化版）
float4 Pass2_TimePipelineReduction(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// texcoord是输出位置，对应纹理A的BA通道
	// 根据输出位置计算一维索引（0-1048575）
	uint2 outputCoord = uint2(texcoord.x * 1024.0, texcoord.y * 1024.0);
	uint outputIndex = outputCoord.y * 1024 + outputCoord.x;
	
	// 只处理历史缓冲区索引范围内的位置（0-4369）
	if (outputIndex == SMOOTH_INDEX)
	{
		// 这个位置专门存储平滑历史数据，直接从纹理B的BA通道读取并返回
		float2 historyCoord = IndexToCoordB(SMOOTH_INDEX);
		return tex2D(SamplerB, historyCoord);
	}
	else if (outputIndex > SMOOTH_INDEX)
	{
		// 超出历史数据范围，直接返回0
		return float4(0.0, 0.0, 0.0, 0.0);
	}
	
	// 每个输出位置对应16个输入像素（4x4规约）
	// 计算这16个像素的起始索引
	uint baseInputIndex = outputIndex * 16;
	
	// 执行4x4规约
	float minVal = 1e6;
	float maxVal = 0.0;
	
	// 遍历4x4的16个像素
	for (uint y = 0; y < 4; y++)
	{
		for (uint x = 0; x < 4; x++)
		{
			// 计算当前像素在16个像素中的位置
			uint pixelInGroup = y * 4 + x;
			uint inputIndex = baseInputIndex + pixelInGroup;
			
			// 根据输入索引确定从哪个通道读取数据
			// 优化：减少嵌套if语句，使用更清晰的条件逻辑
			bool isInRG = inputIndex < 65536;
			bool isInBA = !isInRG && inputIndex < 65536 + 4370;
			
			if (isInRG)
			{
				// 从纹理B的RG通道读取
				float2 inputCoord = IndexToCoordB(inputIndex);
				float4 sampleVal = tex2D(SamplerB, inputCoord);
				
				// RG通道：R存最大值，G存最小值
				minVal = min(minVal, sampleVal.r);
				maxVal = max(maxVal, sampleVal.g);
			}
			else if (isInBA)
			{
				// 从纹理B的BA通道读取历史数据
				// 调整索引：inputIndex - 65536 得到BA通道的索引
				uint baIndex = inputIndex - 65536;
				
				// 优化：将条件检查移到内部，减少嵌套
				if (baIndex <= SMOOTH_INDEX)
				{
					float2 inputCoord = IndexToCoordB(baIndex);
					float4 sampleVal = tex2D(SamplerB, inputCoord);
					
					// BA通道：B存最小值，A存最大值
					minVal = min(minVal, sampleVal.b);
					maxVal = max(maxVal, sampleVal.a);
				}
			}
			// 如果既不在RG也不在BA范围内，则跳过（不执行任何操作）
		}
	}
	
	// 存储结果到纹理A的RG通道
	// B通道存最小值，A通道存最大值
	return float4(minVal, maxVal, minVal, maxVal);
}

// Pass 4：最终处理和平滑
float4 Pass3_FinalProcessing(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 这个Pass写入纹理B，更新最终结果和平滑值并复制历史数据
	// 从纹理A的BA通道索引4368读取历史最终结果
	float2 finalHistoryCoord = IndexToCoordA(FINAL_INDEX);
	float4 finalHistoryData = tex2D(SamplerA, finalHistoryCoord);
	
	// 从纹理A的BA通道读取平滑历史值（索引4369）
	float2 smoothHistoryCoord = IndexToCoordA(SMOOTH_INDEX);
	float4 prevSmooth = tex2D(SamplerA, smoothHistoryCoord);
	float prevSmoothMin = prevSmooth.b;
	float prevSmoothMax = prevSmooth.a;
	
	// 获取当前帧的最小值和最大值（从历史最终结果读取）
	float currentMin = finalHistoryData.b;  // B通道存最小值
	float currentMax = finalHistoryData.a;  // A通道存最大值
	
	// 计算差值（考虑正负）
	float diffMin = currentMin - prevSmoothMin;
	float diffMax = currentMax - prevSmoothMax;

	// 应用改进的平滑公式：分段平滑算法
	float threshold = SmoothFram * SmoothStep;
	
	// 最小值平滑（无分支实现）
	float isLargeChangeMin = step(threshold, abs(diffMin));
	float smallChangeMin = min(abs(diffMin), SmoothStep) * sign(diffMin);
	float largeChangeMin = diffMin * SmoothMult;
	float changeMin = lerp(smallChangeMin, largeChangeMin, isLargeChangeMin);
	float smoothMin = prevSmoothMin + changeMin;
	/*
	float smoothMin = prevSmoothMin; // 初始化为前一帧的平滑值
	if (abs(diffMin) > threshold)
	{
		smoothMin = prevSmoothMin + diffMin * SmoothMult;
	}
	else if(abs(diffMin) <= threshold)
	{
		smoothMin = prevSmoothMin + min(abs(diffMin), SmoothStep) * sign(diffMin);
	}
	*/
	
	// 最大值平滑（无分支实现）
	float isLargeChangeMax = step(threshold, abs(diffMax));
	float smallChangeMax = min(abs(diffMax), SmoothStep) * sign(diffMax);
	float largeChangeMax = diffMax * SmoothMult;
	float changeMax = lerp(smallChangeMax, largeChangeMax, isLargeChangeMax);
	float smoothMax = prevSmoothMax + changeMax;
	/*
	float smoothMax = prevSmoothMax; // 初始化为前一帧的平滑值
	if (abs(diffMax) > threshold)
	{
		float smoothMax = prevSmoothMax + diffMax * SmoothMult;
	}
	else if(abs(diffMax) <= threshold)
	{
		float smoothMax = prevSmoothMax + min(abs(diffMax), SmoothStep) * sign(diffMax);
	}
	*/
	// 计算输出像素在纹理B中的整数坐标
	uint2 outputCoord = uint2(texcoord.x * 256.0, texcoord.y * 256.0);
	uint index = outputCoord.y * 256 + outputCoord.x;
	
	// 检查索引是否在历史数据范围内
	if (index <= FINAL_INDEX)
	{
		// 将索引转换为纹理A坐标（从BA通道读取数据）
		float2 sourceCoord = IndexToCoordA(index);
		float4 sourceData = tex2D(SamplerA, sourceCoord);
		
		// 只复制BA通道（历史数据存储在BA通道）
		return float4(0.0, 0.0, sourceData.b, sourceData.a);
	}
	else if (index == SMOOTH_INDEX)
	{
		// 存储平滑后的结果
		return float4(0.0, 0.0, smoothMin, smoothMax);
	}

	return float4(0.0, 0.0, 0.0, 0.0);
}

// Pass 5：最终颜色校准
float3 Pass4_FinalCalibration(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 检查校准模式
	[branch]
	if (CalibrationMode == 1 || CalibrationMode == 2)
	{
		// 显示校准图案
		return DrawCalibrationPattern(texcoord, CalibrationMode);
	}
	
	// 从后缓冲区采样
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	

	[branch]
	if (ShowFilterEffect)
	{
		float minLuminance = MinLuminance(color);
		float maxLuminance = MaxLuminance(color);
		// 找到被滤除的像素
		if (maxLuminance < UiFilterBlack)
		{
			color = float3(0,0,1);
		}
		else if (minLuminance > UiFilterWhite)
		{
			color = float3(1,0,0);
		}
	}

	// 将texcoord转换为像素坐标（用于调试视图）
	uint x = (uint)(texcoord.x * BUFFER_WIDTH);
	uint y = (uint)(texcoord.y * BUFFER_HEIGHT);
	
	// 获取统计结果
	float minColor = 0.0;
	float usingMinColor = 0.0;
	float maxColor = 1000.0;
	float usingMaxColor = 1000.0;
	
	// 从纹理B的BA通道(FINAL_INDEX)位置读取最终结果
	float2 finalResultCoord = IndexToCoordB(FINAL_INDEX);
	float4 finalStats = tex2D(SamplerB, finalResultCoord);

	float2 smoothCoord = IndexToCoordB(SMOOTH_INDEX);
	float4 smoothData = tex2D(SamplerB, smoothCoord);
	minColor = finalStats.b;
	maxColor = finalStats.a;
	usingMinColor = smoothData.b;
	usingMaxColor = smoothData.a;
	
	// 防止除零
	maxColor = max(maxColor, minColor + 0.001);
	usingMaxColor = max(usingMaxColor, usingMinColor + 0.1);
	
	// 调试视图 - 显示新的双纹理架构
	[branch]
	if (EnableDebug)
	{
		// 右侧显示区域：显示2个纹理，每个占屏幕高度的1/2
		float rightDisplaySize = BUFFER_HEIGHT / 2.0;
		float rightDisplayWidth = rightDisplaySize;
		float rightDisplayHeight = rightDisplaySize;
		
		// 检查当前像素是否在屏幕右侧的显示区域内
		if (x > BUFFER_WIDTH - rightDisplayWidth)
		{
			// 计算在显示区域内的相对位置
			uint displayX = x - (BUFFER_WIDTH - (uint)rightDisplayWidth);
			uint displayY = y;
			
			// 计算当前像素属于哪个纹理（0-1）
			uint textureIndex = displayY / (uint)rightDisplayHeight;
			
			// 确保纹理索引在0-1范围内
			if (textureIndex < 2)
			{
				// 计算在当前纹理显示区域内的相对位置（归一化到[0,1]）
				float localY = (displayY % (uint)rightDisplayHeight) / rightDisplayHeight;
				float localX = displayX / rightDisplayWidth;
				
				// 根据纹理索引采样对应的纹理
				float4 texValue;
				if (textureIndex == 0)
				{
					// 纹理A：1024x1024
					float2 mipCoord = float2(localX, localY);
					texValue = tex2D(SamplerA, mipCoord);
					
					// RG通道显示为红色/绿色，BA通道显示为蓝色/黄色
					float r = texValue.r; // 最大值（RG通道）
					float g = texValue.g; // 最小值（RG通道）
					float b = texValue.b * 2.0; // 规约最小值（BA通道）
					float a = texValue.a * 2.0; // 规约最大值（BA通道）
					
					return float3(r, g + a * 0.5, b); // 组合显示
				}
				else // textureIndex == 1
				{
					// 纹理B：256x256
					float2 mipCoord = float2(localX, localY);
					texValue = tex2D(SamplerB, mipCoord);
					
					// RG通道显示为红色/绿色，BA通道显示为蓝色/黄色
					float r = texValue.r; // 最大值（RG通道）
					float g = texValue.g; // 最小值（RG通道）
					float b = texValue.b * 2.0; // 历史最小值（BA通道）
					float a = texValue.a * 2.0; // 历史最大值（BA通道）
					
					return float3(r, g + a * 0.5, b); // 组合显示
				}
			}
		}
	
	}
	
	// 显示采样边界（如果启用）
	[branch]
	if (ShowSamplingBorder)
	{
		// 紫色边界颜色
		const float3 BORDER_COLOR = float3(1.0, 0.0, 1.0); // 紫色
		
		// 边界宽度（3像素）
		const float BORDER_WIDTH = 3.0;
		
		// 计算归一化的边界宽度
		float borderWidthX = BORDER_WIDTH / BUFFER_WIDTH;
		float borderWidthY = BORDER_WIDTH / BUFFER_HEIGHT;
		
		// 计算当前像素的归一化坐标
		float2 normalizedCoord = float2(x / float(BUFFER_WIDTH), y / float(BUFFER_HEIGHT));
		
		// 根据采样模式确定边界区域
		float2 borderMin, borderMax;
		
		if (SamplingAera == 0) // 全屏模式
		{
			// 整个屏幕的边界
			borderMin = float2(0.0, 0.0);
			borderMax = float2(1.0, 1.0);
		}
		else // 自定义模式
		{
			// 计算像素大小（与pass0_DownsampleTo1024一致）
			float2 pixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
			
			// 采样区域大小（与pass0_DownsampleTo1024一致）
			float2 sampleSize = float2(1024*CustomAreaSize.x*pixelSize.x, 1024*CustomAreaSize.y*pixelSize.y);
			float2 sampleCenter = CustomAreaCenter;
			
			// 计算采样区域的边界
			float2 halfSize = sampleSize * 0.5;
			borderMin = sampleCenter - halfSize;
			borderMax = sampleCenter + halfSize;
			
			// 注意：这里不需要clamp，因为边界可以超过[0,1]范围
			// 边缘模式允许采样坐标超过[0,1]范围
		}
		
		// 检查当前像素是否在边界区域内（3像素宽）
		bool isInBorder = false;
		
		// 检查左边界
		if (normalizedCoord.x >= borderMin.x && normalizedCoord.x <= borderMin.x + borderWidthX &&
			normalizedCoord.y >= borderMin.y && normalizedCoord.y <= borderMax.y)
		{
			isInBorder = true;
		}
		// 检查右边界
		else if (normalizedCoord.x >= borderMax.x - borderWidthX && normalizedCoord.x <= borderMax.x &&
				normalizedCoord.y >= borderMin.y && normalizedCoord.y <= borderMax.y)
		{
			isInBorder = true;
		}
		// 检查上边界
		else if (normalizedCoord.y >= borderMin.y && normalizedCoord.y <= borderMin.y + borderWidthY &&
				normalizedCoord.x >= borderMin.x && normalizedCoord.x <= borderMax.x)
		{
			isInBorder = true;
		}
		// 检查下边界
		else if (normalizedCoord.y >= borderMax.y - borderWidthY && normalizedCoord.y <= borderMax.y &&
				normalizedCoord.x >= borderMin.x && normalizedCoord.x <= borderMax.x)
		{
			isInBorder = true;
		}
		
		// 如果在边界内，返回紫色
		if (isInBorder)
		{
			return BORDER_COLOR;
		}
	}
	
	// 显示UI剔除矩形边框（如果启用）
	[branch]
	if (ShowRectBorder)
	{
		// 青色边框颜色
		const float3 RECT_BORDER_COLOR = float3(0.0, 1.0, 1.0); // 青色
		
		// 边框宽度（2像素）
		const float RECT_BORDER_WIDTH = 2.0;
		
		// 计算归一化的边框宽度
		float rectBorderWidthX = RECT_BORDER_WIDTH / BUFFER_WIDTH;
		float rectBorderWidthY = RECT_BORDER_WIDTH / BUFFER_HEIGHT;
		
		// 计算当前像素的归一化坐标
		float2 normalizedCoord = float2(x / float(BUFFER_WIDTH), y / float(BUFFER_HEIGHT));
		
		// 检查是否在任何启用的矩形边框内
		if (IsInAnyRectBorder(normalizedCoord, rectBorderWidthX, rectBorderWidthY))
		{
			return RECT_BORDER_COLOR;
		}
	}
	
	if (EnableAutoStats)
	{
		// 应用颜色校准
		float3 minColorVec = float3(minColor, minColor, minColor);
		float3 maxColorVec = float3(maxColor, maxColor, maxColor);
		float3 usingMinColorVec = float3(usingMinColor, usingMinColor, usingMinColor);
		float3 usingMaxColorVec = float3(usingMaxColor, usingMaxColor, usingMaxColor);
		color = ColorCalibration(color, minColorVec, maxColorVec, usingMinColorVec, usingMaxColorVec);
	}
	return color;
}
// ============================================================================
// 技术定义 - 简化一维坐标算法（7个Pass完整版）
// ============================================================================

technique SCAC
{
	// Pass 1：将后缓冲区采样到1024x1024并计算亮度，并保存历史数据
	pass Pass0_DownsampleAndSaveHistory
	{
		VertexShader = PostProcessVS;
		PixelShader = pass0_DownsampleAndSaveHistory;
		RenderTarget = TextureA;
	}
	
	// Pass 2：第一次4x4归约（1024x1024 -> 256x256）和历史恢复
	pass Pass1_ReductionAndRestoreHistory
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass1_ReductionAndRestoreHistory;
		RenderTarget = TextureB;
	}
	
	// Pass 3：时间流水线规约 - 对纹理B的RGBA通道有效数据进行4x4规约
	pass Pass2_TimePipelineReduction
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass2_TimePipelineReduction;
		RenderTarget = TextureA;
	}
	
	// Pass 4：最终处理和平滑 - 将最终结果写入纹理A
	pass Pass3_FinalProcessing
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass3_FinalProcessing;
		RenderTarget = TextureB;
	}
	
	// Pass 5：最终颜色校准
	pass Pass4_FinalCalibration
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass4_FinalCalibration;
	}
}
