DROP FUNCTION IF EXISTS
    add_department(INTEGER, TEXT),
    add_employee(TEXT, INTEGER, INTEGER, INTEGER, INTEGER),
    add_room(INTEGER, INTEGER ,TEXT, INTEGER, INTEGER , DATE, INTEGER),
    remove_employee(INTEGER, DATE),
    remove_department(INTEGER),
    book_room(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER),
    unbook_room(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER),
    join_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    leave_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    approve_meeting(INTEGER, INTEGER, DATE, INTEGER, INTEGER, INTEGER, INTEGER),
    change_capacity(INTEGER, INTEGER, INTEGER, DATE, INTEGER);

CREATE OR REPLACE FUNCTION add_department(IN did INT, IN departmentname TEXT)
RETURNS VOID AS $$
BEGIN
INSERT INTO departments values (did, departmentname);
RAISE NOTICE 'Department added';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_employee(ename1 TEXT, did1 INTEGER ,contact1 INTEGER,home_contact1 INTEGER,office_contact1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Employees (ename,resigned_date,did,contact,home_contact,office_contact) VALUES (ename1,NULL,did1,contact1,home_contact1,office_contact1);
RAISE NOTICE 'Employee added';
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

CREATE OR REPLACE FUNCTION remove_employee(employeeId INTEGER, gonedate DATE)
RETURNS VOID AS $$
BEGIN
UPDATE Employees SET resigned_date = gonedate WHERE eid = employeeID;
RAISE NOTICE 'Employee removed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_department(departmentID integer)
RETURNS VOID AS $$
BEGIN
DELETE FROM departments where departments.did = departmentID;
RAISE NOTICE 'Department removed';
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION change_capacity(room1 INTEGER,floor1 INTEGER, cap1 INTEGER, date1 DATE, m_eid1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Updates (date,new_cap, room, floor, m_eid) values (date1, cap1, room1,floor1,m_eid1 );
RAISE NOTICE 'Room Capacity Changed';
END;
$$ LANGUAGE plpgsql;