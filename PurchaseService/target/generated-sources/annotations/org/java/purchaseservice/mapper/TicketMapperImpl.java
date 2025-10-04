package org.java.purchaseservice.mapper;

import java.time.Instant;
import javax.annotation.processing.Generated;
import org.java.purchaseservice.dto.TicketCreationDTO;
import org.java.purchaseservice.dto.TicketRespondDTO;
import org.java.purchaseservice.model.TicketInfo;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-10-03T21:42:34-0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 23.0.2 (Homebrew)"
)
@Component
public class TicketMapperImpl implements TicketMapper {

    @Override
    public TicketInfo toEntity(TicketCreationDTO dto) {
        if ( dto == null ) {
            return null;
        }

        TicketInfo.TicketInfoBuilder ticketInfo = TicketInfo.builder();

        ticketInfo.venueId( dto.getVenueId() );
        ticketInfo.eventId( dto.getEventId() );
        ticketInfo.zoneId( dto.getZoneId() );
        ticketInfo.row( dto.getRow() );
        ticketInfo.column( dto.getColumn() );

        return ticketInfo.build();
    }

    @Override
    public TicketRespondDTO toRespondDto(TicketInfo entity) {
        if ( entity == null ) {
            return null;
        }

        String ticketId = null;
        int zoneId = 0;
        String row = null;
        String column = null;
        Instant createdOn = null;

        ticketId = entity.getTicketId();
        zoneId = entity.getZoneId();
        row = entity.getRow();
        column = entity.getColumn();
        createdOn = entity.getCreatedOn();

        TicketRespondDTO ticketRespondDTO = new TicketRespondDTO( ticketId, zoneId, row, column, createdOn );

        return ticketRespondDTO;
    }
}
