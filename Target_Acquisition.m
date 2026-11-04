%% Setup
sca;
clc;
close all;
clear all;
PsychDefaultSetup(2);
rng('shuffle');

% Find external keyboard
devs = PsychHID('Devices');
target = 'Dell KB216 Wired Keyboard';
productMatch = strcmp({devs.product}, target);
usageMatch = contains(lower({devs.usageName}), 'keyboard');
KeyboardNum = find(productMatch & usageMatch);

% Screen setup
screens = Screen('Screens');
screenNumber = max(screens);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white / 2;
red = [1 0 0];
rect = [];

Screen('Preference', 'SkipSyncTests', 1);
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black, rect);

[screenXpixels, screenYpixels] = Screen('WindowSize', window);
[xCenter, yCenter] = RectCenter(windowRect);
ifi = Screen('GetFlipInterval', window);
hertz = FrameRate(window);
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%% Experiment variables
numBlocks = 32;
numTrials = 15;

baseDelay = 10;                % Mean delay (same baseline)
delayAmplitude = 6;            % For uniform range (+/-)
delayUpdateFrequency = 24;     % How often delay updates (in frames)
maxDelay = baseDelay + delayAmplitude;
minDelay = baseDelay - delayAmplitude;
startingDelay = baseDelay;

%% Set Key variables
variabilityMode = 1; % 1 = Uniform, 2 = Random Walk
pNumber = 41;

if variabilityMode == 1
    condition = 'UNIF';
elseif variabilityMode == 2
    condition = 'RANW';
end

%% Data storage variables
totalNumTrials = 0;

trialResults = table([], [], ...
    'VariableNames', {'TrialNumber', 'CompletionTime'});

blockResults = table([], [], [], ...
    'VariableNames', {'BlockNumber', 'CompletionTime (Seconds)', 'Accuracy (%)'});

allCursorData = {'TrialNumber', 'Block', 'Frame', 'Delay', ...
                 'xDelay', 'yDelay', 'xPos', 'yPos', 'xTarget', 'yTarget'};

%% Target grid setup
GridSpacing = 80;
GridCount   = 13;
TargetDiameter = 60;

LocationArray(1:2, 2:GridCount*GridCount) = zeros;

for i = 1:GridCount
    for j = 1:GridCount
        LocationArray(1, (i*GridCount-1)+j) = ...
            (xCenter-GridSpacing*((GridCount-1)/2))+(i*GridSpacing);
        LocationArray(2, (i*GridCount-1)+j) = ...
            (yCenter-GridSpacing*((GridCount-1)/2))+(j*GridSpacing);
    end
end

CenteredLocationArray = LocationArray - 110;
SquareArrayCoords = [CenteredLocationArray; CenteredLocationArray + TargetDiameter];
SquareArrayNoZero = SquareArrayCoords(:,13:181);

%% Welcome screen
Screen('TextSize', window, 50);
Screen('TextFont', window, 'Arial');
Screen('TextStyle', window, 0);

DrawFormattedText(window, ...
    ['Hello and welcome to this experiment.\n\n' ...
     'Please click the mouse and then press the spacebar to continue.'], ...
    'Center', 'Center', white);

Screen('FrameRect', window, red, windowRect, 5);
Screen('Flip', window);
KbPressWait(KeyboardNum);

%% Instruction screen
Screen('TextSize', window, 35);

DrawFormattedText(window, ...
    ['Your task is to click on the red targets as quickly as you can.\n\n' ...
     'Try to hit the targets in as few clicks as possible.\n\n' ...
     'Once you hit a target, a new one will appear.\n\n' ...
     'Press the spacebar to continue.'], ...
    'Center', 'Center', white);

Screen('FrameRect', window, red, windowRect, 5);
Screen('Flip', window);
KbPressWait(KeyboardNum);

