clear; clc; close all;

%% Nature 风格 FFT 三维峰峦图
% 说明：
% 1. 仅生成 FFT 分析图，不输出温度时域图。
% 2. 四个横摇频率的 FFT 结果放在同一张三维峰峦图中。
% 3. FFT 频率为前方横轴，横摇频率为右侧深度轴，FFT 幅值为竖轴。
% 4. 曲线经过插值和平滑处理，并标注各工况主频值。
% 5. 导出 PNG、PDF 和 MATLAB 可编辑 FIG 文件。

setNatureFigureDefaults();

%% 四组数据配置
cases = struct([]);

cases(1).filePath = "D:\研究生\研一\陆老师课题组\船舶\FDS横摇实验\660kw数据\smoothed_w5\0.05hz，10°原始数据_smoothed_w5.xlsx";
cases(1).rollFreq = 0.05;
cases(1).caseName = "0.05 Hz";

cases(2).filePath = "D:\研究生\研一\陆老师课题组\船舶\FDS横摇实验\660kw数据\smoothed_w5\0.1hz，10°原始数据_smoothed_w5.xlsx";
cases(2).rollFreq = 0.10;
cases(2).caseName = "0.10 Hz";

cases(3).filePath = "D:\研究生\研一\陆老师课题组\船舶\FDS横摇实验\660kw数据\smoothed_w5\0.15hz，10°原始数据_smoothed_w5.xlsx";
cases(3).rollFreq = 0.15;
cases(3).caseName = "0.15 Hz";

cases(4).filePath = "D:\研究生\研一\陆老师课题组\船舶\FDS横摇实验\660kw数据\smoothed_w5\0.2hz，10°原始数据_smoothed_w5.xlsx";
cases(4).rollFreq = 0.20;
cases(4).caseName = "0.20 Hz";

%% 分析参数
selectedDevice = "Device0.8";
trendWindowSeconds = 15;
rawTimeStep = 0.06;
oneSecondMaxFreq = 0.50;
rawMaxFreq = 1.00;

%% 绘图可调参数
plotSettings.smoothWindow = 21;          % 越大越平滑，建议 11-31，需为奇数
plotSettings.interpolationFactor = 10;   % 曲线加密倍数
plotSettings.frequencyTickStep = 0.10;   % FFT 频率刻度间隔，单位 Hz
plotSettings.showPeakLabels = true;      % 是否标注主频值
plotSettings.peakLabelOffset = 0.045;    % 主频标注高度偏移
plotSettings.faceAlpha = 0.36;           % 峰面透明度
plotSettings.viewAngle = [42 24];        % 三维视角：[方位角, 俯仰角]
plotSettings.exportResolution = 600;      % 导出分辨率

%% 输出文件夹
outputDir = fullfile(pwd, "FFT_660kw_smoothed_w5_Nature_Output");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

summaryAll = table();
fftOneSecond = struct([]);
fftRaw = struct([]);

