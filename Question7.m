clear all, close all
gtData = readmatrix('C:/Users/acach/ist-cv-2526/Project/gt.txt'); 
imagesPath = "C:/Users/acach/ist-cv-2526/Project/Images/"; 
nImages = 794;
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

nFrame = 500;
step = 15;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,imagesPath,k,extName));
    vid4D(:,:,:,k)=img;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(imgbk_rgb);

thr = 40;       
minArea = 250;
se = strel('rectangle', [10, 2]);
allMaxIoU = [];
allFrameIoU = [];

totalFP = 0;
totalFN = 0;
totalSplits = 0;
totalMerges = 0;
totalGT = 0;
totalDet = 0;
evalThreshold = 0.5;

for k = 0:nImages
    currentImageGT = gtData(gtData(:, 1) == k, :);
    imgfr_rgb = imread(sprintf(str,imagesPath,k,extName));
    imgfr = double(imgfr_rgb);
         
    imgdif = (abs(double(imgbk(:,:,1))-double(imgfr(:,:,1)))>thr) | ...
        (abs(double(imgbk(:,:,2))-double(imgfr(:,:,2)))>thr) | ...
        (abs(double(imgbk(:,:,3))-double(imgfr(:,:,3)))>thr);
    
    bw_clean = imclose(imgdif, se);
    bw_clean = imopen(bw_clean, se);      
    bw_clean = imfill(bw_clean, 'holes');

    [lb, num] = bwlabel(bw_clean);
    regionProps = regionprops(lb, 'area', 'BoundingBox');
    
    imshow(imgfr_rgb); hold on;
    
    bboxes_det = [];
    label_num = 1;
    for j = 1:num
        if regionProps(j).Area > minArea
            bbox = regionProps(j).BoundingBox;
            bboxes_det = [bboxes_det; bbox];
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-5, num2str(label_num), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
            label_num = label_num + 1;
        end
    end
    
    bboxes_gt = [];
    for i = 1:size(currentImageGT, 1)
        gtID = currentImageGT(i, 2);
        bbox_gt = [currentImageGT(i, 3), currentImageGT(i, 4), currentImageGT(i, 5), currentImageGT(i, 6)];
        bboxes_gt = [bboxes_gt; bbox_gt];
        rectangle('Position', bbox_gt, 'EdgeColor', 'w', 'LineWidth', 2);
        text(bbox_gt(1), bbox_gt(2) - 10, num2str(gtID), 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');
    end
    
    meanFrameIoU = 0; 
    frameFP = 0;
    frameFN = 0;
    frameSplits = 0;
    frameMerges = 0;
    
    if ~isempty(bboxes_det) && ~isempty(bboxes_gt)
        % Rows = GT, Cols = Detections
        iouMatrix = bboxOverlapRatio(bboxes_gt, bboxes_det); 
        
        % Association Matrix C
        C = iouMatrix >= evalThreshold;
        
        rowSums = sum(C, 2);
        colSums = sum(C, 1);
        
        frameFN = sum(rowSums == 0);
        frameFP = sum(colSums == 0);
        frameSplits = sum(rowSums > 1);
        frameMerges = sum(colSums > 1);
        
        maxIouPerGT = max(iouMatrix, [], 2); 
        meanFrameIoU = mean(maxIouPerGT);
        allFrameIoU = [allFrameIoU; meanFrameIoU];
        allMaxIoU = [allMaxIoU; maxIouPerGT]; 
        
    elseif ~isempty(bboxes_gt)
        allMaxIoU = [allMaxIoU; zeros(size(bboxes_gt, 1), 1)];
        frameFN = size(bboxes_gt, 1);
    elseif ~isempty(bboxes_det)
        frameFP = size(bboxes_det, 1);
    end
    
    totalFP = totalFP + frameFP;
    totalFN = totalFN + frameFN;
    totalSplits = totalSplits + frameSplits;
    totalMerges = totalMerges + frameMerges;
    totalGT = totalGT + size(bboxes_gt, 1);
    totalDet = totalDet + size(bboxes_det, 1);
    
    title(['Frame: ', num2str(k), ' - Mean IoU: ', num2str(meanFrameIoU, '%.2f')]);
    hold off;
    drawnow;
end

thresholds = 0:0.1:1; 
successRate = zeros(length(thresholds), 1);
for t = 1:length(thresholds)
    countSuccess = sum(allFrameIoU > thresholds(t));
    successRate(t) = (countSuccess / length(allFrameIoU)) * 100;
end

figure;
plot(thresholds, successRate, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
grid on;
title('Success Plot (IoU Evaluation)');
xlabel('Overlap threshold (IoU)');
ylabel('Success rate (%)');
xlim([0 1]);
ylim([0 105]);

percentFN = (totalFN / max(1, totalGT)) * 100;
percentFP = (totalFP / max(1, totalDet)) * 100;

fprintf('Total GT boxes: %d\n', totalGT);
fprintf('Total Detections: %d\n', totalDet);
fprintf('False Negatives (Misses): %.2f%%\n', percentFN);
fprintf('False Positives (False Alarms): %.2f%%\n', percentFP);
fprintf('Total Splits: %d\n', totalSplits);
fprintf('Total Merges: %d\n', totalMerges);