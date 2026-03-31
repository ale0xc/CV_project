clear all; close all;

path = "C:/Users/acach/ist-cv-2526/Project/Images/";
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

nFrame = 500;
step = 15;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,path,k,extName));
    vid4D(:,:,:,k)=img;
end
imgbk_rgb = median(vid4D,4);
imgBk = double(imgbk_rgb);

thr = 40;       
minArea = 250;
seqLength = 794;
se = strel('rectangle', [10, 2]);

maxP = 1000; 
trajectories = cell(maxP, 1);

activeCentroids = []; 
activeVelocities = []; 
activeIds = []; 
invisibleCounts = []; 
distThreshold = 50; 
maxInvisible = 5; 
nextId = 1;

figure;
for i=0:seqLength
    imgFrRgb = imread(sprintf(str,path,i,extName));
    imgFr = double(imgFrRgb);
         
    imgDif = (abs(imgBk(:,:,1)-imgFr(:,:,1))>thr) | ...
             (abs(imgBk(:,:,2)-imgFr(:,:,2))>thr) | ...
             (abs(imgBk(:,:,3)-imgFr(:,:,3))>thr);
             
    bwClean = imclose(imgDif, se);      
    bwClean = imopen(bwClean, se);
    bwClean = imfill(bwClean, 'holes');
    
    [lb, num] = bwlabel(bwClean);
    regionProps = regionprops(lb,'Area','BoundingBox', 'Centroid');
    
    imshow(imgFrRgb); hold on;
    
    currentBboxes = [];
    currentCentroids = [];
    
    for j = 1:num
        if regionProps(j).Area > minArea
            currentBboxes = [currentBboxes; regionProps(j).BoundingBox];
            currentCentroids = [currentCentroids; regionProps(j).Centroid];
        end
    end
    
    currentIds = zeros(size(currentBboxes, 1), 1);
    matchedActiveIdx = [];
    newIds = [];
    newCentroids = [];
    
    if ~isempty(currentCentroids)
        if ~isempty(activeCentroids)
            predictedCentroids = activeCentroids + activeVelocities;
            distMatrix = pdist2(currentCentroids, predictedCentroids);
            
            for c = 1:size(currentCentroids, 1)
                [minDist, matchIdx] = min(distMatrix(c, :));
                
                if minDist < distThreshold
                    currentIds(c) = activeIds(matchIdx);
                    distMatrix(:, matchIdx) = inf; 
                    matchedActiveIdx = [matchedActiveIdx; matchIdx];
                    
                    activeVelocities(matchIdx, :) = currentCentroids(c, :) - activeCentroids(matchIdx, :);
                    activeCentroids(matchIdx, :) = currentCentroids(c, :);
                    invisibleCounts(matchIdx) = 0;
                else
                    currentIds(c) = nextId;
                    newIds = [newIds; nextId];
                    newCentroids = [newCentroids; currentCentroids(c, :)];
                    nextId = nextId + 1;
                end
            end
        else
            for c = 1:size(currentCentroids, 1)
                currentIds(c) = nextId;
                newIds = [newIds; nextId];
                newCentroids = [newCentroids; currentCentroids(c, :)];
                nextId = nextId + 1;
            end
        end
        
        numOldActive = length(activeIds);
        unmatchedIdx = setdiff(1:numOldActive, matchedActiveIdx);
        invisibleCounts(unmatchedIdx) = invisibleCounts(unmatchedIdx) + 1;
        activeCentroids(unmatchedIdx, :) = activeCentroids(unmatchedIdx, :) + activeVelocities(unmatchedIdx, :);
        
        activeIds = [activeIds; newIds];
        activeCentroids = [activeCentroids; newCentroids];
        activeVelocities = [activeVelocities; zeros(length(newIds), 2)];
        invisibleCounts = [invisibleCounts; zeros(length(newIds), 1)];
        
        validTracks = invisibleCounts <= maxInvisible;
        activeIds = activeIds(validTracks);
        activeCentroids = activeCentroids(validTracks, :);
        activeVelocities = activeVelocities(validTracks, :);
        invisibleCounts = invisibleCounts(validTracks);
        
        for c = 1:size(currentBboxes, 1)
            bbox = currentBboxes(c, :);
            center = currentCentroids(c, :);
            assignedId = currentIds(c);
            
            trajectories{assignedId} = [trajectories{assignedId}; center];
            if size(trajectories{assignedId}, 1) > 20
                trajectories{assignedId} = trajectories{assignedId}(end-19:end, :);
            end
            
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-5, num2str(assignedId), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
            
            pathP = trajectories{assignedId};
            if size(pathP, 1) > 1
                plot(pathP(:, 1), pathP(:, 2), 'y-', 'LineWidth', 1.5);
                plot(center(1), center(2), 'y.', 'MarkerSize', 10);
            end
        end
    else
        if ~isempty(activeIds)
            invisibleCounts = invisibleCounts + 1;
            activeCentroids = activeCentroids + activeVelocities;
            
            validTracks = invisibleCounts <= maxInvisible;
            activeIds = activeIds(validTracks);
            activeCentroids = activeCentroids(validTracks, :);
            activeVelocities = activeVelocities(validTracks, :);
            invisibleCounts = invisibleCounts(validTracks);
        end
    end
    
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end