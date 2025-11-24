package org.java.purchaseservice.service.initialize;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.java.purchaseservice.config.VenuesProperties;
import org.java.purchaseservice.model.venue.VenueConfig;
import org.java.purchaseservice.service.redis.RedisKeyUtil;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class VenueConfigService implements InitializingBean {
	private final StringRedisTemplate stringRedisTemplate;
	private final VenuesProperties venuesProperties;

	@Override
	public void afterPropertiesSet() {
		log.info("[VenueConfigService] Initializing venue configurations from YAML...");
		if (venuesProperties.getMap() == null || venuesProperties.getMap().isEmpty()) {
			log.warn("[VenueConfigService] No venues found in configuration. Skipping initialization.");
			return;
		}

		for (Map.Entry<String, VenueConfig> entry : venuesProperties.getMap().entrySet()) {
			String venueId = entry.getKey();
			VenueConfig venueConfig = entry.getValue();
			if (venueConfig.getZones() != null) {
				int zoneCount = venueConfig.getZones().getZoneCount();
				int rowCount = venueConfig.getZones().getRowCount();
				int colCount = venueConfig.getZones().getColCount();

				log.info("[VenueConfigService] Initializing venue '{}' with {} zones, {} rows, {} cols",
						venueId, zoneCount, rowCount, colCount);

				for (int zoneId = 1; zoneId <= zoneCount; zoneId++){
					initializeVenueZone(venueId, zoneId, rowCount, colCount);
				}
			}
		}
		log.info("[VenueConfigService] Finished initializing all venues.");
	}

	public void initializeVenueZone(String venueId, int zoneId, int rowCount, int colCount) {
		String rowCountKey = RedisKeyUtil.getRowCountKey(venueId, zoneId);
		stringRedisTemplate.opsForValue().set(rowCountKey, String.valueOf(rowCount));

		String seatPerRowKey = RedisKeyUtil.getSeatPerRowKey(venueId, zoneId);
		stringRedisTemplate.opsForValue().set(seatPerRowKey, String.valueOf(colCount));

		String capacityKey = RedisKeyUtil.getZoneCapacityKey(venueId, zoneId);
		stringRedisTemplate.opsForValue().set(capacityKey, String.valueOf(rowCount * colCount));

		String venueZonesKey = RedisKeyUtil.getZoneSetKey(venueId);
		stringRedisTemplate.opsForSet().add(venueZonesKey, String.valueOf(zoneId));
	}

	public boolean isVenueExists(String venueId) {
		String venueZonesKey = RedisKeyUtil.getZoneSetKey(venueId);
		Boolean hasKey = stringRedisTemplate.hasKey(venueZonesKey);
		return hasKey != null && hasKey;
	}

	public Set<String> getVenueZones(String venueId) {
		String venueZonesKey = RedisKeyUtil.getZoneSetKey(venueId);
		return stringRedisTemplate.opsForSet().members(venueZonesKey);
	}

	public int getRowCount(String venueId, int zoneId) {
		String rowCountKey = RedisKeyUtil.getRowCountKey(venueId, zoneId);
		return getIntValue(rowCountKey);
	}

	public int getSeatPerRow(String venueId, int zoneId) {
		String seatKey = RedisKeyUtil.getSeatPerRowKey(venueId, zoneId);
		return getIntValue(seatKey);
	}

	public int getZoneCapacity(String venueId, int zoneId) {
		String zoneKey = RedisKeyUtil.getZoneCapacityKey(venueId, zoneId);
		return getIntValue(zoneKey);
	}

	private int getIntValue(String key) {
		String value = stringRedisTemplate.opsForValue().get(key);
		if (value != null) {
			try {
				return Integer.parseInt(value);
			} catch (NumberFormatException e) {
				log.warn("NumberFormatException for key '{}', value '{}'", key, value);
				return 0;
			}
		}
		return 0;
	}
}
