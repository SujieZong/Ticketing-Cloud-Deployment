# 快速启动指南

## 仅运行项目（推荐）
**环境要求**：
- **Docker Desktop** (包含 Docker Engine 和 Compose)

```bash
# macOS 安装 Docker
brew install --cask docker      # Docker Desktop

# 克隆并启动项目
git clone <your-repo-url>
cd cs6620-Rabbit-ticket
chmod +x composeUp.sh composeDown.sh
./composeUp.sh                   # 自动构建并启动所有服务
```

## 开发环境（修改代码）
**额外环境要求**：
- **Java 21** (JDK 21 LTS) 
- **Maven 3.8+**

```bash
# macOS 安装开发工具
brew install --cask temurin     # Java 21（仅开发需要）
brew install maven              # Maven（仅开发需要）

# 本地构建和测试
mvn clean package -DskipTests   # 构建项目
mvn test                        # 运行测试
```

## 验证服务
```bash
# 等待约 1-2 分钟后验证
curl http://localhost:8081/api/v1/health    # QueryService 健康检查
curl http://localhost:8080/actuator/health  # PurchaseService 健康检查

# RabbitMQ 管理界面
open http://localhost:15672  # guest/guest
```

## 停止服务
```bash
./composeDown.sh
```

## 故障排查
- **端口占用**: 确保 8080/8081/3306/6379/5672/15672 端口空闲
- **Docker 问题**: 确保 Docker Desktop 正在运行
- **构建失败**: 如需修改代码，请安装 Java 21 和 Maven
- **查看日志**: `docker-compose logs -f <service-name>`

---

# 高并发票务平台 - CQRS 架构

## 项目概述
采用 CQRS 模式的高并发票务系统，实现读写分离和事件驱动架构。

**数据流向**：
```
购票请求 → PurchaseService（Redis 座位锁定 + RabbitMQ 事件发布）
             ↓
         RabbitConsumer（消费事件并写入 MySQL）
             ↓
         QueryService（从 MySQL 读取数据）
```

**核心技术栈**：Java 21 + Spring Boot 3.x + MySQL 8.x + Redis 7.x + RabbitMQ 3

## 系统架构设计

### CQRS 分离原理
- **命令侧（写）**: PurchaseService 负责处理购票请求，使用 Redis 进行座位状态管理和锁定，通过 RabbitMQ 发布事件
- **查询侧（读）**: QueryService 负责提供各种查询接口，直接从 MySQL 读取数据
- **事件投影**: RabbitConsumer 监听消息队列，将事件数据异步写入 MySQL，实现最终一致性

### 服务架构

#### 核心业务服务
| 服务 | 端口 | 职责说明 | 主要技术 |
|------|------|----------|----------|
| **PurchaseService** | 8080 | 处理购票请求，座位锁定，事件发布 | Redis + RabbitMQ |
| **QueryService** | 8081 | 提供票务查询和统计功能 | MySQL + JPA |
| **RabbitConsumer** | - | 消费事件，数据投影到 MySQL | RabbitMQ + MySQL |

#### 基础设施组件
| 组件 | 端口 | 作用说明 | 数据类型 |
|------|------|----------|----------|
| **MySQL** | 3306 | 主数据存储，持久化票务信息 | 结构化数据 |
| **Redis** | 6379 | 座位状态缓存，分布式锁 | 键值缓存 |
| **RabbitMQ** | 5672/15672 | 消息队列，解耦服务通信 | 事件消息 |

## API 接口说明

### PurchaseService - 购票服务 (8080)
**核心职责**：处理所有购票相关的写操作，是整个系统的命令入口。

**为什么这样设计**：
- 不直接操作 MySQL，避免写操作阻塞读操作
- 使用 Redis 实现快速座位状态检查和锁定
- 通过 RabbitMQ 异步通知其他服务，提高响应速度

**技术架构**：
- **Spring Boot Web**: 提供 REST API 接口
- **Spring Data Redis**: 座位状态缓存和分布式锁
- **Spring AMQP**: RabbitMQ 消息发布
- **Validation**: 请求参数校验

**核心接口详解**：
```
POST /api/v1/tickets              # 购买票据 - 核心业务接口
  请求体：TicketPurchaseRequestDTO (包含用户ID、场馆ID、座位信息等)
  处理流程：
  └─ 1. 数据验证：检查请求参数完整性和格式
  └─ 2. 座位检查：Redis 查询座位是否可用
  └─ 3. 原子锁定：使用 Lua 脚本确保座位锁定的原子性
  └─ 4. 事件发布：将购票事件发送到 RabbitMQ
  └─ 5. 快速响应：立即返回购票结果，不等待数据库写入
  响应体：TicketRespondDTO (包含票据ID、状态、座位信息等)

GET  /actuator/health             # Spring Boot 健康检查
  返回：服务运行状态、依赖组件(Redis、RabbitMQ)连接状态
```

