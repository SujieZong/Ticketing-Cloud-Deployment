package org.java.purchaseservice.service.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;

import io.awspring.cloud.sns.core.SnsTemplate;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.java.purchaseservice.dto.MqDTO;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class TicketMessagePublisher {

    private final SnsTemplate snsTemplate;
    private final ObjectMapper objectMapper;

    @Value("${sns.topic.ticket-created-arn}") // publish to SNS through topic
    private String ticketTopicArn; // from application.yml

    public void publishTicketCreated(MqDTO ticketMessage) {
        try {
            String message = objectMapper.writeValueAsString(ticketMessage);

            snsTemplate.convertAndSend(
                    ticketTopicArn,
                    message);

            log.info("Successfully published ticket message: ticketId={}", ticketMessage.getTicketId());
        } catch (Exception e) {
            log.error("Failed to publish ticket message: ticketId={}, error={}",
                    ticketMessage.getTicketId(), e.getMessage(), e);
            throw new RuntimeException("Failed to publish ticket message", e);
        }
    }
}