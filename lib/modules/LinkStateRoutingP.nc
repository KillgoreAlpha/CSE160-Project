#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/constants.h"
#include "../../includes/structs.h"

module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface SimpleSend as Sender;
    uses interface Matrix<uint16_t, uint16_t> as PacketsReceived;
    uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface Timer<TMilli> as LSRTimer;
    uses interface Random;
}

implementation {
    typedef struct {
        uint8_t nextHop;
        float cost;
    } Route;

typedef struct {
    uint8_t neighbor;
    float cost;
    float quality;
} LinkStatePacket;

    float linkState[LINK_STATE_MAX_ROUTES][LINK_STATE_MAX_ROUTES];
    Route routingTable[LINK_STATE_MAX_ROUTES];
    LinkStatePacket linkStatePayload[10];
    LinkStatePacket incomingLinkState[10];
    uint16_t numKnownNodes = 0;
    uint16_t numRoutes = 0;
    uint16_t sequenceNum = 0;
    pack routePack;
    bool hasTopologyChanges = FALSE;
    uint16_t lastSentLinkStateSeq = 0;
    bool pendingUpdate = FALSE;

    void initializeRoutingTable();
    bool updateState(uint16_t incomingSrc);
    bool updateRoute(uint8_t dest, uint8_t nextHop, float cost);
    void addRoute(uint8_t dest, uint8_t nextHop, float cost);
    void removeRoute(uint8_t dest);
    void sendLinkStatePacket(uint8_t lostNeighbor);
    void handleForward(pack* myMsg);
    void dijkstra();
    float validateCost(float cost);

    command error_t LinkStateRouting.start() {
        dbg(ROUTING_CHANNEL, "Link State Routing Started on node %u!\n", TOS_NODE_ID);
        initializeRoutingTable();
        // Initial delay before starting periodic updates
        call LSRTimer.startOneShot(30000);
        lastSentLinkStateSeq = 0;
        return SUCCESS;
    }

    event void LSRTimer.fired() {
        if (call LSRTimer.isOneShot()) {
            // Convert to periodic timer with random offset to avoid synchronization
            uint32_t period = 60000 + (uint16_t)(call Random.rand16() % 5000);
            call LSRTimer.startPeriodic(period);
            // Force initial update
            pendingUpdate = TRUE;
        }
        
        if (pendingUpdate) {
            sendLinkStatePacket(0);
        }
    }

    command void LinkStateRouting.ping(uint16_t destination, uint8_t* payload) {
        makePack(&routePack, TOS_NODE_ID, destination, 0, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
        dbg(ROUTING_CHANNEL, "PING FROM %d TO %d\n", TOS_NODE_ID, destination);
        logPack(&routePack);
        call LinkStateRouting.routePacket(&routePack);
    }

    command void LinkStateRouting.routePacket(pack* myMsg) {
        uint8_t nextHop;
        if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_PING) {
            dbg(ROUTING_CHANNEL, "PING Packet has reached destination %d!!!\n", TOS_NODE_ID);
            makePack(&routePack, myMsg->dest, myMsg->src, 0, PROTOCOL_PINGREPLY, 0, (uint8_t*)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            call LinkStateRouting.routePacket(&routePack);
            return;
        } else if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_PINGREPLY) {
            dbg(ROUTING_CHANNEL, "PING_REPLY Packet has reached destination %d!!!\n", TOS_NODE_ID);
            return;
        }

        if (routingTable[myMsg->dest].cost < LINK_STATE_MAX_COST) {
            nextHop = routingTable[myMsg->dest].nextHop;
            dbg(ROUTING_CHANNEL, "Node %d routing packet through %d\n", TOS_NODE_ID, nextHop);
            logPack(myMsg);
            call Sender.send(*myMsg, nextHop);
        } else {
            dbg(ROUTING_CHANNEL, "No route to destination. Dropping packet...\n");
            logPack(myMsg);
        }
    }

    command void LinkStateRouting.handleLinkState(pack* myMsg) {
        uint16_t incomingSrc = myMsg->src;
        uint16_t incomingSeq = myMsg->seq;
        
        memcpy(incomingLinkState, myMsg->payload, sizeof(LinkStatePacket) * 10);
        
        // Only process if we haven't seen this update before
        if (incomingSrc == TOS_NODE_ID || call PacketsReceived.containsVal(incomingSrc, incomingSeq)) {
            return;
        }
        
        // Record that we've processed this packet
        call PacketsReceived.insertVal(incomingSrc, incomingSeq);
        
        // Update our link state if the packet contains new information
        if (updateState(incomingSrc)) {
            dijkstra();  // Recalculate routes if state changed
        }
    }

    command void LinkStateRouting.handleNeighborLost(uint16_t lostNeighbor) {
        if (linkState[TOS_NODE_ID][lostNeighbor] != LINK_STATE_MAX_COST) {
            linkState[TOS_NODE_ID][lostNeighbor] = LINK_STATE_MAX_COST;
            linkState[lostNeighbor][TOS_NODE_ID] = LINK_STATE_MAX_COST;
            pendingUpdate = TRUE;
            
            dbg(ROUTING_CHANNEL, "Node %d: Neighbor lost %d\n", TOS_NODE_ID, lostNeighbor);
            
            // Recalculate routes immediately
            dijkstra();
        }
    }

    command void LinkStateRouting.handleNeighborFound(uint16_t neighbor, float quality) {
        float oldCost = linkState[TOS_NODE_ID][neighbor];
        float newCost;
        
        // Ensure quality is valid
        if (quality <= 0.0f || quality > 1.0f) {
            newCost = LINK_STATE_MAX_COST;
        } else {
            // Calculate cost as inverse of quality (higher quality = lower cost)
            // Add 1.0 as base cost to ensure no zero costs
            newCost = 1.0f + ((1.0f - quality) * 2.0f); // Scale factor of 2 to make quality differences more significant
        }
        
        newCost = validateCost(newCost);
        
        if (fabs(newCost - oldCost) > QUALITY_CHANGE_THRESHOLD) {
            linkState[TOS_NODE_ID][neighbor] = newCost;
            linkState[neighbor][TOS_NODE_ID] = newCost;
            pendingUpdate = TRUE;
            
            dbg(ROUTING_CHANNEL, "Node %d: Significant link change to %d (cost: %.2f, quality: %.2f)\n",
                TOS_NODE_ID, neighbor, newCost, quality);
            
            // Recalculate routes immediately
            dijkstra();
        }
    }


    command void LinkStateRouting.printLinkState() {
        uint16_t i, j;
        dbg(ROUTING_CHANNEL, "Link State for Node %d:\n", TOS_NODE_ID);
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            for (j = 0; j < LINK_STATE_MAX_ROUTES; j++) {
                if (linkState[i][j] != (float)LINK_STATE_MAX_COST) {
                    dbg(ROUTING_CHANNEL, "  %d -> %d: Cost %.2f\n", i, j, linkState[i][j]);
                }
            }
        }
    }

    float validateCost(float cost) {
        if (cost <= 0.0f || isnan(cost)) {
            return LINK_STATE_MAX_COST;
        }
        // Allow costs between 1.0 and LINK_STATE_MAX_COST (inclusive)
        if (cost > LINK_STATE_MAX_COST) {
            return LINK_STATE_MAX_COST;
        }
        return cost;
    }

