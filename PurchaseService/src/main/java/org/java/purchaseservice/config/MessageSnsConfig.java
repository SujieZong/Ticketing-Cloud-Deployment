package org.java.purchaseservice.config;

import io.awspring.cloud.sns.core.SnsTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsSessionCredentials;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.SnsClientBuilder;

@Configuration
public class MessageSnsConfig {

  @Value("${AWS_REGION:us-west-2}") private String awsRegion;
  @Value("${AWS_ACCESS_KEY_ID:}") private String accessKey;
  @Value("${AWS_SECRET_ACCESS_KEY:}") private String secretKey;
  @Value("${AWS_SESSION_TOKEN:}") private String sessionToken;

  @Bean
  public SnsClient snsClient() {
    SnsClientBuilder builder = SnsClient.builder()
        .region(Region.of(awsRegion))
        .credentialsProvider(resolveCredentials());

    return builder.build();
  }

  @Bean
  public SnsTemplate snsTemplate(SnsClient snsClient) {
    return new SnsTemplate(snsClient);
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
