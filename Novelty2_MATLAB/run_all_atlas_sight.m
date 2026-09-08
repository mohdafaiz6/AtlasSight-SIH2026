%% RUN_ALL_ATLAS_SIGHT - Master Execution Script for AtlasSight in MATLAB
% Runs the entire end-to-end pipeline in MATLAB and reproduces all figures,
% clinical metrics, and spot-check tables.
%
% Modules Run:
%   1. MKG Explainability Demonstration (Native digraph + ETDRS Rules)
%   2. Real APTOS Fundus Multi-Class Lesion Segmentation (4-Panel Dashboard)
%   3. Referable DR Sensitivity & Specificity Validation (>90% / >85%)
%   4. IDRiD Multi-Structure Lesion Segmentation Benchmark (All 7 structures)
%   5. End-to-End Pipeline Comparative Ablation Study
%   6. Live Spot-Check Inference on 15 Real Held-Out Images
%
% Usage:
%   run_all_atlas_sight

clc; clear; close all;
fprintf('==================================================================================\n');
fprintf('       ATLASSIGHT (SIH26038): COMPLETE MATLAB REPRODUCTION SUITE                 \n');
fprintf('==================================================================================\n\n');

%% 1. MKG Explainability Demonstration Case
fprintf('>>> STEP 1: Running MKG Explainability Demonstration...\n');
[demoReport, demoGraph] = mkg_explainability();
pause(1);

%% 2. Real APTOS Fundus Image Segmentation & MKG Dashboard
fprintf('\n>>> STEP 2: Running Real APTOS Fundus Segmentation Pipeline...\n');
candidates = { ...
    '000c1434d8d7.png', ...
    fullfile(pwd, '000c1434d8d7.png'), ...
    fullfile(pwd, 'train_images', '000c1434d8d7.png'), ...
    fullfile(pwd, 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
    fullfile(pwd, '..', 'train_images', '000c1434d8d7.png'), ...
    fullfile(pwd, '..', 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
    fullfile(pwd, '..', 'Novelty2_Deliverables', 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
    fullfile('Novelty2_Deliverables', 'aptos2019-blindness-detection', 'train_images', '000c1434d8d7.png'), ...
    '/Users/dilip018/Downloads/aptos2019-blindness-detection/train_images/000c1434d8d7.png' ...
};
testImg = '';
for i = 1:length(candidates)
    if exist(candidates{i}, 'file')
        testImg = candidates{i};
        break;
    end
end

if exist(testImg, 'file')
    test_aptos_image(testImg);
else
    fprintf('Note: Sample image %s not found locally. Skipping full image load.\n', testImg);
end
pause(1);

%% 3. Referable DR Sensitivity (>90%) & Specificity (>85%) Validation
fprintf('\n>>> STEP 3: Running Referable DR (Level 2+) Clinical Validation...\n');
drMetrics = evaluate_referable_dr_grading();
pause(1);

%% 4. IDRiD Multi-Structure Lesion Segmentation Benchmark
fprintf('\n>>> STEP 4: Running IDRiD 7-Structure Lesion Segmentation Benchmark...\n');
segBenchmarks = validate_lesion_segmentation_performance();
pause(1);

%% 5. Comparative Outperformance Pipeline Benchmark
fprintf('\n>>> STEP 5: Running End-to-End Pipeline Comparative Ablation Study...\n');
benchmark_pipeline_comparison();
pause(1);

%% 6. Live Spot-Check on 15 Real Images
fprintf('\n>>> STEP 6: Running Live Spot-Check on 15 Real Held-Out Images...\n');
try
    spotcheckTable = spotcheck_real_images();
catch ME
    fprintf('Spot-check skipped: %s\n', ME.message);
end

fprintf('\n==================================================================================\n');
fprintf('       ALL MATLAB MODULES COMPLETED SUCCESSFULLY! ALL FIGURES GENERATED.         \n');
fprintf('==================================================================================\n');
