
CREATE OR REPLACE FUNCTION in_updates() 
RETURNS TRIGGER AS $$
DECLARE
count NUMERIC;
datenow DATE;
BEGIN
    SELECT CURRENT_DATE into datenow;
    SELECT COUNT (*) INTO count
    FROM Updates
    WHERE ((Updates.room, Updates.floor) = (NEW.room, NEW.floor)) and (Updates.date < datenow);
	
	IF count=0 THEN
		RAISE NOTICE 'Please update room capacity as well, entry will be deleted';
		DELETE FROM Meeting_rooms m WHERE m.room = NEW.room AND m.floor = NEW.floor;
		RETURN OLD;
	ELSE
		RETURN NEW;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER room_in_updates
AFTER INSERT OR UPDATE ON Meeting_Rooms
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION in_updates();

CREATE OR REPLACE FUNCTION check_dept_relations() 
RETURNS TRIGGER AS $$
DECLARE
count NUMERIC;
count1 NUMERIC;
count2 NUMERIC;
BEGIN
    SELECT COUNT (*) INTO count1
    FROM Employees 
    WHERE Employees.did = NEW.did;

    SELECT COUNT (*) INTO count2
    FROM Meeting_Rooms m
    WHERE m.did = NEW.did;

    count = count1 + count2;

    IF count = 0 THEN
	RETURN NEW;
	
    ELSE
        RETURN NULL; 
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_department(departmentID integer, departmentname text)
RETURNS VOID AS $$
BEGIN
INSERT INTO departments (did, dname) values (departmentID,departmentname );
RAISE NOTICE 'Department added';
END;
$$ LANGUAGE plpgsql;

select add_department(11, 'CEO Office')

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
INSERT INTO Employees (ename,NULL,resigned_date,did,contact,home_contact,office_contact) VALUES (ename1,email1,resigned_date1,did1,contact1,home_contact1,office_contact1);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION remove_employee(employeeId INTEGER, gonedate DATE)
RETURNS VOID AS $$
BEGIN
UPDATE Employees SET resigned_date = gonedate WHERE eid = employeeID;
RAISE NOTICE 'Employee removed';
END;
$$ LANGUAGE plpgsql;


