clear all, close all
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
decay_factor = 0.995; 
fig_dynamic = figure('Name', 'Dynamic Heatmap');

dim_factor = 0.4;

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
    
    label_num = 1;
    for j = 1:num
        if regionProps(j).Area > minArea
            bbox = regionProps(j).BoundingBox;
            center = regionProps(j).Centroid; 
            
            label_num = label_num + 1;
            
            x = round(center(1));
            y = round(center(2));
            
            if x > 0 && x <= w && y > 0 && y <= h
                map_static(y, x) = map_static(y, x) + 1;
                map_dynamic(y, x) = map_dynamic(y, x) + 2;
            end
        end
    end
    
    figure(fig_dynamic);
    clf;
    imshow(uint8(imgbk_rgb * dim_factor));
    hold on;
    dyn_smooth = imgaussfilt(map_dynamic, 8);
    max_dyn = max(dyn_smooth(:));
    if max_dyn > 0
        dyn_norm = dyn_smooth / max_dyn;
    else
        dyn_norm = dyn_smooth;
    end
    h_dyn = imagesc(dyn_smooth);
    colormap('hot');
    set(h_dyn, 'AlphaData', dyn_norm);
    axis image; axis off;
    title(sprintf('Dynamic Heatmap - Frame %d', i));
    drawnow;
end

figure('Name', 'Global Static Heatmap ');
imshow(uint8(imgbk_rgb));
hold on;
stat_smooth = imgaussfilt(map_static, 15);
max_stat = max(stat_smooth(:));
if max_stat > 0
    stat_norm = stat_smooth / max_stat;
else
    stat_norm = stat_smooth;
end
h_stat = imagesc(stat_smooth);
colormap('hot');
colorbar;
set(h_stat, 'AlphaData', stat_norm * 0.85);
axis image; axis off;
title('Static Heatmap');