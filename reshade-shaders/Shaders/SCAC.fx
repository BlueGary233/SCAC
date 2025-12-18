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
 * version 0.05
 * version 0.01 Create at 2025/12/13
 * TODO 添加亮度极值平滑系统。√
 * TODO 添加ui过滤。√
 * TODO 调整ui。√
 * version 0.04 Create at 2025/12/18
 * TODO 改进亮度极值平滑，使其不依赖历史值。
 * TODO 改进检测算法，使用单纹理以提高性能。
 * version 0.05 修复ui过滤不生效的问题。
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

uniform int HistorySmoothingAlgorithm <
	ui_category = "Advance";
	ui_type = "combo";
	ui_label = "History Smoothing Algorithm";
	ui_tooltip = "选择历史平滑算法/Select history smoothing algorithm.";
	ui_items = "Off\0Preserve (Min/Max)\0Average (17-frame mean)\0";
> = 2;

uniform bool EnableDebug <
	ui_category = "Advance";
	ui_label = "Enable Debug View";
	ui_tooltip = "启用调试视图，显示所有规约纹理/Enable debug view to display all shader textures.";
> = false;

#include "ReShade.fxh"

// ============================================================================
// 辅助函数
// ============================================================================

// 计算像素亮度：max(max(r,g),b) - 单通道简化,max确保黑位准确。
float CalculateLuminance(float3 color)
{
	return max(max(color.r, color.g), color.b);
}

