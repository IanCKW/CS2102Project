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
        DELETE FROM Approves a1 WHERE (
            a1.time = hour AND
            a1.date = bookingDate AND
            a1.room = bookingRoom AND
            a1.floor = bookingFloor AND
            a1.b_eid = eid
        );
        DELETE FROM Sessions s1 WHERE (
            s1.time = hour AND
            s1.date = bookingDate AND
            s1.room = bookingRoom AND
            s1.floor = bookingFloor AND
            s1.b_eid = eid
        );
        hour := hour + 1;
    END LOOP;
    RAISE NOTICE 'Room Unbooked';
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
        hour := hour + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;





CREATE OR REPLACE FUNCTION add_department(IN did INT, IN departmentname TEXT)
RETURNS VOID AS $$
BEGIN
INSERT INTO departments values (did, departmentname);
RAISE NOTICE 'Department added';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_department(departmentID integer)
RETURNS VOID AS $$
BEGIN
DELETE FROM departments where departments.did = departmentID;
RAISE NOTICE 'Department removed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_room(room1 INTEGER,floor1 INTEGER,rname1 text ,did1 INTEGER, cap1 INTEGER , date1 DATE, m_eid1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Meeting_Rooms (room, floor, rname, did) values (room1, floor1, rname1, did1);
INSERT INTO Updates (date,new_cap, room, floor, m_eid) values (date1, cap1,room1,floor1,m_eid1 );
RAISE NOTICE 'Room added, Capacity updated';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_capacity(room1 INTEGER,floor1 INTEGER, cap1 INTEGER, date1 DATE, m_eid1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Updates (date,new_cap, room, floor, m_eid) values (date1, cap1, room1,floor1,m_eid1 );
RAISE NOTICE 'Room Capacity Changed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_employee(ename1 TEXT, did1 INTEGER ,contact1 INTEGER,home_contact1 INTEGER,office_contact1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Employees (ename,resigned_date,did,contact,home_contact,office_contact) VALUES (ename1,NULL,did1,contact1,home_contact1,office_contact1);
RAISE NOTICE 'Employee added';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION remove_employee(employeeId INTEGER, gonedate DATE)
RETURNS VOID AS $$
BEGIN
UPDATE Employees SET resigned_date = gonedate WHERE eid = employeeID;
RAISE NOTICE 'Employee removed';
END;
$$ LANGUAGE plpgsql;




--- Note that FUNC contact_tracing is in the IanTrigger.sql

---DECLARE HEALTH ---
CREATE OR REPLACE FUNCTION declare_health(eid1 INT, date1 DATE, temp1 FLOAT)
RETURNS VOID AS $$
BEGIN
INSERT INTO Health_Declarations (eid,date,temp) VALUES (eid1,date1,temp1);
END;
$$ LANGUAGE plpgsql;

-- NON_COMPLIANCE ROUTINE --
CREATE OR REPLACE FUNCTION non_compliance(IN start_date DATE, IN end_date DATE)
RETURNS TABLE(id INT, c FLOAT) AS $$

    SELECT e.eid AS id, extract(day FROM end_date::timestamp - start_date::timestamp) - count(h.eid) + 1 AS c
    FROM Employees e 
    LEFT OUTER JOIN  
    (SELECT * FROM Health_Declarations h1 WHERE h1.date >= START_DATE AND h1.date <= end_date)
    AS h ON e.eid = h.eid
    GROUP BY e.eid;

$$ LANGUAGE sql ;



DROP FUNCTION IF EXISTS check_approval_status(INTEGER, DATE, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS view_booking_report(DATE, INTEGER);
DROP FUNCTION IF EXISTS view_future_meeting(DATE, INTEGER);
DROP FUNCTION IF EXISTS view_manager_report(DATE, INTEGER);

--find all meeting-rooms + their approval-status booked by this employee from the given date onwards
CREATE OR REPLACE FUNCTION check_approval_status(IN meeting_time INT, IN meeting_date DATE, IN meeting_room INT, IN meeting_floor INT, IN meeting_bid INT)
RETURNS VARCHAR(12) AS $$
DECLARE
    num_of_approved INTEGER;
    approved VARCHAR(12) := 'approved';
    not_approved VARCHAR(12) := 'not approved';
BEGIN
    SELECT COUNT (*) INTO num_of_approved
    FROM Approves a
    WHERE a.time = meeting_time
    AND a.date = meeting_date
    AND a.room = meeting_room
    AND a.floor = meeting_floor
    AND a.b_eid = meeting_bid;

    IF num_of_approved > 0 THEN
        RETURN approved;
    ELSE
        RETURN not_approved;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION view_booking_report(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, approval_status VARCHAR(12)) AS $$
BEGIN
    RETURN QUERY
    SELECT s.floor AS floor_no, s.room AS room_no, s.date AS meeting_date, s.time AS meeting_time, 
        (SELECT * FROM check_approval_status(s.time, s.date, s.room, s.floor, s.b_eid)) AS approval_status
    FROM Sessions s
    WHERE s.date >= start_date
    AND s.b_eid = this_eid
    ORDER BY s.date, s.time;
END;
$$ LANGUAGE plpgsql;

--find all approved meetings that this employee has to attend from the given date onwards
CREATE OR REPLACE FUNCTION view_future_meeting(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT) AS $$
BEGIN
    RETURN QUERY
    SELECT j.floor AS floor_no, j.room AS room_no, j.date AS meeting_date, j.time AS meeting_time
    FROM Joins j, Approves a
    WHERE j.time = a.time
    AND j.date = a.date
    AND j.room = a.room
    AND j.floor = a.floor
    AND j.b_eid = a.b_eid
    AND j.e_eid = this_eidsele
    AND j.date >= start_date
    ORDER BY j.date, j.time;
END;
$$ LANGUAGE plpgsql;

--find all meeting-rooms that require approval from this manager from the given date onwards
CREATE OR REPLACE FUNCTION view_manager_report(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, booker_id INT) AS $$
BEGIN
    RETURN QUERY
    SELECT s.floor AS floor_no, s.room AS room_no, s.date AS meeting_date, s.time AS meeting_time, s.b_eid AS booker_id
    FROM Sessions s
    WHERE NOT EXISTS (SELECT * 
        FROM Approves a 
        WHERE s.time = a.time
        AND s.date = a.date
        AND s.room = a.room
        AND s.floor = a.floor
        AND s.b_eid = a.b_eid)
    AND s.date >= start_date
    AND EXISTS (SELECT r.room, r.floor
        FROM Employees e, Managers m, Meeting_Rooms r
        WHERE e.eid = m.eid
        AND e.did = r.did
        AND r.room = s.room
        AND r.floor = s.floor
        AND e.eid = this_eid)
    ORDER BY s.date, s.time;
END;
$$ LANGUAGE plpgsql;