**关键实现细节**：
- **座位锁定策略**: 使用 Redis Lua 脚本保证检查和锁定的原子性，防止并发冲突
- **事件发布**: 采用发布-确认模式，确保消息成功投递到 RabbitMQ
- **错误处理**: 座位不可用、系统异常等情况的优雅处理

---

### QueryService - 查询服务 (8081)
**核心职责**：提供所有票务相关的读操作，是系统的查询入口。

**为什么这样设计**：
- 专注于读操作，优化查询性能
- 直接从 MySQL 读取完整的业务数据
- 提供多维度的数据查询和统计功能

**技术架构**：
- **Spring Boot Web**: 提供 REST API 接口
- **Spring Data JPA**: ORM 数据访问层
- **MySQL Connector**: 数据库连接
- **HikariCP**: 高性能连接池

**核心接口详解**：
```
GET /api/v1/health                          # 服务健康检查
  返回：服务状态、数据库连接状态、可用端点列表

GET /api/v1/tickets/{ticketId}              # 查询单张票详情
  路径参数：ticketId (票据唯一标识)
  返回：TicketInfoDTO (完整的票据信息，包括用户、场馆、座位、价格等)
  异常处理：票据不存在返回 404

GET /api/v1/tickets                         # 获取所有已售票据列表  
  返回：List<TicketInfoDTO> (所有已售票据的集合)
  注意：当前无分页，适合小数据量场景

GET /api/v1/tickets/count/{eventId}         # 按事件统计售票数量
  路径参数：eventId (活动ID)
  返回：已售票据数量统计
  用途：活动热度分析、库存管理

GET /api/v1/tickets/revenue/{venueId}/{eventId}  # 收入统计
  路径参数：venueId (场馆ID), eventId (活动ID)
  返回：该场馆该活动的总收入金额
  用途：财务报表、收益分析
```

**数据模型**：
- **TicketInfo Entity**: 票据主实体，包含所有业务字段
- **DTO 转换**: 使用 MapStruct 进行 Entity 和 DTO 的转换
- **数据库设计**: 优化索引，支持高效的多维度查询

---

### RabbitConsumer - 事件消费服务
**核心职责**：连接写入侧和读取侧，实现数据的异步投影。

**为什么需要这个服务**：
- **解耦架构**: PurchaseService 不需要关心数据持久化细节
- **异步处理**: 用户购票后立即得到响应，数据库写入在后台进行
- **最终一致性**: 保证写入侧的事件最终反映到读取侧的数据库中

**技术架构**：
- **Spring AMQP**: RabbitMQ 消息消费
- **Spring Data JPA**: 数据库写入操作
- **Spring Transaction**: 事务管理，保证数据一致性

**工作流程详解**：
```
1. 消息监听
   └─ 监听 RabbitMQ 中的购票事件队列
   └─ 使用 @RabbitListener 注解自动消费消息

2. 数据转换
   └─ 将消息中的事件数据转换为 TicketInfo 实体
   └─ 验证数据完整性和业务规则

3. 数据库写入
   └─ 使用 JPA Repository 将数据持久化到 MySQL
   └─ 在事务中执行，保证数据一致性

4. 异常处理
   └─ 消息消费失败时的重试机制
   └─ 死信队列处理无法消费的消息
   └─ 幂等性保证：重复消息不会产生重复数据
```

**关键实现细节**：
- **消息确认机制**: 只有成功写入数据库后才确认消息消费
- **事务管理**: 使用 Spring @Transactional 保证数据库操作的原子性
- **错误恢复**: 消费失败的消息会重新入队，支持重试
- **监控日志**: 详细记录消息处理过程，便于问题排查

**数据流示例**：
```
购票事件 (JSON) → 消息队列 → RabbitConsumer → TicketInfo 实体 → MySQL 数据库
```

---

### 微服务协作流程

**完整购票流程**：
```
1. 用户发起购票请求 → PurchaseService
2. PurchaseService 验证参数 → Redis 检查座位
3. Redis 原子锁定座位 → 发布事件到 RabbitMQ
4. PurchaseService 立即响应用户：购票成功
5. RabbitConsumer 异步消费事件 → 写入 MySQL
6. 用户稍后查询票据详情 → QueryService → MySQL
```

**服务间依赖关系**：
- **PurchaseService**: 依赖 Redis (座位状态) + RabbitMQ (事件发布)
- **QueryService**: 依赖 MySQL (数据查询)
- **RabbitConsumer**: 依赖 RabbitMQ (事件消费) + MySQL (数据写入)

**容错机制**：
- Redis 不可用 → PurchaseService 降级，拒绝购票请求
- RabbitMQ 不可用 → PurchaseService 无法发布事件，购票失败
- MySQL 不可用 → QueryService 返回服务暂不可用，RabbitConsumer 消息重试
