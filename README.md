# High-Concurrency Ticketing Platform - CQRS Architecture

A high-performance ticketing system built with CQRS pattern, implementing read-write separation and event-driven architecture using AWS services.

## Table of Contents
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Services](#services)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites
- **Java 21** (JDK 21 LTS)
- **Maven 3.8+**
- **Docker** (for local development)
- **AWS CLI v2** (for AWS deployment)
- **Terraform 1.6+** (for infrastructure)

### Local Development Setup
```bash
# Clone the repository
git clone <your-repo-url>
cd cs6620-Rabbit-ticket

# Start local infrastructure
docker compose up -d

# Build and run services
mvn clean package -DskipTests
mvn spring-boot:run -pl PurchaseService &
mvn spring-boot:run -pl QueryService &
mvn spring-boot:run -pl RabbitCombinedConsumer &
```

### Health Check
```bash
# Check service health
curl http://localhost:8080/actuator/health  # Purchase Service
curl http://localhost:8081/api/v1/health    # Query Service
```

## Architecture Overview

### CQRS Pattern Implementation
This system implements Command Query Responsibility Segregation (CQRS) with event-driven architecture:

```
Ticket Purchase Request → PurchaseService (Redis seat locking + SNS event publishing)
                              ↓
                    Amazon SNS Topic → SQS Queue
                              ↓
                   SqsConsumer (async MySQL write)
                              ↓
                   QueryService (MySQL data read)
```

### Technology Stack
- **Java 21** + **Spring Boot 3.x**
- **MySQL 8.x** (primary data store)
- **Redis 7.x** (seat state caching)
- **AWS SNS/SQS** (event messaging)
- **Docker** (containerization)
- **Terraform** (infrastructure as code)

### Service Architecture

| Service | Port | Responsibility | Technologies |
|---------|------|----------------|--------------|
| **PurchaseService** | 8080 | Handle ticket purchases, seat locking, event publishing | Redis + SNS |
| **QueryService** | 8081 | Provide ticket query and analytics APIs | MySQL + JPA |
| **SqsConsumer** | N/A | Consume events and project data to MySQL | SQS + MySQL |

### Infrastructure Components

| Component | Purpose | Data Type |
|-----------|---------|-----------|
| **MySQL (RDS)** | Primary data persistence | Structured ticket data |
| **Redis (ElastiCache)** | Seat state caching and distributed locks | Key-value cache |
| **AWS SNS/SQS** | Event publishing and async consumption | Event messages |

## Services

### PurchaseService (Port 8080)
**Core Responsibility**: Handle all write operations for ticket purchases.

**Key Features**:
- REST API for ticket purchases
- Redis-based seat locking with Lua scripts
- SNS event publishing for eventual consistency
- Input validation and error handling

**Architecture**:
- **Spring Boot Web**: REST API endpoints
- **Spring Data Redis**: Seat state management
- **AWS Spring SNS**: Event publishing
- **Validation**: Request parameter validation

### QueryService (Port 8081)
**Core Responsibility**: Handle all read operations for ticket queries.

**Key Features**:
- REST API for ticket information retrieval
- Multi-dimensional query support
- Revenue and sales analytics
- Optimized read performance

**Architecture**:
- **Spring Boot Web**: REST API endpoints
- **Spring Data JPA**: Data access layer
- **MySQL Connector**: Database connectivity
- **HikariCP**: Connection pooling

### SqsConsumer
**Core Responsibility**: Bridge between write and read sides through event consumption.

**Key Features**:
- Asynchronous event processing
- Data projection to MySQL
- Transactional data consistency
- Dead letter queue handling

**Architecture**:
- **AWS Spring SQS**: Message consumption
- **Spring Data JPA**: Database operations
- **Spring Transactions**: Data consistency
- **Error Handling**: Retry and dead letter mechanisms

## API Documentation

### PurchaseService APIs

#### POST /api/v1/tickets
Purchase a ticket with seat locking and event publishing.

**Request Body**:
```json
{
  "userId": "string",
  "venueId": "string",
  "eventId": "string",
  "zoneId": 1,
  "rowLabel": "A",
  "colLabel": "1"
}
```

**Response**:
```json
{
  "ticketId": "string",
  "status": "CONFIRMED",
  "venueId": "string",
  "eventId": "string",
  "zoneId": 1,
  "rowLabel": "A",
  "colLabel": "1",
  "price": 100.00,
  "createdOn": "2025-11-01T10:00:00Z"
}
```

#### GET /actuator/health
Service health check endpoint.

### QueryService APIs

#### GET /api/v1/health
Service health check.

**Response**:
```json
{
  "status": "UP",
  "endpoints": [
    "/api/v1/tickets/{id}",
    "/api/v1/tickets",
    "/api/v1/tickets/count/{eventId}",
    "/api/v1/tickets/revenue/{venueId}/{eventId}"
  ]
}
```

#### GET /api/v1/tickets/{ticketId}
Get ticket details by ID.

**Response**:
```json
{
  "ticketId": "string",
  "userId": "string",
  "venueId": "string",
  "eventId": "string",
  "zoneId": 1,
  "rowLabel": "A",
  "colLabel": "1",
  "price": 100.00,
  "status": "SOLD",
  "createdOn": "2025-11-01T10:00:00Z"
}
```

#### GET /api/v1/tickets
Get all sold tickets.

**Response**: Array of ticket objects.

#### GET /api/v1/tickets/count/{eventId}
Get ticket sales count for an event.

**Response**:
```json
{
  "eventId": "string",
  "soldCount": 150
}
```

#### GET /api/v1/tickets/revenue/{venueId}/{eventId}
Get revenue for venue and event combination.

**Response**:
```json
{
  "venueId": "string",
  "eventId": "string",
  "totalRevenue": 15000.00
}
```

## Development

### Local Development Environment
```bash
# Start infrastructure services
docker compose up -d

# Build all services
mvn clean package -DskipTests

# Run individual services
mvn spring-boot:run -pl PurchaseService
mvn spring-boot:run -pl QueryService
mvn spring-boot:run -pl RabbitCombinedConsumer
```

### Testing
```bash
# Run unit tests
mvn test

# Run integration tests
mvn verify

# Run with specific profile
mvn spring-boot:run -Dspring-boot.run.profiles=docker
```

### Code Structure
```
├── PurchaseService/          # Command side - ticket purchases
├── QueryService/            # Query side - data retrieval
├── RabbitCombinedConsumer/  # Event consumer - data projection
├── config/
│   ├── terraform/          # AWS infrastructure
│   ├── environment/        # Environment configurations
│   └── scripts/            # Build and deploy scripts
├── docker-compose.yml       # Local development setup
└── pom.xml                  # Parent POM
```

## Deployment

### AWS Deployment Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform 1.6+
- Docker for image building

### Infrastructure Deployment
```bash
# Initialize Terraform
cd config/terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

### Service Deployment
```bash
# Build and push Docker images
./config/scripts/deploy-ecr.sh

# Deploy services to ECS
./config/scripts/deploy-aws.sh
```

### Environment Configuration
Update `config/environment/.env` with your AWS resource endpoints:

```bash
# Database
SPRING_DATASOURCE_URL=jdbc:mysql://your-rds-endpoint:3306/ticket_platform

# Redis
SPRING_DATA_REDIS_HOST=your-elasticache-endpoint

# AWS Services
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=your-account-id
SNS_TOPIC_ARN=arn:aws:sns:us-west-2:your-account-id:ticket.exchange.fifo
```

## Troubleshooting

### Common Issues

#### Service Startup Failures
**Symptoms**: Services fail to start with connection errors.

**Solutions**:
- Check database connectivity: `mysql -h <rds-endpoint> -u <username> -p`
- Verify Redis connection: `redis-cli -h <elasticache-endpoint> ping`
- Check AWS credentials: `aws sts get-caller-identity`
- Review CloudWatch logs for detailed error messages

#### Message Processing Issues
**Symptoms**: Messages not being consumed or processed.

**Solutions**:
- Verify SNS topic and SQS queue exist: `aws sns list-topics`, `aws sqs list-queues`
- Check SQS queue attributes: `aws sqs get-queue-attributes --queue-url <queue-url>`
- Review SQS consumer logs in CloudWatch
- Check dead letter queue for failed messages

#### Terraform Deployment Failures
**Symptoms**: Infrastructure creation fails.

**Solutions**:
- Verify IAM permissions for Terraform operations
- Check VPC and subnet configurations
- Ensure service quotas are sufficient
- Review Terraform state and error messages

### Monitoring and Logging
- **CloudWatch Logs**: All services log to CloudWatch for centralized monitoring
- **Health Endpoints**: Use `/actuator/health` for service health checks
- **Metrics**: Monitor ECS service metrics and RDS/ElastiCache performance

### Performance Tuning
- **Database**: Monitor slow queries and optimize indexes
- **Redis**: Configure appropriate cache TTL and memory limits
- **SQS**: Adjust visibility timeout and batch processing settings
- **ECS**: Scale services based on CPU/memory utilization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
