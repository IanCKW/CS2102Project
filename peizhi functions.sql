CREATE OR REPLACE FUNCTION add_department(did INT, departmentname TEXT)
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

CREATE OR REPLACE FUNCTION add_employee(ename1 TEXT, resigned_date1 DATE,did1 INTEGER ,contact1 INTEGER,home_contact1 INTEGER,office_contact1 INTEGER)
RETURNS VOID AS $$
BEGIN
INSERT INTO Employees (ename,resigned_date,did,contact,home_contact,office_contact) VALUES (ename1,resigned_date1,did1,contact1,home_contact1,office_contact1);
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
