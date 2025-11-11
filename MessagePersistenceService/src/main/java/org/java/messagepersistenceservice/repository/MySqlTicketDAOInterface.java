package org.java.messagepersistenceservice.repository;

import org.java.messagepersistenceservice.model.TicketInfo;

public interface MySqlTicketDAOInterface {
	void createTicket(TicketInfo ticket);
}
