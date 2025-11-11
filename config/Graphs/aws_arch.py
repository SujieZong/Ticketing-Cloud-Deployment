# file: network_boundaries_v3.py
# Requires: pip install diagrams ; local Graphviz installed

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.general import InternetAlt2
from diagrams.aws.network import ALB, InternetGateway, RouteTable
from diagrams.aws.compute import Fargate
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.integration import SNS, SQS
from diagrams.aws.security import Shield  # 用作 SG 图标

with Diagram(
    "Ticketing - Network Boundaries (us-west-2)",
    filename="network_boundaries_v3",
    show=False,
    direction="LR",
):
    internet = InternetAlt2("Internet")

    # ================= Region / Account / VPC（仅 Public 子网） =================
    with Cluster("Region: us-west-2"):
        with Cluster("AWS Account"):
            with Cluster("Default VPC 172.31.0.0/16  (Public Subnets Only)"):
                # 可选：把 IGW/RTB 用虚线表示“控制层/路由”，不影响核心链路可读性
                igw = InternetGateway("IGW")
                rtb_public = RouteTable("Public RT\n0.0.0.0/0 → IGW")

                # 入口：ALB + SG（内联）
                sg_alb = Shield("ALB-SG\n80/443 from 0.0.0.0/0")
                alb = ALB("Application Load Balancer :80/:443")

                # 应用：ECS + SG（内联）
                sg_ecs = Shield("ECS-SG\n:8080 from ALB-SG")
                with Cluster("ECS Fargate Services (:8080)"):
                    svc_query = Fargate("QueryService")
                    svc_purchase = Fargate("PurchaseService")
                    svc_projector = Fargate("MessagePersistenceService")

                # 数据：RDS/Redis + 各自 SG（内联）
                sg_rds = Shield("RDS-SG\n:3306 from ECS-SG")
                rds = RDS("Aurora MySQL :3306\n(single instance)")

                sg_redis = Shield("REDIS-SG\n:6379 from ECS-SG")
                redis = ElastiCache("Redis :6379\n(single node)")

                # 集成：SNS / SQS（无 SG 概念）
                with Cluster("Messaging"):
                    sns = SNS("SNS Topic: ticket-events")
                    sqs = SQS("SQS Queue: ticket-sql")

    # ========================== 流量路径（把 SG 放进链路） ==========================
    # Internet -> (ALB-SG) -> ALB
    internet >> Edge(label="HTTPS 443") >> sg_alb >> alb

    # ALB -> (ECS-SG) -> ECS Services
    alb >> Edge(label="HTTP 8080") >> sg_ecs
    sg_ecs >> svc_query
    sg_ecs >> svc_purchase
    sg_ecs >> svc_projector

    # Query / Projector -> (RDS-SG) -> RDS
    svc_query >> Edge(color="green", label=":3306") >> sg_rds >> rds
    svc_projector >> Edge(color="orange", label=":3306") >> sg_rds >> rds

    # Purchase -> (REDIS-SG) -> Redis
    svc_purchase >> Edge(color="blue", label=":6379") >> sg_redis >> redis

    # 消息链路：Purchase -> SNS -> SQS -> Projector
    svc_purchase >> Edge(color="red", label="Publish") >> sns
    sns >> Edge(color="red", label="Fan-out") >> sqs
    sqs >> Edge(color="red", label="Consume") >> svc_projector

    # ============= 可选的“控制/路由面”虚线路径，帮助定位但不干扰主视图 =============
    internet >> Edge(style="dotted") >> igw
    igw >> Edge(style="dotted") >> rtb_public
