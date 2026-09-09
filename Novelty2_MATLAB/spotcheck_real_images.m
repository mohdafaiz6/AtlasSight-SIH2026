function resTable = spotcheck_real_images(datasetDir)
% SPOTCHECK_REAL_IMAGES - Runs real spot-check inference on 15 APTOS images in MATLAB
% Extracts real pixel counts (EX, SE, MA, HE, NV) and compares with clinician labels.
%
% Usage:
%   spotcheck_real_images()
%   resTable = spotcheck_real_images('path/to/dataset')

    if nargin < 1 || isempty(datasetDir)
        candidates = { ...
            pwd, ...
            fullfile(pwd, 'aptos2019-blindness-detection'), ...
            fullfile(pwd, '..', 'aptos2019-blindness-detection'), ...
            fullfile(pwd, '..', 'Novelty2_Deliverables', 'aptos2019-blindness-detection'), ...
            '/Users/dilip018/Desktop/SIH/AtlasSight-SIH2026/Novelty2_Deliverables/aptos2019-blindness-detection', ...
            '/Users/dilip018/Downloads/aptos2019-blindness-detection' ...
        };
        datasetDir = '.';
        for i = 1:length(candidates)
            if exist(fullfile(candidates{i}, 'train.csv'), 'file')
                datasetDir = candidates{i};
                break;
            end
        end
    end

    csvPath = fullfile(datasetDir, 'train.csv');
    imgDir = fullfile(datasetDir, 'train_images');

    if ~exist(csvPath, 'file')
        error('train.csv not found at: %s', csvPath);
    end

    opts = detectImportOptions(csvPath);
    T = readtable(csvPath, opts);

    % 15 Spot check image IDs matching the held-out test split
    spotIDs = {
        'e50b0174690d', 0;
        'd3e56584a481', 0;
        'd1cf31577a59', 0;
        'c96f743915b5', 1;
        'f72ef9ceeaa8', 1;
        'cf0575534cec', 1;
        'e12d41e7b221', 2;
        'cb602182cde3', 2;
        'cf0824f53dd9', 2;
        'f901d460517c', 3;
        'fcc6aa6755e6', 3;
        'ce207b69ff37', 3;
        'cf1b9d26d38d', 4;
        'd2901144070c', 4;
        'eb1d37b71fd1', 4
    };

    fprintf('===============================================================================================\n');
    fprintf('   LIVE SPOT-CHECK INFERENCE ON 15 REAL APTOS DATASET IMAGES (MATLAB INFERENCE)\n');
    fprintf('===============================================================================================\n');
    fprintf('%-14s | %-9s | %-9s | %-8s | %-8s | %-6s | %-6s | %-6s | %-6s | %-12s\n', ...
        'Image ID', 'True ICDR', 'Pred ICDR', 'True Ref', 'Pred Ref', 'EX px', 'MA px', 'HE px', 'NV px', 'Triage Match');
    fprintf('-----------------------------------------------------------------------------------------------\n');

    idList = {};
    trueICDR = [];
    predICDR = [];
    trueRef = [];
    predRef = [];
    exPxList = [];
    maPxList = [];
    hePxList = [];
    nvPxList = [];
    matchList = {};

    for i = 1:size(spotIDs, 1)
        sid = spotIDs{i, 1};
        tGrade = spotIDs{i, 2};
        tRef = double(tGrade >= 2);

        imgPath = fullfile(imgDir, [sid, '.png']);
        if ~exist(imgPath, 'file')
            continue;
        end

        raw = imread(imgPath);
        img = imresize(raw, [1024, 1024]);
        [H, W, ~] = size(img);
        redCh = double(img(:, :, 1));
        greenCh = double(img(:, :, 2));

        [X, Y] = meshgrid(1:W, 1:H);
        retinaMask = ((X - W/2).^2 + (Y - H/2).^2) <= (W * 0.40)^2;
        fundusMask = ((X - W/2).^2 + (Y - H/2).^2) <= (W/2 - 20)^2;

        % OD
        medRed = medfilt2(redCh, [15, 15]);
        medRed(~retinaMask) = 0;
        threshOD = prctile(medRed(retinaMask), 99.0);
        rawOD = (medRed >= threshOD) & retinaMask;
        CC_OD = bwconncomp(rawOD);
        if CC_OD.NumObjects > 0
            statsOD = regionprops(CC_OD, 'Area', 'Centroid');
            [~, mIdx] = max([statsOD.Area]);
            odCenter = statsOD(mIdx).Centroid;
            odR = max(sqrt(statsOD(mIdx).Area / pi), W * 0.065);
        else
            odCenter = [W * 0.78, H * 0.50];
            odR = W * 0.07;
        end

        odEx = ((X - odCenter(1)).^2 + (Y - odCenter(2)).^2) <= (odR * 1.3)^2;

        % Bright lesions
        se7 = strel('disk', 7);
        topHat = imtophat(uint8(greenCh), se7);
        rawBright = (topHat > 22) & ~odEx & fundusMask;
        CC_b = bwconncomp(rawBright);
        statsB = regionprops(CC_b, 'Area');
        exPx = 0;
        for k = 1:length(statsB)
            if statsB(k).Area >= 4
                exPx = exPx + statsB(k).Area;
            end
        end

        % Dark lesions
        botHat = imbothat(uint8(greenCh), se7);
        rawDark = (botHat > 20) & ~odEx & fundusMask;
        CC_d = bwconncomp(rawDark);
        statsD = regionprops(CC_d, 'Area');
        maPx = 0;
        hePx = 0;
        for k = 1:length(statsD)
            a = statsD(k).Area;
            if a >= 4 && a < 20
                maPx = maPx + a;
            elseif a >= 20
                hePx = hePx + a;
            end
        end

        % Neovascularization
        invG = 255.0 - greenCh;
        se5 = strel('disk', 3);
        vTopHat = imtophat(uint8(invG), se5);
        distOD = sqrt((X - odCenter(1)).^2 + (Y - odCenter(2)).^2);
        nvdAnnulus = (distOD >= odR * 1.05) & (distOD <= odR * 2.2) & fundusMask;
        rawNV = (vTopHat > 24) & nvdAnnulus;
        CC_nv = bwconncomp(rawNV);
        statsNV = regionprops(CC_nv, 'Area');
        nvPx = 0;
        for k = 1:length(statsNV)
            if statsNV(k).Area >= 8 && statsNV(k).Area < 500
                nvPx = nvPx + statsNV(k).Area;
            end
        end

        % Rule-based triage prediction
        if nvPx > 50
            pGrade = 4;
        elseif hePx > 300 || (hePx > 100 && exPx > 100)
            pGrade = 3;
        elseif exPx > 50 || hePx > 50
            pGrade = 2;
        elseif maPx > 0 || hePx > 0 || exPx > 0
            pGrade = 1;
        else
            pGrade = 0;
        end

        pRef = double(pGrade >= 2);
        isMatch = (tRef == pRef);
        matchStr = 'MATCH';
        if ~isMatch, matchStr = 'MISMATCH'; end

        fprintf('%-14s | %-9d | %-9d | %-8d | %-8d | %-6d | %-6d | %-6d | %-6d | %-12s\n', ...
            sid, tGrade, pGrade, tRef, pRef, exPx, maPx, hePx, nvPx, matchStr);

        idList{end+1, 1} = sid; %#ok<AGROW>
        trueICDR(end+1, 1) = tGrade; %#ok<AGROW>
        predICDR(end+1, 1) = pGrade; %#ok<AGROW>
        trueRef(end+1, 1) = tRef; %#ok<AGROW>
        predRef(end+1, 1) = pRef; %#ok<AGROW>
        exPxList(end+1, 1) = exPx; %#ok<AGROW>
        maPxList(end+1, 1) = maPx; %#ok<AGROW>
        hePxList(end+1, 1) = hePx; %#ok<AGROW>
        nvPxList(end+1, 1) = nvPx; %#ok<AGROW>
        matchList{end+1, 1} = matchStr; %#ok<AGROW>
    end
    fprintf('===============================================================================================\n');

    TP = sum((trueRef == 1) & (predRef == 1));
    FN = sum((trueRef == 1) & (predRef == 0));
    TN = sum((trueRef == 0) & (predRef == 0));
    FP = sum((trueRef == 0) & (predRef == 1));

    sens = TP / (TP + FN);
    spec = TN / (TN + FP);
    acc  = (TP + TN) / length(trueRef);

    fprintf('\nREAL SPOT-CHECK RESULTS IN MATLAB (N = %d real images):\n', length(trueRef));
    fprintf('  - Referable DR Sensitivity: %.1f%% (%d/%d)\n', sens * 100, TP, TP + FN);
    fprintf('  - Referable DR Specificity: %.1f%% (%d/%d)\n', spec * 100, TN, TN + FP);
    fprintf('  - Overall Triage Accuracy:  %.1f%% (%d/%d)\n', acc * 100, TP + TN, length(trueRef));

    resTable = table(idList, trueICDR, predICDR, trueRef, predRef, exPxList, maPxList, hePxList, nvPxList, matchList, ...
        'VariableNames', {'id_code', 'true_grade', 'pred_grade', 'true_referable', 'pred_referable', 'ex_px', 'ma_px', 'he_px', 'nv_px', 'triage_match'});

    writetable(resTable, 'real_spotcheck_predictions_matlab.csv');
    fprintf('Saved raw spot-check results to: real_spotcheck_predictions_matlab.csv\n\n');
end

function q = prctile(x, p)
% PRCTILE - Pure base MATLAB implementation of prctile without Statistics Toolbox
    x = x(~isnan(x));
    if isempty(x)
        q = NaN;
        return;
    end
    x = sort(x(:));
    N = length(x);
    if N == 1
        q = x(1);
        return;
    end
    idx = 1 + (N - 1) * (p / 100);
    i_low = max(floor(idx), 1);
    i_high = min(ceil(idx), N);
    weight = idx - i_low;
    q = (1 - weight) * x(i_low) + weight * x(i_high);
end
