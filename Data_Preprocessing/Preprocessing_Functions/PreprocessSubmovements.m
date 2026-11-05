function s = PreprocessSubmovements(xPos, yPos)

vx = diff(xPos);
vy = diff(yPos);

vel = sqrt(vx.^2 + vy.^2);

[~, locs] = findpeaks(vel);

s = numel(locs);

end