package org.java.purchaseservice.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitFactory {

	public static final String TICKET_EXCHANGE = "ticket.exchange";
	// public static final String TICKET_NOSQL = "ticketNoSQL";
	public static final String TICKET_SQL = "ticketSQL";

	// SQL queue
	@Bean
	public Queue ticketSqlQueue() {
		return new Queue(TICKET_SQL, true);
	}

	// put the message into TicketExchange
	@Bean
	public TopicExchange ticketExchange() {
		return new TopicExchange(TICKET_EXCHANGE, true, false);
	}

	@Bean
	public Binding bindingSql(Queue ticketSqlQueue, TopicExchange ticketExchange) {
		return BindingBuilder.bind(ticketSqlQueue).to(ticketExchange).with("ticket.created");
	}

	@Bean
	public MessageConverter jsonMessageConverter() {
		return new Jackson2JsonMessageConverter();
	}

	@Bean
	public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory,
			MessageConverter messageConverter) {
		RabbitTemplate template = new RabbitTemplate(connectionFactory);
		template.setMessageConverter(messageConverter);
		return template;
	}

	@Bean(name = "rabbitListenerContainerFactory")
	public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
			ConnectionFactory connectionFactory,
			MessageConverter messageConverter) {
		SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
		factory.setConnectionFactory(connectionFactory);
		factory.setMessageConverter(messageConverter);

		// change to manual ack
		factory.setAcknowledgeMode(AcknowledgeMode.MANUAL);
		// if failed put back to queue
		factory.setDefaultRequeueRejected(true);

		factory.setConcurrentConsumers(20);
		factory.setMaxConcurrentConsumers(50);
		factory.setPrefetchCount(100);

		return factory;
	}

}
