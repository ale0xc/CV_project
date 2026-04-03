clear all, close all
path = "View_01/";
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

% --- Background Detection ---
nFrame = 500;
step = 15;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,path,k,extName));
    vid4D(:,:,:,k)=img;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(rgb2gray(imgbk_rgb));

% --- Detection & Tracking Setup ---
thr     = 40;       
minArea   = 250;
maxArea = 2500; 
maxWidth = 45;
seqLength = 794;
se = strel('rectangle', [10, 2]);

galerie_p = []; 
next_id = 1;     
visual_threshold = 0.60; 
N_bins = 100;

figure; hold on
for i = 0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
    imgfr = double(rgb2gray(imgfr_rgb));
         
    % Computations (Detection)
    imgdif = abs(imgbk - imgfr) > thr;
    bw_clean = imopen(imgdif, se);      
    bw_clean = imclose(bw_clean, se);
    bw_clean = imfill(bw_clean, 'holes');
    
    [lb, num] = bwlabel(bw_clean);
    regionProps = regionprops(lb,'Area','BoundingBox', 'Centroid');
    
    imshow(imgfr_rgb); hold on;
    
    % Drawings & Tracking
    active_id_frame = [];
    for j = 1:num
        area = regionProps(j).Area;
        bbox = regionProps(j).BoundingBox;

        if area > minArea && area < maxArea && bbox(3) < maxWidth
            centroid_curr = regionProps(j).Centroid;
            
            pedestrians_img = imcrop(imgfr_rgb, bbox);
            [h_p, w_p, ~] = size(pedestrians_img);
            mid = round(h_p / 2);

            img_torse = pedestrians_img(1:mid, :, :);
            img_legs  = pedestrians_img(mid+1:end, :, :);

            hist_torse = compute_hist_rgb(img_torse, N_bins);
            hist_legs  = compute_hist_rgb(img_legs, N_bins);

            h_curr = [hist_torse, hist_legs];

            best_id = -1;
            best_score = 0;
            idx_galerie = -1;
            
            for t = 1:length(galerie_p)
                current_test_id = galerie_p(t).id;
                if ismember(current_test_id, active_id_frame)
                    continue;
                end

                last_pos = galerie_p(t).last_centroid;
                last_w   = galerie_p(t).last_w;
                last_h   = galerie_p(t).last_h;
                
                dist_x = abs(centroid_curr(1) - last_pos(1));
                dist_y = abs(centroid_curr(2) - last_pos(2));
                
                if (dist_x <= 4 * last_w) && (dist_y <= 2 * last_h)

                    h_prev = galerie_p(t).hist;
                    score = sum(min(h_curr, h_prev)) / 6;
                
                    if score > best_score
                        best_score = score;
                        best_id = galerie_p(t).id;
                        idx_galerie = t;
                    end
                end
            end
            
            if best_score > visual_threshold
                id_final = best_id;
                galerie_p(idx_galerie).hist = h_curr; 
                galerie_p(idx_galerie).last_centroid = centroid_curr;
                galerie_p(idx_galerie).last_w = bbox(3);
                galerie_p(idx_galerie).last_h = bbox(4);
            else
                id_final = next_id;
                next_id = next_id + 1;

                new_entry.id = id_final;
                new_entry.hist = h_curr;
                new_entry.last_centroid = centroid_curr;
                new_entry.last_w = bbox(3);
                new_entry.last_h = bbox(4);
                galerie_p = [galerie_p, new_entry];
            end
           
            active_id_frame = [active_id_frame, id_final];
            
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            texte_label = num2str(id_final);
            text(bbox(1), bbox(2)-5, texte_label, 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
        
        else
            if area >= maxArea || bbox(3) >= maxWidth
                rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 1, 'LineStyle', '--');
            end
        end

    end
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end


function h_out = compute_hist_rgb(img, bins)
    [nl, nc, ~] = size(img);
    npix = max(nl * nc, 1);
    hr = imhist(img(:,:,1), bins) / npix;
    hg = imhist(img(:,:,2), bins) / npix;
    hb = imhist(img(:,:,3), bins) / npix;
    h_out = [hr', hg', hb'];
end