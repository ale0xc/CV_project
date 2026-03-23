gtData = readmatrix('C:/Users/acach/ist-cv-2526/Project/gt.txt'); 
imagesPath = "C:/Users/acach/ist-cv-2526/Project/Images/"; 
nImages = 794;
extName = 'jpg';
frameIdComp = 4;
str  = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];
nGT = 10;

for k = 0:nImages
    img= imread(sprintf(str,imagesPath,k,extName));
    
    currentImageGT = gtData(gtData(:, 1) == k, :);
    
    imshow(img);
    hold on;
    
    for i = 1:size(currentImageGT, 1)
        gtID = currentImageGT(i, 2);
        bbox = [currentImageGT(i, 3), currentImageGT(i, 4), ...
                currentImageGT(i, 5), currentImageGT(i, 6)];
        
        rectangle('Position', bbox, 'EdgeColor', 'w', 'LineWidth', 2);
        text(bbox(1), bbox(2) - 10, num2str(gtID), ...
            'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');
    end
    
    title(['Frame: ', num2str(k)]);
    hold off;
    drawnow;
end