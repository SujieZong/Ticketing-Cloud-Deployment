package org.java.purchaseservice;

import org.java.purchaseservice.dto.TicketPurchaseRequestDTO;
import org.java.purchaseservice.dto.TicketRespondDTO;
import org.java.purchaseservice.exception.CreateTicketException;
import org.java.purchaseservice.exception.SeatOccupiedException;
import org.java.purchaseservice.mapper.TicketMapper;
import org.java.purchaseservice.model.TicketInfo;
import org.java.purchaseservice.model.TicketStatus;
import org.java.purchaseservice.service.messaging.TicketMessagePublisher;
import org.java.purchaseservice.service.purchase.TicketPurchaseService;
import org.java.purchaseservice.service.redis.SeatOccupiedRedisFacade;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class TicketPurchaseServiceTest {

	@Test
	void purchaseTicket_success_publishesMessageAndReturnsDTO() throws Exception {
		// mocks
		SeatOccupiedRedisFacade seat = mock(SeatOccupiedRedisFacade.class);
		TicketMessagePublisher messagePublisher = mock(TicketMessagePublisher.class);
		TicketMapper ticketMapper = mock(TicketMapper.class);

		TicketPurchaseService svc = new TicketPurchaseService(seat, ticketMapper, messagePublisher);

		// request DTO
		var req = new TicketPurchaseRequestDTO("V1", "E1", 1, "A", "7");

		// mapper: CreationDTO -> entity；entity -> respondDTO
		when(ticketMapper.toEntity(any())).thenAnswer(inv -> {
			var creation = inv.getArgument(0, org.java.purchaseservice.dto.TicketCreationDTO.class);
			var e = new TicketInfo();
			e.setVenueId(creation.getVenueId());
			e.setEventId(creation.getEventId());
			e.setZoneId(creation.getZoneId());
			e.setRow(creation.getRow());
			e.setColumn(creation.getColumn());
			return e;
		});
		when(ticketMapper.toRespondDto(any(TicketInfo.class))).thenAnswer(inv -> {
			TicketInfo t = inv.getArgument(0);
			return new TicketRespondDTO(t.getTicketId(), t.getZoneId(), t.getRow(), t.getColumn(), t.getCreatedOn());
		});

		// act
		TicketRespondDTO resp = svc.purchaseTicket(req);

		// assert —— 占座调用
		verify(seat).tryOccupySeat("E1", "V1", 1, "A", "7");

		// 发布消息：验证 MqDTO 包含正确字段
		verify(messagePublisher).publishTicketCreated(argThat(msg -> {
			assertThat(msg.getVenueId()).isEqualTo("V1");
			assertThat(msg.getEventId()).isEqualTo("E1");
			assertThat(msg.getZoneId()).isEqualTo(1);
			assertThat(msg.getRow()).isEqualTo("A");
			assertThat(msg.getColumn()).isEqualTo("7");
			assertThat(msg.getTicketId()).isNotBlank();
			assertThat(msg.getCreatedOn()).isNotNull();
			assertThat(msg.getStatus()).isEqualTo(TicketStatus.PAID);
			return true;
		}));

		// 返回 DTO
		assertThat(resp).isNotNull();
		assertThat(resp.getTicketId()).isNotBlank();
		assertThat(resp.getZoneId()).isEqualTo(1);
		assertThat(resp.getRow()).isEqualTo("A");
		assertThat(resp.getColumn()).isEqualTo("7");
		assertThat(resp.getCreatedOn()).isNotNull();
	}

	@Test
	void purchaseTicket_whenSeatAlreadyOccupied_throws_andNoMessagePublished() {
		SeatOccupiedRedisFacade seat = mock(SeatOccupiedRedisFacade.class);
		TicketMessagePublisher messagePublisher = mock(TicketMessagePublisher.class);
		TicketMapper ticketMapper = mock(TicketMapper.class);

		TicketPurchaseService svc = new TicketPurchaseService(seat, ticketMapper, messagePublisher);

		var req = new TicketPurchaseRequestDTO("V1", "E1", 1, "A", "7");

		doThrow(new SeatOccupiedException("occupied"))
				.when(seat).tryOccupySeat("E1", "V1", 1, "A", "7");

		assertThatThrownBy(() -> svc.purchaseTicket(req)).isInstanceOf(SeatOccupiedException.class);

		verify(messagePublisher, never()).publishTicketCreated(any());
	}

	@Test
	void purchaseTicket_whenMessagePublishingFails_releaseSeat_andThrowCreateTicketException() {
		SeatOccupiedRedisFacade seat = mock(SeatOccupiedRedisFacade.class);
		TicketMessagePublisher messagePublisher = mock(TicketMessagePublisher.class);
		TicketMapper ticketMapper = mock(TicketMapper.class);

		when(ticketMapper.toEntity(any())).thenReturn(new TicketInfo());

		TicketPurchaseService svc = new TicketPurchaseService(seat, ticketMapper, messagePublisher);

		var req = new TicketPurchaseRequestDTO("V1", "E1", 1, "A", "7");

		doThrow(new RuntimeException("SNS down")).when(messagePublisher).publishTicketCreated(any());

		assertThatThrownBy(() -> svc.purchaseTicket(req))
				.isInstanceOf(CreateTicketException.class);

		verify(seat).releaseSeat("E1", "V1", 1, "A", "7");
	}
}