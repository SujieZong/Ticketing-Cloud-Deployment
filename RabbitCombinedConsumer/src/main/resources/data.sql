-- 初始化测试数据
-- 这个文件会在Spring Boot启动时自动执行

-- 1. 插入测试场馆
INSERT INTO venue (venue_id, city) VALUES ('Venue1', 'Shanghai'), ('venue-test', 'Beijing') ON DUPLICATE KEY UPDATE city=VALUES(city);

-- 2. 插入测试分区
INSERT INTO zone (venue_id, zone_id, ticket_price, row_count, col_count) VALUES ('Venue1', 1, 100.00, 10, 20), ('Venue1', 2, 150.00, 8, 15), ('venue-test', 1, 80.00, 12, 25) ON DUPLICATE KEY UPDATE ticket_price=VALUES(ticket_price), row_count=VALUES(row_count), col_count=VALUES(col_count);

-- 3. 插入测试事件
INSERT INTO event (event_id, venue_id, name, type, event_date) VALUES ('Event1', 'Venue1', 'Spring Concert 2025', 'Concert', '2025-12-25'), ('event-test', 'venue-test', 'Test Event', 'Test', '2025-11-15') ON DUPLICATE KEY UPDATE name=VALUES(name), type=VALUES(type), event_date=VALUES(event_date);