function avgVel_m = PreprocessAverageVelocity(xPos, yPos, IFI)
% PreprocessAverageVelocity
%   Computes the average cursor velocity for a trial using the
%   central difference method. Converts to meters per second
%   using known pixel pitch (0.277 mm/px).
%
% Inputs:
%   xPos, yPos  - cursor position vectors (in pixels)
%   IFI         - inter-frame interval (ms per frame, e.g., 16.7)
%
% Output:
%   avgVel_m    - average velocity (meters per second)
%
%   If fewer than 2 samples are present, returns NaN.

    %% --- Handle single-sample or empty input ---
    if numel(xPos) < 2 || numel(yPos) < 2
        avgVel_m = NaN;
        return;
    end

    %% --- Constants ---
    px2m = 0.311 / 1000;   % convert 0.311 mm to meters
    dt = IFI / 1000;       % convert ms to seconds

    %% --- Compute velocity using Central Difference Method ---
    vx = zeros(size(xPos));
    vy = zeros(size(yPos));

    % Central difference for interior points
    vx(2:end-1) = (xPos(3:end) - xPos(1:end-2)) / (2 * dt);
    vy(2:end-1) = (yPos(3:end) - yPos(1:end-2)) / (2 * dt);

    % Forward and backward difference for first/last frames
    vx(1)   = (xPos(2) - xPos(1)) / dt;
    vy(1)   = (yPos(2) - yPos(1)) / dt;
    vx(end) = (xPos(end) - xPos(end-1)) / dt;
    vy(end) = (yPos(end) - yPos(end-1)) / dt;

    %% --- Compute velocity magnitude and average ---
    vMag = sqrt(vx.^2 + vy.^2);   % instantaneous velocity (px/s)
    avgVel_px = mean(vMag, 'omitnan'); % average velocity in px/s
    avgVel_m  = avgVel_px * px2m;      % convert to m/s

end
