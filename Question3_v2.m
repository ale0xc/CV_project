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
imgbk = double(imgbk_rgb);

% --- Parameters ---
thr = 40;       
minArea = 250;
seqLength = 794;
se = strel('rectangle', [10, 2]);

% --- Tracking & Trajectories Setup ---
max_p = 50; 
trajectories = cell(max_p, 1);
last_positions = []; % [x, y, id]
dist_threshold = 50; 
figure;
for i=0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
    imgfr = double(imgfr_rgb);

    imgdif = (abs(double(imgbk(:,:,1))-double(imgfr(:,:,1)))>thr) | ...
        (abs(double(imgbk(:,:,2))-double(imgfr(:,:,2)))>thr) | ...
        (abs(double(imgbk(:,:,3))-double(imgfr(:,:,3)))>thr);
         
    % Computations
    bw_clean = imclose(imgdif, se);      
    bw_clean = imopen(bw_clean, se);
    bw_clean = imfill(bw_clean, 'holes');
    [lb, num] = bwlabel(bw_clean);
    regionProps = regionprops(lb,'area','BoundingBox', 'Centroid');
    
    imshow(imgfr_rgb); hold on;
    
    current_positions = []; 
    ids_deja_pris_cette_frame = []; 
    
    for j = 1:num
        if regionProps(j).Area > minArea
            bbox = regionProps(j).BoundingBox;
            center = regionProps(j).Centroid;
            
            assigned_id = -1;
            min_dist = dist_threshold;
            if ~isempty(last_positions)
                for t = 1:size(last_positions, 1)
                    old_id = last_positions(t, 3);
                    
                    if ismember(old_id, ids_deja_pris_cette_frame)
                        continue;
                    end
                    
                    d = sqrt(sum((center - last_positions(t, 1:2)).^2));
                    if d < min_dist
                        min_dist = d;
                        assigned_id = old_id;
                    end
                end
            end
            
            if assigned_id == -1
                for id_candidat = 1:max_p
                    if ~ismember(id_candidat, ids_deja_pris_cette_frame) && ...
                       (isempty(last_positions) || ~ismember(id_candidat, last_positions(:,3)))
                        assigned_id = id_candidat;
                        trajectories{assigned_id} = []; 
                        break;
                    end
                end
            end
            
            ids_deja_pris_cette_frame = [ids_deja_pris_cette_frame, assigned_id];
            current_positions = [current_positions ; center, assigned_id];
            
            % Update Trajectories
            trajectories{assigned_id} = [trajectories{assigned_id} ; center];
            if size(trajectories{assigned_id}, 1) > 20
                trajectories{assigned_id} = trajectories{assigned_id}(end-19:end, :);
            end
            
            % Drawings
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-5, num2str(assigned_id), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
            
            path_p = trajectories{assigned_id};
            if size(path_p, 1) > 1
                plot(path_p(:, 1), path_p(:, 2), 'y-', 'LineWidth', 1.5);
                plot(center(1), center(2), 'y.', 'MarkerSize', 10);
            end
        end
    end
    
    for id_test = 1:max_p
        if ~ismember(id_test, ids_deja_pris_cette_frame)
            trajectories{id_test} = [];
        end
    end
    
    last_positions = current_positions;
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end