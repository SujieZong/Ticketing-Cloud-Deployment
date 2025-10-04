package org.java.purchaseservice.service.messaging;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.java.purchaseservice.config.RabbitFactory;
import org.java.purchaseservice.dto.MqDTO;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class TicketMessagePublisher {

    private final RabbitTemplate rabbitTemplate;

    public void publishTicketCreated(MqDTO ticketMessage) {
        try {
            rabbitTemplate.convertAndSend(
                    RabbitFactory.TICKET_EXCHANGE,
                    "ticket.created",
                    ticketMessage);
            log.info("Successfully published ticket message: ticketId={}", ticketMessage.getTicketId());
        } catch (Exception e) {
            log.error("Failed to publish ticket message: ticketId={}, error={}",
                    ticketMessage.getTicketId(), e.getMessage(), e);
            throw new RuntimeException("Failed to publish ticket message", e);
        }
    }
}