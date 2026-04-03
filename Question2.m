clear all, close all

path = "View_01/";
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

% Background Detection
nFrame = 500;
step = 15;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,path,k,extName));
    vid4D(:,:,:,k)=img;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(imgbk_rgb);


% Detection 
thr     = 40;       
minArea   = 250;
seqLength = 794;

se = strel('rectangle', [10, 2]);

figure; hold on
for i=0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
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
    label_num = 1;
    for j = 1:num
        if regionProps(j).Area > minArea
            bbox = regionProps(j).BoundingBox;
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-5, num2str(label_num), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
            label_num = label_num + 1;
        end
    end
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end