//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


#include "protocol.h"
#include "channels.h"

enum{
	PACKET_HEADER_LENGTH = 8,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	MAX_TTL = 32
};


typedef nx_struct pack{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;		//Sequence Number
	nx_uint8_t TTL;			//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}pack;

typedef nx_struct frame{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;		//Sequence Number
	nx_uint8_t TTL;			//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}frame;

typedef nx_struct packet{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint16_t seq;		//Sequence Number
	nx_uint8_t TTL;			//Time to Live
	nx_uint8_t protocol;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}packet;



/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
void logPack(pack *input){
	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
};

enum{
	AM_PACK=6
};

void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
	Package->src = src;
	Package->dest = dest;
	Package->TTL = TTL;
	Package->protocol = protocol;
	Package->seq = seq;
	memcpy(Package->payload, payload, length);
}

void makeLinkPack(frame *Frame, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
	Frame->src = src;
	Frame->dest = dest;
	Frame->TTL = TTL;
	Frame->protocol = protocol;
	Frame->seq = seq;
	memcpy(Frame->payload, payload, length);
}

void makeIPPack(packet *Packet, version, header_length, uint8_t service, uint16_t total_length, uint16_t id, flags, offset, uint8_t TTL, uint8_t protocol, uint16_t checksum, uint32_t src, uint32_t dest, uint8_t* payload){
	Packet->src = src;
	Packet->dest = dest;
	Packet->TTL = TTL;
	Packet->protocol = protocol;
	Packet->seq = seq;
	memcpy(Packet->payload, payload, length);
}

void makeTCPPack(pack *Packet, uint16_t src, uint16_t dest, uint32_t seq, uint32_t ack, uint4_t offset, uint16_t flags, uint16_t window, uint8_t* payload, uint8_t length){
	Packet->src = src;
	Packet->dest = dest;
	Packet->seq = seq;
	Packet->ack = ack;
	Packet->offset = offset;
	Packet->flags = flags;
	Packet->window = window;
	memcpy(Packet->payload, payload, length);
}


#endif