%% 批量分析
for c = 1:numel(cases)
    filePath = cases(c).filePath;
    rollFreq = cases(c).rollFreq;
    doubleFreq = 2 * rollFreq;
    caseName = cases(c).caseName;

    fprintf("\n==============================\n");
    fprintf("正在分析 %s 工况\n", caseName);
    fprintf("文件：%s\n", filePath);

    %% 读取 Excel
    opts = detectImportOptions(filePath);
    opts.VariableNamesRange = "A2";
    opts.DataRange = "A3";
    T = readtable(filePath, opts);

    time = T.Time;
    varNames = T.Properties.VariableNames;

    %% 选取测点
    deviceNameDot = selectedDevice;
    deviceNameUnder = strrep(selectedDevice, ".", "_");

    if ismember(deviceNameUnder, varNames)
        temp = T.(deviceNameUnder);
        deviceName = char(deviceNameDot);
    elseif ismember(deviceNameDot, varNames)
        temp = T.(deviceNameDot);
        deviceName = char(deviceNameDot);
    else
        error("没有找到 %s 对应的数据列。请检查 Excel 表头。", selectedDevice);
    end

    %% 每秒平均与去趋势
    timeSec = floor(time);
    timeSec(timeSec == 60) = 59;

    [groupID, secList] = findgroups(timeSec);
    time_1s = secList + 0.5;
    temp_1s = splitapply(@mean, temp, groupID);

    trend = movmean(temp_1s, trendWindowSeconds, "omitnan");
    tempFluct_1s = temp_1s - trend;

    %% 1 s 平均数据 FFT
    [freq_1s, amp_1s] = singleSidedFFT(tempFluct_1s, 1);
    metrics_1s = extractFFTMetrics(freq_1s, amp_1s, rollFreq, doubleFreq, oneSecondMaxFreq);

    fftOneSecond(c).freq = freq_1s;
    fftOneSecond(c).amp = amp_1s;
    fftOneSecond(c).caseName = char(caseName);
    fftOneSecond(c).rollFreq = rollFreq;
    fftOneSecond(c).doubleFreq = doubleFreq;
    fftOneSecond(c).metrics = metrics_1s;

    %% 原始 0.06 s 数据 FFT
    validIdx = ~isnan(time) & ~isnan(temp);
    timeRaw = time(validIdx);
    tempRaw = temp(validIdx);

    timeUniform = (min(timeRaw):rawTimeStep:max(timeRaw))';
    tempUniform = interp1(timeRaw, tempRaw, timeUniform, "linear", "extrap");
    tempUniform = tempUniform - mean(tempUniform, "omitnan");

    [freqRaw, ampRaw] = singleSidedFFT(tempUniform, 1 / rawTimeStep);
    metricsRaw = extractFFTMetrics(freqRaw, ampRaw, rollFreq, doubleFreq, rawMaxFreq);

    fftRaw(c).freq = freqRaw;
    fftRaw(c).amp = ampRaw;
    fftRaw(c).caseName = char(caseName);
    fftRaw(c).rollFreq = rollFreq;
    fftRaw(c).doubleFreq = doubleFreq;
    fftRaw(c).metrics = metricsRaw;

    %% 导出 FFT 数据
    fftTable_1s = table(freq_1s(:), amp_1s(:), ...
        'VariableNames', {'Frequency_Hz', 'Amplitude'});
    writetable(fftTable_1s, fullfile(outputDir, ...
        sprintf("%s_%s_FFT_1s_data.xlsx", erase(caseName, " "), deviceNameUnder)));

    fftTableRaw = table(freqRaw(:), ampRaw(:), ...
        'VariableNames', {'Frequency_Hz', 'Amplitude'});
    writetable(fftTableRaw, fullfile(outputDir, ...
        sprintf("%s_%s_FFT_raw006s_data.xlsx", erase(caseName, " "), deviceNameUnder)));

    %% 汇总结果
    newRow = table( ...
        string(caseName), ...
        string(deviceName), ...
        rollFreq, ...
        doubleFreq, ...
        metrics_1s.mainFreq, ...
        metrics_1s.mainAmp, ...
        metrics_1s.rollAmp, ...
        metrics_1s.doubleAmp, ...
        metrics_1s.doubleToRoll, ...
        metricsRaw.mainFreq, ...
        metricsRaw.mainAmp, ...
        metricsRaw.rollAmp, ...
        metricsRaw.doubleAmp, ...
        metricsRaw.doubleToRoll, ...
        1 / rollFreq, ...
        1 / doubleFreq, ...
        'VariableNames', { ...
            '工况', ...
            '测点', ...
            '横摇频率_Hz', ...
            '二倍频_Hz', ...
            '每秒平均主频_Hz', ...
            '每秒平均主频幅值', ...
            '每秒平均基频幅值', ...
            '每秒平均二倍频幅值', ...
            '每秒平均二倍频基频比', ...
            '原始数据主频_Hz', ...
            '原始数据主频幅值', ...
            '原始数据基频幅值', ...
            '原始数据二倍频幅值', ...
            '原始数据二倍频基频比', ...
            '横摇周期_s', ...
            '二倍频周期_s' ...
        } ...
    );

    summaryAll = [summaryAll; newRow]; %#ok<AGROW>

    fprintf("%s %s FFT 分析结果：\n", caseName, deviceName);
    fprintf("每秒平均主频 = %.4f Hz，二倍频/基频 = %.4f\n", ...
        metrics_1s.mainFreq, metrics_1s.doubleToRoll);
    fprintf("原始数据主频 = %.4f Hz，二倍频/基频 = %.4f\n", ...
        metricsRaw.mainFreq, metricsRaw.doubleToRoll);
end

%% 绘制四个横摇频率三维峰峦 FFT 图
plotNatureFFTRidge3D(fftRaw, rawMaxFreq, char(selectedDevice), plotSettings);

%% 导出汇总结果
summaryFile = fullfile(outputDir, "FFT_summary_all_cases_Nature.xlsx");
writetable(summaryAll, summaryFile);

disp(" ");
disp("四组工况 FFT 汇总结果：");
disp(summaryAll);
fprintf("\n全部 FFT 图和数据已保存到：\n%s\n", outputDir);

