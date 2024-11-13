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
    float validateLinkQuality(float quality);
    void validateLinkState();
    void debugLinkState();


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
        float oldCost, newCost;
        
        if (neighbor >= MAX_NODES) return;
        
        oldCost = linkState[TOS_NODE_ID][neighbor];
        
        // Validate and bound quality
        quality = validateLinkQuality(quality);
        
        // Calculate cost (1.0 for perfect quality, 2.0 for worst valid quality)
        if (quality > 0.0) {
            newCost = 1.0 + (1.0 - quality);
        } else {
            newCost = LINK_STATE_MAX_COST;
        }
        
        if (fabs(newCost - oldCost) > QUALITY_CHANGE_THRESHOLD) {
            linkState[TOS_NODE_ID][neighbor] = newCost;
            linkState[neighbor][TOS_NODE_ID] = newCost;
            pendingUpdate = TRUE;
            
            dbg(ROUTING_CHANNEL, "Node %d: Link quality to %d changed: %.2f (cost: %.2f)\n",
                TOS_NODE_ID, neighbor, quality, newCost);
            
            dijkstra();
        }
    }


    command void LinkStateRouting.printLinkState() {
        uint16_t i, j;
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
        dbg(ROUTING_CHANNEL, "Link State for Node %d:\n", TOS_NODE_ID);
        
        
        for (i = 0; i < neighborsListSize; i++) {
            if (neighbors[i] < MAX_NODES) {
                float quality = call NeighborDiscovery.neighborQuality(neighbors[i]);
                float cost = quality > 0.0 ? 1.0 + (1.0 - quality) : LINK_STATE_MAX_COST;
                dbg(ROUTING_CHANNEL, "  %d <-> %d: Cost %.2f (Quality: %.2f)\n", 
                    TOS_NODE_ID, neighbors[i], cost, quality);
            }
        }
        
        // Then print known links between other nodes
        dbg(ROUTING_CHANNEL, "Known Remote Links:\n");
        for (i = 1; i < MAX_NODES; i++) {
            if (i == TOS_NODE_ID) continue;
            for (j = i + 1; j < MAX_NODES; j++) {
                if (linkState[i][j] != LINK_STATE_MAX_COST) {
                    dbg(ROUTING_CHANNEL, "  %d <-> %d: Cost %.2f\n", i, j, linkState[i][j]);
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

        float validateLinkQuality(float quality) {
            if (isnan(quality) || quality < 0.0) return 0.0;
            if (quality > 1.0) return 1.0;
            return quality;
        }

        void validateLinkState() {
    uint16_t i, j;
    float maxCost;
    bool stateChanged = FALSE;  // Flag to track if the link state table was modified

    for (i = 1; i < MAX_NODES; i++) {
        for (j = 1; j < MAX_NODES; j++) {
            // Ensure symmetry
            if (linkState[i][j] != linkState[j][i]) {
                dbg(ROUTING_CHANNEL, "Warning: Asymmetric link state detected %d<->%d: %.2f != %.2f\n",
                    i, j, linkState[i][j], linkState[j][i]);
                // Fix asymmetry by using the higher cost
                maxCost = (linkState[i][j] > linkState[j][i]) ? linkState[i][j] : linkState[j][i];
                linkState[i][j] = maxCost;
                linkState[j][i] = maxCost;
                stateChanged = TRUE;  // Set the flag to indicate a change in link state
            }
            
            // Ensure valid costs
            if (linkState[i][j] != LINK_STATE_MAX_COST && 
                (linkState[i][j] < MIN_VALID_COST || linkState[i][j] > MAX_VALID_COST)) {
                dbg(ROUTING_CHANNEL, "Warning: Invalid link cost detected %d<->%d: %.2f\n",
                    i, j, linkState[i][j]);
                linkState[i][j] = LINK_STATE_MAX_COST;
                linkState[j][i] = LINK_STATE_MAX_COST;
                stateChanged = TRUE;  // Set the flag to indicate a change in link state
            }
        }
    }

    // If the link state table was modified, recalculate the routing table
    if (stateChanged) {
        dijkstra();
    }
}

    bool isDirectNeighbor(uint16_t nodeId) {
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
        uint16_t i;
        
        for (i = 0; i < neighborsListSize; i++) {
            if (neighbors[i] == nodeId) return TRUE;
        }
        return FALSE;
    }

    float calculateLinkCost(float quality) {
        float validQuality;
        validQuality = validateLinkQuality(quality);
        if (validQuality == 0.0) return LINK_STATE_MAX_COST;
        return 1.0 + (1.0 - validQuality);
    }

    void debugLinkState() {
        uint16_t i, j;
        dbg(ROUTING_CHANNEL, "Current Link State for Node %d:\n", TOS_NODE_ID);
        for (i = 1; i < MAX_NODES; i++) {
            for (j = 1; j < MAX_NODES; j++) {
                if (linkState[i][j] != LINK_STATE_MAX_COST) {
                    dbg(ROUTING_CHANNEL, "  %d->%d: %.2f\n", i, j, linkState[i][j]);
                }
            }
        }
    }

    void dijkstra() {
        uint16_t i, j;
        uint8_t current;
        float minDist;
        float linkCost;
        float newDist;
        float dist[MAX_NODES];
        uint8_t prev[MAX_NODES];
        bool visited[MAX_NODES];
        uint8_t hopCount;
        uint8_t nextHop;
        
        // Initialize arrays
        for (i = 0; i < MAX_NODES; i++) {
            dist[i] = LINK_STATE_MAX_COST;
            prev[i] = 0;
            visited[i] = FALSE;
        }
        
        // Distance to self is 0
        dist[TOS_NODE_ID] = 0;
        prev[TOS_NODE_ID] = TOS_NODE_ID;
        
        debugLinkState();
        
        // Main Dijkstra loop
        for (i = 0; i < MAX_NODES; i++) {
            current = 0;
            minDist = LINK_STATE_MAX_COST;
            
            // Find unvisited node with minimum distance
            for (j = 1; j < MAX_NODES; j++) {
                if (!visited[j] && dist[j] < minDist) {
                    minDist = dist[j];
                    current = j;
                }
            }
            
            if (current == 0) break;  // No more reachable nodes
            
            visited[current] = TRUE;
            
            // Update distances through current node
            for (j = 1; j < MAX_NODES; j++) {
                if (visited[j]) continue;
                
                linkCost = linkState[current][j];
                if (linkCost == LINK_STATE_MAX_COST) continue;
                
                newDist = dist[current] + linkCost;
                
                if (newDist < dist[j]) {
                    dist[j] = newDist;
                    prev[j] = current;
                    
                    dbg(ROUTING_CHANNEL, "Node %d: Found path to %d through %d with cost %.2f\n",
                        TOS_NODE_ID, j, current, newDist);
                }
            }
        }
        
        // Update routing table
        numRoutes = 0;
        for (i = 1; i < MAX_NODES; i++) {
            if (i == TOS_NODE_ID) {
                routingTable[i].nextHop = TOS_NODE_ID;
                routingTable[i].cost = 0;
                continue;
            }
            
            if (dist[i] != LINK_STATE_MAX_COST) {
                // Trace back through prev[] to find first hop
                current = i;
                nextHop = 0;
                hopCount = 0;
                
                while (prev[current] != TOS_NODE_ID && hopCount < MAX_NODES) {
                    nextHop = current;
                    current = prev[current];
                    hopCount++;
                }
                
                // If we reached the source node and found a valid next hop
                if (prev[current] == TOS_NODE_ID && linkState[TOS_NODE_ID][current] != LINK_STATE_MAX_COST) {
                    nextHop = current;  // Use the direct neighbor as next hop
                    routingTable[i].nextHop = nextHop;
                    routingTable[i].cost = dist[i];
                    numRoutes++;
                    
                    // Debug path
                    dbg(ROUTING_CHANNEL, "Node %d: Route to %d via %d, cost=%.2f, path: ",
                        TOS_NODE_ID, i, nextHop, dist[i]);
                        
                    current = i;
                    while (current != TOS_NODE_ID) {
                        dbg_clear(ROUTING_CHANNEL, "%d <- ", current);
                        current = prev[current];
                    }
                    dbg_clear(ROUTING_CHANNEL, "%d\n", TOS_NODE_ID);
                } else {
                    routingTable[i].nextHop = 0;
                    routingTable[i].cost = LINK_STATE_MAX_COST;
                }
            }
        }
    }

    command void LinkStateRouting.printRouteTable() {
        uint16_t i, j;
        char pathString[128];
        uint8_t pathNodes[MAX_NODES];
        uint8_t pathLength;
        uint8_t current;
        uint8_t next;
        float actualCost;
        
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Routing Table for Node %d\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Destination | Next Hop | Cost | Full Path\n");
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
        
        for (i = 1; i < MAX_NODES; i++) {
            if (routingTable[i].cost != LINK_STATE_MAX_COST) {
                // Start with source
                pathLength = 0;
                actualCost = 0;
                pathNodes[pathLength++] = TOS_NODE_ID;
                
                // Follow path through next hops
                current = TOS_NODE_ID;
                while (current != i && pathLength < MAX_NODES) {
                    next = (current == TOS_NODE_ID) ? routingTable[i].nextHop : 
                                routingTable[current].nextHop;
                    
                    if (next == 0 || linkState[current][next] == LINK_STATE_MAX_COST) {
                        break;  // Invalid path
                    }
                    
                    actualCost += linkState[current][next];
                    pathNodes[pathLength++] = next;
                    current = next;
                }
                
                if (pathLength < MAX_NODES && current == i) {
                    // Build path string
                    sprintf(pathString, "%d", pathNodes[0]);
                    for (j = 1; j < pathLength; j++) {
                        sprintf(pathString + strlen(pathString), " -> %d", pathNodes[j]);
                    }
                    
                    dbg(ROUTING_CHANNEL, "%10d | %8d | %.2f | %s\n",
                        i, routingTable[i].nextHop, actualCost, pathString);
                }
            }
        }
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
    }

    void initializeRoutingTable() {
        uint16_t i, j;
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            routingTable[i].nextHop = 0;
            routingTable[i].cost = LINK_STATE_MAX_COST;
            for (j = 0; j < LINK_STATE_MAX_ROUTES; j++) {
                linkState[i][j] = LINK_STATE_MAX_COST;
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
    uint8_t neighbor;
    float newCost;
    bool isStateUpdated = FALSE;
    
    if (incomingSrc >= MAX_NODES) return FALSE;
    
    for (i = 0; i < 10; i++) {
        neighbor = incomingLinkState[i].neighbor;
        if (neighbor == 0 || neighbor >= MAX_NODES) continue;
        
        newCost = incomingLinkState[i].cost;
        if (newCost >= MIN_VALID_COST && newCost <= MAX_VALID_COST) {
            if (linkState[incomingSrc][neighbor] != newCost) {
                linkState[incomingSrc][neighbor] = newCost;
                linkState[neighbor][incomingSrc] = newCost;
                isStateUpdated = TRUE;
                
                dbg(ROUTING_CHANNEL, "Updated link state: %d<->%d = %.2f\n",
                    incomingSrc, neighbor, newCost);
            }
        }
    }
    
    return isStateUpdated;
}


    void sendLinkStatePacket(uint8_t lostNeighbor) {
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
        uint16_t i, counter;
        LinkStatePacket linkStatePayload[10];
        float quality;
        
        if (!pendingUpdate) return;
        pendingUpdate = FALSE;
        
        // Initialize payload array
        for (i = 0; i < 10; i++) {
            linkStatePayload[i].neighbor = 0;
            linkStatePayload[i].cost = LINK_STATE_MAX_COST;
            linkStatePayload[i].quality = 0.0;
        }
        
        counter = 0;
        
        // Only share information about direct neighbors
        for (i = 0; i < neighborsListSize && counter < 10; i++) {
            if (neighbors[i] >= MAX_NODES) continue;
            
            quality = call NeighborDiscovery.neighborQuality(neighbors[i]);
            quality = validateLinkQuality(quality);
            
            linkStatePayload[counter].neighbor = neighbors[i];
            linkStatePayload[counter].quality = quality;
            linkStatePayload[counter].cost = quality > 0.0 ? 1.0 + (1.0 - quality) : LINK_STATE_MAX_COST;
            
            // Update our own link state table
            linkState[TOS_NODE_ID][neighbors[i]] = linkStatePayload[counter].cost;
            linkState[neighbors[i]][TOS_NODE_ID] = linkStatePayload[counter].cost;
            
            counter++;
        }
        
        if (counter > 0 || lostNeighbor != 0) {
            lastSentLinkStateSeq++;
            dbg(ROUTING_CHANNEL, "Node %d: Sending link state update seq %d with %d neighbors\n", 
                TOS_NODE_ID, lastSentLinkStateSeq, counter);
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