function pe = PreprocessPathEfficiency(xPos, yPos)

dx = diff(xPos);
dy = diff(yPos);

pathLength = sum(sqrt(dx.^2 + dy.^2));
straightLine = sqrt((xPos(end)-xPos(1))^2 + (yPos(end)-yPos(1))^2);

if pathLength > 0
    pe = straightLine / pathLength;
else
    pe = NaN;
end

end