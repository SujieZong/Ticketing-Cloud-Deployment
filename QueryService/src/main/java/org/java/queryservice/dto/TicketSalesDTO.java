package org.java.queryservice.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class TicketSalesDTO {
	private List<TicketInfoDTO> soldTickets;
	private SalesSummaryDTO summary;
}