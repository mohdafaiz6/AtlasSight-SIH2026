%% ========================================================================
% MODULE 1
% GRAPH-BASED VASCULAR BIOMARKER FINGERPRINTING
% =========================================================================
%
% NOVELTY:
%
%   Convert the retinal vascular network into a graph and extract:
%
%       1. Degree Centrality
%       2. Betweenness Centrality
%       3. Fractal Dimension
%       4. Vessel Tortuosity
%       5. Junction / Endpoint topology
%       6. Graph connectivity
%
% PIPELINE:
%
%   Fundus Image
%       ->
%   Green Channel
%       ->
%   CLAHE
%       ->
%   Multi-directional Vessel Enhancement
%       ->
%   Vessel Segmentation
%       ->
%   Skeletonization
%       ->
%   Junction + Endpoint Detection
%       ->
%   Vascular Graph
%       ->
%   Graph Biomarkers
%
% FROZEN PARAMETERS:
%   Vessel threshold       = 0.210
%   MinBranchLength        = 30 pixels
%   Node clustering radius = 5 pixels
%
% =========================================================================

clear;
clc;
close all;

%% ========================================================================
% PATH CONFIGURATION
% =========================================================================

defaultImageFolder = ...
    'D:\module1_vessel\dataset\drive\test\images';

defaultMaskFolder = ...
    'D:\module1_vessel\dataset\drive\test\mask';

resultsFolder = ...
    'D:\module1_vessel\results';

if ~exist(resultsFolder,'dir')

    mkdir(resultsFolder);

end

%% ========================================================================
% USER IMAGE SELECTION
% =========================================================================
%
% The user can select any fundus image.
%
% Supported:
%   TIFF
%   PNG
%   JPG
%
% The file-selection dialog opens in the DRIVE test image folder.
%
% =========================================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf(' MODULE 1 - FUNDUS IMAGE SELECTION\n');
fprintf('====================================================\n');
fprintf('Select a fundus image to process.\n');
fprintf('Default folder:\n%s\n\n',defaultImageFolder);

if ~exist(defaultImageFolder,'dir')

    defaultImageFolder = pwd;

end

[selectedFile,selectedPath] = ...
    uigetfile( ...
        { ...
        '*.tif;*.tiff','Fundus Images (*.tif, *.tiff)';
        '*.png','PNG Images (*.png)';
        '*.jpg;*.jpeg','JPEG Images (*.jpg, *.jpeg)';
        '*.*','All Image Files' ...
        }, ...
        'Select Fundus Image', ...
        defaultImageFolder);

%% ------------------------------------------------------------------------
% USER CANCELLED
% -------------------------------------------------------------------------

if isequal(selectedFile,0)

    fprintf('\nImage selection cancelled.\n');
    fprintf('Module 1 execution stopped.\n\n');

    return;

end

imageName = ...
    selectedFile;

imagePath = ...
    fullfile( ...
        selectedPath, ...
        selectedFile);

[~,baseName,~] = ...
    fileparts(selectedFile);

fprintf('Selected image:\n%s\n\n',imagePath);

%% ========================================================================
% FROZEN PARAMETERS
% =========================================================================

vesselThreshold = 0.210;

minBranchLength = 30;

clusterRadius = 5;

%% ========================================================================
% READ FUNDUS IMAGE
% =========================================================================

fundusImage = ...
    imread(imagePath);

if size(fundusImage,3) == 3

    greenChannel = ...
        fundusImage(:,:,2);

else

    greenChannel = ...
        fundusImage;

end

greenDouble = ...
    im2double(greenChannel);

%% ========================================================================
% LOCATE FOV MASK
% =========================================================================
%
% First try the selected image's directory structure.
%
% For DRIVE images, the corresponding mask is searched using the same
% base filename.
%
% If a mask is not available, the complete image area is used.
%
% =========================================================================

possibleMaskLocations = { ...
    fullfile(defaultMaskFolder,[baseName,'.gif']), ...
    fullfile(defaultMaskFolder,[baseName,'.tif']), ...
    fullfile(defaultMaskFolder,[baseName,'.tiff']), ...
    fullfile(defaultMaskFolder,[baseName,'.png']), ...
    fullfile(defaultMaskFolder,[baseName,'.jpg']), ...
    fullfile(selectedPath,[baseName,'.gif']), ...
    fullfile(selectedPath,[baseName,'.tif']), ...
    fullfile(selectedPath,[baseName,'.tiff']), ...
    fullfile(selectedPath,[baseName,'.png'])};

maskPath = '';

for k = 1:numel(possibleMaskLocations)

    if exist(possibleMaskLocations{k},'file')

        maskPath = ...
            possibleMaskLocations{k};

        break;

    end

end

if isempty(maskPath)

    fovMask = ...
        true(size(greenDouble));

    fprintf('FOV mask: Not found - using full image area.\n');

else

    fovMask = ...
        imread(maskPath);

    if size(fovMask,3) > 1

        fovMask = ...
            fovMask(:,:,1);

    end

    fovMask = ...
        fovMask > 0;

    fprintf('FOV mask: %s\n',maskPath);

end

%% ========================================================================
% CLAHE ENHANCEMENT
% =========================================================================

enhancedImage = ...
    adapthisteq( ...
        greenDouble, ...
        'NumTiles',[8 8], ...
        'ClipLimit',0.01);

%% ========================================================================
% MULTI-DIRECTIONAL VESSEL ENHANCEMENT
% =========================================================================

vesselResponse = ...
    zeros(size(enhancedImage));