%% 局部函数
function setNatureFigureDefaults()
    textFontName = pickAvailableFont(["SimSun", "宋体", "Microsoft YaHei", "SimHei", "Arial Unicode MS"]);
    numberFontName = pickAvailableFont(["Times New Roman", "Times", "Arial"]);

    set(groot, "defaultFigureColor", "w");
    set(groot, "defaultAxesFontName", numberFontName);
    set(groot, "defaultTextFontName", textFontName);
    set(groot, "defaultAxesFontSize", 13);
    set(groot, "defaultAxesLineWidth", 0.9);
    set(groot, "defaultAxesBox", "off");
    set(groot, "defaultAxesTickDir", "out");
    set(groot, "defaultAxesTickLength", [0.012 0.012]);
    set(groot, "defaultLineLineWidth", 1.6);
    set(groot, "defaultLegendBox", "off");
    set(groot, "defaultLegendFontSize", 9);
end

function fontName = pickAvailableFont(candidates)
    availableFonts = string(listfonts);
    fontName = "Arial";

    for i = 1:numel(candidates)
        if any(strcmpi(availableFonts, candidates(i)))
            fontName = candidates(i);
            return;
        end
    end
end

function colors = naturePalette()
    colors.blue = [0.000, 0.278, 0.671];
    colors.sky = [0.337, 0.706, 0.914];
    colors.teal = [0.000, 0.471, 0.451];
    colors.green = [0.000, 0.620, 0.451];
    colors.orange = [0.835, 0.369, 0.000];
    colors.red = [0.733, 0.157, 0.184];
    colors.purple = [0.494, 0.184, 0.557];
    colors.gray = [0.220, 0.220, 0.220];
    colors.lightGray = [0.890, 0.890, 0.890];

    colors.caseLines = [
        colors.blue
        colors.orange
        colors.green
        colors.purple
    ];

    colors.caseFaces = [
        0.477, 0.694, 0.824
        0.929, 0.627, 0.329
        0.520, 0.780, 0.662
        0.647, 0.525, 0.745
    ];
end

function [freq, amp] = singleSidedFFT(signal, fs)
    y = signal(:);
    y = fillmissing(y, "linear", "EndValues", "nearest");
    y = y - mean(y, "omitnan");

    N = numel(y);
    Y = fft(y);

    P2 = abs(Y / N);
    amp = P2(1:floor(N / 2) + 1);
    amp(2:end-1) = 2 * amp(2:end-1);

    freq = fs * (0:floor(N / 2)) / N;
end

function metrics = extractFFTMetrics(freq, amp, rollFreq, doubleFreq, maxFreq)
    [~, idxRoll] = min(abs(freq - rollFreq));
    [~, idxDouble] = min(abs(freq - doubleFreq));

    searchMask = freq > 0 & freq <= maxFreq;
    freqSearch = freq(searchMask);
    ampSearch = amp(searchMask);

    [mainAmp, idxMain] = max(ampSearch);

    metrics.mainFreq = freqSearch(idxMain);
    metrics.mainAmp = mainAmp;
    metrics.rollAmp = amp(idxRoll);
    metrics.doubleAmp = amp(idxDouble);
    metrics.doubleToRoll = metrics.doubleAmp / max(metrics.rollAmp, eps);
end

