package org.java.purchaseservice.config;

import io.awspring.cloud.sns.core.SnsTemplate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.sns.SnsClient;

@Configuration
public class MessageSnsConfig {

  @Bean
  public SnsClient snsClient() {
    return SnsClient.create();
  }

  @Bean
  public SnsTemplate snsTemplate(SnsClient snsClient) {
    return new SnsTemplate(snsClient);
  }

}
