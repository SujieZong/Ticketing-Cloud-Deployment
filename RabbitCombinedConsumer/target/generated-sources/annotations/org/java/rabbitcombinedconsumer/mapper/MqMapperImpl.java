package org.java.rabbitcombinedconsumer.mapper;

import javax.annotation.processing.Generated;
import org.java.rabbitcombinedconsumer.dto.MqDTO;
import org.java.rabbitcombinedconsumer.model.TicketInfo;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-10-03T21:42:36-0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 23.0.2 (Homebrew)"
)
@Component
public class MqMapperImpl implements MqMapper {

    @Override
    public TicketInfo toTicketInfo(MqDTO mqDTO) {
        if ( mqDTO == null ) {
            return null;
        }

        TicketInfo ticketInfo = new TicketInfo();

        ticketInfo.setTicketId( mqDTO.getTicketId() );
        ticketInfo.setVenueId( mqDTO.getVenueId() );
        ticketInfo.setEventId( mqDTO.getEventId() );
        ticketInfo.setZoneId( mqDTO.getZoneId() );
        ticketInfo.setRow( mqDTO.getRow() );
        ticketInfo.setColumn( mqDTO.getColumn() );
        ticketInfo.setCreatedOn( mqDTO.getCreatedOn() );

        ticketInfo.setStatus( mapStatus(mqDTO.getStatus()) );

        return ticketInfo;
    }
}
