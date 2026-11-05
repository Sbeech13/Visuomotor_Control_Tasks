function v = PreprocessVelocityVariability(xPos, yPos)

vx = diff(xPos);
vy = diff(yPos);

vel = sqrt(vx.^2 + vy.^2);

v = std(vel, 'omitnan');

end