void dijkstra() {
    uint16_t i, j;
    float dist[LINK_STATE_MAX_ROUTES];
    uint8_t prev[LINK_STATE_MAX_ROUTES];
    bool visited[LINK_STATE_MAX_ROUTES] = {FALSE};
    uint8_t current;
    
    // Initialize distances
    for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
        dist[i] = (float)LINK_STATE_MAX_COST;
        prev[i] = 0;
    }
    
    dist[TOS_NODE_ID] = 0;
    
    for (i = 0; i < MAX_NODES; i++) {  // Only process valid nodes
        float minDist = (float)LINK_STATE_MAX_COST;
        current = 0;
        
        // Find unvisited node with minimum distance
        for (j = 1; j < MAX_NODES; j++) {  // Only check valid nodes
            if (!visited[j] && dist[j] < minDist) {
                minDist = dist[j];
                current = j;
            }
        }
        
        if (current == 0) break;
        
        visited[current] = TRUE;
        
        // Update distances through current node
        for (j = 1; j < MAX_NODES; j++) {  // Only process valid nodes
            if (!visited[j] && linkState[current][j] != (float)LINK_STATE_MAX_COST) {
                float newDist = dist[current] + linkState[current][j];
                if (newDist < dist[j]) {
                    dist[j] = newDist;
                    prev[j] = current;
                    dbg(ROUTING_CHANNEL, "Node %d: Updated distance to %d through %d = %.2f\n",
                        TOS_NODE_ID, j, current, newDist);
                }
            }
        }
    }
    
    // Update routing table
    numRoutes = 0;
    for (i = 1; i < MAX_NODES; i++) {  // Only process valid nodes
        if (i == TOS_NODE_ID) continue;
        
        if (dist[i] != (float)LINK_STATE_MAX_COST) {
            uint8_t nextHop = i;
            uint8_t prevNode = prev[i];
            
            // Trace back to find first hop
            while (prevNode != TOS_NODE_ID && prevNode != 0) {
                nextHop = prevNode;
                prevNode = prev[prevNode];
            }
            
            if (prevNode == TOS_NODE_ID) {  // Only add valid paths
                routingTable[i].nextHop = nextHop;
                routingTable[i].cost = dist[i];
                numRoutes++;
                dbg(ROUTING_CHANNEL, "Node %d: Added route to %d via %d with cost %.2f\n",
                    TOS_NODE_ID, i, nextHop, dist[i]);
            }
        } else {
            routingTable[i].nextHop = 0;
            routingTable[i].cost = (float)LINK_STATE_MAX_COST;
        }
    }
}

   // Modified printRouteTable to show complete paths
    command void LinkStateRouting.printRouteTable() {
        uint16_t i, j;
        uint8_t current, next, pathLength;
        uint8_t path[MAX_NODES];
        float dist[LINK_STATE_MAX_ROUTES];
        float totalCost, minCost;
        char pathString[128];  // Increased buffer size for longer paths
        
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Routing Table for Node %d\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Destination | Next Hop | Cost | Full Path\n");
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
        
        for (i = 1; i < MAX_NODES; i++) {
            if (routingTable[i].cost != (float)LINK_STATE_MAX_COST) {
                // Build complete path by following link state table
                current = i;
                pathLength = 0;
                totalCost = 0;
                
                // Start from destination and work backwards
                while (current != TOS_NODE_ID && pathLength < MAX_NODES) {
                    path[pathLength++] = current;
                    // Find next hop towards source using link state table
                    next = 0;
                    minCost = LINK_STATE_MAX_COST;
                    for (j = 1; j < MAX_NODES; j++) {
                        if (linkState[current][j] != LINK_STATE_MAX_COST && 
                            dist[j] < minCost) {
                            minCost = dist[j];
                            next = j;
                        }
                    }
                    if (next == 0) break;
                    totalCost += linkState[current][next];
                    current = next;
                }
                
                // Build path string
                sprintf(pathString, "%d", TOS_NODE_ID);
                for (current = pathLength - 1; current != (uint8_t)-1; current--) {
                    sprintf(pathString + strlen(pathString), " -> %d", path[current]);
                }
                
                dbg(ROUTING_CHANNEL, "%10d | %8d | %.2f | %s\n", 
                    i, routingTable[i].nextHop, routingTable[i].cost, pathString);
            }
        }
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
    }

    void initializeRoutingTable() {
        uint16_t i, j;
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            routingTable[i].nextHop = 0;
            routingTable[i].cost = (float)LINK_STATE_MAX_COST;
            for (j = 0; j < LINK_STATE_MAX_ROUTES; j++) {
                linkState[i][j] = (float)LINK_STATE_MAX_COST;
            }
        }
        routingTable[TOS_NODE_ID].nextHop = TOS_NODE_ID;
        routingTable[TOS_NODE_ID].cost = 0.0;
        linkState[TOS_NODE_ID][TOS_NODE_ID] = 0.0;
        numKnownNodes = 1;
        numRoutes = 1;
    }


    bool updateState(uint16_t incomingSrc) {
        uint16_t i;
        int8_t neighbor;
        float newCost, quality;
        bool isStateUpdated = FALSE;
        
        if (incomingSrc >= 64) return FALSE;
        
        for (i = 0; i < 10; i++) {
            neighbor = incomingLinkState[i].neighbor;
            quality = incomingLinkState[i].quality;
            
            // Skip invalid entries
            if (neighbor == 0 || neighbor >= 64) continue;
            
            // Calculate cost - use LINK_STATE_MAX_COST for invalid qualities

            if (quality <= 0.0f || quality > 1.0f) {
                newCost = LINK_STATE_MAX_COST;
            } else {
                newCost = 1.0f + (1.0f - quality);
            }
            
            if (linkState[incomingSrc][neighbor] != newCost) {
                linkState[incomingSrc][neighbor] = newCost;
                linkState[neighbor][incomingSrc] = newCost;
                isStateUpdated = TRUE;
                
                dbg(ROUTING_CHANNEL, "Link state updated: %d<->%d = %.2f (quality: %.2f)\n", 
                    incomingSrc, neighbor, newCost, quality);
            }
        }
        
        if (isStateUpdated) {
            dbg(ROUTING_CHANNEL, "Recalculating routes due to link state update from %d\n", incomingSrc);
            dijkstra();
        }
        
        return isStateUpdated;
    }


    void sendLinkStatePacket(uint8_t lostNeighbor) {
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
        uint16_t i = 0;
        uint16_t counter = 0;
        LinkStatePacket linkStatePayload[10];

        // Only send if we have pending updates
        if (!pendingUpdate) {
            return;
        }

        // Clear pending update flag
        pendingUpdate = FALSE;

        // Initialize payload array
        for (i = 0; i < 10; i++) {
            linkStatePayload[i].neighbor = 0;
            linkStatePayload[i].cost = LINK_STATE_MAX_COST;
        }

        // Add current neighbors to payload
        for (i = 0; i < neighborsListSize && counter < 10; i++) {
            if (neighbors[i] >= MAX_NODES) continue;
            
            linkStatePayload[counter].neighbor = neighbors[i];
            linkStatePayload[counter].cost = linkState[TOS_NODE_ID][neighbors[i]];
            counter++;
        }

        if (counter > 0 || lostNeighbor != 0) {
            // Only increment sequence number when actually sending
            lastSentLinkStateSeq++;
            dbg(ROUTING_CHANNEL, "Node %d: Sending link state update seq %d\n", 
                TOS_NODE_ID, lastSentLinkStateSeq);
            call Flooding.floodLinkState((uint8_t*)&linkStatePayload);
        }
    }

    void addRoute(uint8_t dest, uint8_t nextHop, float cost) {
        if (routingTable[dest].cost == (float)LINK_STATE_MAX_COST || 
            cost < routingTable[dest].cost ||
            (cost == routingTable[dest].cost && nextHop != routingTable[dest].nextHop)) {
            
            routingTable[dest].nextHop = nextHop;
            routingTable[dest].cost = cost;
            
            if (routingTable[dest].cost == (float)LINK_STATE_MAX_COST) {
                numRoutes++;
            }
            
            dbg(ROUTING_CHANNEL, "Updated route to node %hhu: nextHop=%hhu, cost=%.2f\n", 
                dest, nextHop, cost);
        }
    }

    void removeRoute(uint8_t dest) {
        if (routingTable[dest].cost != (float)LINK_STATE_MAX_COST) {
            routingTable[dest].nextHop = 0;
            routingTable[dest].cost = (float)LINK_STATE_MAX_COST;
            numRoutes = (numRoutes > 0) ? numRoutes - 1 : 0; // Ensure it doesn't go negative
        }
    }
}
