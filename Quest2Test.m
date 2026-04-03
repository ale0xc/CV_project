clear all, close all
path = "View_01/";
extName = 'jpg';
frameIdComp = 4;
str = ['%sframe_%.' num2str(frameIdComp) 'd.%s'];

% ---------------------------------------------------------
% 1. INITIALISATION ET DÉTECTION DU FOND
% ---------------------------------------------------------
nFrame = 500;
step = 15;

for k = 1 : 1 : nFrame/step
    img = imread(sprintf(str,path,k,extName));
    vid4D(:,:,:,k) = img;
end
imgbk_rgb = median(vid4D,4);
imgbk = double(imgbk_rgb);

% ---------------------------------------------------------
% 2. PARAMÈTRES DE DÉTECTION ET DE SUIVI
% ---------------------------------------------------------
thr       = 40;        
% [MODIFICATION 1] : Baissé à 100. Permet de capter les bouts de corps (épaules, pieds) 
% qui dépassent derrière le poteau avant que la personne ne soit complètement sortie.
minArea   = 100;       
seqLength = 794;
se = strel('rectangle', [10, 2]); 

tracks = struct('id', {}, 'bbox', {}, 'centroid', {}, 'invisible_count', {}, 'last_full_bbox', {});

next_id = 1; 
max_distance_base = 40; % Distance standard
max_invisible = 60;     % Temps de patience

figure; hold on
% ---------------------------------------------------------
% 3. BOUCLE PRINCIPALE
% ---------------------------------------------------------
for i=0:seqLength
    imgfr_rgb = imread(sprintf(str,path,i,extName));
    imgfr = double(imgfr_rgb);
          
    imgdif = (abs(double(imgbk(:,:,1))-double(imgfr(:,:,1)))>thr) | ...
             (abs(double(imgbk(:,:,2))-double(imgfr(:,:,2)))>thr) | ...
             (abs(double(imgbk(:,:,3))-double(imgfr(:,:,3)))>thr);
    
    bw_clean = imclose(imgdif, se);
    bw_clean = imopen(bw_clean, se);      
    bw_clean = imfill(bw_clean, 'holes');
    
    [lb num] = bwlabel(bw_clean);
    regionProps = regionprops(lb, 'Area', 'BoundingBox', 'Centroid');
    
    imshow(imgfr_rgb); hold on;
    
    % ÉTAPE A : INVENTAIRE DES DÉTECTIONS ACTUELLES
    current_detections = [];
    for j = 1:num
        if regionProps(j).Area > minArea
            det.bbox = regionProps(j).BoundingBox;
            det.centroid = regionProps(j).Centroid;
            current_detections = [current_detections; det];
        end
    end
    
    % [MODIFICATION 2] ÉTAPE B : MATRICE DE COÛT (Évite les vols d'ID dans les groupes)
    num_tracks = length(tracks);
    num_dets = length(current_detections);
    cost_matrix = inf(num_tracks, num_dets); % Matrice remplie d'infinis par défaut
    
    for t = 1:num_tracks
        % [MODIFICATION 3] : Rayon élastique. Le rayon de recherche s'élargit
        % de 4 pixels pour chaque frame passée cachée derrière le poteau.
        dynamic_radius = max_distance_base + (tracks(t).invisible_count * 4);
        
        for d = 1:num_dets
            dist = norm(tracks(t).centroid - current_detections(d).centroid);
            if dist <= dynamic_radius
                cost_matrix(t, d) = dist; % On sauvegarde la distance valide
            end
        end
    end
    
    matched_tracks = false(num_tracks, 1);
    matched_detections = false(num_dets, 1);
    new_tracks = struct('id', {}, 'bbox', {}, 'centroid', {}, 'invisible_count', {}, 'last_full_bbox', {});
    
    % Résolution de la matrice : on lie les paires avec la distance la plus petite en premier
    for iter = 1:min(num_tracks, num_dets)
        [min_val, min_idx] = min(cost_matrix(:)); % Trouve le min global
        if isinf(min_val)
            break; % Il n'y a plus de paires possibles dans les rayons autorisés
        end
        
        [best_t, best_d] = ind2sub([num_tracks, num_dets], min_idx);
        
        matched_tracks(best_t) = true;
        matched_detections(best_d) = true;
        
        % --- MISE À JOUR DU TRACK ---
        trk = tracks(best_t);
        det = current_detections(best_d);
        updated_track.id = trk.id;
        
        % Logique d'occlusion partielle (Poteau / Groupes)
        curr_area = det.bbox(3) * det.bbox(4);
        old_area = trk.last_full_bbox(3) * trk.last_full_bbox(4);
        
        if curr_area < old_area * 0.60
            % La personne est à moitié cachée : on garde le gros carré en mémoire
            w = trk.last_full_bbox(3);
            h = trk.last_full_bbox(4);
            new_x = det.centroid(1) - w/2;
            new_y = det.centroid(2) - h/2;
            updated_track.bbox = [new_x, new_y, w, h];
            updated_track.last_full_bbox = trk.last_full_bbox;
        else
            % La personne est bien visible
            updated_track.bbox = det.bbox;
            updated_track.last_full_bbox = det.bbox;
        end
        
        updated_track.centroid = det.centroid;
        updated_track.invisible_count = 0;
        new_tracks(end+1) = updated_track;
        
        % On bloque cette personne et cette détection dans la matrice (elles sont "mariées")
        cost_matrix(best_t, :) = inf;
        cost_matrix(:, best_d) = inf;
    end
    
    % ÉTAPE C : GESTION DES RESTES (Cachés et Nouveaux)
    
    % 1. Les tracks qui n'ont rien trouvé (Cachés complètement)
    for t = 1:num_tracks
        if ~matched_tracks(t)
            trk = tracks(t);
            trk.invisible_count = trk.invisible_count + 1;
            
            if trk.invisible_count <= max_invisible
                new_tracks(end+1) = trk;
            end
        end
    end
    
    % 2. Les détections qui n'ont pas de track (Nouvelles personnes)
    for d = 1:num_dets
        if ~matched_detections(d)
            det = current_detections(d);
            new_track.id = next_id;
            new_track.bbox = det.bbox;
            new_track.last_full_bbox = det.bbox;
            new_track.centroid = det.centroid;
            new_track.invisible_count = 0;
            new_tracks(end+1) = new_track;
            next_id = next_id + 1;
        end
    end
    
    tracks = new_tracks;
    
    % ÉTAPE D : DESSIN DES RÉSULTATS
    for t = 1:length(tracks)
        bbox = tracks(t).bbox;
        id = tracks(t).id;
        
        if tracks(t).invisible_count > 0
            rectangle('Position', bbox, 'EdgeColor', [1 1 0], 'linewidth', 2, 'LineStyle', '--');
            text(bbox(1), bbox(2)-10, num2str(id), 'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
        else
            rectangle('Position', bbox, 'EdgeColor', [1 0 0], 'linewidth', 2);
            text(bbox(1), bbox(2)-10, num2str(id), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
        end
    end
    
    title(['Frame: ', num2str(i)]);
    drawnow;
    hold off;
end