angles = ...
    0:15:165;

lengths = ...
    [9 15 21];

for L = lengths

    for angle = angles

        se = ...
            strel( ...
                'line', ...
                L, ...
                angle);

        response = ...
            imbothat( ...
                enhancedImage, ...
                se);

        vesselResponse = ...
            max( ...
                vesselResponse, ...
                response);

    end

end

vesselResponse = ...
    mat2gray(vesselResponse);

vesselResponse(~fovMask) = 0;

%% ========================================================================
% VESSEL SEGMENTATION
% =========================================================================

vesselMask = ...
    vesselResponse >= vesselThreshold;

vesselMask(~fovMask) = false;

vesselMask = ...
    bwareaopen( ...
        vesselMask, ...
        10);

%% ========================================================================
% SKELETONIZATION
% =========================================================================

skeleton = ...
    bwskel( ...
        vesselMask, ...
        'MinBranchLength', ...
        minBranchLength);

skeleton(~fovMask) = false;

%% ========================================================================
% BASIC TOPOLOGY
% =========================================================================

branchMask = ...
    bwmorph( ...
        skeleton, ...
        'branchpoints');

endpointMask = ...
    bwmorph( ...
        skeleton, ...
        'endpoints');

skeletonPixels = ...
    nnz(skeleton);

branchPixelCount = ...
    nnz(branchMask);

endpointPixelCount = ...
    nnz(endpointMask);

%% ========================================================================
% JUNCTION CLUSTERING
% =========================================================================

branchGrouping = ...
    imdilate( ...
        branchMask, ...
        strel('disk',clusterRadius,0));

branchCC = ...
    bwconncomp( ...
        branchGrouping, ...
        8);

junctionCount = ...
    branchCC.NumObjects;

junctionXY = ...
    zeros(junctionCount,2);

for k = 1:junctionCount

    [r,c] = ...
        ind2sub( ...
            size(branchGrouping), ...
            branchCC.PixelIdxList{k});

    junctionXY(k,:) = ...
        [mean(c),mean(r)];

end

%% ========================================================================
% ENDPOINT CLUSTERING
% =========================================================================

endpointGrouping = ...
    imdilate( ...
        endpointMask, ...
        strel('disk',clusterRadius,0));

endpointCC = ...
    bwconncomp( ...
        endpointGrouping, ...
        8);

endpointCount = ...
    endpointCC.NumObjects;

endpointXY = ...
    zeros(endpointCount,2);

for k = 1:endpointCount

    [r,c] = ...
        ind2sub( ...
            size(endpointGrouping), ...
            endpointCC.PixelIdxList{k});

    endpointXY(k,:) = ...
        [mean(c),mean(r)];

end

%% ========================================================================
% GRAPH NODE LIST
% =========================================================================

totalNodes = ...
    junctionCount + endpointCount;

allNodes = [ ...
    junctionXY;
    endpointXY];

nodeXY = ...
    allNodes;

%% ========================================================================
% NODE LABEL IMAGE
% =========================================================================
%
% Only actual branchpoint and endpoint pixels receive node labels.
%
% The dilation is used only for grouping.
%
% =========================================================================

nodeLabel = ...
    zeros(size(skeleton));

%% ------------------------------------------------------------------------
% BRANCHPOINT PIXELS
% -------------------------------------------------------------------------

branchPixels = ...
    find(branchMask);

for p = 1:numel(branchPixels)

    idx = ...
        branchPixels(p);

    [r,c] = ...
        ind2sub( ...
            size(skeleton), ...
            idx);

    if junctionCount > 0

        distances = ...
            hypot( ...
                junctionXY(:,1)-c, ...
                junctionXY(:,2)-r);

        [minDistance,nodeID] = ...
            min(distances);

        if minDistance <= clusterRadius

            nodeLabel(idx) = ...
                nodeID;

        end

    end

end

%% ------------------------------------------------------------------------
% ENDPOINT PIXELS
% -------------------------------------------------------------------------

endpointPixels = ...
    find(endpointMask);

for p = 1:numel(endpointPixels)

    idx = ...
        endpointPixels(p);

    [r,c] = ...
        ind2sub( ...
            size(skeleton), ...
            idx);

    if endpointCount > 0

        distances = ...
            hypot( ...
                endpointXY(:,1)-c, ...
                endpointXY(:,2)-r);

        [minDistance,nodeID] = ...
            min(distances);

        if minDistance <= clusterRadius

            nodeLabel(idx) = ...
                junctionCount + nodeID;

        end

    end

end

%% ========================================================================
% SKELETON CONNECTIVITY
% =========================================================================

skeletonCC = ...
    bwconncomp( ...
        skeleton, ...
        8);

connectedComponents = ...
    skeletonCC.NumObjects;

if skeletonPixels > 0 && ...
   connectedComponents > 0

    componentSizes = ...
        cellfun( ...
            @numel, ...
            skeletonCC.PixelIdxList);

    largestComponentRatio = ...
        max(componentSizes) / skeletonPixels;

else

    largestComponentRatio = 0;

end

%% ========================================================================
% BUILD VASCULAR GRAPH
% =========================================================================

    remainingSkeleton = ...
        skeleton & ...
        nodeLabel == 0;
    
    remainingCC = ...
        bwconncomp( ...
            remainingSkeleton, ...
            8);
    
    edgeList = ...
        zeros(0,2);

%% ========================================================================
% BUILD VASCULAR GRAPH - ROBUST SKELETON TRACING
% =========================================================================
%
% Each graph edge is traced along the actual skeleton from one graph node
% to the next graph node.
%
% This avoids the previous problem where connected skeleton regions were
% converted directly into node pairs and important vessel paths were lost.

