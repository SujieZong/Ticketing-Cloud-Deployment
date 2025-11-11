package org.java.messagepersistenceservice.service.sqs;

import io.awspring.cloud.sqs.annotation.SqsListener;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.java.messagepersistenceservice.dto.MqDTO;
import org.java.messagepersistenceservice.mapper.MqMapper;
import org.java.messagepersistenceservice.repository.MySqlTicketDAOInterface;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Service;
import org.java.messagepersistenceservice.exception.TransientException;

@Slf4j
@Service
@RequiredArgsConstructor
public class SqsMySqlConsumer {
    private final MySqlTicketDAOInterface mySqlTicketDAO;
    private final MqMapper mqMapper;

    @SqsListener(value = "${sqs.queue.ticket-sql-name}", factory = "defaultSqsListenerContainerFactory")
    public void mySqlConsume(
            MqDTO dto,
            @Header(value = "ApproximateReceiveCount", required = false) Integer receiveCount,
            @Header(value = "MessageId", required = false) String messageId) {
        log.info("【MySqlSQS】Received ticketId={}, receiveCount={}, msgId={}", dto.getTicketId(), receiveCount,
                messageId);

        try {
            mySqlTicketDAO.createTicket(mqMapper.toTicketInfo(dto)); // delete on success
        } catch (TransientException e) {
            // Retryable error, add back and retry
            log.warn("[Retryable Error] TicketId={}, ReceiveCount={}, Error={}", dto.getTicketId(), receiveCount,
                    e.getMessage());
            throw e;
        } catch (Exception e) {
            // Non-retryable error, should not be retried
            log.error("[Non-Retryable Error] Dropping message. TicketId={}, ReceiveCount={}, Error={}, StackTrace={}",
                    dto.getTicketId(), receiveCount, e.getMessage(), e);
        }
    }
}
