function overshootFlag = PreprocessOvershoot(b, t, xPos, yPos, xTarget, yTarget, targetRadius)
% PreprocessOvershoot
%   Detects overshoot and visualizes the cursor trajectory with geometry lines
%   in a fixed 1920x1080 HD coordinate system.
%
% Overshoot = cursor passes beyond the perpendicular plane through the target
%             (in direction of motion) AND is outside the target radius.
%
% Inputs:
%   b, t             - block and trial numbers (for labeling)
%   xPos, yPos       - cursor position vectors
%   xTarget, yTarget - scalar target coordinates
%   targetRadius     - radius of target (e.g., 30 px)
%
% Output:
%   overshootFlag    - 1 if overshoot occurred, else 0

%% --- Compute geometry ---
xStart = xPos(1);
yStart = yPos(1);

% Start→Target vector
v_st = [xTarget - xStart, yTarget - yStart];
v_st = v_st / norm(v_st);

% Cursor vectors (Target→Cursor)
dx = xPos - xTarget;
dy = yPos - yTarget;
v_tc = [dx(:), dy(:)];

% Dot product: >0 = beyond target
dotVals = v_tc * v_st';
distToTarget = sqrt(sum(v_tc.^2, 2));

beyondTarget  = dotVals > 0;
outsideRadius = distToTarget > targetRadius;
overshootPts  = beyondTarget & outsideRadius;
overshootFlag = any(overshootPts);

%% --- Visualization ---
show = 0;
if show == 1
    fig = figure('Color','w', ...
        'Position',[100, 100, 1920, 1080]);  % fixed HD window
    hold on; axis equal; grid on;

    % Maintain same coordinate space as display
    xlim([0 1920]);
    ylim([0 1080]);
    set(gca, 'YDir', 'reverse'); % match screen coordinate system (origin top-left)

    % Title now includes block/trial info
    title(sprintf('Block %d — Trial %d  |  Overshoot Visualization (1920×1080)', b, t), ...
        'FontWeight', 'bold', 'FontSize', 14);

    xlabel('X Position (px)');
    ylabel('Y Position (px)');

    % Plot target and geometry
    viscircles([xTarget, yTarget], targetRadius, 'Color',[1 0 0],'LineStyle','--');
    plot(xTarget, yTarget, 'rx', 'MarkerSize', 12, 'LineWidth', 2);
    plot(xStart, yStart, 'kx', 'MarkerSize', 12, 'LineWidth', 2);
    plot([xStart xTarget], [yStart yTarget], 'k-', 'LineWidth', 2);

    % Movement direction arrow
    quiver(xStart, yStart, v_st(1)*100, v_st(2)*100, 0, 'k--', 'LineWidth', 1.5);

    % Perpendicular 90° line at target
    perpVec = [-v_st(2), v_st(1)];
    tt = linspace(-300,300,2);
    plot(xTarget + perpVec(1)*tt, yTarget + perpVec(2)*tt, 'r--', 'LineWidth', 1.5);

    % Trajectory (green normal, red overshoot)
    scatter(xPos(~overshootPts), yPos(~overshootPts), 25, 'g', 'filled');
    scatter(xPos(overshootPts),  yPos(overshootPts),  25, 'r', 'filled');
    plot(xPos, yPos, 'k-', 'LineWidth', 1);

    legend({'Target radius','Target','Start','Start→Target',...
        'Direction arrow','Perpendicular (90°)','Normal points','Overshoot points'}, ...
        'Location','bestoutside');

    text(xTarget+15, yTarget-15, sprintf('Overshoot = %d', overshootFlag), ...
        'FontWeight','bold','Color','k','FontSize',11);

    %% --- Wait for click or keypress ---
    try
        waitforbuttonpress;   % Wait for user interaction
    catch
        % Safe exit if figure closed manually
    end

    if isvalid(fig)
        close(fig);
    end
end
end
