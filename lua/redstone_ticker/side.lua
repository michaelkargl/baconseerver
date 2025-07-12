local Side = {
    Front = 'front',
    Back = 'back',
    Left = 'left',
    Right = 'right',
    Up = 'up',
    Down = 'down'
};

function Side.getKeys()
    return {'Front','Back','Left','Right','Up','Down' };
end

return Side;
