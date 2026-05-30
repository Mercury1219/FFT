clear; clc; close all;

%% Nature 风格 FFT 分析图
% 说明：
% 1. 仅生成 FFT 分析图，不再输出原始温度曲线或去趋势温度波动图。
% 2. 每个工况的 FFT 图独立保存，不使用合并子图。
% 3. 图片采用白底、克制配色、中文标注，并同时导出 PNG/PDF/SVG。

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

outputDir = fullfile(pwd, "FFT_660kw_smoothed_w5_Nature_Output");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

summaryAll = table();
colors = naturePalette();

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

    %% 每秒平均数据 FFT
    [freq_1s, amp_1s] = singleSidedFFT(tempFluct_1s, 1);
    metrics_1s = extractFFTMetrics(freq_1s, amp_1s, rollFreq, doubleFreq, oneSecondMaxFreq);

    title_1s = sprintf("%s 工况 FFT 频谱", caseName);
    note_1s = sprintf("测点 %s | 主频 %.3f Hz | 二倍频/基频 %.2f", ...
        deviceName, metrics_1s.mainFreq, metrics_1s.doubleToRoll);
    outBase_1s = fullfile(outputDir, sprintf("%s_%s_FFT_1s_Nature", ...
        erase(caseName, " "), deviceNameUnder));

    plotNatureFFT(freq_1s, amp_1s, rollFreq, doubleFreq, oneSecondMaxFreq, ...
        title_1s, note_1s, colors.blue, outBase_1s);

    %% 原始 0.06 s 数据 FFT
    validIdx = ~isnan(time) & ~isnan(temp);
    timeRaw = time(validIdx);
    tempRaw = temp(validIdx);

    timeUniform = (min(timeRaw):rawTimeStep:max(timeRaw))';
    tempUniform = interp1(timeRaw, tempRaw, timeUniform, "linear", "extrap");
    tempUniform = tempUniform - mean(tempUniform, "omitnan");

    [freqRaw, ampRaw] = singleSidedFFT(tempUniform, 1 / rawTimeStep);
    metricsRaw = extractFFTMetrics(freqRaw, ampRaw, rollFreq, doubleFreq, rawMaxFreq);

    titleRaw = sprintf("%s 工况 FFT 频谱", caseName);
    noteRaw = sprintf("测点 %s | 主频 %.3f Hz | 二倍频/基频 %.2f", ...
        deviceName, metricsRaw.mainFreq, metricsRaw.doubleToRoll);
    outBaseRaw = fullfile(outputDir, sprintf("%s_%s_FFT_raw006s_Nature", ...
        erase(caseName, " "), deviceNameUnder));

    plotNatureFFT(freqRaw, ampRaw, rollFreq, doubleFreq, rawMaxFreq, ...
        titleRaw, noteRaw, colors.teal, outBaseRaw);

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

%% 导出汇总结果
summaryFile = fullfile(outputDir, "FFT_summary_all_cases_Nature.xlsx");
writetable(summaryAll, summaryFile);

disp(" ");
disp("四组工况 FFT 汇总结果：");
disp(summaryAll);
fprintf("\n全部 FFT 图和数据已保存到：\n%s\n", outputDir);

%% 局部函数
function setNatureFigureDefaults()
    fontName = pickAvailableFont(["Microsoft YaHei", "SimHei", "Arial Unicode MS", "Arial"]);

    set(groot, "defaultFigureColor", "w");
    set(groot, "defaultAxesFontName", fontName);
    set(groot, "defaultTextFontName", fontName);
    set(groot, "defaultAxesFontSize", 10);
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
    colors.teal = [0.000, 0.471, 0.451];
    colors.orange = [0.835, 0.369, 0.000];
    colors.red = [0.733, 0.157, 0.184];
    colors.gray = [0.220, 0.220, 0.220];
    colors.lightGray = [0.890, 0.890, 0.890];
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

function plotNatureFFT(freq, amp, rollFreq, doubleFreq, maxFreq, figTitle, noteText, mainColor, outBase)
    colors = naturePalette();
    fig = figure("Name", figTitle, "Units", "centimeters", ...
        "Position", [2 2 17.6 10.8], "Color", "w");
    ax = axes(fig);
    hold(ax, "on");

    mask = freq >= 0 & freq <= maxFreq;
    freqPlot = freq(mask);
    ampPlot = amp(mask);

    h = area(ax, freqPlot, ampPlot, ...
        "FaceColor", mainColor, ...
        "FaceAlpha", 0.18, ...
        "EdgeColor", mainColor, ...
        "LineWidth", 1.8);
    h.DisplayName = "FFT 幅值谱";

    [peakAmp, idxPeak] = max(ampPlot(freqPlot > 0));
    freqNonzero = freqPlot(freqPlot > 0);
    peakFreq = freqNonzero(idxPeak);

    s = scatter(ax, peakFreq, peakAmp, 34, ...
        "MarkerFaceColor", colors.orange, ...
        "MarkerEdgeColor", "w", ...
        "LineWidth", 0.8, ...
        "DisplayName", "主峰");

    yMax = max(ampPlot) * 1.22;
    if yMax <= 0 || isnan(yMax)
        yMax = 1;
    end

    xline(ax, rollFreq, "--", ...
        "Color", colors.gray, ...
        "LineWidth", 1.15, ...
        "HandleVisibility", "off");
    xline(ax, doubleFreq, "--", ...
        "Color", colors.red, ...
        "LineWidth", 1.15, ...
        "HandleVisibility", "off");

    text(ax, rollFreq, yMax * 0.90, sprintf("基频 %.2f Hz", rollFreq), ...
        "Color", colors.gray, ...
        "FontSize", 8.5, ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "top", ...
        "BackgroundColor", "w", ...
        "Margin", 2);
    text(ax, doubleFreq, yMax * 0.82, sprintf("二倍频 %.2f Hz", doubleFreq), ...
        "Color", colors.red, ...
        "FontSize", 8.5, ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "top", ...
        "BackgroundColor", "w", ...
        "Margin", 2);

    text(ax, peakFreq, min(peakAmp * 1.08, yMax * 0.92), ...
        sprintf("主频 %.3f Hz", peakFreq), ...
        "Color", colors.gray, ...
        "FontSize", 9, ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "bottom");

    title(ax, figTitle, "FontSize", 11, "FontWeight", "bold");
    subtitle(ax, noteText, "FontSize", 9, "Color", [0.35 0.35 0.35]);
    xlabel(ax, "频率 (Hz)", "FontSize", 10);
    ylabel(ax, "FFT 幅值", "FontSize", 10);

    xlim(ax, [0 maxFreq]);
    ylim(ax, [0 yMax]);
    grid(ax, "on");
    ax.GridColor = colors.lightGray;
    ax.GridAlpha = 0.55;
    ax.MinorGridAlpha = 0.20;
    ax.Layer = "top";

    legend(ax, [h, s], {"FFT 幅值谱", "主峰"}, ...
        "Location", "northeast", "NumColumns", 1);

    exportgraphics(fig, outBase + ".png", "Resolution", 600);
    exportgraphics(fig, outBase + ".pdf", "ContentType", "vector");
    exportgraphics(fig, outBase + ".svg", "ContentType", "vector");
    close(fig);
end