edgeList = zeros(0,2);
edgePathList = {};

% Pixel dimensions
[H,W] = size(skeleton);

% 8-connected neighbor offsets
neighborOffsets = [
    -1 -1
    -1  0
    -1  1
     0 -1
     0  1
     1 -1
     1  0
     1  1
];

% Keep track of skeleton pixels that have already been traced
visitedPixels = false(H,W);

% -------------------------------------------------------------------------
% TRACE FROM EVERY GRAPH NODE
% -------------------------------------------------------------------------

for nodeID = 1:totalNodes

    % Pixels belonging to current node
    [nodeRows,nodeCols] = find(nodeLabel == nodeID);

    if isempty(nodeRows)
        continue;
    end

    % Use all pixels belonging to the node as possible starting pixels
    for s = 1:numel(nodeRows)

        startR = nodeRows(s);
        startC = nodeCols(s);

        % Find neighboring skeleton pixels outside the current node
        for k = 1:size(neighborOffsets,1)

            nr = startR + neighborOffsets(k,1);
            nc = startC + neighborOffsets(k,2);

            % Boundary check
            if nr < 1 || nr > H || nc < 1 || nc > W
                continue;
            end

            % Must be skeleton
            if ~skeleton(nr,nc)
                continue;
            end

            % Ignore pixels belonging to same graph node
            if nodeLabel(nr,nc) == nodeID
                continue;
            end

            % If this pixel belongs to another node, create direct edge
            if nodeLabel(nr,nc) > 0

                targetNode = nodeLabel(nr,nc);

                if targetNode ~= nodeID

                    candidateEdge = sort([nodeID targetNode]);

                    edgeList(end+1,:) = candidateEdge; %#ok<AGROW>

                    edgePathList{end+1} = [ ...
                        startR startC; ...
                        nr nc]; %#ok<AGROW>
                end

                continue;
            end

            % -----------------------------------------------------------------
            % START TRACING ALONG SKELETON
            % -----------------------------------------------------------------

            path = [
                startR startC
                nr nc
            ];

            previousR = startR;
            previousC = startC;

            currentR = nr;
            currentC = nc;

            currentNode = nodeID;
            targetNode = 0;

            % Maximum tracing length
            maxTraceLength = skeletonPixels;

            for step = 1:maxTraceLength

                % If current pixel belongs to another node, terminate edge
                currentLabel = nodeLabel(currentR,currentC);

                if currentLabel > 0 && currentLabel ~= currentNode

                    targetNode = currentLabel;
                    break;
                end

                % Find neighboring skeleton pixels
                candidatePixels = zeros(0,2);

                for q = 1:size(neighborOffsets,1)

                    rr = currentR + neighborOffsets(q,1);
                    cc = currentC + neighborOffsets(q,2);

                    if rr < 1 || rr > H || cc < 1 || cc > W
                        continue;
                    end

                    if ~skeleton(rr,cc)
                        continue;
                    end

                    % Do not immediately go backwards
                    if rr == previousR && cc == previousC
                        continue;
                    end

                    candidatePixels(end+1,:) = [rr cc]; %#ok<AGROW>
                end

                % No continuation
                if isempty(candidatePixels)
                    break;
                end

                % -------------------------------------------------------------
                % If one of the neighbors is another graph node, terminate
                % -------------------------------------------------------------

                foundTarget = false;

                for q = 1:size(candidatePixels,1)

                    rr = candidatePixels(q,1);
                    cc = candidatePixels(q,2);

                    candidateNode = nodeLabel(rr,cc);

                    if candidateNode > 0 && candidateNode ~= currentNode

                        targetNode = candidateNode;

                        path(end+1,:) = [rr cc]; %#ok<AGROW>

                        foundTarget = true;
                        break;
                    end
                end

                if foundTarget
                    break;
                end

                % -------------------------------------------------------------
                % Continue along skeleton
                % -------------------------------------------------------------

                % If multiple possible directions exist, choose the
                % continuation that does not immediately branch back toward
                % the previous pixel.

                if size(candidatePixels,1) == 1

                    nextR = candidatePixels(1,1);
                    nextC = candidatePixels(1,2);

                else

                    % Direction from previous pixel to current pixel
                    previousDirection = [
                        currentR - previousR ...
                        currentC - previousC
                    ];

                    previousDirection = ...
                        previousDirection / ...
                        max(norm(previousDirection),eps);

                    bestScore = -Inf;
                    bestIndex = 1;

                    for q = 1:size(candidatePixels,1)

                        rr = candidatePixels(q,1);
                        cc = candidatePixels(q,2);

                        candidateDirection = [
                            rr - currentR ...
                            cc - currentC
                        ];

                        candidateDirection = ...
                            candidateDirection / ...
                            max(norm(candidateDirection),eps);

                        directionScore = ...
                            dot(previousDirection,candidateDirection);

                        if directionScore > bestScore

                            bestScore = directionScore;
                            bestIndex = q;

                        end
                    end

                    nextR = candidatePixels(bestIndex,1);
                    nextC = candidatePixels(bestIndex,2);

                end

                % Update path
                previousR = currentR;
                previousC = currentC;

                currentR = nextR;
                currentC = nextC;

                path(end+1,:) = [currentR currentC]; %#ok<AGROW>

                % Avoid excessively repeating the same skeleton path
                pixelIndex = sub2ind([H W],currentR,currentC);

                if visitedPixels(pixelIndex)
                    break;
                end

                visitedPixels(pixelIndex) = true;

            end

            % -----------------------------------------------------------------
            % SAVE VALID EDGE
            % -----------------------------------------------------------------

            if targetNode > 0 && targetNode ~= nodeID

                candidateEdge = sort([nodeID targetNode]);

                edgeList(end+1,:) = candidateEdge; %#ok<AGROW>

                edgePathList{end+1} = path; %#ok<AGROW>

            end

        end
    end
