function avg_accuracy = svmMultiClassKFold_canopy_based(species, rois, features, debug, kernel, kernel_param)
%% This is a k-fold classification all-vs-all (as compared to one-vs-all) based on 
%using separate canopies for training and test sets. to make sure I do not
% use pixels of a tree both for train and test.

% if nargin < 1
%   debug = 0;
%   kernel_param = 1;
% end



[g gn] = grp2idx(species);      %# nominal class to numeric (string specie to numeric)

%k=10; % one for test 9 for trainning
k = 5; % at most 5 crowns for some species.

%%
% Do SVM on ROIs. (specify which ROIs to be used for train/test - determine
% the train/test ROI index using crossvalind function)

unique_rois = unique(rois);
unique_rois_species =  cell(numel(unique_rois),1);
for i = 1:numel(unique_rois)
    roiIdx = rois == unique_rois(i);
    rois_specie = species(roiIdx);
    unique_rois_species(i) = rois_specie(1);
end


sum_accuracy = 0;
cvFolds = crossvalind('Kfold', unique_rois_species, k);   %# get indices of 10-fold CV


for i = 1:k                          % Run SVM classificatoin k times (k being the # of folds)
    testIdx = (cvFolds == i);        % get test set indices
    trainIdx = ~testIdx;             % get training indices
             
    pairwise = nchoosek(1:length(gn),2);            %# all-vs-all pairwise models [1,2;1,3;2,3]
    svmModel = cell(size(pairwise,1),1);            %# NchooseK binary-classifers: one classifier for each [1,2;1,3;2,3]
    predTest = zeros(sum(testIdx),numel(svmModel)); %# binary predictions - three predictions per test (one for each classfier above)

    %# classify using one-against-one approach
    for j=1:numel(svmModel)
        %# get only training instances belonging to this pair
        selector = any( bsxfun(@eq, g, pairwise(j,:)) , 2 );
        idx = trainIdx & selector;

        % train - test
      %  try
            if strcmp(kernel, 'polynomial')
               svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                 'BoxConstraint',2e-1, 'Kernel_Function', kernel, 'Polyorder',kernel_param);         
            elseif strcmp(kernel, 'rbf')
               svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                 'Method','QP', ...
                 'BoxConstraint',Inf, 'Kernel_Function', kernel, 'RBF_Sigma',kernel_param);
            end
          predTest(:,j) = svmclassify(svmModel{j}, features(testIdx,:));

       % catch ME
        %end
    end
    pred = mode(predTest,2);   %# voting: clasify as the class receiving most votes
                           % Find the most frequent value of each column.

    %# performance
    [cmat, order] = confusionmat(g(testIdx),pred);
    acc = 100*sum(diag(cmat))./sum(cmat(:));
    if debug 
      fprintf('SVM (1-against-1):\naccuracy = %.2f%%\n', acc);
      fprintf('Confusion Matrix:\n'), disp(cmat)
      order
      gn
    end
    
    sum_accuracy = sum_accuracy + acc;
end

avg_accuracy = sum_accuracy / k;


































% here i try to generate train/test indexes myself. later I realized I can
% still use matlab's crossvalind to generate them. above I am exploring
% this

unique_species = unique(species);

