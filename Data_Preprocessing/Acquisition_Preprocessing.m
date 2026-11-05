%% Spatiotemporal Motor Control Preprocessing
% Processes NoiseExp_Cursor data only
%
% Expected folder structure:
%   Uniform/
%       P_xx/
%           *NoiseExp_Cursor*.csv
%   Random_Walk/
%       P_xx/
%           *NoiseExp_Cursor*.csv
%
% Requires: Preprocessing_Functions/ on the MATLAB path

clc; clear;
addpath('Preprocessing_Functions/');

%% Settings
targetString = 'NoiseExp_Cursor';
outputFile   = 'Cursor_Kinematics_NoiseExp.csv';
saveData     = true;

%% Discover participants from folder structure
conditions = struct( ...
    'folder', {'Uniform/', 'Random_Walk/'}, ...
    'label',  {'Uniform', 'RandomWalk'} ...
);

% Fill this with the datafile names of your participants
AllData = [];

for c = 1:numel(conditions)
    condFolder = conditions(c).folder;
    condLabel  = conditions(c).label;
    
    if ~isfolder(condFolder)
        warning('Folder not found: %s', condFolder);
        continue;
    end
    
    % Get participant subfolders
    participantDirs = dir(condFolder);
    participantDirs = participantDirs([participantDirs.isdir] & ...
        ~ismember({participantDirs.name}, {'.', '..'}));
    
    for p = 1:numel(participantDirs)
        participant = participantDirs(p).name;
        participantPath = fullfile(condFolder, participant);
        
        fprintf('\n=== %s (%s) ===\n', participant, condLabel);
        
        % Find NoiseExp_Cursor file
        match = dir(fullfile(participantPath, ['*' targetString '*.csv']));
        match = match(~startsWith({match.name}, '._'));  % ignore macOS metadata
        
        if isempty(match)
            fprintf('   No %s file found.\n', targetString);
            continue;
        end
        
        filename = fullfile(participantPath, match(1).name);
        fprintf('   Processing: %s\n', match(1).name);
        Cursordata = readtable(filename);
        
        blocks = unique(Cursordata.Block);
        for b = 1:numel(blocks)
            blockData = Cursordata(Cursordata.Block == blocks(b), :);
            trialIDs  = unique(blockData.TrialNumber);
            TrialData = [];
            
            for t = 1:numel(trialIDs)
                trialData = blockData(blockData.TrialNumber == trialIDs(t), :);
                
                xPos    = trialData.xDelay;
                yPos    = trialData.yDelay;
                xTarget = trialData.xTarget(1);
                yTarget = trialData.yTarget(1);
                
                if length(xPos) < 5
                    continue;
                end
                
                % Performance metrics
                trialOvershoot       = PreprocessOvershoot(b, t, xPos, yPos, xTarget, yTarget, 30);
                trialPeakVelocity    = PreprocessPeakVelocity(xPos, yPos, 16.7);
                trialAverageVelocity = PreprocessAverageVelocity(xPos, yPos, 16.7);
                
                % Kinematics
                trialPathEff = PreprocessPathEfficiency(xPos, yPos);
                trialJerk    = PreprocessJerk(xPos, yPos);
                trialVar     = PreprocessVelocityVariability(xPos, yPos);
                trialSubmov  = PreprocessSubmovements(xPos, yPos);
                
                TrialData = [TrialData; ...
                    trialOvershoot, ...
                    trialPeakVelocity, ...
                    trialAverageVelocity, ...
                    trialPathEff, ...
                    trialJerk, ...
                    trialVar, ...
                    trialSubmov];
            end
            
            if isempty(TrialData)
                continue;
            end
            
            % Block-level summary
            AllData = [AllData; { ...
                participant, ...
                condLabel, ...
                blocks(b), ...
                sum(TrialData(:,1)), ...
                mean(TrialData(:,3), 'omitnan'), ...
                max(TrialData(:,2), [], 'omitnan'), ...
                mean(TrialData(:,4), 'omitnan'), ...
                mean(TrialData(:,5), 'omitnan'), ...
                mean(TrialData(:,6), 'omitnan'), ...
                mean(TrialData(:,7), 'omitnan')}];
        end
    end
end

%% Save results
if saveData && ~isempty(AllData)
    ResultsTable = cell2table(AllData, ...
        'VariableNames', {'ParticipantID','Condition','Block', ...
        'NumOvershoots','AverageVelocity','PeakVelocity', ...
        'PathEfficiency','Jerk','VelocityVariability','Submovements'});
    
    writetable(ResultsTable, outputFile);
    fprintf('\nTable saved as %s\n', outputFile);
    disp(head(ResultsTable, 10));
else
    ResultsTable = table();
    fprintf('\nNo data processed.\n');
end

%% Overshoot summary figure
if ~isempty(ResultsTable)
    fprintf('\nGenerating overshoot summary figure...\n');
    ResultsTable.Condition = categorical(ResultsTable.Condition);
    blocks = unique(ResultsTable.Block);
    groups = categories(ResultsTable.Condition);
    
    meanOvershoots = zeros(numel(blocks), numel(groups));
    semOvershoots  = zeros(numel(blocks), numel(groups));
    
    for g = 1:numel(groups)
        cond = groups{g};
        for b = 1:numel(blocks)
            these = ResultsTable.NumOvershoots( ...
                ResultsTable.Block == blocks(b) & ResultsTable.Condition == cond);
            meanOvershoots(b,g) = mean(these, 'omitnan');
            semOvershoots(b,g)  = std(these, 'omitnan') / sqrt(numel(these));
        end
    end
    
    figure('Color','w'); hold on;
    for g = 1:numel(groups)
        errorbar(blocks, meanOvershoots(:,g), semOvershoots(:,g), '-o', 'LineWidth', 1.5);
    end
    xlabel('Block Number', 'Color', 'k');
    ylabel('Average Number of Overshoots', 'Color', 'k');
    legend(groups, 'Location', 'best', 'TextColor', 'k');
    title('Average Overshoots per Block (NoiseExp\_Cursor)', 'Color', 'k');
    grid on;
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'Color', 'w', ...
        'XColor', 'k', 'YColor', 'k', 'Box', 'off');
end