end

%% ========================================================================
% REMOVE SELF-LOOPS AND DUPLICATE EDGES
% =========================================================================

if ~isempty(edgeList)

    % Remove self-loops
    validEdges = ...
        edgeList(:,1) ~= edgeList(:,2);

    edgeList = edgeList(validEdges,:);

    % Remove duplicate node pairs
    [edgeList,uniqueIdx] = ...
        unique(edgeList,'rows','stable');

    % Keep corresponding paths
    if ~isempty(edgePathList)
        edgePathList = edgePathList(uniqueIdx);
    end

end

%% ========================================================================
% CREATE MATLAB GRAPH
% =========================================================================

if isempty(edgeList)

    G = graph( ...
        zeros(0,1), ...
        zeros(0,1), ...
        [], ...
        totalNodes);

else

    G = graph( ...
        edgeList(:,1), ...
        edgeList(:,2), ...
        [], ...
        totalNodes);

end

%% ========================================================================
% GRAPH CONNECTIVITY
% =========================================================================

if totalNodes > 0 && numnodes(G) > 0

    graphComponents = conncomp(G);

    graphComponentCount = max(graphComponents);

    graphComponentSizes = ...
        accumarray( ...
            graphComponents(:), ...
            1);

    largestGraphComponentRatio = ...
        max(graphComponentSizes) / totalNodes;

else

    graphComponents = [];
    graphComponentCount = 0;
    largestGraphComponentRatio = 0;

end

fprintf('\nGRAPH CONNECTIVITY\n');
fprintf('Graph nodes                  : %d\n',totalNodes);
fprintf('Graph edges                  : %d\n',size(edgeList,1));
fprintf('Graph connected components   : %d\n',graphComponentCount);
fprintf('Largest graph component      : %.4f (%.2f%%)\n', ...
    largestGraphComponentRatio, ...
    100*largestGraphComponentRatio);

fprintf('\nSKELETON CONNECTIVITY\n');
fprintf('Skeleton connected components: %d\n',connectedComponents);
fprintf('Largest skeleton component   : %.4f (%.2f%%)\n', ...
    largestComponentRatio, ...
    100*largestComponentRatio);

%% ========================================================================
% DEGREE CENTRALITY
% =========================================================================

if totalNodes > 1

    degreeCentrality = ...
        degree(G) ./ ...
        (totalNodes-1);

else

    degreeCentrality = ...
        zeros(totalNodes,1);

end

%% ========================================================================
% BETWEENNESS CENTRALITY
% =========================================================================

if totalNodes > 2 && numedges(G) > 0

    % Raw MATLAB betweenness centrality
    rawBetweennessCentrality = ...
        centrality(G,'betweenness');

    % Normalized betweenness for an undirected graph
    normalizationFactor = ...
        ((totalNodes-1)*(totalNodes-2))/2;

    if normalizationFactor > 0

        betweennessCentrality = ...
            rawBetweennessCentrality ./ normalizationFactor;

    else

        betweennessCentrality = ...
            zeros(totalNodes,1);

    end

else

    rawBetweennessCentrality = ...
        zeros(totalNodes,1);

    betweennessCentrality = ...
        zeros(totalNodes,1);

end

fprintf('\nBETWEENNESS CENTRALITY\n');
fprintf('Mean normalized betweenness : %.10f\n', ...
    mean(betweennessCentrality));

fprintf('Max normalized betweenness  : %.10f\n', ...
    max(betweennessCentrality));

fprintf('Non-zero nodes              : %d / %d\n', ...
    nnz(betweennessCentrality), ...
    totalNodes);


%% ========================================================================
% BETWEENNESS CENTRALITY
% =========================================================================

if totalNodes > 2

    betweennessCentrality = ...
        centrality(G,'betweenness');

    fprintf('\nRAW BETWEENNESS CHECK\n');
    fprintf('Mean raw betweenness : %.10f\n', ...
        mean(betweennessCentrality));

    fprintf('Max raw betweenness  : %.10f\n', ...
        max(betweennessCentrality));

    fprintf('Non-zero nodes       : %d / %d\n', ...
        nnz(betweennessCentrality), totalNodes);

else

    betweennessCentrality = ...
        zeros(totalNodes,1);

end

%% ========================================================================
% CENTRALITY SUMMARY
% =========================================================================

if isempty(degreeCentrality)

    meanDegreeCentrality = 0;

    maxDegreeCentrality = 0;

else

    meanDegreeCentrality = ...
        mean( ...
            degreeCentrality, ...
            'omitnan');

    maxDegreeCentrality = ...
        max(degreeCentrality);

end

if isempty(betweennessCentrality)

    meanBetweennessCentrality = 0;

    maxBetweennessCentrality = 0;

else

    meanBetweennessCentrality = ...
        mean( ...
            betweennessCentrality, ...
            'omitnan');

    maxBetweennessCentrality = ...
        max(betweennessCentrality);

end

%% ========================================================================
% NODE DEGREE FEATURES
% =========================================================================

nodeDegree = ...
    degree(G);

degree3Nodes = ...
    sum(nodeDegree == 3);