for i = 1 : numel(unique_species) % for each specie
    filterIdx = strcmp(species, unique_species(i));
    rois_specie = rois(filterIdx);
    rois_specie_uniq = unique(rois_specie); % identify relevant ROIs
    
    disp(rois_specie_uniq');
    
    % k_fold proportion
    data_size = numel(rois_specie_uniq);
    test_sample_size = round(data_size/k); % if equal take one for test, the rest train
    
    testIdx0 = randsample(data_size, test_sample_size);
    trainIdx0 = setxor(total_index, [testIdx0]);
    
    features_specie = features(filterIdx);
    
    
    % specify a different fold for each ROI
   % ----- cvFolds = 
    
    % Actual k-fold implemetation
    for i = 1:k                          % Run SVM classificatoin k times (k being the # of folds)
        testIdx = (cvFolds == i);        % get test set indices
        trainIdx = ~testIdx;             % get training indices
        
        pairwise = nchoosek(1:length(gn),2);            %# all-vs-all pairwise models [1,2;1,3;2,3]
        svmModel = cell(size(pairwise,1),1);            %# NchooseK binary-classifers: one classifier for each [1,2;1,3;2,3]
        predTest = zeros(sum(testIdx),numel(svmModel)); %# binary predictions - three predictions per test (one for each classfier above)
        
        %# classify using one-against-one approach
        for j=1:numel(svmModel)
            %# get only training instances belonging to this pair
            selector = any( bsxfun(@eq, g, pairwise(j,:)) , 2 );
            idx = trainIdx & selector;
            
            % train - test
            %  try
            if strcmp(kernel, 'polynomial')
                svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                    'BoxConstraint',2e-1, 'Kernel_Function', kernel, 'Polyorder',kernel_param);
            elseif strcmp(kernel, 'rbf')
                svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                    'Method','QP', ...
                    'BoxConstraint',Inf, 'Kernel_Function', kernel, 'RBF_Sigma',kernel_param);
            end
            predTest(:,j) = svmclassify(svmModel{j}, features(testIdx,:));
            
            % catch ME
            %end
        end
        pred = mode(predTest,2);   %# voting: clasify as the class receiving most votes
        % Find the most frequent value of each column.
        
        %# performance
        [cmat, order] = confusionmat(g(testIdx),pred);
        acc = 100*sum(diag(cmat))./sum(cmat(:));
        if debug
            fprintf('SVM (1-against-1):\naccuracy = %.2f%%\n', acc);
            fprintf('Confusion Matrix:\n'), disp(cmat)
            order
            gn
        end
        
        sum_accuracy = sum_accuracy + acc;
    end
    
    avg_accuracy = sum_accuracy / k;
    
    
    
    
end


%%
sum_accuracy = 0;
cvFolds = crossvalind('Kfold', specie, k);   %# get indices of 10-fold CV

for i = 1:k                          % Run SVM classificatoin k times (k being the # of folds)
    testIdx = (cvFolds == i);        % get test set indices
    trainIdx = ~testIdx;             % get training indices
             
    pairwise = nchoosek(1:length(gn),2);            %# all-vs-all pairwise models [1,2;1,3;2,3]
    svmModel = cell(size(pairwise,1),1);            %# NchooseK binary-classifers: one classifier for each [1,2;1,3;2,3]
    predTest = zeros(sum(testIdx),numel(svmModel)); %# binary predictions - three predictions per test (one for each classfier above)

    %# classify using one-against-one approach
    for j=1:numel(svmModel)
        %# get only training instances belonging to this pair
        selector = any( bsxfun(@eq, g, pairwise(j,:)) , 2 );
        idx = trainIdx & selector;

        % train - test
      %  try
            if strcmp(kernel, 'polynomial')
               svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                 'BoxConstraint',2e-1, 'Kernel_Function', kernel, 'Polyorder',kernel_param);         
            elseif strcmp(kernel, 'rbf')
               svmModel{j} = svmtrain(features(idx,:), g(idx), ...
                 'Method','QP', ...
                 'BoxConstraint',Inf, 'Kernel_Function', kernel, 'RBF_Sigma',kernel_param);
            end
          predTest(:,j) = svmclassify(svmModel{j}, features(testIdx,:));

       % catch ME
        %end
    end
    pred = mode(predTest,2);   %# voting: clasify as the class receiving most votes
                           % Find the most frequent value of each column.

    %# performance
    [cmat, order] = confusionmat(g(testIdx),pred);
    acc = 100*sum(diag(cmat))./sum(cmat(:));
    if debug 
      fprintf('SVM (1-against-1):\naccuracy = %.2f%%\n', acc);
      fprintf('Confusion Matrix:\n'), disp(cmat)
      order
      gn
    end
    
    sum_accuracy = sum_accuracy + acc;
end

avg_accuracy = sum_accuracy / k;

end
