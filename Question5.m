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
imgbk = double(rgb2gray(imgbk_rgb));

thr     = 40;       
minArea = 250;
seqLength = 794;
se = strel('rectangle', [10, 2]);

[h, w] = size(imgbk);
map_static = zeros(h, w);
map_dynamic = zeros(h, w);

decay_factor = 0.90; 
fig_dynamic = figure('Name', 'Dynamic Heatmap');
dim_factor = 0.4;

R = 30;
[X, Y] = meshgrid(-R:R, -R:R);
metric = 'gaussian'; 

switch metric
    case 'cityblock'
        D = abs(X) + abs(Y);
        kernel = max(0, R - D); 
        
    case 'chessboard'
        D = max(abs(X), abs(Y));
        kernel = max(0, R - D);
        
    case 'euclidean'
        D = sqrt(X.^2 + Y.^2);
        kernel = max(0, R - D);
        
    case 'gaussian'
        sigma = R / 3;
        kernel = exp(-(X.^2 + Y.^2) / (2 * sigma^2));
end
kernel = kernel / max(kernel(:));

for i=0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
    imgfr = double(rgb2gray(imgfr_rgb));
         
    imgdif = abs(imgbk - imgfr) > thr;
    bw_clean = imopen(imgdif, se);      
    bw_clean = imclose(bw_clean, se);
    bw_clean = imfill(bw_clean, 'holes');
    
    [lb, num] = bwlabel(bw_clean);
    regionProps = regionprops(lb,'area','BoundingBox', 'Centroid');
    
    map_dynamic = map_dynamic * decay_factor;
    frame_impulses = zeros(h, w);
    
    label_num = 1;
    for j = 1:num
        if regionProps(j).Area > minArea
            bbox = regionProps(j).BoundingBox;
            center = regionProps(j).Centroid; 
            
            label_num = label_num + 1;
            
            x = round(center(1));
            y = round(center(2));
            if x > 0 && x <= w && y > 0 && y <= h
                frame_impulses(y, x) = 1;
            end
        end
    end
    
    frame_heat = imfilter(frame_impulses, kernel, 'replicate');
    
    map_static = map_static + frame_heat;
    map_dynamic = map_dynamic + frame_heat;
    
    figure(fig_dynamic);
    clf;
    imshow(uint8(imgbk_rgb * dim_factor));
    hold on;
    
    max_dyn = max(map_dynamic(:));
    if max_dyn > 0
        dyn_norm = sqrt(map_dynamic) / sqrt(max_dyn);
    else
        dyn_norm = map_dynamic;
    end
    
    h_dyn = imagesc(map_dynamic);
    colormap('hot');
    
    if max_dyn > 0
        clim([0, max_dyn * 0.6]); 
    end
    
    set(h_dyn, 'AlphaData', dyn_norm);
    axis image; axis off;
    title(sprintf('Dynamic Heatmap (%s) - Frame %d', metric, i));
    drawnow;
end

figure('Name', 'Global Static Heatmap');
imshow(uint8(imgbk_rgb));
hold on;

max_stat = max(map_static(:));
if max_stat > 0
    stat_norm = sqrt(map_static) / sqrt(max_stat);
else
    stat_norm = map_static;
end

h_stat = imagesc(map_static);
colormap('hot');
colorbar;

saturation_limit = max_stat * 0.4; 
if saturation_limit > 0
    clim([0, saturation_limit]); 
end

set(h_stat, 'AlphaData', stat_norm * 0.85);
axis image; axis off;
title('Static Occupancy Heatmap');