package org.java.queryservice.mapper;

import javax.annotation.processing.Generated;
import org.java.queryservice.dto.TicketInfoDTO;
import org.java.queryservice.model.TicketInfo;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2025-10-03T21:42:37-0700",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 23.0.2 (Homebrew)"
)
@Component
public class TicketMapperImpl implements TicketMapper {

    @Override
    public TicketInfoDTO toInfoDto(TicketInfo entity) {
        if ( entity == null ) {
            return null;
        }

        TicketInfoDTO ticketInfoDTO = new TicketInfoDTO();

        ticketInfoDTO.setRow( entity.getRow() );
        ticketInfoDTO.setColumn( entity.getColumn() );
        ticketInfoDTO.setTicketId( entity.getTicketId() );
        ticketInfoDTO.setVenueId( entity.getVenueId() );
        ticketInfoDTO.setEventId( entity.getEventId() );
        ticketInfoDTO.setZoneId( entity.getZoneId() );
        ticketInfoDTO.setStatus( entity.getStatus() );
        ticketInfoDTO.setCreatedOn( entity.getCreatedOn() );

        return ticketInfoDTO;
    }
}
