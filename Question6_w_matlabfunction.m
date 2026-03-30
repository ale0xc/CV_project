clear all; close all;

path = "C:/Users/acach/ist-cv-2526/Project/Images/";
extName = 'jpg';
frameIdComp = 4;
str = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

nFrame = 500;
step = 15;
sampleFrames = 1:step:nFrame;
numSamples = length(sampleFrames);

firstImg = imread(sprintf(str, path, 1, extName));
[h, w, c] = size(firstImg);
vid4D = zeros(h, w, c, numSamples, 'uint8');

for idx = 1:numSamples
    vid4D(:,:,:,idx) = imread(sprintf(str, path, sampleFrames(idx), extName));
end

imgBkRgb = median(vid4D, 4);
imgBk = double(imgBkRgb);

thr = 40;
minArea = 400;
seqLength = 794;
se = strel('rectangle', [10, 2]);
allPedestrianPoints = [];

for i = 0:seqLength
    imgFrRgb = imread(sprintf(str, path, i, extName));
    imgFr = double(imgFrRgb);
    
    imgDif = (abs(imgBk(:,:,1) - imgFr(:,:,1)) > thr) | ...
             (abs(imgBk(:,:,2) - imgFr(:,:,2)) > thr) | ...
             (abs(imgBk(:,:,3) - imgFr(:,:,3)) > thr);
             
    bwClean = imclose(imgDif, se);
    bwClean = imopen(bwClean, se);
    bwClean = imfill(bwClean, 'holes');
    
    [lb, num] = bwlabel(bwClean);
    regionProps = regionprops(lb, 'Area', 'Centroid');
    
    if ~isempty(regionProps)
        validIdx = [regionProps.Area] > minArea;
        validProps = regionProps(validIdx);
        if ~isempty(validProps)
            currentCentroids = vertcat(validProps.Centroid);
            allPedestrianPoints = [allPedestrianPoints; currentCentroids];
        end
    end
end

X = allPedestrianPoints;
numClusters = 4; 

options = statset('MaxIter', 200, 'TolFun', 1e-5, 'Display', 'off');
gmmModel = fitgmdist(X, numClusters, 'Options', options, 'Replicates', 10, 'RegularizationValue', 1e-5);

logL = -gmmModel.NegativeLogLikelihood;
bicValue = gmmModel.BIC;

fprintf('\nMATLAB fitgmdist Algorithm Results:\n');
fprintf('Chosen Clusters (K): %d\n', numClusters);
fprintf('Final Log-Likelihood: %.2f\n', logL);
fprintf('BIC Evaluation Score: %.2f\n\n', bicValue);

figure('Name', 'MATLAB EM Trajectory Analysis');
imshow(uint8(imgBkRgb * 0.4)); 
hold on;

scatter(X(:,1), X(:,2), 2, 'white', 'filled', 'MarkerFaceAlpha', 0.05);

colors = ['r', 'g', 'b', 'c', 'm', 'y'];
xGrid = linspace(1, w, 100);
yGrid = linspace(1, h, 100);
[X1, X2] = meshgrid(xGrid, yGrid);

for k = 1:numClusters
    muK = gmmModel.mu(k, :);
    sigmaK = gmmModel.Sigma(:, :, k);
    weightK = gmmModel.ComponentProportion(k) * 100;
    
    diffGrid = [X1(:) X2(:)] - muK;
    invSigma = inv(sigmaK);
    detSigma = det(sigmaK);
    normConst = 1 / sqrt(((2*pi)^2) * detSigma);
    exponent = -0.5 * sum((diffGrid * invSigma) .* diffGrid, 2);
    F = normConst * exp(exponent);
    F = reshape(F, length(yGrid), length(xGrid));
    
    maxF = max(F(:));
    contourLevels = [maxF*0.4, maxF*0.7, maxF*0.9]; 
    
    colorIdx = mod(k-1, length(colors)) + 1;
    
    contour(xGrid, yGrid, F, contourLevels, 'LineColor', colors(colorIdx), 'LineWidth', 2);
    plot(muK(1), muK(2), 'x', 'MarkerSize', 12, 'LineWidth', 3, 'Color', colors(colorIdx));
    text(muK(1) + 15, muK(2) - 15, sprintf('Path %d (%.1f%%)', k, weightK), 'Color', colors(colorIdx), 'FontSize', 12, 'FontWeight', 'bold');
end

title(sprintf('EM Algorithm - K = %d (BIC: %.0f)', numClusters, bicValue));
hold off;