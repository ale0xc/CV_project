gtData = readmatrix('C:/Users/acach/ist-cv-2526/Project/gt.txt'); 
imagesPath = "C:/Users/acach/ist-cv-2526/Project/Images/"; 
nImages = 794;
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];
nGT = 10;

% Background Detection
nFrame = 500;
step = 15;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,imagesPath,k,extName));
    vid4D(:,:,:,k)=img;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(imgbk_rgb);

% Detection 
thr     = 40;       
minArea   = 250;
seqLength = 794;

se = strel('rectangle', [10, 2]);

allMaxIoU = [];

for k = 0:nImages
    
    currentImageGT = gtData(gtData(:, 1) == k, :);

    imgfr_rgb = imread(sprintf(str,imagesPath,k,extName));
    imgfr = double(imgfr_rgb);
         
    %Computations
    imgdif = (abs(double(imgbk(:,:,1))-double(imgfr(:,:,1)))>thr) | ...
        (abs(double(imgbk(:,:,2))-double(imgfr(:,:,2)))>thr) | ...
        (abs(double(imgbk(:,:,3))-double(imgfr(:,:,3)))>thr);

    bw_clean = imclose(imgdif, se);      
    bw_clean = imopen(bw_clean, se);
    bw_clean = imfill(bw_clean, 'holes');

    [lb num]=bwlabel(bw_clean);
    regionProps = regionprops(lb,'area','BoundingBox');

    imshow(imgfr_rgb); hold on;

    % Drawings
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
        bbox_gt = [currentImageGT(i, 3), currentImageGT(i, 4), ...
                currentImageGT(i, 5), currentImageGT(i, 6)];
        bboxes_gt = [bboxes_gt; bbox_gt];
        
        rectangle('Position', bbox_gt, 'EdgeColor', 'w', 'LineWidth', 2);
        text(bbox_gt(1), bbox_gt(2) - 10, num2str(gtID), ...
            'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');
    end

    % IoU
    meanFrameIoU = 0; 
    if ~isempty(bboxes_det) && ~isempty(bboxes_gt)
        iouMatrix = bboxOverlapRatio(bboxes_det, bboxes_gt);

        maxIouPerGT = max(iouMatrix, [], 1); 

        meanFrameIoU = mean(maxIouPerGT);

        allMaxIoU = [allMaxIoU, maxIouPerGT]; 
    elseif ~isempty(bboxes_gt)
        allMaxIoU = [allMaxIoU, zeros(1, size(bboxes_gt, 1))];
    end

    title(['Frame: ', num2str(k), ' - Mean IoU: ', num2str(meanFrameIoU, '%.2f')]);
    hold off;
    drawnow;
end

% Success Plot 

thresholds = 0:0.1:1; 

successRate = zeros(length(thresholds), 1);

for t = 1:length(thresholds)
    countSuccess = sum(allMaxIoU > thresholds(t));

    successRate(t) = (countSuccess / length(allMaxIoU)) * 100;
end

figure;
plot(thresholds, successRate, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
grid on;
title('Success Plot (IoU Evaluation)');
xlabel('Overlap threshold (IoU)');
ylabel('Success rate (%)');
xlim([0 1]);
ylim([0 105]);