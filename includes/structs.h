#ifndef STRUCTS_H
#define STRUCTS_H

typedef struct neighbor_t {
    uint16_t id;
    bool isActive;
    uint16_t lastHeard;
    float linkQuality;
} neighbor_t;

#endif
