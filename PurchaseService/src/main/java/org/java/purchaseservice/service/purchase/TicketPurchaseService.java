package org.java.purchaseservice.service.purchase;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.java.purchaseservice.dto.MqDTO;
import org.java.purchaseservice.dto.TicketCreationDTO;
import org.java.purchaseservice.dto.TicketPurchaseRequestDTO;
import org.java.purchaseservice.dto.TicketRespondDTO;
import org.java.purchaseservice.exception.CreateTicketException;
import org.java.purchaseservice.exception.SeatOccupiedException;
import org.java.purchaseservice.mapper.TicketMapper;
import org.java.purchaseservice.model.TicketInfo;
import org.java.purchaseservice.model.TicketStatus;
import org.java.purchaseservice.service.TicketPurchaseServiceInterface;
import org.java.purchaseservice.service.messaging.TicketMessagePublisher;
import org.java.purchaseservice.service.redis.SeatOccupiedRedisFacade;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class TicketPurchaseService implements TicketPurchaseServiceInterface {

	private final SeatOccupiedRedisFacade seatOccupiedRedisFacade;
	private final TicketMapper ticketMapper;
	private final TicketMessagePublisher ticketMessagePublisher;

	// transfer input data into a Response DTO object and save to Database through
	// DAO and Mapper
	@Override
	@Transactional
	public TicketRespondDTO purchaseTicket(TicketPurchaseRequestDTO dto) {
		log.info("[TicketPurchaseService] purchaseTicket start: eventId={}, zone={}, row={}, col={}", dto.getEventId(),
				dto.getZoneId(), dto.getRow(), dto.getColumn());

		// Part 1: Redis - Set Redis seat occupancy to a True - Lua script
		try {
			seatOccupiedRedisFacade.tryOccupySeat(dto.getEventId(), dto.getVenueId(), dto.getZoneId(), dto.getRow(),
					dto.getColumn());
			log.debug("[TicketPurchaseService] seat occupied OK for eventId={}, seat={}-{}", dto.getEventId(),
					dto.getRow(), dto.getColumn());
		} catch (SeatOccupiedException e) {
			log.warn("[TicketPurchaseService] seat already occupied: eventId={}, seat={}-{}", dto.getEventId(),
					dto.getRow(), dto.getColumn());
			throw e;
		}

		// -- Part 2 Generation UUID and time--
		String ticketId = UUID.randomUUID().toString();
		Instant now = Instant.now();

		try {
			// -- part 3 Write to DynamoDB -> construct DTO then write
			TicketCreationDTO creation = TicketCreationDTO.builder().ticketId(ticketId).venueId(dto.getVenueId())
					.eventId(dto.getEventId()).zoneId(dto.getZoneId()).row(dto.getRow()).column(dto.getColumn())
					.status(TicketStatus.PAID).createdOn(now).build();

			//
			TicketInfo entity = ticketMapper.toEntity(creation);
			entity.setTicketId(ticketId);
			entity.setStatus(creation.getStatus());
			entity.setCreatedOn(now);

			// -- Part 4 -- Publish message to SNS directly
			MqDTO event = MqDTO.builder()
					.ticketId(ticketId)
					.venueId(dto.getVenueId())
					.eventId(dto.getEventId())
					.zoneId(dto.getZoneId())
					.row(dto.getRow())
					.column(dto.getColumn())
					.createdOn(now)
					.status(creation.getStatus())
					.build();

			// Publish message to SNS for downstream processing
			ticketMessagePublisher.publishTicketCreated(event);
			log.info("Message published to SNS for ticketId={}", ticketId);

			// direct return
			return ticketMapper.toRespondDto(entity);

		} catch (Exception ex) {
			// any error, release seat
			safeReleaseSeat(dto, ticketId, ex);
			throw new CreateTicketException("Failed to create ticket", ex);
		}
	}

	// Release seat from Redis
	private void safeReleaseSeat(TicketPurchaseRequestDTO dto, String ticketId, Exception original) {
		try {
			seatOccupiedRedisFacade.releaseSeat(dto.getEventId(), dto.getVenueId(), dto.getZoneId(), dto.getRow(),
					dto.getColumn());
			log.info("[TicketPurchaseService] seat released after failure, ticketId={}", ticketId);
		} catch (Exception re) {
			log.error("[TicketPurchaseService] seat release FAILED, ticketId={}, cause={}, releaseErr={}", ticketId,
					original.getMessage(), re.getMessage(), re);
		}
	}
}