package org.java.messagepersistenceservice.mapper;

import org.java.messagepersistenceservice.dto.MqDTO;
import org.java.messagepersistenceservice.model.TicketInfo;
import org.java.messagepersistenceservice.model.TicketStatus;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;

// consume MQ message
@Mapper(componentModel = "spring", unmappedSourcePolicy = ReportingPolicy.IGNORE)
public interface MqMapper {

	@Mapping(target = "status", expression = "java(mapStatus(mqDTO.getStatus()))")
	TicketInfo toTicketInfo(MqDTO mqDTO);
	//
	// default TicketStatus mapStatus(String s) {
	// if (s == null) return TicketStatus.PENDING_PAYMENT;
	// return switch (s.trim().toUpperCase()) {
	// case "PAID" -> TicketStatus.PAID;
	// case "CANCELLED" -> TicketStatus.CANCELLED;
	// case "CREATED" -> TicketStatus.PENDING_PAYMENT;
	// default -> TicketStatus.PENDING_PAYMENT;
	// };
	// }

	default TicketStatus mapStatus(TicketStatus s) {
		return s == null ? TicketStatus.PENDING_PAYMENT : s;
	}
}