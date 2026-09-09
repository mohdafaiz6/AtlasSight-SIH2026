function report = test_aptos_image(imagePath)
% TEST_APTOS_IMAGE - End-to-end Retinal Lesion Segmentation & MKG in MATLAB
%
% Performs:
%   1. Automated Optic Disc & Fovea localization
%   2. Mathematical morphology multi-class segmentation:
%      - Hard Exudates (Top-Hat, area < 80 px)
%      - Soft Exudates / Cotton Wool Spots (Top-Hat, area >= 80 px)
%      - Microaneurysms (Bottom-Hat, area < 20 px)
%      - Hemorrhages (Bottom-Hat, area >= 20 px)
%      - Neovascularization (Inverted Green channel peripapillary annulus)
%   3. Dynamic physical metric calibration (1 DD = 1500 µm)
%   4. Dual-panel MKG explainability report & visual dashboard
%   5. 4-Panel Multi-Class Segmentation Breakdown Dashboard
%
% Usage:
%   test_aptos_image() % Runs on default sample image
%   report = test_aptos_image('path_to_fundus.png');

    % Default sample paths
    if nargin < 1 || isempty(imagePath)
        candidates = { ...
            '000c1434d8d7.png', ...
            fullfile(pwd, '000c1434d8d7.png'), ...
            fullfile(pwd, 'train_images', '000c1434d8d7.png'), ...
            fullfile(pwd, 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
            fullfile(pwd, '..', 'train_images', '000c1434d8d7.png'), ...
            fullfile(pwd, '..', 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
            fullfile(pwd, '..', 'Novelty2_Deliverables', 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
            '/Users/dilip018/Desktop/SIH/AtlasSight-SIH2026/Novelty2_Deliverables/aptos2019-blindness-detection/train_images/000c1434d8d7.png', ...
            '/Users/dilip018/Downloads/aptos2019-blindness-detection/train_images/000c1434d8d7.png' ...
        };
        imagePath = '';
        for i = 1:length(candidates)
            if exist(candidates{i}, 'file')
                imagePath = candidates{i};
                break;
            end
        end
        if isempty(imagePath)
            imagePath = '000c1434d8d7.png';
        end
    end

    if ~exist(imagePath, 'file')
        error('Image file not found: %s. Please provide a path to a fundus image (e.g. test_aptos_image(''my_image.png''))', imagePath);
    end

    [~, baseName, ~] = fileparts(imagePath);
    fprintf('Loading image: %s\n', imagePath);
    rawImg = imread(imagePath);
    img = imresize(rawImg, [1024, 1024]);
    [H, W, ~] = size(img);

    redCh = double(img(:, :, 1));
    greenCh = double(img(:, :, 2));

    %% 1. Optic Disc Detection & Physical Calibration
    [X, Y] = meshgrid(1:W, 1:H);
    retinaMask = ((X - W/2).^2 + (Y - H/2).^2) <= (W * 0.40)^2;
    fundusMask = ((X - W/2).^2 + (Y - H/2).^2) <= (W/2 - 20)^2;

    medRed = medfilt2(redCh, [15, 15]);
    medRed(~retinaMask) = 0;
    threshOD = prctile(medRed(retinaMask), 99.0);
    rawOD = (medRed >= threshOD) & retinaMask;

    CC_OD = bwconncomp(rawOD);
    if CC_OD.NumObjects > 0
        statsOD = regionprops(CC_OD, 'Area', 'Centroid');
        [~, maxIdx] = max([statsOD.Area]);
        opticDisc = statsOD(maxIdx).Centroid;
        odRadiusPx = max(sqrt(statsOD(maxIdx).Area / pi), W * 0.065);
    else
        opticDisc = [W * 0.78, H * 0.50];
        odRadiusPx = W * 0.07;
    end

    discDiameterPx = 2 * odRadiusPx;
    scaleMicronsPerPx = 1500.0 / discDiameterPx;

    %% 2. Fovea Estimation
    if opticDisc(1) > W / 2
        expFx = opticDisc(1) - 2.5 * discDiameterPx;
    else
        expFx = opticDisc(1) + 2.5 * discDiameterPx;
    end
    expFx = max(min(expFx, W - 100), 100);
    expFy = opticDisc(2);

    sr = round(odRadiusPx * 0.8);
    y1 = max(round(expFy - sr), 1); y2 = min(round(expFy + sr), H);
    x1 = max(round(expFx - sr), 1); x2 = min(round(expFx + sr), W);

    macWindow = medfilt2(greenCh(y1:y2, x1:x2), [9, 9]);
    [~, minIdx] = min(macWindow(:));
    [minY, minX] = ind2sub(size(macWindow), minIdx);
    fovea = [x1 + minX - 1, y1 + minY - 1];

    %% 3. Morphological Lesion Segmentation
    odExclusion = ((X - opticDisc(1)).^2 + (Y - opticDisc(2)).^2) <= (odRadiusPx * 1.3)^2;

    % A. Bright lesions (Top-Hat)
    se7 = strel('disk', 7);
    topHat = imtophat(uint8(greenCh), se7);
    rawBright = (topHat > 22) & ~odExclusion & fundusMask;

    CC_bright = bwconncomp(rawBright);
    statsBright = regionprops(CC_bright, 'Area', 'Centroid', 'PixelIdxList');

    hardExMask = false(H, W);
    softExMask = false(H, W);
    lesions = struct('type', {}, 'centroid', {}, 'area', {});

    for k = 1:length(statsBright)
        areaK = statsBright(k).Area;
        if areaK >= 4 && areaK < 80
            hardExMask(statsBright(k).PixelIdxList) = true;
            lesions(end+1) = struct('type', 'HardExudate', 'centroid', statsBright(k).Centroid, 'area', areaK); %#ok<AGROW>
        elseif areaK >= 80
            softExMask(statsBright(k).PixelIdxList) = true;
            lesions(end+1) = struct('type', 'SoftExudate', 'centroid', statsBright(k).Centroid, 'area', areaK); %#ok<AGROW>
        end
    end

    % B. Dark lesions (Bottom-Hat)
    botHat = imbothat(uint8(greenCh), se7);
    rawDark = (botHat > 20) & ~odExclusion & fundusMask;

    CC_dark = bwconncomp(rawDark);
    statsDark = regionprops(CC_dark, 'Area', 'Centroid', 'PixelIdxList');

    maMask = false(H, W);
    heMask = false(H, W);

    for k = 1:length(statsDark)
        areaK = statsDark(k).Area;
        if areaK >= 4 && areaK < 20
            maMask(statsDark(k).PixelIdxList) = true;
            lesions(end+1) = struct('type', 'Microaneurysm', 'centroid', statsDark(k).Centroid, 'area', areaK); %#ok<AGROW>
        elseif areaK >= 20
            heMask(statsDark(k).PixelIdxList) = true;
            lesions(end+1) = struct('type', 'Hemorrhage', 'centroid', statsDark(k).Centroid, 'area', areaK); %#ok<AGROW>
        end
    end

    % C. Neovascularization (Inverted green channel peripapillary top-hat)
    invG = 255.0 - greenCh;
    se5 = strel('disk', 3);
    vesselTopHat = imtophat(uint8(invG), se5);
    distFromOD = sqrt((X - opticDisc(1)).^2 + (Y - opticDisc(2)).^2);
    nvdAnnulus = (distFromOD >= odRadiusPx * 1.05) & (distFromOD <= odRadiusPx * 2.2) & fundusMask;

    rawNV = (vesselTopHat > 24) & nvdAnnulus;
    CC_NV = bwconncomp(rawNV);
    statsNV = regionprops(CC_NV, 'Area', 'Centroid', 'PixelIdxList');
    nvMask = false(H, W);

    for k = 1:length(statsNV)
        areaK = statsNV(k).Area;
        if areaK >= 8 && areaK < 500
            nvMask(statsNV(k).PixelIdxList) = true;
            lesions(end+1) = struct('type', 'Neovascularization', 'centroid', statsNV(k).Centroid, 'area', areaK); %#ok<AGROW>
        end
    end

    odPx = sum(rawOD(:));
    hePx = sum(hardExMask(:));
    sePx = sum(softExMask(:));
    maPx = sum(maMask(:));
    hemPx = sum(heMask(:));
    nvPx = sum(nvMask(:));

    fprintf('Detected Optic Disc: (%.0f, %.0f), Radius: %.1f px\n', opticDisc(1), opticDisc(2), odRadiusPx);
    fprintf('Detected Fovea: (%.0f, %.0f)\n', fovea(1), fovea(2));
    fprintf('Segmented Pixels:\n');
    fprintf('  - Hard Exudates: %d px\n', hePx);
    fprintf('  - Soft Exudates: %d px\n', sePx);
    fprintf('  - Microaneurysms: %d px\n', maPx);
    fprintf('  - Hemorrhages: %d px\n', hemPx);
    fprintf('  - Neovascularization: %d px\n', nvPx);

    %% 4. Run MKG Explainability
    [report, G] = mkg_explainability(fovea, opticDisc, odRadiusPx, lesions, img);
    saveas(gcf, sprintf('aptos_%s_result_matlab.png', baseName));
    fprintf('Saved MKG explanation figure to: aptos_%s_result_matlab.png\n', baseName);

    %% 5. Generate 4-Panel Multi-Class Segmentation Breakdown Dashboard
    figBreakdown = figure('Name', '4-Panel Segmentation Breakdown', 'Color', [0.07 0.07 0.07], 'Position', [100, 100, 1200, 1000]);

    % Panel 1: Original Fundus with Landmarks
    subplot(2, 2, 1);
    if exist('imshow', 'file') == 2
        imshow(img);
    else
        image(img);
        axis image;
    end
    hold on;
    draw_circle_compat(opticDisc, odRadiusPx, 'Color', 'c', 'LineWidth', 1.8, 'LineStyle', '--');
    plot(opticDisc(1), opticDisc(2), 'c+', 'MarkerSize', 12, 'LineWidth', 2);
    plot(fovea(1), fovea(2), 'y*', 'MarkerSize', 14, 'LineWidth', 2);
    title('1. Original Fundus & Anatomical Landmarks', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

    % Panel 2: Multi-Class Pixel Segmentation Overlay
    subplot(2, 2, 2);
    overlayImg = double(img) / 255.0;
    % Cyan for OD
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.4*rawOD) + 0.0 * 0.4 * rawOD;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.4*rawOD) + 0.9 * 0.4 * rawOD;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.4*rawOD) + 0.9 * 0.4 * rawOD;
    % Gold for Hard Exudates
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.85*hardExMask) + 1.0 * 0.85 * hardExMask;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.85*hardExMask) + 0.85 * 0.85 * hardExMask;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.85*hardExMask) + 0.0 * 0.85 * hardExMask;
    % Pale Cyan for Soft Exudates
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.7*softExMask) + 0.8 * 0.7 * softExMask;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.7*softExMask) + 0.95 * 0.7 * softExMask;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.7*softExMask) + 1.0 * 0.7 * softExMask;
    % Red for Hemorrhages
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.8*heMask) + 0.95 * 0.8 * heMask;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.8*heMask) + 0.1 * 0.8 * heMask;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.8*heMask) + 0.1 * 0.8 * heMask;
    % Magenta for Microaneurysms
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.9*maMask) + 1.0 * 0.9 * maMask;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.9*maMask) + 0.0 * 0.9 * maMask;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.9*maMask) + 1.0 * 0.9 * maMask;
    % Lime for Neovascularization
    overlayImg(:, :, 1) = overlayImg(:, :, 1) .* (1 - 0.85*nvMask) + 0.0 * 0.85 * nvMask;
    overlayImg(:, :, 2) = overlayImg(:, :, 2) .* (1 - 0.85*nvMask) + 1.0 * 0.85 * nvMask;
    overlayImg(:, :, 3) = overlayImg(:, :, 3) .* (1 - 0.85*nvMask) + 0.35 * 0.85 * nvMask;
    if exist('imshow', 'file') == 2
        imshow(overlayImg);
    else
        image(overlayImg); axis image; axis off;
    end
    title('2. Multi-Class Pixel Segmentation Overlay', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

    % Panel 3: Bright Lesions Channel (Hard vs Soft Exudates)
    subplot(2, 2, 3);
    brightCanvas = zeros(H, W, 3);
    brightCanvas(:, :, 1) = hardExMask * 1.0 + softExMask * 0.8;
    brightCanvas(:, :, 2) = hardExMask * 0.85 + softExMask * 0.95;
    brightCanvas(:, :, 3) = hardExMask * 0.0 + softExMask * 1.0;
    if exist('imshow', 'file') == 2
        imshow(brightCanvas);
    else
        image(brightCanvas); axis image; axis off;
    end
    title('3. Bright Lesions Channel (EX [Gold] vs SE [Cyan])', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

    % Panel 4: Dark & Vascular Lesions (MAs, Hemorrhages, NV)
    subplot(2, 2, 4);
    darkCanvas = zeros(H, W, 3);
    darkCanvas(:, :, 1) = heMask * 0.9 + maMask * 1.0 + nvMask * 0.0;
    darkCanvas(:, :, 2) = heMask * 0.1 + maMask * 0.0 + nvMask * 1.0;
    darkCanvas(:, :, 3) = heMask * 0.1 + maMask * 1.0 + nvMask * 0.35;
    if exist('imshow', 'file') == 2
        imshow(darkCanvas);
    else
        image(darkCanvas); axis image; axis off;
    end
    title('4. Dark & Vascular Channel (MA [Magenta], HE [Red], NV [Lime])', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

    scaleSq = scaleMicronsPerPx^2;
    burdenStr = sprintf('QUANTITATIVE RADIOMICS LESION BURDEN (Scale: %.2f µm/px):  OD: %d px (%.2f mm²)  |  EX: %d px (%.0f µm²)  |  SE: %d px (%.0f µm²)  |  MA: %d px (%.0f µm²)  |  HE: %d px (%.0f µm²)  |  NV: %d px (%.0f µm²)', ...
        scaleMicronsPerPx, odPx, odPx*scaleSq/1e6, hePx, hePx*scaleSq, sePx, sePx*scaleSq, maPx, maPx*scaleSq, hemPx, hemPx*scaleSq, nvPx, nvPx*scaleSq);
    annotation('textbox', [0.05, 0.01, 0.90, 0.04], 'String', burdenStr, 'Color', 'w', ...
        'BackgroundColor', [0.15 0.15 0.15], 'EdgeColor', [0.4 0.4 0.4], 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    saveas(figBreakdown, sprintf('aptos_%s_segmentation_breakdown_matlab.png', baseName));
    fprintf('Saved segmentation breakdown figure to: aptos_%s_segmentation_breakdown_matlab.png\n', baseName);
end

function h = draw_circle_compat(centers, radii, varargin)
% DRAW_CIRCLE_COMPAT - Base MATLAB fallback for circle drawing (no toolbox required)
    hold on;
    theta = linspace(0, 2*pi, 180);
    h = [];
    for k = 1:size(centers, 1)
        c = centers(k, :);
        r = radii(min(k, end));
        x = c(1) + r * cos(theta);
        y = c(2) + r * sin(theta);
        hp = plot(x, y, varargin{:});
        h = [h; hp]; %#ok<AGROW>
    end
end
