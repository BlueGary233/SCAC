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
 * TODO 改进检测算法，使用单纹理或计算着色器以提高性能。
 */

#include "ReShadeUI.fxh"

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
> = 0.95;

uniform float BlackLimiter <
	ui_text = "最大黑位限制（为1时无限制/Unlimited for 1）";
	ui_category = "自动校正/Auto calibration";
	ui_type = "slider";
	ui_min = 0.00; ui_max = 1.0;
	ui_step = 0.01f;
	ui_label = "Max Black Limiter";
	ui_tooltip = "限制检测到的原始最低亮度，避免将灰色校准成黑色/Limit the detected raw minimum brightness to avoid calibrating grey as black";
> = 0.10;

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
> = 0.0;

uniform float UiFilterWhite <
	ui_text = "ui亮色过滤";
	ui_category = "UI过滤/UI filter";
	ui_type = "drag";
	ui_min = 0.5; ui_max = 100.0;
	ui_step = 0.001f;
	ui_label = "UI Filter White Level";
	ui_tooltip = "滤除UI过亮像素的阈值/Threshold for filtering overly light UI pixels.";
> = 100.0;

uniform float3 RGBGamma <
	ui_text = "明暗调整";
	ui_type = "drag";
	ui_min = 0.0; ui_max = 2.0;
	ui_step = 0.001f;
	ui_label = "Gamma";
	ui_tooltip = "调整画面整体明暗/Adjust the overall brightness and contrast of the image.";
> = 1.0;

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

uniform int Smoothness <
	ui_category = "Advance";
	ui_type = "slider";
	ui_label = "Smoothness";
	ui_tooltip = "平滑度控制，值越大变化越平滑/Smoothness control, higher values result in smoother changes.";
	ui_min = 1;
	ui_max = 200;
	ui_step = 1;
> = 200;

uniform bool EnableDebug <
	ui_category = "Advance";
	ui_label = "Enable Debug View";
	ui_tooltip = "启用调试视图，显示所有规约纹理/Enable debug view to display all shader textures.";
> = false;

#include "ReShade.fxh"

// ============================================================================
// 辅助函数
// ============================================================================

// 计算像素亮度：min(min(r,g),b) - 单通道简化,min确保黑位准确和画面稳定。
float CalculateLuminance(float3 color)
{
	return min(min(color.r, color.g), color.b);//(color.r + color.g + color.b)/3;
}

// 颜色校准函数 - 支持scRGB/HDR
float3 ColorCalibration(float3 color,
						float3 minColor,
						float3 maxColor,
						float3 useingMinColor,
						float3 useingMaxColor)
{
	// 应用自动调整限制和ui滤除
    useingMaxColor = max(useingMaxColor, ScreenMax * WhiteLimiter);
	useingMinColor = min(useingMinColor, ScreenMin + BlackLimiter);
	color = clamp(color,UiFilterBlack,UiFilterWhite);

	// 归一化color并应用gamma调整
	color = (color - useingMinColor) / (useingMaxColor - useingMinColor);
	color = clamp(color,0,1);
	color = pow(color, 1.0 / RGBGamma);
	color = color * (useingMaxColor - useingMinColor) + useingMinColor;

	// 校准黑位和白位（合并为一步）
	color = ScreenMin + (color - useingMinColor)* (ScreenMax - ScreenMin)
			/ (useingMaxColor - useingMinColor);

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
			// 确保采样坐标在有效范围内
			// sampleCoord = clamp(sampleCoord, pixelSize * 0.5, 1.0 - pixelSize * 0.5);注释掉因为这个clamp似乎并不必要
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

// ============================================================================
// Pass着色器
// ============================================================================

// Pass 1：将后缓冲区采样到1024x1024并计算亮度
float4 pass0_DownsampleTo1024(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 测试模式：输出测试图案以验证坐标映射
	// R通道：水平渐变（0到1）
	// G通道：垂直渐变（0到1）
	// B通道：固定0
	// 这样我们可以清楚地看到纹理是否覆盖整个区域
	
	// float2 testPattern = texcoord; // 直接使用texcoord作为渐变
	
	// 存储到TextureMip0（R通道存水平渐变，G通道存垂直渐变）
	// return float4(testPattern.x, testPattern.y, 0.0, 1.0);
	
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
		// 采样区域
		float2 sampleSize = float2(1024*CustomAreaSize.x*pixelSize.x, 1024*CustomAreaSize.y*pixelSize.y);
		
		float2 sampleCenter = CustomAreaCenter;
		
		// 将1024x1024纹理坐标映射到自定义区域
		// 公式：中心 + (texcoord - 0.5) * 大小
		sampleCoord = sampleCenter + (texcoord - 0.5) * sampleSize;
	}
	
	// 注意：这里不需要clamp，因为AddressU = Border; AddressV = Border;
	// 允许采样坐标超过[0,1]范围，边缘模式会返回边界颜色
	
	// 从后缓冲区采样RGB值（使用Point过滤直接采样）
	float3 color = tex2D(ReShade::BackBuffer, sampleCoord).rgb;
	
	// 计算亮度（单通道）
	float luminance = CalculateLuminance(color);

	// UI滤除（如果启用）
	[branch]
	if (EnableUIFilter)
	{
		// 应用滤除
		luminance = clamp(luminance,UiFilterBlack,UiFilterWhite);
		/*
		luminance += (luminance < UiFilterBlack) * UiFilterBlack;
		Luminance -= (Luminance > UiFilterWhite) * UiFilterWhite;
		*/
	}
	
	// 存储到TextureMip0（R通道存亮度，G通道存相同值用于后续处理）
	return float4(luminance, luminance, 0.0, 1.0);
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

// Pass 5：第四次4x4归约（16x16 -> 4x4）
float4 Pass4_Reduction5(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip3, 1.0 / 16.0);
}