function plotNatureFFTRidge3D(fftData, maxFreq, deviceName, plotSettings)
    colors = naturePalette();

    fig = figure("Name", "四个横摇频率 FFT 三维峰峦图", ...
        "Units", "centimeters", ...
        "Position", [2 2 18.4 13.2], ...
        "Color", "w");

    ax = axes(fig);
    hold(ax, "on");

    zMax = 0;
    lineHandles = gobjects(1, numel(fftData));
    legendText = cell(1, numel(fftData));

    for i = 1:numel(fftData)
        mask = fftData(i).freq >= 0 & fftData(i).freq <= maxFreq;

        freqPlot = fftData(i).freq(mask);
        ampPlot = fftData(i).amp(mask);

        freqPlot = freqPlot(:)';
        ampPlot = ampPlot(:)';

        rollFreq = fftData(i).rollFreq;
        lineColor = colors.caseLines(i, :);
        faceColor = colors.caseFaces(i, :);

        nFine = max(numel(freqPlot) * plotSettings.interpolationFactor, 500);
        freqFine = linspace(min(freqPlot), max(freqPlot), nFine);
        ampFine = interp1(freqPlot, ampPlot, freqFine, "pchip");

        localWindow = min(plotSettings.smoothWindow, numel(ampFine));
        if mod(localWindow, 2) == 0
            localWindow = max(1, localWindow - 1);
        end

        if localWindow >= 3
            ampSmooth = smoothdata(ampFine, "gaussian", localWindow);
        else
            ampSmooth = ampFine;
        end

        ampSmooth = max(ampSmooth, 0);

        mainFreq = fftData(i).metrics.mainFreq;
        mainAmpSmooth = interp1(freqFine, ampSmooth, mainFreq, "linear", "extrap");

        fill3(ax, ...
            [freqFine, fliplr(freqFine)], ...
            [rollFreq * ones(size(freqFine)), rollFreq * ones(size(freqFine))], ...
            [ampSmooth, zeros(size(ampSmooth))], ...
            faceColor, ...
            "FaceAlpha", plotSettings.faceAlpha, ...
            "EdgeColor", "none", ...
            "HandleVisibility", "off");

        lineHandles(i) = plot3(ax, ...
            freqFine, ...
            rollFreq * ones(size(freqFine)), ...
            ampSmooth, ...
            "Color", lineColor, ...
            "LineWidth", 1.95);

        scatter3(ax, ...
            mainFreq, rollFreq, mainAmpSmooth, ...
            32, ...
            "MarkerFaceColor", lineColor, ...
            "MarkerEdgeColor", "w", ...
            "LineWidth", 0.8, ...
            "HandleVisibility", "off");

        if plotSettings.showPeakLabels
            text(ax, ...
                mainFreq, ...
                rollFreq, ...
                mainAmpSmooth + plotSettings.peakLabelOffset * max(mainAmpSmooth, 1), ...
                sprintf("%.2f Hz", mainFreq), ...
                "Color", lineColor, ...
                "FontName", "Times New Roman", ...
                "FontSize", 12, ...
                "FontWeight", "bold", ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "bottom", ...
                "BackgroundColor", "w", ...
                "Margin", 1.5, ...
                "HandleVisibility", "off");
        end

        doubleAmpSmooth = interp1(freqFine, ampSmooth, fftData(i).doubleFreq, ...
            "linear", "extrap");

        plot3(ax, ...
            [fftData(i).doubleFreq, fftData(i).doubleFreq], ...
            [rollFreq, rollFreq], ...
            [0, doubleAmpSmooth], ...
            "Color", lineColor, ...
            "LineStyle", ":", ...
            "LineWidth", 1.05, ...
            "HandleVisibility", "off");

        zMax = max(zMax, max(ampSmooth, [], "omitnan"));

        legendText{i} = sprintf("%s | %.3f Hz | %.2f", ...
            fftData(i).caseName, ...
            fftData(i).metrics.mainFreq, ...
            fftData(i).metrics.doubleToRoll);
    end

    zMax = zMax * 1.14;
    if zMax <= 0 || isnan(zMax)
        zMax = 1;
    end

    rollFreqs = [fftData.rollFreq];

    xlim(ax, [0 maxFreq]);
    ylim(ax, [min(rollFreqs) - 0.015, max(rollFreqs) + 0.015]);
    zlim(ax, [0 zMax]);

    ax.FontName = "Times New Roman";
    ax.FontSize = 15;

    xlabel(ax, "FFT 频率 (Hz)", "FontName", "SimSun", "FontSize", 18, "FontWeight", "bold");
    ylabel(ax, "横摇频率 (Hz)", "FontName", "SimSun", "FontSize", 18, "FontWeight", "bold");
    zlabel(ax, "FFT 幅值", "FontName", "SimSun", "FontSize", 18, "FontWeight", "bold");

    captionText = sprintf("测点 %s；原始 0.06 s 信号；半透明峰面展示频谱能量分布", deviceName);
    text(ax, maxFreq * 0.03, max(rollFreqs) + 0.008, zMax * 0.93, captionText, ...
        "FontName", "SimSun", ...
        "FontSize", 14, ...
        "FontWeight", "bold", ...
        "Color", [0.25 0.25 0.25], ...
        "BackgroundColor", "w", ...
        "Margin", 3, ...
        "HorizontalAlignment", "left", ...
        "VerticalAlignment", "top", ...
        "HandleVisibility", "off");

    yticks(ax, rollFreqs);
    yticklabels(ax, arrayfun(@(v) sprintf("%.2f", v), rollFreqs, ...
        "UniformOutput", false));

    xticks(ax, 0:plotSettings.frequencyTickStep:maxFreq);

    grid(ax, "on");
    box(ax, "on");

    ax.GridColor = colors.lightGray;
    ax.GridAlpha = 0.72;
    ax.MinorGridColor = colors.lightGray;
    ax.MinorGridAlpha = 0.28;
    ax.XMinorGrid = "on";
    ax.YMinorGrid = "on";
    ax.Layer = "top";
    ax.Projection = "perspective";
    ax.PlotBoxAspectRatio = [1.45 0.72 0.78];
    ax.Color = [1 1 1];

    view(ax, plotSettings.viewAngle);

    legend(ax, lineHandles, legendText, ...
        "Location", "northeastoutside", ...
        "FontName", "Times New Roman", ...
        "FontSize", 11);

    rotate3d(fig, "on");

disp("三维 FFT 峰峦图已在 MATLAB 中打开。");
disp("可直接用鼠标拖动图窗手动调节视角。");
disp("调好后可在 MATLAB 图窗中手动保存图片或 FIG 文件。");

end
