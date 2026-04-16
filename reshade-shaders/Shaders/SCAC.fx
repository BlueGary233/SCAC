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
 * TODO 改进检测算法，使用单纹理或计算着色器以提高性能。
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

// 检查点是否在任何启用的矩形内，并返回左边缘坐标
bool IsInAnyExclusionRect(float2 normalizedCoord, out float2 leftEdgeCoord)
{
	leftEdgeCoord = float2(0, 0);
	
	// 矩形0
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

// 检查点是否在任何启用的矩形边框内
bool IsInAnyRectBorder(float2 normalizedCoord, float borderWidthX, float borderWidthY)
{
	// 检查8个矩形
	if (RectEnable0 && IsInRectBorder(normalizedCoord, RectPos0, RectSize0, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable1 && IsInRectBorder(normalizedCoord, RectPos1, RectSize1, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable2 && IsInRectBorder(normalizedCoord, RectPos2, RectSize2, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable3 && IsInRectBorder(normalizedCoord, RectPos3, RectSize3, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable4 && IsInRectBorder(normalizedCoord, RectPos4, RectSize4, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable5 && IsInRectBorder(normalizedCoord, RectPos5, RectSize5, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable6 && IsInRectBorder(normalizedCoord, RectPos6, RectSize6, borderWidthX, borderWidthY))
	{
		return true;
	}
	if (RectEnable7 && IsInRectBorder(normalizedCoord, RectPos7, RectSize7, borderWidthX, borderWidthY))
	{
		return true;
	}
	
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

// 通用4x4归约函数
float4 ReductionPass(float4 position : SV_Position, float2 texcoord : TexCoord, sampler2D inputSampler, float2 pixelSize) : SV_Target
{
	// texcoord是归一化坐标[0,1]
	// 每个输出像素对应输入纹理中的4x4块
	// 计算4x4块的起始坐标（从中心偏移-1.5个像素）将初始采样点从4x4的中心移到左上角第一个像素中心。
	float2 startCoord = texcoord - float2(1.5 * pixelSize.x, 1.5 * pixelSize.y);
	
	// 采样4x4区域的16个像素
	float minVal = 1e6;     // 初始化为很大的值，支持scRGB/HDR（可能超过1000尼特）
	float maxVal = 0.0;     // 初始化为很小的值
	
	for (int y = 0; y < 4; y++)		// 这个循环用来遍历4x4块采样。
	{
		for (int x = 0; x < 4; x++)
		{
			float2 sampleCoord = startCoord + float2(x * pixelSize.x, y * pixelSize.y);
			float4 sampleVal = tex2D(inputSampler, sampleCoord);
			
			minVal = min(minVal, sampleVal.r);
			maxVal = max(maxVal, sampleVal.g);
		}
	}
	
	// 存储结果：R通道存最小值，G通道存最大值
	return float4(minVal, maxVal, 0.0, 1.0);
}

// ============================================================================
// 纹理定义
// 固定5次归约：1024 -> 256 -> 64 -> 16 -> 4 -> 1
// ============================================================================

// 纹理0：1024x1024 - 存储下采样后的亮度值
texture2D TextureMip0 <
	pooled = true;
>
{
	Width = 1024;
	Height = 1024;
	Format = RGBA16F;
};
sampler2D SamplerMip0 {
	Texture = TextureMip0;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理1：256x256 - 第一次4x4归约
texture2D TextureMip1 <
	pooled = true;
>
{
	Width = 256;
	Height = 256;
	Format = RGBA16F;
};
sampler2D SamplerMip1 {
	Texture = TextureMip1;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理2：64x64 - 第二次4x4归约
texture2D TextureMip2 <
	pooled = true;
>
{
	Width = 64;
	Height = 64;
	Format = RGBA16F;
};
sampler2D SamplerMip2 {
	Texture = TextureMip2;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理3：16x16 - 第三次4x4归约
texture2D TextureMip3 <
	pooled = true;
>
{
	Width = 16;
	Height = 16;
	Format = RGBA16F;
};
sampler2D SamplerMip3 {
	Texture = TextureMip3;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理4：4x4 - 第四次4x4归约
texture2D TextureMip4 <
	pooled = true;
>
{
	Width = 4;
	Height = 4;
	Format = RGBA16F;
};
sampler2D SamplerMip4 {
	Texture = TextureMip4;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理5：1x1 - 第五次4x4归约（最终结果）
texture2D TextureMip5 <
	pooled = true;
>
{
	Width = 1;
	Height = 1;
	Format = RGBA16F;
};
sampler2D SamplerMip5 {
	Texture = TextureMip5;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};

// 纹理6：1x1 - 存储上次帧的结果
texture2D TexturePrev5 <
	pooled = true;
>
{
	Width = 1;
	Height = 1;
	Format = RGBA16F;
};
sampler2D SamplerPrev5 {
	Texture = TexturePrev5;
	MinFilter = Point;    // 缩小过滤：点过滤
    MagFilter = Point;    // 放大过滤：点过滤
    MipFilter = Point;    // Mipmap过滤：点过滤
    AddressU = Border;     // U方向寻址：边缘
    AddressV = Border;     // V方向寻址：边缘
};
// ============================================================================
// Pass着色器
// ============================================================================

// Pass 1：将后缓冲区采样到1024x1024并计算亮度
float4 pass0_DownsampleTo1024(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
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
	
	// 存储到TextureMip0（R通道存亮度，G通道存相同值用于后续处理）
	return float4(maxLuminance, minLuminance, 0.0, 1.0);
}

// Pass 2：第一次4x4归约（1024x1024 -> 256x256）
float4 Pass2_Reduction1(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip0, 1.0 / 1024.0);
}

// Pass 3：第二次4x4归约（256x256 -> 64x64）
float4 Pass2_Reduction2(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip1, 1.0 / 256.0);
}

// Pass 4：第三次4x4归约（64x64 -> 16x16）
float4 Pass3_Reduction3(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip2, 1.0 / 64.0);
}

// Pass 4：第四次4x4归约（16x16 -> 4x4）
float4 Pass4_Reduction4(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip3, 1.0 / 16.0);
}

// Pass 6：第五次4x4归约（4x4 -> 1x1）和平滑计算
float4 Pass5_Reduction5(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 执行正常的4x4归约
	float4 result = ReductionPass(position, texcoord, SamplerMip4, 1.0 / 4.0);
	
	// 读取上一帧的平滑值（从TexturePrev5的B和A通道）
	float4 prevFrame = tex2D(SamplerPrev5, float2(0.5, 0.5));
	float prevMin = prevFrame.r; // 上一帧的最小值（当前帧的R通道）
	float prevMax = prevFrame.g; // 上一帧的最大值（当前帧的G通道）
	float prevSmoothMin = prevFrame.b;
	float prevSmoothMax = prevFrame.a;
	
	// 获取当前帧的最小值和最大值
	float currentMin = result.r;
	float currentMax = result.g;
	
	// 计算差值（考虑正负）
	float diffMin = currentMin - prevSmoothMin;
	float diffMax = currentMax - prevSmoothMax;

	// 应用改进的平滑公式：分段平滑算法
	// 当 |diff| > SmoothFram * SmoothStep 时：使用 diff * SmoothMult
	// 当 |diff| <= SmoothFram * SmoothStep 时：使用 min(abs(diff), SmoothStep) * sign(diff)
	float threshold = SmoothFram * SmoothStep;
	
	// 最小值平滑（无分支实现）
	float isLargeChangeMin = step(threshold, abs(diffMin));
	float smallChangeMin = min(abs(diffMin), SmoothStep) * sign(diffMin);
	float largeChangeMin = diffMin * SmoothMult;
	float changeMin = lerp(smallChangeMin, largeChangeMin, isLargeChangeMin);
	float smoothMin = prevSmoothMin + changeMin;
	
	// 最大值平滑（无分支实现）
	float isLargeChangeMax = step(threshold, abs(diffMax));
	float smallChangeMax = min(abs(diffMax), SmoothStep) * sign(diffMax);
	float largeChangeMax = diffMax * SmoothMult;
	float changeMax = lerp(smallChangeMax, largeChangeMax, isLargeChangeMax);
	float smoothMax = prevSmoothMax + changeMax;
	
	// 写入结果：
	// R通道：当前帧最小值
	// G通道：当前帧最大值
	// B通道：平滑后的最小值
	// A通道：平滑后的最大值
	result.r = currentMin;
	result.g = currentMax;
	result.b = smoothMin;
	result.a = smoothMax;
	
	return result;
}

float4 Pass5_SavePrev(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 直接将当前帧的结果保存到TexturePrev5，用于下一帧的平滑计算

	return tex2D(SamplerMip5, float2(0.5, 0.5));
}


// Pass 7：最终颜色校准
float3 Pass6_FinalCalibration(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
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

	// 从最终1x1纹理读取结果
	float4 finalStats = tex2D(SamplerPrev5, float2(0.5, 0.5));
	minColor = finalStats.r;
	maxColor = finalStats.g;
	usingMinColor = finalStats.b;
	usingMaxColor = finalStats.a;

	
	// 防止除零
	maxColor = max(maxColor, minColor + 0.001);
	usingMaxColor = max(usingMaxColor, usingMinColor + 0.1);
	
	// 调试视图 - 显示规约纹理
	[branch]
	if (EnableDebug)
	{
		// 右侧显示区域：显示6个规约纹理，每个占屏幕高度的1/6
		float rightDisplaySize = BUFFER_HEIGHT / 6.0;
		float rightDisplayWidth = rightDisplaySize;
		float rightDisplayHeight = rightDisplaySize;
		
		// 检查当前像素是否在屏幕右侧的显示区域内
		if (x > BUFFER_WIDTH - rightDisplayWidth)
		{
			// 计算在显示区域内的相对位置
			uint displayX = x - (BUFFER_WIDTH - (uint)rightDisplayWidth);
			uint displayY = y;
			
			// 计算当前像素属于哪个纹理（0-5）
			uint textureIndex = displayY / (uint)rightDisplayHeight;
			
			// 确保纹理索引在0-5范围内
			if (textureIndex < 6)
			{
				// 计算在当前纹理显示区域内的相对位置（归一化到[0,1]）
				float localY = (displayY % (uint)rightDisplayHeight) / rightDisplayHeight;
				float localX = displayX / rightDisplayWidth;
				
				// 根据纹理索引采样对应的纹理
				float4 mipValue;
				if (textureIndex == 0)
				{
					// TextureMip0: 1024x1024
					float2 mipCoord = float2(localX, localY);
					mipValue = tex2D(SamplerMip0, mipCoord);
				}
				else if (textureIndex == 1)
				{
					// TextureMip1: 256x256
					float2 mipCoord = float2(localX, localY);
					mipValue = tex2D(SamplerMip1, mipCoord);
				}
				else if (textureIndex == 2)
				{
					// TextureMip2: 64x64
					float2 mipCoord = float2(localX, localY);
					mipValue = tex2D(SamplerMip2, mipCoord);
				}
				else if (textureIndex == 3)
				{
					// TextureMip3: 16x16
					float2 mipCoord = float2(localX, localY);
					mipValue = tex2D(SamplerMip3, mipCoord);
				}
				else if (textureIndex == 4)
				{
					// TextureMip4: 4x4
					float2 mipCoord = float2(localX, localY);
					mipValue = tex2D(SamplerMip4, mipCoord);
				}
				else // textureIndex == 5
				{
					// TextureMip5: 1x1 - 总是采样中心点
					mipValue = tex2D(SamplerMip5, float2(0.5, 0.5));
				}
				
				// R通道显示为红色，G通道显示为绿色（保持一致的显示风格）
				return float3(mipValue.r, mipValue.g, 0.0);
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
// 技术定义
// ============================================================================

technique SCAC
{
	pass Pass0_Downsample
	{
		VertexShader = PostProcessVS;
		PixelShader = pass0_DownsampleTo1024;
		RenderTarget = TextureMip0;
	}
	
	pass Pass1_Reduction1
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass2_Reduction1;
		RenderTarget = TextureMip1;
	}
	
	pass Pass2_Reduction2
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass2_Reduction2;
		RenderTarget = TextureMip2;
	}
	
	pass Pass3_Reduction3
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass3_Reduction3;
		RenderTarget = TextureMip3;
	}
	
	pass Pass4_Reduction4
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass4_Reduction4;
		RenderTarget = TextureMip4;
	}
	
	pass Pass5_Reduction5
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass5_Reduction5;
		RenderTarget = TextureMip5;
	}

	pass Pass5_SavePrev
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass5_SavePrev;
		RenderTarget = TexturePrev5;
	}
	
	pass Pass6_Final
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass6_FinalCalibration;
	}
}
