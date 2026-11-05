%% Exp2_WindowedLag.m
% Exposure trials only. Lag is estimated over the 2 s after each delay
% update (24 frames / 400 ms) and paired with that update's delay.
% Positive lag = cursor led the target (same sign as the main analysis).
%
% Expected folder structure:
%   Cons/P_xx/Exp_Tracking_Cursor_xx.csv
%   Unif/P_xx/Exp_Tracking_Cursor_xx.csv
%   RanW/P_xx/Exp_Tracking_Cursor_xx.csv
%
% Outputs:
%   Exp2_WindowedLag.csv
%   Exp2_LagDelay_Slopes.csv

clc; clear;

%% Settings
updateFrames = 24;     % 400 ms at 60 Hz
windowFrames = 120;    % 2 s, long enough for a +/-500 ms lag
skipFrames   = 120;    % drop the 2 s countdown
maxLagMs     = 500;

%% Discover participants from folder structure
conditions = ["Cons", "Unif", "RanW"];
windows = table();

for c = 1:numel(conditions)
    cond = conditions(c);
    if ~isfolder(cond)
        warning('Folder not found: %s', cond);
        continue;
    end
    
    participantDirs = dir(cond);
    participantDirs = participantDirs([participantDirs.isdir] & ...
        ~ismember({participantDirs.name}, {'.', '..'}));
    
    for p = 1:numel(participantDirs)
        participant = participantDirs(p).name;
        fprintf('Processing %s - %s ...\n', cond, participant);
        
        % Extract numeric ID for filename (e.g. P_01 -> 1)
        participantNum = str2double(erase(participant, "P_"));
        if isnan(participantNum)
            warning('Could not parse ID from %s (skipping)', participant);
            continue;
        end
        
        fullPath = fullfile(cond, participant, ...
            sprintf('Exp_Tracking_Cursor_%d.csv', participantNum));
        
        if ~isfile(fullPath)
            warning('File not found: %s (skipping)', fullPath);
            continue;
        end
        
        data = readtable(fullPath);
        trials = sort(unique(data.Trial));
        
        for trial = trials'
            trialData = sortrows(data(data.Trial == trial, :), 'Frame');
            xcursor = trialData.xPos;
            target  = trialData.xTarget;
            delay   = trialData.Delay;
            fs = trialData.FrameRate(1);
            n = numel(xcursor);
            lastStart = n - windowFrames + 1;
            
            if lastStart <= skipFrames
                continue;
            end
            
            % Low-pass filter
            [b, a] = butter(2, 10/(fs/2), 'low');
            xcursor = filtfilt(b, a, xcursor);
            target  = filtfilt(b, a, target);
            
            maxLagFrames = round((maxLagMs/1000) * fs);
            starts = (skipFrames + 1):updateFrames:lastStart;
            
            for w = 1:numel(starts)
                idx = starts(w):(starts(w) + windowFrames - 1);
                imposedFrames = delay(starts(w));
                imposedMs = imposedFrames * (1000/fs);
                
                % Previous delay values (1–4 updates back)
                prevStarts = starts(w) - updateFrames * (1:4);
                prevMs = nan(1, 4);
                for k = 1:4
                    if prevStarts(k) >= 1
                        prevMs(k) = delay(prevStarts(k)) * (1000/fs);
                    end
                end
                
                % Cross-correlation lag
                cursor_d = detrend(xcursor(idx));
                target_d = detrend(target(idx));
                [c, lags] = xcorr(target_d, cursor_d, maxLagFrames, 'coeff');
                [~, peak] = max(c);
                lagMs = lags(peak) * (1000/fs);
                
                newRow = table( ...
                    participant, cond, trial, w, imposedFrames, imposedMs, ...
                    prevMs(1), mean(prevMs(1:2), 'omitnan'), mean(prevMs, 'omitnan'), ...
                    lagMs, ...
                    'VariableNames', {'Participant','Condition','Trial','Window', ...
                    'ImposedDelay_frames','ImposedDelay_ms', ...
                    'Prev1_ms','Prev2Mean_ms','Prev4Mean_ms','LocalLag_ms'});
                windows = [windows; newRow]; %#ok<AGROW>
            end
        end
    end
end

%% Save window-level data
writetable(windows, 'Exp2_WindowedLag.csv');
fprintf('Saved Exp2_WindowedLag.csv (%d windows)\n', height(windows));

%% Participant-level slopes (skip constant-delay condition)
summary = table();
if ~isempty(windows)
    ids = unique(windows.Participant, 'stable');
    for i = 1:numel(ids)
        rows = windows(windows.Participant == ids(i), :);
        if rows.Condition(1) == "Cons"
            continue;   % delay does not vary, so the slope is not interpretable
        end
        
        x = rows.ImposedDelay_ms;
        y = rows.LocalLag_ms;
        keep = isfinite(x) & isfinite(y);
        recent = rows.Prev4Mean_ms;
        keepR = keep & isfinite(recent);
        
        bNow  = polyfit(x(keep), y(keep), 1);
        bMean = polyfit(recent(keepR), y(keepR), 1);
        
        summary = [summary; table( ...
            ids(i), rows.Condition(1), bNow(1), bMean(1), ...
            corr(x(keep), y(keep)), ...
            'VariableNames', {'Participant','Condition', ...
            'Slope_on_current_delay','Slope_on_recent_mean','r_current'})]; %#ok<AGROW>
    end
end

writetable(summary, 'Exp2_LagDelay_Slopes.csv');
disp(summary);