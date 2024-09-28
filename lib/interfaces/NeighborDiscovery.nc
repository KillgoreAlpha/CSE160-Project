interface NeighborDiscovery {
    /**
     * Starts the neighbor discovery process.
     */
    command void start();

    /**
     * Sends a reply to a neighbor discovery packet.
     * @param NEIGHBOR_DISCOVERY_PACKET The received neighbor discovery packet.
     */
    command void reply(pack* NEIGHBOR_DISCOVERY_PACKET);

    /**
     * Processes a received neighbor reply packet.
     * @param NEIGHBOR_REPLY_PACKET The received neighbor reply packet.
     */
    command void readDiscovery(pack* NEIGHBOR_REPLY_PACKET);

    /**
     * Checks if a given node ID is a known neighbor.
     * @param nodeId The ID of the node to check.
     * @return TRUE if the node is a neighbor, FALSE otherwise.
     */
    command bool isNeighbor(uint16_t nodeId);

    /**
     * Gets the last time a neighbor was heard from.
     * @param nodeId The ID of the neighbor node.
     * @return The sequence number when the neighbor was last heard from.
     */
    command uint16_t getLastHeard(uint16_t nodeId);
}