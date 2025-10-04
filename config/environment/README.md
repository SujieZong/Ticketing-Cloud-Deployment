# Environment Management Guide

## 概述

新的环境管理系统使用**独立环境文件**，确保配置不会丢失或被覆盖。

## 文件结构

```
config/environment/
├── .env                 # 当前活动配置（自动生成）
├── .env.docker          # Docker 本地环境
├── .env.aws             # AWS 云环境
├── .env.backup          # 自动备份
├── switch-env.sh        # 环境切换脚本
└── .gitignore          # Git 忽略规则
```

## 环境切换

### 基本命令

```bash
# 切换到 Docker 本地环境
./config/environment/switch-env.sh local
# 或者
./config/environment/switch-env.sh docker

# 切换到 AWS 云环境
./config/environment/switch-env.sh aws

# 查看当前环境
./config/environment/switch-env.sh status
```

### 集成部署

```bash
# 直接在部署时切换环境
./composeUp.sh --env local
./composeUp.sh --env aws --verbose
```

## 环境说明

### Docker 本地环境 (.env.docker)
- **用途**：本地开发和测试
- **服务**：Docker Compose 容器
- **特点**：
  - MySQL: `mysql:3306` (root/root)
  - Redis: `redis:6379`
  - RabbitMQ: `rabbitmq:5672` (guest/guest)
  - 无需外部依赖

### AWS 云环境 (.env.aws)
- **用途**：云端部署
- **服务**：AWS 托管服务
- **特点**：
  - RDS MySQL
  - ElastiCache Redis
  - Amazon MQ (RabbitMQ)
  - 需要配置 AWS 凭据

## 安全性

### ✅ 新系统优势：
1. **配置隔离**：每个环境独立文件，不会相互覆盖
2. **自动备份**：切换前自动备份当前配置
3. **版本控制**：`.env.docker` 和 `.env.aws` 可提交到 Git
4. **可恢复性**：随时可以完全恢复到任何环境

### 🔒 敏感信息处理：
- `.env` 在 `.gitignore` 中，不会提交到 Git
- AWS 凭据模板化，需要手动填入真实值
- 支持环境变量引用 (`${AWS_RDS_PASSWORD}`)

## 工作流程

### 开发流程：
```bash
# 1. 本地开发
./config/environment/switch-env.sh local
./composeUp.sh

# 2. AWS 测试
./config/environment/switch-env.sh aws
# 编辑 .env.aws 填入真实 AWS 凭据
./composeUp.sh --verbose

# 3. 回到本地
./config/environment/switch-env.sh local
```

### 部署流程：
```bash
# 一步部署到指定环境
./composeUp.sh --env aws --verbose
```

## 故障排除

### 恢复配置：
```bash
# 如果配置出错，恢复备份
cp config/environment/.env.backup config/environment/.env

# 或者重新切换到原环境
./config/environment/switch-env.sh local
```

### 检查配置：
```bash
# 查看当前环境
./config/environment/switch-env.sh status

# 查看具体配置
cat config/environment/.env | grep -E "(DEPLOYMENT_ENV|SPRING_DATASOURCE_URL|SPRING_DATA_REDIS_HOST)"
```

## 迁移说明

### 从旧系统迁移：
- ✅ 删除了所有 Kafka/DynamoDB 配置
- ✅ 移除了复杂的变量替换逻辑
- ✅ 简化为 Docker vs AWS 两个环境
- ✅ 配置文件清晰易懂

### 新增功能：
- ✅ 环境状态检查
- ✅ 详细的切换反馈
- ✅ 自动配置验证
- ✅ 集成到部署脚本