// Pass 6：第五次4x4归约（4x4 -> 1x1）和平滑计算
float4 Pass5_Reduction5(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 执行正常的4x4归约
	float4 result = ReductionPass(position, texcoord, SamplerMip4, 1.0 / 4.0);
	
	// 读取上一帧的平滑值（从TextureMip5的B和A通道）
	float4 prevFrame = tex2D(SamplerMip5, float2(0.5, 0.5));
	float prevSmoothMin = prevFrame.b;
	float prevSmoothMax = prevFrame.a;
	
	// 获取当前帧的最小值和最大值
	float currentMin = result.r;
	float currentMax = result.g;
	
	// 计算差值（考虑正负）
	float diffMin = currentMin - prevSmoothMin;
	float diffMax = currentMax - prevSmoothMax;
	
	// 计算平滑步长（1.0 / Smoothness）
	float smoothStep = 0.1 / float(Smoothness);
	
	// 应用平滑公式：smoothResult = result + min(abs(diff), smoothStep) * sign(diff)
	float smoothMin = prevSmoothMin + min(abs(diffMin), smoothStep) * sign(diffMin);
	float smoothMax = prevSmoothMax + min(abs(diffMax), smoothStep) * sign(diffMax);
	
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


// Pass 6：最终颜色校准
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
	
	float luminance = CalculateLuminance(color);
	[branch]
	if (ShowFilterEffect)
	{
		// 找到被滤除的像素
		if (luminance < UiFilterBlack)
		{
			color = float3(0,0,1);
		}
		else if (luminance > UiFilterWhite)
		{
			color = float3(1,0,0);
		}
		//color = all(clamp(luminance,UiFilterBlack,UiFilterWhite));
	}

	// 将texcoord转换为像素坐标（用于调试视图）
	uint x = (uint)(texcoord.x * BUFFER_WIDTH);
	uint y = (uint)(texcoord.y * BUFFER_HEIGHT);
	
	// 获取统计结果
	float minColor = 0.0;
	float useingMinColor = 0.0;
	float maxColor = 1000.0;
	float useingMaxColor = 1000.0;

	// 从最终1x1纹理读取结果
	float4 finalStats = tex2D(SamplerMip5, float2(0.5, 0.5));
	minColor = finalStats.r;
	maxColor = finalStats.g;
	useingMinColor = finalStats.b;
	useingMaxColor = finalStats.a;

	
	// 防止除零
	maxColor = max(maxColor, minColor + 0.001);
	useingMaxColor = max(useingMaxColor,useingMinColor + 0.1);
	
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
	if (EnableAutoStats)
	{
		// 应用颜色校准
		minColor = float3(minColor, minColor, minColor);
		maxColor = float3(maxColor, maxColor, maxColor);
		useingMinColor = float3(useingMinColor, useingMinColor, useingMinColor);
		useingMaxColor = float3(useingMaxColor, useingMaxColor, useingMaxColor);
		color = ColorCalibration(color, minColor, maxColor,useingMinColor,useingMaxColor);
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
		PixelShader = Pass4_Reduction5;
		RenderTarget = TextureMip4;
	}
	
	pass Pass5_Reduction5
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass5_Reduction5;
		RenderTarget = TextureMip5;
	}
	
	pass Pass6_Final
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass6_FinalCalibration;
	}
}
