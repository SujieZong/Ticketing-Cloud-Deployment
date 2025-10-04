package org.java.queryservice.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.util.Map;

@Getter
@Setter
@AllArgsConstructor
@NoArgsConstructor
public class SalesSummaryDTO {
	private int totalTicketsSold;
	private Map<String, Integer> ticketsByEvent;
	private Map<String, Integer> ticketsByVenue;
	private Map<Integer, Integer> ticketsByZone;
	private Map<String, Integer> ticketsByRow;
	private Map<String, Integer> ticketsByColumn;
	private BigDecimal totalRevenue;
}