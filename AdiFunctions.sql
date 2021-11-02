-- Core Functions
DROP FUNCTION IF EXISTS 
    leave_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    search_room(INTEGER, DATE, INTEGER, INTEGER),
    book_room(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER),
    unbook_room(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER),
    join_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    leave_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    approve_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER);

-- Search Room
CREATE OR REPLACE FUNCTION search_room(IN capacity INT, IN date DATE, IN start_hour INT, IN end_hour INT)
RETURNS TABLE(room INT, floor INT, did INT, capacity INT) AS $$
    SELECT m1.room, m1.floor, m1.did, u1.new_cap 
    FROM Meeting_Rooms m1 NATURAL JOIN Updates u1
    WHERE u1.date = (
        SELECT MAX(u2.date) FROM Updates u2 
    ) AND u1.new_cap >= capacity AND NOT EXISTS (
        SELECT 1 FROM Approves a1
        WHERE (a1.time = start_hour OR (a1.time > start_hour AND a1.time < end_hour)) AND
        a1.date = date AND
        a1.room = m1.room AND
        a1.floor = m1.floor
    ) ORDER BY u1.new_cap;
$$ LANGUAGE sql;

-- Book Room
CREATE OR REPLACE FUNCTION book_room(IN floor INT, IN room INT, IN date DATE, 
    IN start_hour INT, IN end_hour INT, IN eid INT) 
RETURNS VOID AS $$
DECLARE
    hour INT := start_hour;
BEGIN
    WHILE hour < end_hour LOOP
        INSERT INTO Sessions VALUES (hour, date, room, floor, eid);
        hour := hour + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Unbook Room
CREATE OR REPLACE FUNCTION unbook_room(IN bookingFloor INT, IN bookingRoom INT, IN bookingDate DATE, 
    IN start_hour INT, IN end_hour INT, IN eid INT)
RETURNS VOID AS $$
DECLARE
    hour INT := start_hour;
BEGIN
    WHILE hour < end_hour LOOP
        DELETE FROM Sessions s1 WHERE (
            s1.time = hour AND
            s1.date = bookingDate AND
            s1.room = bookingRoom AND
            s1.floor = bookingFloor AND
            s1.b_eid = eid
        );
        DELETE FROM Approves a1 WHERE (
            a1.time = hour AND
            a1.date = bookingDate AND
            a1.room = bookingRoom AND
            a1.floor = bookingFloor AND
            a1.b_eid = eid
        );
        hour := hour + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Join Meeting
CREATE OR REPLACE FUNCTION join_meeting(IN floor INT, IN room INT, IN date DATE,
    IN start_hour INT, IN end_hour INT, IN b_eid INT, IN eid INT)
RETURNS VOID AS $$
DECLARE
    hour INT := start_hour;
BEGIN
    WHILE hour < end_hour LOOP
        INSERT INTO Joins VALUES (hour, date, room, floor, b_eid, eid);
        hour := hour + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Leave Meeting
CREATE OR REPLACE FUNCTION leave_meeting(IN meetingFloor INT, IN meetingRoom INT, IN meetingDate DATE,
    IN start_hour INT, IN end_hour INT, IN meeting_b_eid INT, IN eid INT)
RETURNS VOID AS $$
DECLARE
    hour INT := start_hour;
BEGIN
    WHILE hour < end_hour LOOP
        DELETE FROM Joins j1 WHERE (
            j1.time = hour AND
            j1.date = meetingDate AND
            j1.room = meetingRoom AND
            j1.floor = meetingFloor AND
            j1.b_eid = meeting_b_eid AND
            j1.e_eid = eid
        );
        hour := hour + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Approve Meeting
CREATE OR REPLACE FUNCTION approve_meeting(IN floor INT, IN room INT, IN date DATE,
    IN start_hour INT, IN end_hour INT, IN b_eid INT, IN m_eid INT)
RETURNS VOID AS $$
DECLARE
    hour INT := start_hour;
BEGIN
    WHILE hour < end_hour LOOP
        INSERT INTO Approves VALUES (hour, date, room, floor, b_eid, m_eid);
    END LOOP;
END;
$$ LANGUAGE plpgsql;