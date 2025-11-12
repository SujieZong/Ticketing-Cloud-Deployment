-- 1. Insert venues
INSERT INTO venue (venue_id, city)
VALUES ('Venue1', 'Shanghai'), ('venue-test', 'Beijing')
AS new
ON DUPLICATE KEY UPDATE city = new.city;

-- 2. Insert Zones
INSERT INTO zone (venue_id, zone_id, ticket_price, row_count, col_count)
VALUES ('Venue1', 1, 100.00, 10, 20), ('Venue1', 2, 150.00, 8, 15), ('venue-test', 1, 80.00, 12, 25)
AS new
ON DUPLICATE KEY UPDATE ticket_price = new.ticket_price, row_count = new.row_count, col_count = new.col_count;

-- 3. Insert Events
INSERT INTO event (event_id, venue_id, name, type, event_date)
VALUES ('Event1', 'Venue1', 'Spring Concert 2025', 'Concert', '2025-12-25'), ('event-test', 'venue-test', 'Test Event', 'Test', '2025-11-15')
AS new
ON DUPLICATE KEY UPDATE name = new.name, type = new.type, event_date = new.event_date;