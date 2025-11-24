package org.java.purchaseservice.config;

import lombok.Data;
import org.java.purchaseservice.model.venue.VenueConfig;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.util.Map;

@Data
@Configuration
@ConfigurationProperties(prefix = "venues")
public class VenuesProperties {
    private Map<String, VenueConfig> map;
}
