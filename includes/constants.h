#ifndef CONSTANTS_H
#define CONSTANTS_H

// Time Constant
#define TICKS 1024

// Topology and Network Constants
#define MAX_NODES 64
#define MAX_NEIGHBORS 20
#define NEIGHBOR_QUALITY_THRESHOLD 0.1
#define INACTIVE_THRESHOLD 3
#define MTU 1500
#define MAX_TTL 32

// Link State Constants
#define LINK_STATE_MAX_ROUTES 256
#define LINK_STATE_MAX_COST 256
#define MIN_VALID_COST 1.0
#define MAX_VALID_COST 3.0
#define LINK_STATE_TTL 16
#define QUALITY_CHANGE_THRESHOLD 0.1

#define PROTOCOL_LINKSTATE 2
#define MAX_TTL 20
#define QUALITY_THRESHOLD 0.1

#endif /* CONSTANTS_H */

