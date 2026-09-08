function [report, G] = mkg_explainability(fovea, opticDisc, odRadiusPx, lesions, fundusImg)
% MKG_EXPLAINABILITY - Medical Knowledge Graph & ETDRS CSME Explainability
%
% Integrates:
%   1. Optic Disc physical calibration (1 Disc Diameter = 1500 µm).
%   2. ETDRS CSME Rule 1 evaluation (Hard Exudates <= 500 µm from foveal center).
%   3. ICDR 0-4 Diabetic Retinopathy Severity Grading.
%   4. Native MATLAB digraph modeling and clinical text narrative synthesis.
%
% Usage:
%   mkg_explainability() % Runs built-in demonstration case
%   [report, G] = mkg_explainability(fovea, opticDisc, odRadiusPx, lesions, fundusImg)

    % Run demonstration if called with no arguments
    if nargin == 0
        disp('Running MKG Explainability demonstration with sample clinical landmarks...');
        fovea = [1024, 768];
        opticDisc = [1550, 768];
        odRadiusPx = 150; % 300 px diameter -> 5.0 µm / pixel
        
        % Sample lesions: 2 critical hard exudates within 500 µm, 2 MAs, 1 HE
        lesions = struct('type', {}, 'centroid', {}, 'area', {});
        lesions(1) = struct('type', 'HardExudate', 'centroid', [1064, 723], 'area', 25);  % ~60 px = 300 µm
        lesions(2) = struct('type', 'HardExudate', 'centroid', [974, 830], 'area', 35);   % ~80 px = 400 µm
        lesions(3) = struct('type', 'HardExudate', 'centroid', [844, 648], 'area', 40);   % ~216 px = 1080 µm
        lesions(4) = struct('type', 'Microaneurysm', 'centroid', [900, 700], 'area', 6);
        lesions(5) = struct('type', 'Microaneurysm', 'centroid', [950, 850], 'area', 8);
        lesions(6) = struct('type', 'Hemorrhage', 'centroid', [820, 650], 'area', 50);
        
        fundusImg = [];
    end

    %% 1. Anatomical Metric Calibration
    AVG_DD_MICRONS = 1500.0;
    CSME_LIMIT_MICRONS = 500.0;
    MACULA_RADIUS_MICRONS = 1500.0;
    MACULA_LIMIT_MICRONS = 1500.0;

    discDiameterPx = 2 * odRadiusPx;
    scaleMicronsPerPixel = AVG_DD_MICRONS / discDiameterPx;

    %% 2. Lesion Analysis & Distance Metric Computation
    numLesions = length(lesions);
    criticalCSMELesions = []; % [lesionIdx, distMicrons, distDD] (Rule 1: <= 500 um)
    clusterCSMELesions = [];  % [lesionIdx, distMicrons, distDD] (Rule 2: <= 1500 um cluster)
    exudateCount = 0;
    heCount = 0;
    maCount = 0;
    nvCount = 0;

    lesionDistMicrons = zeros(numLesions, 1);
    lesionDistDD = zeros(numLesions, 1);

    for i = 1:numLesions
        lType = lesions(i).type;
        lx = lesions(i).centroid(1);
        ly = lesions(i).centroid(2);

        % Euclidean distance to Fovea
        distPx = sqrt((lx - fovea(1))^2 + (ly - fovea(2))^2);
        distUm = distPx * scaleMicronsPerPixel;
        distDD = distUm / AVG_DD_MICRONS;

        lesionDistMicrons(i) = distUm;
        lesionDistDD(i) = distDD;

        if strcmp(lType, 'HardExudate')
            exudateCount = exudateCount + 1;
            if distUm <= CSME_LIMIT_MICRONS
                criticalCSMELesions = [criticalCSMELesions; i, distUm, distDD]; %#ok<AGROW>
            elseif distUm <= MACULA_LIMIT_MICRONS
                clusterCSMELesions = [clusterCSMELesions; i, distUm, distDD]; %#ok<AGROW>
            end
        elseif strcmp(lType, 'Hemorrhage')
            heCount = heCount + 1;
        elseif strcmp(lType, 'Microaneurysm')
            maCount = maCount + 1;
        elseif strcmp(lType, 'Neovascularization')
            nvCount = nvCount + 1;
        end
    end

    %% 3. Clinical Decision Rules (ETDRS CSME Rule 1 & Rule 2, and ICDR DR)
    hasRule1 = ~isempty(criticalCSMELesions);
    hasRule2 = ~hasRule1 && (size(clusterCSMELesions, 1) >= 2);
    hasCSME = hasRule1 || hasRule2;

    if hasRule1
        csmeLabel = 'CSME High Risk (Rule 1: Foveal <= 500 um)';
        csmeRuleText = sprintf('ETDRS Rule 1 Triggered: %d Hard Exudate(s) <= 500 um from Fovea', size(criticalCSMELesions, 1));
    elseif hasRule2
        csmeLabel = 'CSME Threat (Rule 2: Macular Cluster <= 1 DD)';
        csmeRuleText = sprintf('ETDRS Rule 2 Triggered: %d Hard Exudates in Macular Zone <= 1500 um', size(clusterCSMELesions, 1));
    else
        csmeLabel = 'CSME Negative';
        csmeRuleText = 'ETDRS Cleared: No foveal exudates <= 500 um and no macular cluster <= 1 DD';
    end

    % DR Severity check
    if nvCount > 0
        drGrade = 4;
        drLabel = 'Proliferative DR (PDR, ICDR 4)';
        drRuleText = sprintf('ICDR PDR: %d Neovascularization lesion(s) detected', nvCount);
    elseif heCount >= 40
        drGrade = 3;
        drLabel = 'Severe NPDR (ICDR 3)';
        drRuleText = sprintf('ICDR 4-2-1 Rule: Severe hemorrhages detected (total %d)', heCount);
    elseif (heCount > 2 || exudateCount > 2)
        drGrade = 2;
        drLabel = 'Moderate NPDR (ICDR 2)';
        drRuleText = sprintf('ICDR Moderate: Multiple lesions (%d HE, %d EX)', heCount, exudateCount);
    elseif (maCount > 0 || heCount > 0)
        drGrade = 1;
        drLabel = 'Mild NPDR (ICDR 1)';
        drRuleText = sprintf('ICDR Mild: Microaneurysms only (%d detected)', maCount);
    else
        drGrade = 0;
        drLabel = 'No Apparent DR (ICDR 0)';
        drRuleText = 'No diabetic lesions detected';
    end

    %% 4. Build Native MATLAB Digraph (MKG)
    sourceNodes = {};
    targetNodes = {};
    edgeWeights = [];

    % Add CSME Causal Chain
    if hasRule1
        ruleCSMENode = 'Rule: ETDRS CSME Rule 1 (<= 500um)';
        diagCSMENode = ['Diagnosis: ' csmeLabel];
        for k = 1:size(criticalCSMELesions, 1)
            lIdx = criticalCSMELesions(k, 1);
            lNodeName = sprintf('HardExudate #%d (%.0f um)', lIdx, criticalCSMELesions(k, 2));
            sourceNodes{end+1} = lNodeName; %#ok<AGROW>
            targetNodes{end+1} = ruleCSMENode; %#ok<AGROW>
            edgeWeights(end+1) = criticalCSMELesions(k, 2); %#ok<AGROW>
        end
        sourceNodes{end+1} = ruleCSMENode;
        targetNodes{end+1} = diagCSMENode;
        edgeWeights(end+1) = 1;
    elseif hasRule2
        ruleCSMENode = 'Rule: ETDRS CSME Rule 2 (Macular Cluster <= 1 DD)';
        diagCSMENode = ['Diagnosis: ' csmeLabel];
        for k = 1:size(clusterCSMELesions, 1)
            lIdx = clusterCSMELesions(k, 1);
            lNodeName = sprintf('Cluster Exudate #%d (%.0f um)', lIdx, clusterCSMELesions(k, 2));
            sourceNodes{end+1} = lNodeName; %#ok<AGROW>
            targetNodes{end+1} = ruleCSMENode; %#ok<AGROW>
            edgeWeights(end+1) = clusterCSMELesions(k, 2); %#ok<AGROW>
        end
        sourceNodes{end+1} = ruleCSMENode;
        targetNodes{end+1} = diagCSMENode;
        edgeWeights(end+1) = 1;
    else
        ruleCSMENode = 'Rule: ETDRS CSME (Negative)';
        diagCSMENode = ['Diagnosis: ' csmeLabel];
        sourceNodes{end+1} = ruleCSMENode;
        targetNodes{end+1} = diagCSMENode;
        edgeWeights(end+1) = 0;
    end

    % Add DR Severity Chain
    ruleDRNode = ['Rule: ' drRuleText];
    diagDRNode = ['Diagnosis: ' drLabel];
    sourceNodes{end+1} = ruleDRNode;
    targetNodes{end+1} = diagDRNode;
    edgeWeights(end+1) = drGrade;

    G = digraph(sourceNodes, targetNodes, edgeWeights);

    %% 5. Clinical Narrative Synthesis
    fprintf('\n===========================================================\n');
    fprintf('           OPHTHALMIC RADIOMICS MKG REPORT                 \n');
    fprintf('===========================================================\n');
    fprintf('ASSESSMENT: %s | %s\n\n', drLabel, csmeLabel);
    if hasCSME
        fprintf('CSME EXPLAINABILITY:\n  %s\n', csmeRuleText);
        fprintf('  Closest critical lesion: %.1f µm (%.2f DD) from fovea center.\n', ...
                criticalCSMELesions(1, 2), criticalCSMELesions(1, 3));
        fprintf('  RECOMMENDATION: Urgent retinal referral indicated regardless of DR grade.\n\n');
    else
        fprintf('CSME EXPLAINABILITY:\n  %s\n\n', csmeRuleText);
    end
    fprintf('DR SEVERITY RATIONALE:\n  %s\n', drRuleText);
    fprintf('BIOMARKER TOTALS: EX=%d, HE=%d, MA=%d, NV=%d\n', exudateCount, heCount, maCount, nvCount);
    fprintf('CALIBRATION: 1 DD = 1500 µm (%.2f µm/pixel)\n', scaleMicronsPerPixel);
    fprintf('===========================================================\n');

    report.drGrade = drGrade;
    report.drLabel = drLabel;
    report.hasCSME = hasCSME;
    report.csmeLabel = csmeLabel;
    report.scaleMicronsPerPixel = scaleMicronsPerPixel;
    report.criticalCSMELesions = criticalCSMELesions;

    %% 6. Dual Visualization in MATLAB
    figure('Name', 'MKG Explainability & ETDRS CSME Analysis', 'Color', 'w', 'Position', [100, 100, 1400, 600]);

    % Subplot 1: Fundus & Distance Geometry
    subplot(1, 2, 1);
    hold on;
    if ~isempty(fundusImg)
        imshow(fundusImg);
    else
        % Draw synthetic canvas
        viscircles(fovea, 900, 'Color', [0.3 0.1 0.1], 'LineWidth', 1);
        set(gca, 'Color', 'k', 'XLim', [0, 2048], 'YLim', [0, 1536], 'YDir', 'reverse');
    end

    % Draw Optic Disc
    viscircles(opticDisc, odRadiusPx, 'Color', 'c', 'LineWidth', 2);
    text(opticDisc(1), opticDisc(2) - odRadiusPx - 20, 'Optic Disc (1 DD = 1500 µm)', ...
         'Color', 'c', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    % Draw Fovea
    plot(fovea(1), fovea(2), 'y*', 'MarkerSize', 14, 'LineWidth', 2);
    text(fovea(1) - 40, fovea(2) - 40, 'Fovea Center', 'Color', 'y', 'FontWeight', 'bold');

    % 500 µm ETDRS circle
    r500Px = CSME_LIMIT_MICRONS / scaleMicronsPerPixel;
    viscircles(fovea, r500Px, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);

    % 1500 µm (1 DD) Macula circle
    r1500Px = MACULA_RADIUS_MICRONS / scaleMicronsPerPixel;
    viscircles(fovea, r1500Px, 'Color', [1 0.5 0], 'LineStyle', ':', 'LineWidth', 1.5);

    % Plot lesions
    for i = 1:numLesions
        lx = lesions(i).centroid(1);
        ly = lesions(i).centroid(2);
        lType = lesions(i).type;

        if strcmp(lType, 'HardExudate')
            if lesionDistMicrons(i) <= CSME_LIMIT_MICRONS
                plot([lx, fovea(1)], [ly, fovea(2)], 'r-', 'LineWidth', 1.8);
                plot(lx, ly, 'yo', 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'r', 'MarkerSize', 10);
                text((lx+fovea(1))/2, (ly+fovea(2))/2, sprintf('%.0f µm', lesionDistMicrons(i)), ...
                     'Color', 'w', 'BackgroundColor', 'r', 'FontWeight', 'bold', 'FontSize', 8);
            else
                plot(lx, ly, 'yo', 'MarkerFaceColor', 'y', 'MarkerSize', 7);
            end
        elseif strcmp(lType, 'Hemorrhage')
            plot(lx, ly, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
        else
            plot(lx, ly, 'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 6);
        end
    end
    title('Retinal Topography & ETDRS CSME Distance Analysis', 'FontSize', 12, 'FontWeight', 'bold');
    axis off;

    % Subplot 2: Native Digraph Layout
    subplot(1, 2, 2);
    hG = plot(G, 'Layout', 'layered', 'Direction', 'right', 'ArrowSize', 14, ...
              'MarkerSize', 8, 'NodeColor', [0.2 0.6 0.8], 'EdgeColor', [0.8 0.2 0.2], ...
              'LineWidth', 1.8, 'NodeFontSize', 9, 'NodeFontWeight', 'bold');
    title('Medical Knowledge Graph (Deduction DAG)', 'FontSize', 12, 'FontWeight', 'bold');
    axis off;
end