// 颜色校准函数 - 支持scRGB/HDR
float3 ColorCalibration(float3 color,
						float3 minColor,
						float3 maxColor,
						float3 useingMinColor,
						float3 useingMaxColor)
{
	// 应用自动调整限制
    useingMaxColor = max(useingMaxColor, ScreenMax * WhiteLimiter);
	useingMinColor = min(useingMinColor, ScreenMin + BlackLimiter);

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

// 纹理4_History：4x4 - 历史缓冲区（存储16帧历史的最大值和最小值）
texture2D TextureMip4_History<
	//storage = true;
>
{
	//storage2D = true;
	Width = 4;
	Height = 4;
	Format = RGBA16F;
};
sampler2D SamplerMip4_History {
	Texture = TextureMip4_History;
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
float4 Pass1_DownsampleTo1024(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
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
float4 Pass3_Reduction2(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip1, 1.0 / 256.0);
}

// Pass 4：第三次4x4归约（64x64 -> 16x16）
float4 Pass4_Reduction3(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip2, 1.0 / 64.0);
}

// Pass 5：第四次4x4归约（16x16 -> 4x4）
float4 Pass5_Reduction4(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	return ReductionPass(position, texcoord, SamplerMip3, 1.0 / 16.0);
}

// Pass 6：第五次4x4归约（4x4 -> 1x1）和历史平均值计算
float4 Pass6_Reduction5(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 执行正常的4x4归约
	float4 result = ReductionPass(position, texcoord, SamplerMip4, 1.0 / 4.0);
	
	// 根据历史平滑算法进行计算
	[branch]
	if (HistorySmoothingAlgorithm == 0)
	{
		result.b = result.r;
		result.a = result.g;
	}
	else if (HistorySmoothingAlgorithm == 1) // Preserve (Min/Max) 算法
	{
		// 从Mip4_History采样所有16个像素并计算历史值的极值
		float2 pixelSize = 1.0 / 4.0; // 4x4纹理的像素大小
		float2 startCoord = float2(0.5 * pixelSize.x, 0.5 * pixelSize.y); // 从第一个像素中心开始
		
		float historyMin = 0.0;
		float historyMax = 0.0;
		
		for (int y = 0; y < 4; y++)
		{
			for (int x = 0; x < 4; x++)
			{
				float2 sampleCoord = startCoord + float2(x * pixelSize.x, y * pixelSize.y);
				float4 mip4Value = tex2D(SamplerMip4_History, sampleCoord);
				historyMin = min(historyMin, mip4Value.r);
				historyMax = max(historyMax, mip4Value.g);
			}
		}
		
		// 添加当前帧值到结果中（result.r存储当前帧最小值，result.g存储当前帧最大值）
		// 现在总共有17个数据：16个历史值 + 1个当前帧值
		float totalMin = min(historyMin, result.r);
		float totalMax = max(historyMax, result.g);

		// 存储到结果的B和A通道中
		result.b = totalMin;
		result.a = totalMax;
	}
	else if (HistorySmoothingAlgorithm == 2) // Average (17-frame mean) 算法
	{
		float2 pixelSize = 1.0 / 4.0; // 4x4纹理的像素大小
		float2 startCoord = float2(0.5 * pixelSize.x, 0.5 * pixelSize.y); // 从第一个像素中心开始
		
		float historyMinSum = 0.0;
		float historyMaxSum = 0.0;
		int sampleCount = 0;
		
		for (int y = 0; y < 4; y++)
		{
			for (int x = 0; x < 4; x++)
			{
				float2 sampleCoord = startCoord + float2(x * pixelSize.x, y * pixelSize.y);
				float4 mip4Value = tex2D(SamplerMip4_History, sampleCoord);
				historyMinSum += mip4Value.r;
				historyMaxSum += mip4Value.g;
				sampleCount++;
			}
		}
		
		// 添加当前帧值到累加和中
		historyMinSum += result.r;
		historyMaxSum += result.g;
		sampleCount++; // 现在总共有17个样本
		
		// 计算平均值
		float avgMin = historyMinSum / sampleCount;
		float avgMax = historyMaxSum / sampleCount;
		
		// 存储到结果的B和A通道中
		result.b = avgMin;
		result.a = avgMax;
	}
	// 如果HistorySmoothingAlgorithm == 0 (Off)，则不进行历史平滑
	
	return result;
}

// Pass 7：将当前帧的1x1纹理值存储到历史纹理(0,0)
float4 Pass7_StoreCurrentToHistory(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 这个Pass只写入历史纹理的(0,0)位置
	if (texcoord.x == 0.125 && texcoord.y == 0.125)
	{
		// 从1x1纹理读取当前帧的最小值和最大值
		float4 currentFrame = tex2D(SamplerMip5, float2(0.5, 0.5));
		
		// 存储到历史纹理的(0,0)位置
		// R通道：当前帧最小值
		// G通道：当前帧最大值
		// B和A通道：保留为0（后续用于平均值）
		return float4(currentFrame.r, currentFrame.g, 0.0, 1.0);
	}

	// 其他位置：返回历史纹理的原像素值，保护历史数据不被破坏
	float4 originalHistoryValue = tex2D(SamplerMip4_History, texcoord);
	return originalHistoryValue;
}

// Pass 8：历史值移位
float4 Pass8_HistoryShift(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	// 这个Pass将历史纹理中的值向前移动一位
	// 使用4x4纹理作为16帧的循环缓冲区
	// 将二维坐标转换为一维[0,15]
	
	// 计算当前像素的行列索引（4x4纹理）
	uint col = uint(texcoord.x * 4.0);
	uint row = uint(texcoord.y * 4.0);
	uint pixelIndex = row * 4 + col;
	
	// 计算前一个索引（循环缓冲区）
	uint prevIndex;
	if (pixelIndex == 0)
	{
		prevIndex = 15; // 循环到最后一个位置
	}
	else
	{
		prevIndex = pixelIndex - 1;
	}
	
	// 将一维索引转换回二维纹理坐标
	uint prevCol = prevIndex % 4;
	uint prevRow = prevIndex / 4;
	
	// 计算前一个位置的纹理坐标（像素中心）
	float2 prevTexcoord = float2(
		prevCol * 0.25 + 0.125,
		prevRow * 0.25 + 0.125
	);
	
	// 读取前一个位置的值
	float4 prevValue = tex2D(SamplerMip4_History, prevTexcoord);
	
	return prevValue;
}

// Pass 9：最终颜色校准
float3 Pass9_FinalCalibration(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
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
		float luminance = CalculateLuminance(color);
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
	
	// 调试视图 - 显示历史纹理和规约纹理
	[branch]
	if (EnableDebug)
	{
		// 左侧显示区域：显示3个历史相关纹理，每个占屏幕高度的1/3
		float leftDisplaySize = BUFFER_HEIGHT / 3.0;
		float leftDisplayWidth = leftDisplaySize;
		float leftDisplayHeight = leftDisplaySize;
		
		// 右侧显示区域：显示6个规约纹理，每个占屏幕高度的1/6
		float rightDisplaySize = BUFFER_HEIGHT / 6.0;
		float rightDisplayWidth = rightDisplaySize;
		float rightDisplayHeight = rightDisplaySize;
		
		// 检查当前像素是否在左侧显示区域内
		if (x < leftDisplayWidth)
		{
			// 计算在左侧显示区域内的相对位置
			uint displayX = x;
			uint displayY = y;
			
			// 计算当前像素属于哪个历史纹理（0-2）
			uint historyTextureIndex = displayY / (uint)leftDisplayHeight;
			
			// 确保纹理索引在0-2范围内
			if (historyTextureIndex < 3)
			{
				// 计算在当前纹理显示区域内的相对位置（归一化到[0,1]）
				float localY = (displayY % (uint)leftDisplayHeight) / leftDisplayHeight;
				float localX = displayX / leftDisplayWidth;
				
				// 根据纹理索引采样对应的历史纹理
				float4 historyValue;
				if (historyTextureIndex == 0)
				{
					// TextureMip4_History: 4x4 - 完整图像（RGBA）
					float2 mipCoord = float2(localX, localY);
					historyValue = tex2D(SamplerMip4_History, mipCoord);
					// 显示完整RGBA：R通道为红色，G通道为绿色，B通道为蓝色
					return float3(historyValue.r, historyValue.g, historyValue.b);
				}
				else if (historyTextureIndex == 1)
				{
					// TextureMip4_History: R通道（历史最小值）
					float2 mipCoord = float2(localX, localY);
					historyValue = tex2D(SamplerMip4_History, mipCoord);
					// 只显示R通道（红色）
					return float3(historyValue.r, 0.0, 0.0);
				}
				else // historyTextureIndex == 2
				{
					// TextureMip4_History: G通道（历史最大值）
					float2 mipCoord = float2(localX, localY);
					historyValue = tex2D(SamplerMip4_History, mipCoord);
					// 只显示G通道（绿色）
					return float3(0.0, historyValue.g, 0.0);
				}
			}
		}
		
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
			// 计算像素大小（与Pass1_DownsampleTo1024一致）
			float2 pixelSize = 1.0 / float2(BUFFER_WIDTH, BUFFER_HEIGHT);
			
			// 采样区域大小（与Pass1_DownsampleTo1024一致）
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
	pass Pass1_Downsample
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass1_DownsampleTo1024;
		RenderTarget = TextureMip0;
	}
	
	pass Pass2_Reduction1
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass2_Reduction1;
		RenderTarget = TextureMip1;
	}
	
	pass Pass3_Reduction2
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass3_Reduction2;
		RenderTarget = TextureMip2;
	}
	
	pass Pass4_Reduction3
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass4_Reduction3;
		RenderTarget = TextureMip3;
	}
	
	pass Pass5_Reduction4
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass5_Reduction4;
		RenderTarget = TextureMip4;
	}
	
	pass Pass6_Reduction5
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass6_Reduction5;
		RenderTarget = TextureMip5;
	}
	
	pass Pass7_StoreCurrentToHistory
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass7_StoreCurrentToHistory;
		RenderTarget = TextureMip4_History;
	}
	
	pass Pass8_HistoryShift
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass8_HistoryShift;
		RenderTarget = TextureMip4_History;
	}
	
	pass Pass9_Final
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass9_FinalCalibration;
	}
}
