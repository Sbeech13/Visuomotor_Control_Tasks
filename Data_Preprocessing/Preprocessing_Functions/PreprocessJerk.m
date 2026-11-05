function j = PreprocessJerk(xPos, yPos)

vx = diff(xPos);
vy = diff(yPos);

vel = sqrt(vx.^2 + vy.^2);

acc = diff(vel);
jerk = diff(acc);

j = mean(abs(jerk), 'omitnan');

end