%% Block Loop
for block = 1:numBlocks

    totalClicks = 0;
    blockFrames = 0;
    blockTime = [];
    WelcomeScreenClicks = 0;

    vbl = Screen('Flip', window);
    ShowCursor;

    [~, ~, buttons] = GetMouse(window);
    while any(buttons)
        [~, ~, buttons] = GetMouse(window);
    end

    %% Pre-trial screen
    while WelcomeScreenClicks == 0
        ShowCursor;

        Screen('TextSize', window, 50);
        DrawFormattedText(window, 'Click HERE to start', 'center', 'center', red);
        Screen('FrameRect', window, red, windowRect, 5);
        vbl = Screen('Flip', window);

        [~, ~, buttons] = GetMouse(window);
        if any(buttons)
            while any(buttons)
                [~, ~, buttons] = GetMouse(window);
            end
            WelcomeScreenClicks = 1;
            [x, y] = GetMouse(window);
            mouseBuffer = repmat([x, y], maxDelay, 1);
            bufferIndex = 1;
        end
    end

    currentDelay = startingDelay;
    bufferIsPrimed = false;
    WaitSecs(0.267);

    %% Trial loop
    for trialNum = 1:numTrials

        RanSquare = randi(size(SquareArrayNoZero, 2));
        Column = SquareArrayNoZero(:, RanSquare);
        RanJitter = randi(25);
        JitteredCircle = Column + RanJitter;

        xTarget = mean(JitteredCircle([1 3]));
        yTarget = mean(JitteredCircle([2 4]));

        inside = 0;
        tStart = GetSecs;
        TargetHit = 0;
        trialFrames = 0;

        totalNumTrials = totalNumTrials + 1;

        while TargetHit == 0

            HideCursor;

            blockFrames = blockFrames + 1;
            trialFrames = trialFrames + 1;

            [x, y] = GetMouse(window);

            if mod(blockFrames, delayUpdateFrequency) == 0
                if variabilityMode == 1
                    currentDelay = baseDelay + randi([-delayAmplitude, delayAmplitude]);
                elseif variabilityMode == 2
                    step = randi([-1, 1]);
                    currentDelay = currentDelay + step;

                    if currentDelay > maxDelay
                        currentDelay = maxDelay - (currentDelay - maxDelay);
                    elseif currentDelay < minDelay
                        currentDelay = minDelay + (minDelay - currentDelay);
                    end
                end
            end

            if ~bufferIsPrimed && blockFrames <= currentDelay
                delayedPos = mouseBuffer(1, :);
            else
                roundedDelay = round(currentDelay);
                delayedIndex = mod(bufferIndex - roundedDelay - 1, maxDelay) + 1;
                delayedPos = mouseBuffer(delayedIndex, :);
            end

            if ~bufferIsPrimed && blockFrames > currentDelay
                bufferIsPrimed = true;
            end

            allCursorData(end+1, :) = {totalNumTrials, block, trialFrames, ...
                currentDelay, round(delayedPos(1)), round(delayedPos(2)), ...
                round(x), round(y), xTarget, yTarget};

            mouseBuffer(bufferIndex, :) = [x, y];
            bufferIndex = mod(bufferIndex, maxDelay) + 1;

            Screen('FillOval', window, red, JitteredCircle);
            Screen('DrawDots', window, delayedPos, 25, white, [], 1);
            Screen('FrameRect', window, red, windowRect, 5);

            vbl = Screen('Flip', window, vbl + 0.5 * ifi);

            [ClickX, ClickY, full_buttons] = GetMouse(window);
            buttons = full_buttons(1:3);
            inside = IsInRect(ClickX, ClickY, JitteredCircle);

            if buttons == [1 0 0]
                totalClicks = totalClicks + 1;
                if inside
                    TargetHit = 1;
                end
                WaitSecs(0.267);
            end
        end

        TTH = GetSecs - tStart;
        blockTime = [blockTime; TTH];
        trialResults = [trialResults; {totalNumTrials, TTH}];

        startingDelay = currentDelay;
    end

    Accuracy = (numTrials / totalClicks) * 100;
    blockResults = [blockResults; {block, sum(blockTime), Accuracy}];

    Screen('TextSize', window, 50);
    DrawFormattedText(window, 'Score Overview:', 50, 250, red);
    DrawFormattedText(window, ...
        ['Clicking Accuracy: ' num2str(Accuracy) '%'], 50, 450, red);
    DrawFormattedText(window, ...
        ['Time-To-Hit all 15 Targets: ' num2str(sum(blockTime)) ' Seconds'], ...
        50, 650, red);
    DrawFormattedText(window, 'Press the spacebar', 50, 850, white);

    Screen('Flip', window);
    KbPressWait(KeyboardNum);
end

%% Closing screen & Data save
blockFilename  = ['DAN_Data/NoiseExp_Block_' num2str(pNumber) '_' condition '.csv'];
cursorFilename = ['DAN_Data/NoiseExp_Cursor_' num2str(pNumber) '_' condition '.csv'];

writetable(blockResults, blockFilename);
writecell(allCursorData, cursorFilename);

Screen('TextSize', window, 35);
DrawFormattedText(window, ...
    'You have completed this phase, please wait for the experimenter.', ...
    'Center', 'Center', white);

Screen('FrameRect', window, red, windowRect, 5);
Screen('Flip', window);
KbPressWait(KeyboardNum);

sca;
       