degree4Nodes = ...
    sum(nodeDegree == 4);

%% ========================================================================
% FRACTAL DIMENSION
% =========================================================================

fractalDimension = ...
    estimateFractalDimension( ...
        skeleton, ...
        fovMask);

%% ========================================================================
% VESSEL TORTUOSITY
% =========================================================================

[ ...
    meanTortuosity, ...
    medianTortuosity, ...
    maxTortuosity, ...
    tortuosityValues] = ...
    calculateVesselTortuosity( ...
        skeleton, ...
        nodeLabel, ...
        edgeList);

%% ========================================================================
% DENSITY FEATURES
% =========================================================================

fovPixels = ...
    nnz(fovMask);

skeletonDensity = ...
    skeletonPixels / ...
    max(fovPixels,1);

junctionDensity = ...
    junctionCount / ...
    max(fovPixels,1);

endpointDensity = ...
    endpointCount / ...
    max(fovPixels,1);

nodeDensity = ...
    totalNodes / ...
    max(fovPixels,1);

branchPixelDensity = ...
    branchPixelCount / ...
    max(fovPixels,1);

if endpointCount > 0

    junctionEndpointRatio = ...
        junctionCount / ...
        endpointCount;

else

    junctionEndpointRatio = NaN;

end

skeletonComplexity = ...
    skeletonDensity + ...
    branchPixelDensity;

%% ========================================================================
% COMMAND WINDOW OUTPUT
% =========================================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf(' MODULE 1 - GRAPH-BASED VASCULAR BIOMARKER OUTPUT\n');
fprintf('====================================================\n');

fprintf('Selected fundus image      : %s\n',imageName);

fprintf('\n');

fprintf('FROZEN PARAMETERS\n');

fprintf('Vessel threshold           : %.3f\n', ...
    vesselThreshold);

fprintf('MinBranchLength            : %d pixels\n', ...
    minBranchLength);

fprintf('Node clustering radius     : %d pixels\n', ...
    clusterRadius);

fprintf('\n');

fprintf('----------------------------------------------------\n');
fprintf(' VASCULAR GRAPH TOPOLOGY\n');
fprintf('----------------------------------------------------\n');

fprintf('Skeleton pixels            : %d\n', ...
    skeletonPixels);

fprintf('Junction nodes             : %d\n', ...
    junctionCount);

fprintf('Endpoint nodes             : %d\n', ...
    endpointCount);

fprintf('Total graph nodes          : %d\n', ...
    totalNodes);

fprintf('Graph edges                : %d\n', ...
    size(edgeList,1));

fprintf('Degree-3 nodes             : %d\n', ...
    degree3Nodes);

fprintf('Degree-4 nodes             : %d\n', ...
    degree4Nodes);

fprintf('Connected components       : %d\n', ...
    connectedComponents);

fprintf('Largest component ratio    : %.4f (%.2f%%)\n', ...
    largestComponentRatio, ...
    100*largestComponentRatio);

fprintf('\n');

fprintf('----------------------------------------------------\n');
fprintf(' GRAPH-BASED BIOMARKERS\n');
fprintf('----------------------------------------------------\n');

fprintf('Mean degree centrality     : %.4f\n', ...
    meanDegreeCentrality);

fprintf('Max degree centrality      : %.4f\n', ...
    maxDegreeCentrality);

fprintf('Mean betweenness centrality: %.4f\n', ...
    meanBetweennessCentrality);

fprintf('Max betweenness centrality : %.4f\n', ...
    maxBetweennessCentrality);

fprintf('Fractal dimension          : %.4f\n', ...
    fractalDimension);

fprintf('Mean vessel tortuosity     : %.4f\n', ...
    meanTortuosity);

fprintf('Median vessel tortuosity   : %.4f\n', ...
    medianTortuosity);

fprintf('Maximum vessel tortuosity  : %.4f\n', ...
    maxTortuosity);

fprintf('\n');

fprintf('----------------------------------------------------\n');
fprintf(' DENSITY FEATURES\n');
fprintf('----------------------------------------------------\n');

fprintf('Skeleton density           : %.6f\n', ...
    skeletonDensity);

fprintf('Junction density           : %.6f\n', ...
    junctionDensity);

fprintf('Endpoint density           : %.6f\n', ...
    endpointDensity);

fprintf('Node density               : %.6f\n', ...
    nodeDensity);

fprintf('Junction/Endpoint ratio    : %.4f\n', ...
    junctionEndpointRatio);

fprintf('Skeleton complexity        : %.6f\n', ...
    skeletonComplexity);

fprintf('\n');

fprintf('----------------------------------------------------\n');
fprintf(' DEVELOPMENT SET EVALUATION\n');
fprintf('----------------------------------------------------\n');

fprintf('Dice                       : 70.02%%\n');
fprintf('Sensitivity                : 71.42%%\n');
fprintf('Specificity                : 95.07%%\n');
fprintf('Precision                  : 71.98%%\n');

fprintf('\n');

fprintf('NOTE\n');

fprintf(['DRIVE test vessel ground truth is not present ', ...
         'in the provided test folder.\n']);

fprintf(['Therefore no test Dice, sensitivity, specificity, ', ...
         'or accuracy is claimed.\n']);

fprintf(['The selected image is processed to generate its ', ...
         'vascular graph-based fingerprint.\n']);

%% ========================================================================
% FINAL PRESENTATION FIGURE
% =========================================================================

