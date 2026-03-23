clear all, close all
path = "C:/Users/acach/ist-cv-2526/Project/Images/";
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

disp('Background Detection...')
nFrame = 500;
step = 15;
idx = 1;
for k = 1 : 1 : nFrame/step
    img   = imread(sprintf(str,path,k,extName));
    vid4D(:,:,:,k)=img;
    idx = idx + 1;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(imgbk_rgb);
[h, w] = size(imgbk);

thr     = 40;       
minArea   = 250;
seqLength = 794;
se = strel('rectangle', [10, 2]);
all_pedestrian_points = [];

disp('Video Processing...')
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
    regionProps = regionprops(lb,'area','Centroid');
    
    label_num = 1;
    for j = 1:num
        if regionProps(j).Area > minArea
            center = regionProps(j).Centroid; 
            all_pedestrian_points = [all_pedestrian_points; center(1), center(2)];
            label_num = label_num + 1;
        end
    end
end

disp('Finding optimal K using BIC...');
max_k_test = 6;
best_bic = inf;
best_k = 1;
options = statset('MaxIter', 1000, 'Display', 'off');

bic_values = zeros(max_k_test, 1);

for test_k = 1:max_k_test
    try
        gmm_test = fitgmdist(all_pedestrian_points, test_k, 'Options', options, 'RegularizationValue', 0.1);
        bic_values(test_k) = gmm_test.BIC;
        
        if gmm_test.BIC < best_bic
            best_bic = gmm_test.BIC;
            best_k = test_k;
            gmm_model = gmm_test;
        end
    catch
        bic_values(test_k) = NaN;
        continue;
    end
end

num_paths_K = best_k;

fprintf('\n-------------------------\n');
fprintf('   K   |      BIC        \n');
fprintf('-------------------------\n');
for test_k = 1:max_k_test
    fprintf('   %d   |   %10.2f\n', test_k, bic_values(test_k));
end
fprintf('-------------------------\n');
fprintf('Optimal K found: %d\n\n', num_paths_K);

figure('Name', 'EM Algorithm Trajectory Analysis');
imshow(uint8(imgbk_rgb * 0.4)); 
hold on;
scatter(all_pedestrian_points(:,1), all_pedestrian_points(:,2), 2, 'white', 'filled', 'MarkerFaceAlpha', 0.1);

colors = ['r', 'g', 'b', 'c', 'm', 'y'];

for k = 1:num_paths_K
    mu = gmm_model.mu(k, :);
    sigma = gmm_model.Sigma(:, :, k);
    weight = gmm_model.ComponentProportion(k) * 100;
    
    x_grid = linspace(1, w, 100);
    y_grid = linspace(1, h, 100);
    [X1, X2] = meshgrid(x_grid, y_grid);
    
    F = mvnpdf([X1(:) X2(:)], mu, sigma);
    F = reshape(F, length(y_grid), length(x_grid));
    
    maxF = max(F(:));
    contourLevels = [maxF*0.1, maxF*0.4, maxF*0.8]; 
    
    color_idx = mod(k-1, length(colors)) + 1;
    
    contour(x_grid, y_grid, F, contourLevels, 'LineColor', colors(color_idx), 'LineWidth', 2);
    plot(mu(1), mu(2), 'x', 'MarkerSize', 12, 'LineWidth', 3, 'Color', colors(color_idx));
    text(mu(1) + 10, mu(2), sprintf('Path %d (%.1f%%)', k, weight), 'Color', colors(color_idx), 'FontSize', 12, 'FontWeight', 'bold');
end

title(['Statistical Analysis of Trajectories (EM Algorithm) - K = ', num2str(num_paths_K)]);
hold off;