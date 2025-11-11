package org.java.messagepersistenceservice.config;

import io.awspring.cloud.sqs.config.SqsMessageListenerContainerFactory;
import io.awspring.cloud.sqs.listener.acknowledgement.handler.AcknowledgementMode;
import io.awspring.cloud.sqs.operations.SqsTemplate;
import java.time.Duration;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsSessionCredentials;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsAsyncClient;
import software.amazon.awssdk.services.sqs.SqsAsyncClientBuilder;

@Configuration
public class MessageSqsConfig {

    @Value("${AWS_REGION:us-west-2}") private String awsRegion;
    @Value("${AWS_ACCESS_KEY_ID:}") private String accessKey;
    @Value("${AWS_SECRET_ACCESS_KEY:}") private String secretKey;
    @Value("${AWS_SESSION_TOKEN:}") private String sessionToken;

    @Bean
    @ConditionalOnMissingBean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        return mapper;
    }

    @Bean
    public SqsAsyncClient sqsAsyncClient() {
        SqsAsyncClientBuilder builder = SqsAsyncClient.builder()
                .region(Region.of(awsRegion))
                .credentialsProvider(resolveCredentials());

        return builder.build();
    }

    @Bean
    public SqsTemplate sqsTemplate(SqsAsyncClient client) {
        return SqsTemplate.builder().sqsAsyncClient(client).build();
    }

    @Bean
    public SqsMessageListenerContainerFactory<Object> defaultSqsListenerContainerFactory(
            SqsAsyncClient client) {
        SqsMessageListenerContainerFactory<Object> factory = new SqsMessageListenerContainerFactory<>();
        factory.setSqsAsyncClient(client);
        factory.configure(opts -> opts
                .acknowledgementMode(AcknowledgementMode.ON_SUCCESS)
                .maxMessagesPerPoll(10)
                .pollTimeout(Duration.ofSeconds(20))
                .maxConcurrentMessages(100));
        return factory;
    }

    private AwsCredentialsProvider resolveCredentials() {
        if (!StringUtils.hasText(accessKey) || !StringUtils.hasText(secretKey)) {
            return DefaultCredentialsProvider.create();
        }
        if (StringUtils.hasText(sessionToken)) {
            return StaticCredentialsProvider.create(
                    AwsSessionCredentials.create(accessKey, secretKey, sessionToken));
        }
        return StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secretKey));
    }

}