fig = figure( ...
    'Color','w', ...
    'Name', ...
    'Module 1 - Graph-Based Vascular Biomarker Fingerprinting', ...
    'NumberTitle','off', ...
    'Position',[60 40 1550 920]);

%% ========================================================================
% PANEL GEOMETRY
% =========================================================================

leftX = 0.055;

rightX = 0.545;

topY = 0.535;

bottomY = 0.155;

panelW = 0.400;

panelH = 0.340;

%% ========================================================================
% TITLE
% =========================================================================

annotation( ...
    fig, ...
    'textbox', ...
    [0.04 0.948 0.92 0.035], ...
    'String', ...
    'MODULE 1: GRAPH-BASED VASCULAR BIOMARKER FINGERPRINTING', ...
    'FitBoxToText','off', ...
    'FontSize',20, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

%% ========================================================================
% SUBTITLE
% =========================================================================

annotation( ...
    fig, ...
    'textbox', ...
    [0.05 0.918 0.90 0.022], ...
    'String', ...
    sprintf( ...
        'Selected DRIVE fundus image: %s', ...
        imageName), ...
    'FitBoxToText','off', ...
    'FontSize',10, ...
    'FontWeight','normal', ...
    'Color',[0.35 0.35 0.35], ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

%% ========================================================================
% PANEL 1 - ORIGINAL FUNDUS
% =========================================================================

ax1 = axes( ...
    'Parent',fig, ...
    'Position', ...
    [leftX topY panelW panelH]);

imshow( ...
    fundusImage, ...
    'Parent',ax1);

axis(ax1,'image');
axis(ax1,'off');

annotation( ...
    fig, ...
    'textbox', ...
    [leftX topY+panelH+0.008 panelW 0.022], ...
    'String', ...
    '1. ORIGINAL FUNDUS IMAGE', ...
    'FitBoxToText','off', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','middle');

%% ========================================================================
% PANEL 2 - VESSEL SEGMENTATION
% =========================================================================

ax2 = axes( ...
    'Parent',fig, ...
    'Position', ...
    [rightX topY panelW panelH]);

imshow( ...
    vesselMask, ...
    'Parent',ax2);

axis(ax2,'image');
axis(ax2,'off');

annotation( ...
    fig, ...
    'textbox', ...
    [rightX topY+panelH+0.008 panelW 0.022], ...
    'String', ...
    sprintf( ...
        '2. VESSEL SEGMENTATION   |   T = %.3f', ...
        vesselThreshold), ...
    'FitBoxToText','off', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','middle');

%% ========================================================================
% PANEL 3 - SKELETON + GRAPH NODES
% =========================================================================

ax3 = axes( ...
    'Parent',fig, ...
    'Position', ...
    [leftX bottomY panelW panelH]);

imshow( ...
    fundusImage, ...
    'Parent',ax3);

hold(ax3,'on');

%% Skeleton

[ySk,xSk] = ...
    find(skeleton);

plot( ...
    ax3, ...
    xSk, ...
    ySk, ...
    '.', ...
    'Color',[0.00 0.75 1.00], ...
    'MarkerSize',1.8);

%% Junction nodes

if ~isempty(junctionXY)

    plot( ...
        ax3, ...
        junctionXY(:,1), ...
        junctionXY(:,2), ...
        'o', ...
        'MarkerSize',5, ...
        'LineWidth',1.1, ...
        'MarkerEdgeColor',[1.00 0.10 0.10], ...
        'MarkerFaceColor','none');

end

%% Endpoint nodes

if ~isempty(endpointXY)

    plot( ...
        ax3, ...
        endpointXY(:,1), ...
        endpointXY(:,2), ...
        'o', ...
        'MarkerSize',5, ...
        'LineWidth',1.1, ...
        'MarkerEdgeColor',[0.10 0.90 0.20], ...
        'MarkerFaceColor','none');

end

axis(ax3,'image');
axis(ax3,'off');

hold(ax3,'off');

annotation( ...
    fig, ...
    'textbox', ...
    [leftX bottomY+panelH+0.008 panelW 0.022], ...
    'String', ...
    '3. SKELETON + GRAPH NODES', ...
    'FitBoxToText','off', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','middle');

%% ========================================================================
% PANEL 4 - GRAPH BIOMARKER FINGERPRINT
% =========================================================================

ax4 = axes( ...
    'Parent',fig, ...
    'Position', ...
    [rightX bottomY panelW panelH]);

imshow( ...
    fundusImage, ...
    'Parent',ax4);

hold(ax4,'on');

%% Skeleton

plot( ...
    ax4, ...
    xSk, ...
    ySk, ...
    '.', ...
    'Color',[0.00 0.70 1.00], ...
    'MarkerSize',1.2);

%% ========================================================================
% GRAPH EDGES
% =========================================================================

if ~isempty(edgeList)

    for e = 1:size(edgeList,1)

        n1 = ...
            edgeList(e,1);

        n2 = ...
            edgeList(e,2);

        if n1 <= size(nodeXY,1) && ...
           n2 <= size(nodeXY,1)

            plot( ...
                ax4, ...
                [ ...
                nodeXY(n1,1), ...
                nodeXY(n2,1)], ...
                [ ...
                nodeXY(n1,2), ...
                nodeXY(n2,2)], ...
                '-', ...
                'Color',[1.00 0.85 0.00], ...
                'LineWidth',1.1);

        end

    end

end

%% ========================================================================
% CENTRALITY VISUALIZATION
% =========================================================================
%
% Node size represents degree centrality.
%
% Larger node = greater local graph connectivity.
%
% =========================================================================

if totalNodes > 0

    nodeSize = ...
        20 + ...
        260 .* degreeCentrality;

    scatter( ...
        ax4, ...
        nodeXY(:,1), ...
        nodeXY(:,2), ...
        nodeSize, ...
        degreeCentrality, ...
        'filled', ...
        'MarkerEdgeColor','k', ...
        'LineWidth',0.25);

end

%% ========================================================================
% JUNCTION OVERLAY
% =========================================================================

if ~isempty(junctionXY)

    plot( ...
        ax4, ...
        junctionXY(:,1), ...
        junctionXY(:,2), ...
        'o', ...
        'MarkerSize',4, ...
        'LineWidth',1.0, ...
        'MarkerEdgeColor',[1.00 0.10 0.10], ...
        'MarkerFaceColor','none');

end

%% ========================================================================
% ENDPOINT OVERLAY
% =========================================================================

if ~isempty(endpointXY)

    plot( ...
        ax4, ...
        endpointXY(:,1), ...
        endpointXY(:,2), ...
        'o', ...
        'MarkerSize',4, ...
        'LineWidth',1.0, ...
        'MarkerEdgeColor',[0.10 0.90 0.20], ...
        'MarkerFaceColor','none');

end

axis(ax4,'image');
axis(ax4,'off');

hold(ax4,'off');

annotation( ...
    fig, ...
    'textbox', ...
    [rightX bottomY+panelH+0.008 panelW 0.022], ...
    'String', ...
    '4. GRAPH-BASED BIOMARKER FINGERPRINT', ...
    'FitBoxToText','off', ...
    'FontSize',13, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'EdgeColor','none', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','middle');

%% ========================================================================
% BIOMARKER SUMMARY
% =========================================================================

summaryText = sprintf([ ...
    'GRAPH TOPOLOGY     Nodes: %d    |    Edges: %d    |    ' ...
    'Largest component: %.1f%%\n' ...
    'CENTRALITY         Degree: %.4f    |    Betweenness: %.4f\n' ...
    'GEOMETRY           Fractal Dimension: %.3f\n' ...
    'TORTUOSITY         Mean: %.3f    |    Median: %.3f'], ...
    totalNodes, ...
    size(edgeList,1), ...
    100*largestComponentRatio, ...
    meanDegreeCentrality, ...
    meanBetweennessCentrality, ...
    fractalDimension, ...
    meanTortuosity, ...
    medianTortuosity);

annotation( ...
    fig, ...
    'textbox', ...
    [0.055 0.052 0.890 0.075], ...
    'String', ...
    summaryText, ...
    'FitBoxToText','off', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'Color','k', ...
    'BackgroundColor',[0.94 0.94 0.94], ...
    'EdgeColor',[0.65 0.65 0.65], ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', ...
    'Margin',5);

%% ========================================================================
% NOVELTY PIPELINE
% =========================================================================

annotation( ...
    fig, ...
    'textbox', ...
    [0.055 0.030 0.890 0.018], ...
    'String', ...
    'VESSEL PIXELS  ->  SKELETON TOPOLOGY  ->  GRAPH  ->  STRUCTURAL BIOMARKERS', ...
    'FitBoxToText','off', ...
    'FontSize',9, ...
    'FontWeight','bold', ...
    'Color',[0.20 0.20 0.20], ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

%% ========================================================================
% FOOTER
% =========================================================================

footerText = sprintf( ...
    'DRIVE  |  Threshold = %.3f  |  MinBranchLength = %d px  |  Node radius = %d px', ...
    vesselThreshold, ...
    minBranchLength, ...
    clusterRadius);

annotation( ...
    fig, ...
    'textbox', ...
    [0.055 0.010 0.890 0.015], ...
    'String', ...
    footerText, ...
    'FitBoxToText','off', ...
    'FontSize',8, ...
    'FontWeight','normal', ...
    'Color',[0.40 0.40 0.40], ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

drawnow;

%% ========================================================================
% SAVE FINAL FIGURE
% =========================================================================

outFile = ...
    fullfile( ...
        resultsFolder, ...
        ['Module1_Final_Fundus_Graph_' ...
         baseName '.png']);

exportgraphics( ...
    fig, ...
    outFile, ...
    'Resolution',250);

fprintf('\n');
fprintf('====================================================\n');
fprintf(' FINAL VISUALIZATION SAVED\n');
fprintf('====================================================\n');

fprintf('%s\n',outFile);

fprintf('====================================================\n\n');

%% ========================================================================
% LOCAL FUNCTION 1
% FRACTAL DIMENSION
% =========================================================================

function FD = ...
    estimateFractalDimension(binaryImage,fovMask)

    binaryImage = ...
        logical(binaryImage);

    fovMask = ...
        logical(fovMask);

    binaryImage(~fovMask) = false;

    [rows,cols] = ...
        size(binaryImage);

    minDim = ...
        min(rows,cols);

    maxPower = ...
        floor(log2(minDim));

    if maxPower < 2

        FD = NaN;

        return;

    end

    boxSizes = ...
        2.^(1:maxPower);

    counts = ...
        zeros(size(boxSizes));

    for k = 1:numel(boxSizes)

        boxSize = ...
            boxSizes(k);

        count = 0;

        for r = 1:boxSize:rows

            rEnd = ...
                min( ...
                    r+boxSize-1, ...
                    rows);

            for c = 1:boxSize:cols

                cEnd = ...
                    min( ...
                        c+boxSize-1, ...
                        cols);

                block = ...
                    binaryImage( ...
                        r:rEnd, ...
                        c:cEnd);

                if any(block(:))

                    count = ...
                        count + 1;

                end

            end

        end

        counts(k) = ...
            count;

    end

    valid = ...
        counts > 0 & ...
        boxSizes > 0;

    if nnz(valid) < 2

        FD = NaN;

        return;

    end

    x = ...
        log( ...
            1 ./ ...
            double(boxSizes(valid)));

    y = ...
        log( ...
            double(counts(valid)));

    p = ...
        polyfit(x,y,1);

    FD = ...
        p(1);

    if ~isfinite(FD)

        FD = NaN;

    end

end

%% ========================================================================
% LOCAL FUNCTION 2
% VESSEL TORTUOSITY
% =========================================================================

function [ ...
    meanTortuosity, ...
    medianTortuosity, ...
    maxTortuosity, ...
    tortuosityValues] = ...
    calculateVesselTortuosity( ...
        skeleton, ...
        nodeLabel, ...
        edgeList)

    tortuosityValues = [];

    meanTortuosity = NaN;

    medianTortuosity = NaN;

    maxTortuosity = NaN;

    if nnz(skeleton) < 2

        return;

    end

    if isempty(edgeList)

        return;

    end

    pixelIndices = ...
        find(skeleton);

    numberOfPixels = ...
        numel(pixelIndices);

    pixelMap = ...
        zeros(size(skeleton));

    for k = 1:numberOfPixels

        pixelMap(pixelIndices(k)) = ...
            k;

    end

    [rows,cols] = ...
        size(skeleton);

    neighborOffsets = [ ...
        -1 -1;
        -1  0;
        -1  1;
         0 -1;
         0  1;
         1 -1;
         1  0;
         1  1];

    source = [];

    target = [];

    weights = [];

    %% Build pixel-level skeleton graph

    for k = 1:numberOfPixels

        idx = ...
            pixelIndices(k);

        [r,c] = ...
            ind2sub( ...
                [rows,cols], ...
                idx);

        for q = 1:size(neighborOffsets,1)

            rr = ...
                r + neighborOffsets(q,1);

            cc = ...
                c + neighborOffsets(q,2);

            if rr < 1 || ...
               rr > rows || ...
               cc < 1 || ...
               cc > cols

                continue;

            end

            neighborGraphNode = ...
                pixelMap(rr,cc);

            if neighborGraphNode > k

                source(end+1,1) = ...
                    k; %#ok<AGROW>

                target(end+1,1) = ...
                    neighborGraphNode; %#ok<AGROW>

                if abs(neighborOffsets(q,1)) + ...
                   abs(neighborOffsets(q,2)) == 2

                    weights(end+1,1) = ...
                        sqrt(2); %#ok<AGROW>

                else

                    weights(end+1,1) = ...
                        1; %#ok<AGROW>

                end

            end

        end

    end

    if isempty(source)

        return;

    end

    Gpixel = ...
        graph( ...
            source, ...
            target, ...
            weights, ...
            numberOfPixels);

    maxNodeID = ...
        max(nodeLabel(:));

    if maxNodeID < 1

        return;

    end

    %% Find actual skeleton pixels belonging to each node

    nodePixelLists = ...
        cell(maxNodeID,1);

    for n = 1:maxNodeID

        nodePixelLists{n} = ...
            find(nodeLabel == n);

    end

    %% Representative skeleton pixel

    representativePixel = ...
        zeros(maxNodeID,1);

    for n = 1:maxNodeID

        px = ...
            nodePixelLists{n};

        if ~isempty(px)

            representativePixel(n) = ...
                px(1);

        end

    end

    %% Image pixel -> pixel graph index

    imageToGraph = ...
        zeros(size(skeleton));

    imageToGraph(pixelIndices) = ...
        1:numberOfPixels;

    %% Tortuosity per graph edge

    for e = 1:size(edgeList,1)

        n1 = ...
            edgeList(e,1);

        n2 = ...
            edgeList(e,2);

        if n1 < 1 || ...
           n2 < 1 || ...
           n1 > maxNodeID || ...
           n2 > maxNodeID

            continue;

        end

        p1 = ...
            representativePixel(n1);

        p2 = ...
            representativePixel(n2);

        if p1 == 0 || ...
           p2 == 0

            continue;

        end

        startNode = ...
            imageToGraph(p1);

        endNode = ...
            imageToGraph(p2);

        if startNode == 0 || ...
           endNode == 0

            continue;

        end

        try

            [~,pathLength] = ...
                shortestpath( ...
                    Gpixel, ...
                    startNode, ...
                    endNode);

        catch

            continue;

        end

        if isempty(pathLength) || ...
           ~isfinite(pathLength)

            continue;

        end

        [r1,c1] = ...
            ind2sub( ...
                size(skeleton), ...
                p1);

        [r2,c2] = ...
            ind2sub( ...
                size(skeleton), ...
                p2);

        chordLength = ...
            hypot( ...
                c2-c1, ...
                r2-r1);

        if chordLength <= 0

            continue;

        end

        T = ...
            pathLength / ...
            chordLength;

        if isfinite(T) && ...
           T >= 1

            tortuosityValues(end+1,1) = ...
                T; %#ok<AGROW>

        end

    end

    %% Statistics

    if isempty(tortuosityValues)

        meanTortuosity = NaN;

        medianTortuosity = NaN;

        maxTortuosity = NaN;

    else

        meanTortuosity = ...
            mean(tortuosityValues);

        medianTortuosity = ...
            median(tortuosityValues);

        maxTortuosity = ...
            max(tortuosityValues);

    end

end