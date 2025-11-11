# Ticketing Platform API Documentation

This directory contains the API documentation for the High-Concurrency CQRS Ticketing Platform.

## Files

- `Ticket.postman_collection.json` - Postman collection for API testing
- `swagger.yaml` - OpenAPI 3.0 specification for the API

## API Overview

The ticketing platform implements a CQRS (Command Query Responsibility Segregation) architecture with the following services:

### Services
- **Purchase Service** (`/purchase/*`) - Handles ticket purchases (Command side)
- **Query Service** (`/query/*`) - Handles ticket queries (Query side)
- **Events Service** (`/events/*`) - Handles event projections

### Key Features
- High-concurrency ticket purchasing
- CQRS architecture for read/write separation
- Event-driven architecture with SNS/SQS
- Redis caching for performance
- MySQL database for persistence

## API Endpoints

### Health Checks
- `GET /purchase/health` - Purchase service health
- `GET /query/health` - Query service health
- `GET /events/health` - Events service health

### Purchase Operations
- `POST /purchase/api/v1/tickets` - Purchase a ticket

### Query Operations
- `GET /query/api/v1/tickets` - Get all tickets
- `GET /query/api/v1/tickets/{ticketId}` - Get specific ticket
- `GET /query/api/v1/tickets/count/{eventId}` - Get event ticket count
- `GET /query/api/v1/tickets/revenue/{venueId}/{eventId}` - Get event revenue

### Admin Operations
- `POST /admin/reset/redis` - Clear Redis cache
- `POST /admin/reset/mysql` - Reset MySQL database

## Using the OpenAPI Specification

### Swagger UI
You can view the API documentation using Swagger UI:

1. Go to [Swagger Editor](https://editor.swagger.io/)
2. Copy and paste the contents of `swagger.yaml`
3. The interactive documentation will be generated automatically

### Alternative Viewers
- [SwaggerHub](https://swaggerhub.com/)
- [Stoplight](https://stoplight.io/)
- Local Swagger UI instance

## Authentication
Admin endpoints require Bearer token authentication:
```
Authorization: Bearer <your-jwt-token>
```

## Environment Variables
- `alb` - ALB Load Balancer URL (default: http://localhost:8080)
- `ticketId` - Ticket ID for query operations

## Data Models

### Ticket Purchase Request
```json
{
  "venueId": "Venue1",
  "eventId": "Event1",
  "zoneId": 1,
  "row": "c",
  "column": "2"
}
```

### Ticket Response
```json
{
  "ticketId": "4ebadf55-dbfa-4884-afaa-f001308bc7b0",
  "venueId": "Venue1",
  "eventId": "Event1",
  "zoneId": 1,
  "row": "c",
  "column": "2",
  "purchaseTime": "2025-11-03T10:30:00Z",
  "price": 75.00,
  "status": "active"
}
```

## Architecture Notes

- **CQRS Pattern**: Write operations (purchases) are separated from read operations (queries)
- **Event Sourcing**: Ticket purchases generate events that are processed asynchronously
- **Caching**: Redis is used for caching frequently accessed data
- **Message Queue**: SNS/SQS handles event distribution between services

## Development

To test the APIs locally:
1. Import the Postman collection
2. Set the `alb` variable to your local server URL
3. Run the health checks first
4. Test purchase and query operations