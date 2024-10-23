#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/constants.h"

module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface SimpleSend as Sender;
    uses interface MapList<uint16_t, uint16_t> as PacketsReceived;
    uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface Timer<TMilli> as LSRTimer;
    uses interface Random;
}

implementation {
    typedef struct {
        uint8_t nextHop;
        uint8_t cost;
    } Route;

    typedef struct {
        uint8_t neighbor;
        uint8_t cost;
    } LinkStatePacket;

    uint8_t linkState[LINK_STATE_MAX_ROUTES][LINK_STATE_MAX_ROUTES];
    Route routingTable[LINK_STATE_MAX_ROUTES];
    uint16_t numKnownNodes = 0;
    uint16_t numRoutes = 0;
    uint16_t sequenceNum = 0;
    pack routePack;

    void initializeRoutingTable();
    bool updateState(pack* myMsg);
    bool updateRoute(uint8_t dest, uint8_t nextHop, uint8_t cost);
    void addRoute(uint8_t dest, uint8_t nextHop, uint8_t cost);
    void removeRoute(uint8_t dest);
    void sendLinkStatePacket(uint8_t lostNeighbor);
    void handleForward(pack* myMsg);
    void dijkstra();

    command error_t LinkStateRouting.start() {
        dbg(ROUTING_CHANNEL, "Link State Routing Started on node %u!\n", TOS_NODE_ID);
        initializeRoutingTable();
        call LSRTimer.startOneShot(30000);
        return SUCCESS;
    }

    event void LSRTimer.fired() {
        if (call LSRTimer.isOneShot()) {
            // Convert to periodic timer after initial delay
            call LSRTimer.startPeriodic(30000 + (uint16_t)(call Random.rand16() % 5000));
            } else {
                dbg(ROUTING_CHANNEL, "Node %d: LSR Timer fired. Updating link state.\n", 
                    TOS_NODE_ID);
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
        // Check if we've already seen this packet
        if (myMsg->src == TOS_NODE_ID || call PacketsReceived.containsVal(myMsg->src, myMsg->seq)) {
            return;
        }
        
        // Record that we've received this packet
        call PacketsReceived.insertVal(myMsg->src, myMsg->seq);
        
        // Update our link state if the packet contains new information
        if (updateState(myMsg)) {
            dijkstra();  // Recalculate routes if state changed
        }
        
        // Forward the flood using the Flooding interface
        call Flooding.forwardFlood(myMsg);
    }

    command void LinkStateRouting.handleNeighborLost(uint16_t lostNeighbor) {
            dbg(ROUTING_CHANNEL, "Node %d: Neighbor lost %u\n", TOS_NODE_ID, lostNeighbor);
            
            // Update local link state
            if (linkState[TOS_NODE_ID][lostNeighbor] != LINK_STATE_MAX_COST) {
                linkState[TOS_NODE_ID][lostNeighbor] = LINK_STATE_MAX_COST;
                linkState[lostNeighbor][TOS_NODE_ID] = LINK_STATE_MAX_COST;
                numKnownNodes--;
                removeRoute(lostNeighbor);
            }
            
            // Broadcast the neighbor loss
            sendLinkStatePacket(lostNeighbor);
            
            // Recalculate routes
            dijkstra();
        }

    command void LinkStateRouting.handleNeighborFound() {
            uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
            uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
            uint16_t i = 0;
            
            // Update local link state with new neighbors
            for (i = 0; i < neighborsListSize; i++) {
                linkState[TOS_NODE_ID][neighbors[i]] = 1;
                linkState[neighbors[i]][TOS_NODE_ID] = 1;
            }
            
            // Broadcast updated link state
            sendLinkStatePacket(0);
            
            // Recalculate routes
            dijkstra();
        }

    command void LinkStateRouting.printLinkState() {
        uint16_t i, j;
        dbg(ROUTING_CHANNEL, "Link State for Node %d:\n", TOS_NODE_ID);
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            for (j = 0; j < LINK_STATE_MAX_ROUTES; j++) {
                if (linkState[i][j] != LINK_STATE_MAX_COST) {
                    dbg(ROUTING_CHANNEL, "  %d -> %d: Cost %d\n", i, j, linkState[i][j]);
                }
            }
        }
    }

    command void LinkStateRouting.printRouteTable() {
        uint16_t i, j;
        uint8_t currentNode, nextHop;
        char pathString[64];  // Buffer for storing the complete path
        
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Routing Table for Node %d\n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, "===========================================\n");
        dbg(ROUTING_CHANNEL, "Destination | Next Hop | Cost | Full Path\n");
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
        
        for (i = 1; i < LINK_STATE_MAX_ROUTES; i++) {
            if (routingTable[i].cost != LINK_STATE_MAX_COST) {
                // Initialize the path string with the source
                sprintf(pathString, "%d", TOS_NODE_ID);
                
                // Start from our node and follow the path
                currentNode = TOS_NODE_ID;
                while (currentNode != i) {
                    // Find next hop for current destination
                    if (currentNode == TOS_NODE_ID) {
                        nextHop = routingTable[i].nextHop;
                    } else {
                        nextHop = routingTable[i].nextHop;
                        // Follow the path through intermediate nodes
                        for (j = 1; j < LINK_STATE_MAX_ROUTES; j++) {
                            if (linkState[currentNode][j] < LINK_STATE_MAX_COST) {
                                nextHop = j;
                                break;
                            }
                        }
                    }
                    
                    // Add this hop to the path string
                    sprintf(pathString + strlen(pathString), " -> %d", nextHop);
                    
                    // Move to next node
                    currentNode = nextHop;
                    
                    // Safety check to prevent infinite loops
                    if (strlen(pathString) > 50) break;
                }
                
                dbg(ROUTING_CHANNEL, "%10d | %8d | %4d | %s\n", 
                    i, 
                    routingTable[i].nextHop, 
                    routingTable[i].cost,
                    pathString);
            }
        }
        
        // Print summary information
        dbg(ROUTING_CHANNEL, "-------------------------------------------\n");
        dbg(ROUTING_CHANNEL, "Total Routes: %d\n", numRoutes);
        dbg(ROUTING_CHANNEL, "Known Nodes: %d\n", numKnownNodes);
        dbg(ROUTING_CHANNEL, "===========================================\n\n");
        
        // Also print the link state table for verification
        dbg(ROUTING_CHANNEL, "Link State Table:\n");
        dbg(ROUTING_CHANNEL, "===========================================\n");
        for (i = 1; i < LINK_STATE_MAX_ROUTES; i++) {
            uint16_t j;
            bool hasLinks = FALSE;
            
            for (j = 1; j < LINK_STATE_MAX_ROUTES; j++) {
                if (linkState[i][j] != LINK_STATE_MAX_COST) {
                    if (!hasLinks) {
                        dbg(ROUTING_CHANNEL, "Node %d connects to: ", i);
                        hasLinks = TRUE;
                    }
                    dbg(ROUTING_CHANNEL, "[%d cost:%d] ", j, linkState[i][j]);
                }
            }
            if (hasLinks) {
                dbg(ROUTING_CHANNEL, "\n");
            }
        }
        dbg(ROUTING_CHANNEL, "===========================================\n");
    }

    void initializeRoutingTable() {
        uint16_t i, j;
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            routingTable[i].nextHop = 0;
            routingTable[i].cost = LINK_STATE_MAX_COST;
        }
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            for (j = 0; j < LINK_STATE_MAX_ROUTES; j++) {
                linkState[i][j] = LINK_STATE_MAX_COST;
            }
        }
        routingTable[TOS_NODE_ID].nextHop = TOS_NODE_ID;
        routingTable[TOS_NODE_ID].cost = 0;
        linkState[TOS_NODE_ID][TOS_NODE_ID] = 0;
        numKnownNodes++;
        numRoutes++;
    }

    bool updateState(pack* myMsg) {
        uint16_t i;
        LinkStatePacket* lsp = (LinkStatePacket*)myMsg->payload;
        bool isStateUpdated = FALSE;
        
        for (i = 0; i < 10; i++) {
            if (lsp[i].neighbor == 0) continue; // Skip empty entries
            
            // Update both directions of the link
            if (linkState[myMsg->src][lsp[i].neighbor] != lsp[i].cost) {
                if (linkState[myMsg->src][lsp[i].neighbor] == LINK_STATE_MAX_COST) {
                    numKnownNodes++;
                } else if (lsp[i].cost == LINK_STATE_MAX_COST) {
                    numKnownNodes--;
                }
                
                linkState[myMsg->src][lsp[i].neighbor] = lsp[i].cost;
                linkState[lsp[i].neighbor][myMsg->src] = lsp[i].cost;
                isStateUpdated = TRUE;
                
                dbg(ROUTING_CHANNEL, "Updated link state: %d->%d = %d\n", 
                    myMsg->src, lsp[i].neighbor, lsp[i].cost);
            }
        }
        
        // If we received new link state information, schedule a routing update
        if (isStateUpdated) {
            dbg(ROUTING_CHANNEL, "Link state updated from node %d, recalculating routes\n", 
                myMsg->src);
        }
        
        return isStateUpdated;
    }

    void sendLinkStatePacket(uint8_t lostNeighbor) {
            uint32_t* neighbors = call NeighborDiscovery.getNeighbors();
            uint16_t neighborsListSize = call NeighborDiscovery.getNeighborListSize();
            uint16_t i = 0, counter = 0;
            LinkStatePacket linkStatePayload[10];

            // Initialize payload array
            for (i = 0; i < 10; i++) {
                linkStatePayload[i].neighbor = 0;
                linkStatePayload[i].cost = 0;
            }

            // Add lost neighbor to payload if any
            if (lostNeighbor != 0) {
                dbg(ROUTING_CHANNEL, "Node %d: Broadcasting lost neighbor %u\n", 
                    TOS_NODE_ID, lostNeighbor);
                linkStatePayload[counter].neighbor = lostNeighbor;
                linkStatePayload[counter].cost = LINK_STATE_MAX_COST;
                counter++;
            }

            // Add current neighbors to payload
            for (; i < neighborsListSize; i++) {
                linkStatePayload[counter].neighbor = neighbors[i];
                linkStatePayload[counter].cost = 1;
                counter++;
                
                // When payload is full or we're at the last neighbor, send the packet
                if (counter == 10 || i == neighborsListSize - 1) {
                    // Start new flood using Flooding interface
                    call Flooding.newFlood(AM_BROADCAST_ADDR, (uint8_t*)&linkStatePayload);
                    
                    // Reset counter and clear payload for next batch if needed
                    while (counter > 0) {
                        counter--;
                        linkStatePayload[counter].neighbor = 0;
                        linkStatePayload[counter].cost = 0;
                    }
                }
            }
        }

    void dijkstra() {
        uint16_t i = 0;
        uint8_t currentNode = TOS_NODE_ID, minCost = LINK_STATE_MAX_COST, nextNode = 0;
        uint8_t prev[LINK_STATE_MAX_ROUTES];
        uint8_t cost[LINK_STATE_MAX_ROUTES];
        bool visited[LINK_STATE_MAX_ROUTES];
        uint16_t count = numKnownNodes;

        // Initialize arrays
        for (i = 0; i < LINK_STATE_MAX_ROUTES; i++) {
            cost[i] = LINK_STATE_MAX_COST;
            prev[i] = 0;
            visited[i] = FALSE;
        }

        cost[currentNode] = 0;
        prev[currentNode] = currentNode;

        while (count > 0) {
            // Find minimum cost paths from current node
            for (i = 1; i < LINK_STATE_MAX_ROUTES; i++) {
                if (!visited[i] && linkState[currentNode][i] < LINK_STATE_MAX_COST) {
                    uint8_t newCost = cost[currentNode] + linkState[currentNode][i];
                    if (newCost < cost[i]) {
                        cost[i] = newCost;
                        prev[i] = currentNode;
                    }
                }
            }

            visited[currentNode] = TRUE;
            
            // Find next unvisited node with minimum cost
            minCost = LINK_STATE_MAX_COST;
            nextNode = 0;
            for (i = 1; i < LINK_STATE_MAX_ROUTES; i++) {
                if (cost[i] < minCost && !visited[i]) {
                    minCost = cost[i];
                    nextNode = i;
                }
            }
            
            if (nextNode == 0) break; // No more reachable nodes
            currentNode = nextNode;
            count--;
        }

        // Update routing table with complete paths
        for (i = 1; i < LINK_STATE_MAX_ROUTES; i++) {
            if (i == TOS_NODE_ID) continue;
            
            if (cost[i] != LINK_STATE_MAX_COST) {
                uint8_t firstHop = i;
                uint8_t current = i;
                
                // Traverse back to find first hop
                while (prev[current] != TOS_NODE_ID) {
                    firstHop = current;
                    current = prev[current];
                    if (current == 0) break; // Safety check
                }
                
                // Only update if we found a valid path
                if (current != 0) {
                    addRoute(i, firstHop, cost[i]);
                }
            } else {
                removeRoute(i);
            }
        }
    }

    void addRoute(uint8_t dest, uint8_t nextHop, uint8_t cost) {
        // Add route if:
        // 1. We don't have a route to this destination yet (cost is MAX)
        // 2. This is a better route than what we have
        // 3. This is a new next hop for the same cost (for redundancy)
        if (routingTable[dest].cost == LINK_STATE_MAX_COST || 
            cost < routingTable[dest].cost ||
            (cost == routingTable[dest].cost && nextHop != routingTable[dest].nextHop)) {
            
            routingTable[dest].nextHop = nextHop;
            routingTable[dest].cost = cost;
            
            if (routingTable[dest].cost == LINK_STATE_MAX_COST) {
                numRoutes++;
            }
            
            dbg(ROUTING_CHANNEL, "Updated route to node %d: nextHop=%d, cost=%d\n", 
                dest, nextHop, cost);
        }
    }

    void removeRoute(uint8_t dest) {
        routingTable[dest].nextHop = 0;
        routingTable[dest].cost = LINK_STATE_MAX_COST;
        numRoutes--;
    }
}
