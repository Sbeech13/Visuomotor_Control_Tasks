%% Tracking Task


sca; clc; close all; clear;
PsychDefaultSetup(2);
rng('shuffle');
addpath('Psychtoolbox')

%% Screen Setup

screens = Screen('Screens');
screenNumber = max(screens);
Screen('Preference','SkipSyncTests',1);

white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
red   = [1 0 0];
blue  = [0 0 1];
green = [0 1 0];

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);
[screenXpixels, screenYpixels] = Screen('WindowSize', window);
[xCenter, yCenter] = RectCenter(windowRect);
ifi = Screen('GetFlipInterval', window);
frameRate = FrameRate(window);
Priority(MaxPriority(window));
Screen('BlendFunction', window,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');

%% Key Parameters

% Delay parameters
meanDelay = 10;
delayAmplitude = 6;
delayFrequency = 24;
maxDelay = meanDelay + delayAmplitude;
minDelay = meanDelay - delayAmplitude;
startingDelay = meanDelay;

% Task parameters
numTrials = 32; % 32  
targetSize = 50;
cursorSize = 25;
countdownTime = 2;
trialTime = 30;
VisiblePathDuration = 2.5;
totalDuration = countdownTime + trialTime;
totalFrames = round(totalDuration * frameRate);
stationaryFrames = round(countdownTime * frameRate);
movingFrames = totalFrames - stationaryFrames;

% Path parameters
visiblePathFrames = round(frameRate * (VisiblePathDuration/2));
frequencies = [0.09 0.165 0.195 0.375 0.495];
amplitudes  = [90 95 100 105 110];
numComponents = 5;

%% Participant Variables

pNumber = 4;
variabilityMode = 2; % 0 = No Delay, 1 = Constant, 2 = Uniform, 3 = Random Walk

if variabilityMode == 0
    condition = 'Control';
    startingDelay = 0;
elseif variabilityMode == 1
    condition = 'Const';
elseif variabilityMode == 2
    condition = 'Unif';
elseif variabilityMode == 3
    condition = 'RanW';
else
    error('Invalid Variability Mode')
end

%% Data Storage
cursorData = {'Participant','Condition','Trial','Frame','Delay','xReal','xPos','xTarget','InTarget','FrameRate','PathSpacing'};

%% Instruction screen
Screen('TextSize', window, 35);
DrawFormattedText(window, ['Your task is to follow the blue target as closely as you can.\n\n' ...
    'You simply control the sideways movement, so watch the upcoming red path.\n\n' ...
    'Your cursor will turn green when on the target, so try to maintain this position.\n\n'...
    'Press the spacebar to continue.'], 'Center', 'Center', white);
Screen('FrameRect', window, red, windowRect, 5);
Screen('Flip', window);
KbWait;
KbReleaseWait;

%% Instruction screen
Screen('TextSize', window, 35);
DrawFormattedText(window, ['There will be a two second countdown to the start of the trial.\n\n' ...
    'You will always start over the target, so do not move the cursor in this time.\n\n' ...
    'Press the spacebar to start the task.'], 'Center', 'Center', white);
Screen('FrameRect', window, red, windowRect, 5);
Screen('Flip', window);
KbWait;
KbReleaseWait;


%% Trial Loop
for trial = 1:numTrials

    HideCursor;

    %% Random vertical scaling
    minSpacing = targetSize * 0.05;
    maxSpacing = targetSize * 0.135;
    pathSpacing = minSpacing + rand * (maxSpacing - minSpacing);

    %% Initialize delay buffer
    currentDelay = startingDelay;
    bufferIsPrimed = false;

    %% Generate Path
    shuffledFreqs = frequencies(randperm(numComponents));
    bootAmps = amplitudes(randi(numComponents,[1 numComponents]));
    phases = 2*pi*rand(1,numComponents);
    movingPathX = zeros(1,movingFrames);

    for f = 1:numComponents
        movingPathX = movingPathX + ...
            bootAmps(f) * sin(2*pi*shuffledFreqs(f)*((1:movingFrames)/frameRate) + phases(f));
    end

    stationaryPathX = ones(1,stationaryFrames) * (movingPathX(1) + xCenter);
    pathX = [stationaryPathX, movingPathX + xCenter];

    %% Initialize Mouse
    SetMouse(round(pathX(1)), round(yCenter), screenNumber);
    mouseBuffer = repmat([pathX(1) yCenter], maxDelay, 1);
    bufferIndex = 1;
    vbl = Screen('Flip', window);

    %% Data storage
    trialFrameData = cell(movingFrames,11);
    rowCounter = 0;

    %% Frame Loop
    for frame = 1:totalFrames

        [keyIsDown,~,keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('ESCAPE'))
            sca; return
        end

        % Get real mouse
        [x,y] = GetMouse(window);

%% Update delay
if mod(frame,delayFrequency)==0

    if variabilityMode == 0
        currentDelay = 0;

    elseif variabilityMode == 1
        currentDelay = meanDelay;

    elseif variabilityMode == 2
        currentDelay = meanDelay + randi([-delayAmplitude delayAmplitude]);

    elseif variabilityMode == 3
        step = randi([-1 1]);
        currentDelay = currentDelay + step;

        if currentDelay > maxDelay
            currentDelay = maxDelay - (currentDelay-maxDelay);
        elseif currentDelay < minDelay
            currentDelay = minDelay + (minDelay-currentDelay);
        end
    end
end

        %% Get delayed cursor
        if currentDelay == 0
            delayedPos = [x y];
        else
            if ~bufferIsPrimed && frame <= currentDelay
                delayedPos = mouseBuffer(1,:);
            else
                roundedDelay = round(currentDelay);
                delayedIndex = mod(bufferIndex-roundedDelay-1,maxDelay)+1;
                delayedPos = mouseBuffer(delayedIndex,:);
            end
        end

        if ~bufferIsPrimed && frame > currentDelay
            bufferIsPrimed = true;
        end

        cursorX = delayedPos(1);
        targetX = pathX(frame);

        %% Store real mouse in buffer
        mouseBuffer(bufferIndex,:) = [x y];
        bufferIndex = mod(bufferIndex,maxDelay)+1;

        %% Check if on target
        inTarget = abs(cursorX-targetX) <= targetSize/2;

        %% Store Data
        if frame > stationaryFrames

            movingFrame = frame - stationaryFrames;
            rowCounter = rowCounter + 1;

            trialFrameData(rowCounter,:) = ...
                {pNumber, condition, trial, movingFrame, currentDelay, round(x), round(cursorX), round(targetX), inTarget, frameRate, pathSpacing};

        end

        %% Drawing
        Screen('FillRect', window, black);
        Screen('FrameRect', window, red, windowRect, 10);

        for d = 1:visiblePathFrames
            idx = frame + d;
            if idx <= totalFrames
                Screen('DrawDots', window,[pathX(idx), yCenter - d*pathSpacing],targetSize,red,[],2);
            end
        end

        for d = 1:visiblePathFrames
            idx = frame - d;
            dotX = pathX(max(idx,1));
            Screen('DrawDots', window,[dotX, yCenter + d*pathSpacing],targetSize,red,[],2);
        end

        Screen('DrawDots', window,[targetX yCenter],targetSize,blue,[],2);

        if inTarget
            cursorColor = green;
        else
            cursorColor = white;
        end

        Screen('DrawDots', window,[cursorX yCenter],cursorSize,cursorColor,[],2);

        if frame <= stationaryFrames
            txt = sprintf('Start in: %.1f',(stationaryFrames-frame)/frameRate);
            Screen('TextSize',window,36);
            DrawFormattedText(window,txt,screenXpixels-500,500,white);
        end

        vbl = Screen('Flip', window, vbl + 0.5*ifi);

    end

    %% Append Trial Data
    cursorData = [cursorData; trialFrameData];
    startingDelay = currentDelay;

    %% Inter-trial screen
    if trial < numTrials

        ShowCursor;

        % Calculate score
        inTargetCol = cell2mat(trialFrameData(:,9));
        percentOnTarget = mean(inTargetCol)*100;

        % Show score
        Screen('TextSize',window,40);
        Screen('FrameRect',window,red,windowRect,10);
        percentText = sprintf('Percent Time On Target: %.1f%%',percentOnTarget);
        DrawFormattedText(window,percentText,'center',yCenter-80,green);
        DrawFormattedText(window,'Press Spacebar for next trial.','center','center',white);
        Screen('Flip',window);
        KbWait;

    end
end

%% Save Data

writeData = 1;
if writeData == 1
    cursorFilename = ['Exp_Tracking_Cursor_' num2str(pNumber) '.csv'];
    writecell(cursorData, cursorFilename);
end

%% End Screen
ShowCursor;
Screen('TextSize',window,40);
Screen('FrameRect',window,red,windowRect,10);
DrawFormattedText(window,'Experiment over - Press spacebar to exit.','center','center',white);
Screen('Flip',window);
KbWait;
sca;

%% Click here
   