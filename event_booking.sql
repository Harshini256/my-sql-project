create database event_ticket_db;
use event_ticket_db;
show tables;
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15)
);

CREATE TABLE events (
    event_id INT PRIMARY KEY AUTO_INCREMENT,
    event_name VARCHAR(100) NOT NULL,
    event_date DATE NOT NULL,
    venue VARCHAR(100),
    ticket_price DECIMAL(10,2) NOT NULL,
    total_tickets INT NOT NULL,
    available_tickets INT NOT NULL,
    CHECK (ticket_price >= 0),
    CHECK (total_tickets >= 0),
    CHECK (available_tickets >= 0),
    CHECK (available_tickets <= total_tickets)
);

desc events;

CREATE TABLE bookings (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    event_id INT NOT NULL,
    tickets_booked INT NOT NULL,
    booking_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    booking_status VARCHAR(20) DEFAULT 'CONFIRMED',
    total_amount DECIMAL(10,2) NOT NULL,

    FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),

    FOREIGN KEY (event_id)
        REFERENCES events(event_id),

    CHECK (tickets_booked > 0),
    CHECK (total_amount >= 0)
);

desc bookings;

CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    payment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(30) NOT NULL,
    payment_amount DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'PENDING',

    FOREIGN KEY (booking_id)
        REFERENCES bookings(booking_id),

    CHECK (payment_amount >= 0)
);
desc payments;

insert into customers(customer_name,email,phone)
values
('Harshini', 'harshini@gmail.com',9182550630),
('Bhagya','bhagi@gmail.com',9152643728),
('Sneha','sneha@gmail.com',6301542359),
('Yasaswini','yashu@gmail.com',9876543210),
('Pravalika','pravali@gmail.com',6281568219);

select*from customers;

insert into events
(event_name, event_date, venue, ticket_price,
 total_tickets, available_tickets)
values
('Hackathon', '2026-11-15', 'Codegnan', 500, 100, 100),
('Music Concert', '2026-11-20', 'Beach Road', 1200, 200, 200),
('College fest', '2026-11-25', 'Au Grounds', 300, 150, 150),
('AI Conference', '2026-12-05', 'Au convention center', 800, 120, 120),
('Dance Show', '2026-12-10', 'Open Auditorium', 400, 80, 80);

select*from events;


INSERT INTO bookings
(customer_id, event_id, tickets_booked, booking_status, total_amount)
VALUES
(1, 1, 2, 'CONFIRMED', 1000.00),
(2, 2, 1, 'CONFIRMED', 1200.00),
(3, 3, 3, 'CONFIRMED', 900.00),
(4, 4, 2, 'CONFIRMED', 1600.00),
(5, 1, 1, 'CONFIRMED', 500.00),
(1, 5, 2, 'CONFIRMED', 800.00),
(2, 5, 2, 'CONFIRMED', 800.00),
(2, 5, 1, 'CANCELLED', 400.00);



UPDATE events e
SET e.available_tickets = e.total_tickets - (
    SELECT COALESCE(SUM(b.tickets_booked), 0)
    FROM bookings b
    WHERE b.event_id = e.event_id
      AND b.booking_status = 'CONFIRMED'
)
WHERE e.event_id > 0;


SELECT
    event_name,
    total_tickets,
    available_tickets
FROM events;


INSERT INTO payments
(booking_id, payment_method, payment_amount, payment_status)
VALUES
(1, 'UPI', 1000.00, 'PAID'),
(2, 'CARD', 1200.00, 'PAID'),
(3, 'CASH', 900.00, 'PENDING'),
(4, 'UPI', 1600.00, 'PAID'),
(5, 'CARD', 500.00, 'PAID'),
(6, 'UPI', 800.00, 'PENDING'),
(7, 'UPI', 800.00, 'PENDING');

SELECT * FROM bookings;
SELECT * FROM payments;

SELECT event_name, total_tickets, available_tickets
FROM events;

CREATE VIEW booking_details AS
SELECT
    b.booking_id,
    c.customer_name,
    e.event_name,
    b.tickets_booked,
    b.booking_date,
    b.booking_status,
    b.total_amount
FROM bookings b
JOIN customers c
    ON b.customer_id = c.customer_id
