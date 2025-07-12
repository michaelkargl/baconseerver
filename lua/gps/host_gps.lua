package.path = package.path..';/disk/?.lua';

local config = require('gps_cluster_config');
local gpsInit = require('gps_init');

local nodeConfig = config.nodes.center;
gpsInit.host(
    nodeConfig.name,
    nodeConfig.x,
    nodeConfig.y,
    nodeConfig.z
);
