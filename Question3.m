clear all, close all
path = "View_01/";
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
imgbk = double(imgbk_rgb);

thr = 40;       
minArea = 250;
seqLength = 794;
se = strel('rectangle', [10, 2]);

max_p = 1000; 
trajectories = cell(max_p, 1);
last_bboxes = []; 
last_ids = []; 
iou_threshold = 0.3; 
next_id = 1;

figure;
for i=0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
    imgfr = double(imgfr_rgb);
         
    imgdif = (abs(double(imgbk(:,:,1))-double(imgfr(:,:,1)))>thr) | ...
        (abs(double(imgbk(:,:,2))-double(imgfr(:,:,2)))>thr) | ...
        (abs(double(imgbk(:,:,3))-double(imgfr(:,:,3)))>thr);
    bw_clean = imclose(imgdif, se);      
    bw_clean = imopen(bw_clean, se);
    bw_clean = imfill(bw_clean, 'holes');
    
    [lb, num] = bwlabel(bw_clean);
    regionProps = regionprops(lb,'area','BoundingBox', 'Centroid');
    
    imshow(imgfr_rgb); hold on;
    
    current_bboxes = [];
    current_centroids = [];
    
    for j = 1:num
        if regionProps(j).Area > minArea
            current_bboxes = [current_bboxes; regionProps(j).BoundingBox];
            current_centroids = [current_centroids; regionProps(j).Centroid];
        end
    end
    
    current_ids = zeros(size(current_bboxes, 1), 1);
    
    if ~isempty(current_bboxes)
        if ~isempty(last_bboxes)
            iouMatrix = bboxOverlapRatio(current_bboxes, last_bboxes);
            
            for c = 1:size(current_bboxes, 1)
                [max_iou, match_idx] = max(iouMatrix(c, :));
                
                if max_iou > iou_threshold
                    current_ids(c) = last_ids(match_idx);
                    iouMatrix(:, match_idx) = -1; 
                else
                    current_ids(c) = next_id;
                    next_id = next_id + 1;
                end
            end
        else
            for c = 1:size(current_bboxes, 1)
                current_ids(c) = next_id;
                next_id = next_id + 1;
            end
        end
        
        for c = 1:size(current_bboxes, 1)
            bbox = current_bboxes(c, :);
            center = current_centroids(c, :);
            assigned_id = current_ids(c);
            
            trajectories{assigned_id} = [trajectories{assigned_id} ; center];
            if size(trajectories{assigned_id}, 1) > 20
                trajectories{assigned_id} = trajectories{assigned_id}(end-19:end, :);
            end
            
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-5, num2str(assigned_id), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
            
            path_p = trajectories{assigned_id};
            if size(path_p, 1) > 1
                plot(path_p(:, 1), path_p(:, 2), 'y-', 'LineWidth', 1.5);
                plot(center(1), center(2), 'y.', 'MarkerSize', 10);
            end
        end
    end
    
    last_bboxes = current_bboxes;
    last_ids = current_ids;
    
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end