JOIN events e
    ON b.event_id = e.event_id;
    
    
select*from booking_details;


SHOW full tables
WHERE table_type = 'VIEW';


CREATE INDEX idx_booking_date
ON bookings(booking_date);


SHOW INDEX FROM bookings;


SELECT *
FROM bookings
WHERE booking_date >= '2026-11-01';


SELECT booking_id, booking_date
FROM bookings;

 -- creation of stored procedure
 
 
DELIMITER //

CREATE PROCEDURE GetCustomerBookings(
    IN p_customer_id INT
)
BEGIN
    SELECT
        b.booking_id,
        c.customer_name,
        e.event_name,
        b.tickets_booked,
        b.booking_status,
        b.total_amount
    FROM bookings b
    JOIN customers c
        ON b.customer_id = c.customer_id
    JOIN events e
        ON b.event_id = e.event_id
    WHERE b.customer_id = p_customer_id;
END //

DELIMITER ;


call GetCustomerBookings(1);


DELIMITER //

CREATE PROCEDURE BookTickets(
    IN p_customer_id INT,
    IN p_event_id INT,
    IN p_tickets INT
)
BEGIN
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_available INT;
    DECLARE v_total DECIMAL(10,2);
    DECLARE v_booking_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_tickets <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tickets must be greater than zero';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM customers
        WHERE customer_id = p_customer_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer does not exist';
    END IF;

    SELECT ticket_price, available_tickets
    INTO v_price, v_available
    FROM events
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF v_available IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Event does not exist';
    END IF;

    IF p_tickets > v_available THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Not enough tickets available';
    END IF;

    SET v_total = v_price * p_tickets;

    INSERT INTO bookings (
        customer_id,
        event_id,
        tickets_booked,
        booking_status,
        total_amount
    )
    VALUES (
        p_customer_id,
        p_event_id,
        p_tickets,
        'CONFIRMED',
        v_total
    );

    SET v_booking_id = LAST_INSERT_ID();

    UPDATE events
    SET available_tickets = available_tickets - p_tickets
    WHERE event_id = p_event_id;

    COMMIT;

    SELECT
        'Booking successful' AS message,
        v_booking_id AS booking_id,
        v_total AS total_amount;
END //

DELIMITER ;


SELECT event_id, event_name, ticket_price, available_tickets
FROM events;



CALL BookTickets(1, 1, 2);

SELECT * FROM bookings
ORDER BY booking_id DESC;

SELECT event_id, event_name, available_tickets
FROM events;

SELECT
    booking_id,
    customer_id,
    event_id,
    tickets_booked,
    booking_status,
    total_amount
FROM bookings
ORDER BY booking_id DESC
LIMIT 1;

SELECT
    event_name,
    total_tickets,
    available_tickets
FROM events
WHERE event_id = 1;

CALL BookTickets(1, 1, 2);

SELECT event_name, total_tickets, available_tickets
FROM events
WHERE event_id = 1;

SELECT booking_id, event_id, tickets_booked, total_amount
FROM bookings
ORDER BY booking_id DESC
LIMIT 3;

-- creation of triggers


DELIMITER //

CREATE TRIGGER check_ticket_availability
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_available INT;

    SELECT available_tickets
    INTO v_available
    FROM events
    WHERE event_id = NEW.event_id;

    IF NEW.booking_status = 'CONFIRMED'
       AND NEW.tickets_booked > v_available THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Not enough tickets available';
    END IF;
END //

DELIMITER ;

show triggers;

SELECT event_id, event_name, available_tickets
FROM events
WHERE event_id = 1;

INSERT INTO bookings
(customer_id, event_id, tickets_booked, booking_status, total_amount)
VALUES
(1, 1, 999999, 'CONFIRMED', 499999500.00);

SELECT DATABASE();
SHOW TABLES;

desc events;
desc bookings;

show triggers;


INSERT INTO bookings
(customer_id, event_id, tickets_booked, booking_status, total_amount)
VALUES
(1, 1, 999999, 'CONFIRMED', 499999500.00);


DELIMITER //

CREATE TRIGGER restore_cancelled_tickets
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
    IF OLD.booking_status = 'CONFIRMED'
       AND NEW.booking_status = 'CANCELLED' THEN

        UPDATE events
        SET available_tickets = available_tickets + OLD.tickets_booked
        WHERE event_id = OLD.event_id;

    END IF;
END //

DELIMITER ;

show triggers;


DELIMITER //

CREATE TRIGGER validate_payment_amount
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    IF NEW.payment_amount < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment amount cannot be negative';
    END IF;
END //

DELIMITER ;

show triggers;


SELECT
    booking_id,
    event_id,
    tickets_booked,
    booking_status
FROM bookings
WHERE booking_id = 1;


SELECT event_name, total_tickets, available_tickets
FROM events
WHERE event_id = 1;
UPDATE bookings
SET booking_status = 'CANCELLED'
WHERE booking_id = 1;

SELECT booking_id, booking_status
FROM bookings
WHERE booking_id = 1;

SELECT event_name, available_tickets
FROM events
WHERE event_id = 1;



SHOW FULL TABLES
WHERE Table_type = 'VIEW';

select*from booking_details;

 -- Show customer names and their events:
 
 
SELECT
    c.customer_name,
    e.event_name,
    b.tickets_booked,
    b.total_amount
FROM bookings b
INNER JOIN customers c
    ON b.customer_id = c.customer_id
INNER JOIN events e
    ON b.event_id = e.event_id;
    
 -- Show only confirmed bookings:
 
 
SELECT
    c.customer_name,
    e.event_name,
    b.tickets_booked,
    b.total_amount
FROM bookings b
INNER JOIN customers c
    ON b.customer_id = c.customer_id
INNER JOIN events e
    ON b.event_id = e.event_id
WHERE b.booking_status = 'CONFIRMED';


 -- using group by:
SELECT
    e.event_name,
    COUNT(b.booking_id) AS total_bookings
FROM events e
INNER JOIN bookings b
    ON e.event_id = b.event_id
GROUP BY e.event_id, e.event_name;

 -- using having:
 
 
SELECT
    e.event_name,
    COUNT(b.booking_id) AS confirmed_bookings
FROM events e
INNER JOIN bookings b
    ON e.event_id = b.event_id
WHERE b.booking_status = 'CONFIRMED'
GROUP BY e.event_id, e.event_name
HAVING COUNT(b.booking_id) > 1;


SELECT customer_id, customer_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM bookings
    WHERE booking_status = 'CONFIRMED'
);

 -- Find events priced above the average:
 
 
SELECT event_name, ticket_price
FROM events
WHERE ticket_price > (
    SELECT AVG(ticket_price)
    FROM events
);

SELECT event_name, ticket_price
FROM events
WHERE event_id = 1;

 -- transactions — COMMIT and ROLLBACK:
 
 START TRANSACTION;
UPDATE events
SET ticket_price = 999
WHERE event_id = 1;

ROLLBACK;

SELECT event_name, ticket_price
FROM events
WHERE event_id = 1;

ROLLBACK;

SELECT event_name, ticket_price
FROM events
WHERE event_id = 1;

UPDATE events
SET ticket_price = 500.00
WHERE event_id = 1;

SELECT event_name, ticket_price
FROM events
WHERE event_id = 1;

SHOW PROCEDURE STATUS
WHERE Db = 'event_ticket_db';

CALL GetCustomerBookings(1);

SHOW TRIGGERS;

SHOW FULL TABLES
WHERE Table_type = 'VIEW';

SHOW TABLES;

SHOW TRIGGERS;
CALL GetCustomerBookings(1);
SHOW FULL TABLES
WHERE Table_type = 'VIEW';



SELECT
    e.event_id,
    e.event_name,
    e.total_tickets,
    e.available_tickets,
    COALESCE(
        SUM(
            CASE
                WHEN b.booking_status = 'CONFIRMED'
                THEN b.tickets_booked
                ELSE 0
            END
        ), 0
    ) AS confirmed_tickets
FROM events e
LEFT JOIN bookings b
    ON e.event_id = b.event_id
GROUP BY
    e.event_id,
    e.event_name,
    e.total_tickets,
    e.available_tickets
ORDER BY e.event_id;

SHOW PROCEDURE STATUS
WHERE Db = 'event_ticket_db';






 
 






