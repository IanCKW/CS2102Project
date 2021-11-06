DROP TRIGGER IF EXISTS setEmployeeEmail ON Employees;
DROP TRIGGER IF EXISTS validJunior ON Juniors;
DROP TRIGGER IF EXISTS validBooker ON Bookers;
DROP TRIGGER IF EXISTS validSenior ON Seniors;
DROP TRIGGER IF EXISTS validManager ON Managers;
DROP TRIGGER IF EXISTS room_in_updates ON Meeting_rooms;
DROP TRIGGER IF EXISTS want_to_delete_dept ON Departments;
DROP TRIGGER IF EXISTS date_time_check_book ON Sessions;
DROP TRIGGER IF EXISTS date_time_check_join ON Joins;
DROP TRIGGER IF EXISTS join_automatically ON Sessions;
DROP TRIGGER IF EXISTS temp_check_join ON Joins;
DROP TRIGGER IF EXISTS temp_check_book ON Sessions;
DROP TRIGGER IF EXISTS approved_check_join ON Joins;
DROP TRIGGER IF EXISTS approved_check_book ON Sessions;
DROP TRIGGER IF EXISTS approves_check ON Approves;
DROP TRIGGER IF EXISTS meeting_cancelled ON JOINS;
DROP TRIGGER IF EXISTS approved_check_leave ON Joins;
DROP TRIGGER IF EXISTS updates_check ON Updates;
DROP TRIGGER IF EXISTS cap_check ON Joins;

-- Autogenerate employee email addresses
CREATE OR REPLACE FUNCTION autogenerateEmployeeEmail()
RETURNS TRIGGER AS $$
BEGIN
    NEW.email := NEW.eid || '@meta.com';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER setEmployeeEmail
BEFORE INSERT OR UPDATE ON Employees
FOR EACH ROW EXECUTE FUNCTION autogenerateEmployeeEmail();

-- Check that new junior is not a booker
CREATE OR REPLACE FUNCTION juniorNotBooker()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Bookers 
    WHERE NEW.eid = Bookers.eid; 

    IF count > 0 THEN
        RAISE NOTICE 'Employee is a booker';
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validJunior
BEFORE INSERT OR UPDATE ON Juniors
FOR EACH ROW EXECUTE FUNCTION juniorNotBooker();

-- Check that new booker is not a junior
CREATE OR REPLACE FUNCTION bookerNotJunior()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Juniors
    WHERE NEW.eid = Juniors.eid;

    IF count > 0 THEN
        RAISE NOTICE 'Employee is a junior';
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validBooker
BEFORE INSERT OR UPDATE ON Bookers
FOR EACH ROW EXECUTE FUNCTION bookerNotJunior();

-- Check that new senior is not a manager
CREATE OR REPLACE FUNCTION seniorNotManager()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Managers
    WHERE NEW.eid = Managers.eid;

    IF count > 0 THEN
        RAISE NOTICE 'Employee is a manager';
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validSenior
BEFORE INSERT OR UPDATE ON Seniors
FOR EACH ROW EXECUTE FUNCTION seniorNotManager();

-- Check that new manager is not a senior
CREATE OR REPLACE FUNCTION managerNotSenior()
RETURNS TRIGGER AS $$
DECLARE
    count NUMERIC;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Seniors
    WHERE NEW.eid = Seniors.eid;
    
    IF count > 0 THEN
        RAISE NOTICE 'Employee is a senior';
        RETURN NULL;
    ELSE 
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validManager
BEFORE INSERT OR UPDATE ON Managers
FOR EACH ROW EXECUTE FUNCTION managerNotSenior();

-- Ensure there is an update associated with a meeting room
CREATE OR REPLACE FUNCTION in_updates() 
RETURNS TRIGGER AS $$
DECLARE
count NUMERIC;
datenow DATE;
BEGIN
    SELECT CURRENT_DATE into datenow;
    SELECT COUNT (*) INTO count
    FROM Updates
    WHERE ((Updates.room, Updates.floor) = (NEW.room, NEW.floor)) and (Updates.date <= datenow);
	
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

-- Department deletion (handles resigned employees)
CREATE OR REPLACE FUNCTION check_resign(IN in_eid INT)
RETURNS DATE AS $$
    SELECT COALESCE(e.resigned_date,'3000-01-01')
    FROM Employees e
    WHERE e.eid = in_eid;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION check_dept_relations() 
RETURNS TRIGGER AS $$
DECLARE
count NUMERIC;
count1 NUMERIC;
count2 NUMERIC;
BEGIN
    SELECT COUNT (*) INTO count1
    FROM Employees 
    WHERE Employees.did = OLD.did and check_resign(Employees.eid) > CURRENT_DATE ;

    SELECT COUNT (*) INTO count2
    FROM Meeting_Rooms m
    WHERE m.did = OLD.did;

    count = count1 + count2;

    IF count = 0 THEN
	    RAISE NOTICE 'Department will be deleted and all resigned employees will be
        shifted to the resigned department';
        UPDATE Employees e
        SET did = 0
        WHERE e.did = OLD.did AND check_resign(e.eid) <= CURRENT_DATE;
	RETURN OLD;
	
    ELSE
	RAISE NOTICE 'Department cannot be deleted due to leftover resources';
        RETURN NULL; 
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER want_to_delete_dept
BEFORE DELETE ON Departments
FOR EACH ROW EXECUTE FUNCTION check_dept_relations();

--The employee booking the room immediately joins the booked meeting
CREATE OR REPLACE FUNCTION automatically_join()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Joins (time, date, room, floor, b_eid, e_eid) VALUES (NEW.time, NEW.date, NEW.room, NEW.floor, NEW.b_eid, NEW.b_eid);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER join_automatically
AFTER INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION automatically_join();

--A booking can only be made for future meetings
CREATE OR REPLACE FUNCTION check_date_time_book()
RETURNS TRIGGER AS $$
DECLARE
    date_current DATE;
BEGIN
    SELECT CURRENT_DATE INTO date_current;

    IF NEW.date < date_current THEN
        RAISE NOTICE 'Cannot book in the past';
        RETURN NULL;
    ELSE
        RAISE NOTICE 'Room Booked';
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER date_time_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_date_time_book();

--An employee can only join future meetings
CREATE OR REPLACE FUNCTION check_date_time_join()
RETURNS TRIGGER AS $$
DECLARE
    date_current DATE;
BEGIN
    SELECT CURRENT_DATE INTO date_current;

    IF NEW.date < date_current THEN
        RAISE NOTICE 'Session is already over';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER date_time_check_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_date_time_join();

--If an employee is having a fever, they cannot join a booked meeting (check the most recent temperature)
CREATE OR REPLACE FUNCTION check_temp_join()
RETURNS TRIGGER AS $$
DECLARE
    t FLOAT;
BEGIN
    SELECT temp INTO t
    FROM Health_Declarations hd
    WHERE hd.eid = NEW.e_eid;

    IF t > 37.5 THEN
        RAISE NOTICE 'Not allowed to join session as employee has fever';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER temp_check_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_temp_join();

CREATE OR REPLACE FUNCTION check_temp_book()
RETURNS TRIGGER AS $$
DECLARE
    tem FLOAT;
BEGIN
    SELECT temp INTO tem
    FROM Health_Declarations hd
    WHERE hd.eid = NEW.b_eid;

    IF tem > 37.5 THEN
        RAISE NOTICE 'Not allowed to book as booker has fever';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER temp_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_temp_book();

-- CHECKS THAT THE MANAGER IS FROM THE SAME DEPARTMENT AS THE MEETING ROOM
CREATE OR REPLACE FUNCTION check_manager_from_same_dep_as_mr()
RETURNS TRIGGER AS $$
DECLARE
    m_department_id INTEGER; -- manager
    target_department_id INTEGER; -- session or update
BEGIN
    SELECT COALESCE(e.did,-1) INTO m_department_id 
    FROM Employees e, Managers m
    WHERE e.eid = m.eid AND NEW.m_eid = m.eid;

    SELECT COALESCE(mr.did, -1) INTO target_department_id
    FROM Meeting_Rooms mr
    WHERE mr.room = NEW.room AND mr.floor = NEW.floor;

    IF  m_department_id <> target_department_id THEN
        RAISE NOTICE 'The manager doesnt come from the same dep as the meeting room';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approves_check
BEFORE INSERT OR UPDATE ON Approves
FOR EACH ROW 
EXECUTE FUNCTION check_manager_from_same_dep_as_mr();

--No employees can join from an already approved session
CREATE OR REPLACE FUNCTION check_approved_join()
RETURNS TRIGGER AS $$
DECLARE
    join_approved INTEGER;
BEGIN
    SELECT COUNT(*) INTO join_approved
    FROM Approves a
    WHERE a.time = NEW.time
    AND a.date = NEW.date
    AND a.room = NEW.room
    AND a.floor = NEW.floor
    AND a.b_eid = NEW.b_eid;

    IF join_approved > 0 THEN
        RAISE NOTICE 'Cannot join or leave approved session';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approved_check_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_approved_join();

--No employees can leave from an already approved session
CREATE OR REPLACE FUNCTION check_approved_leave()
RETURNS TRIGGER AS $$
DECLARE
    join_approved INTEGER;
BEGIN
    SELECT COUNT(*) INTO join_approved
    FROM Approves a
    WHERE a.time = OLD.time
    AND a.date = OLD.date
    AND a.room = OLD.room
    AND a.floor = OLD.floor
    AND a.b_eid = OLD.b_eid;

    IF join_approved > 0 THEN
        RAISE NOTICE 'Cannot join or leave approved session';
        RETURN NULL;
    ELSE
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approved_check_leave
BEFORE DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_approved_leave();

--A session can only be booked if there isn't already an approved session of the same time, date, room, and floor
CREATE OR REPLACE FUNCTION check_approved_book()
RETURNS TRIGGER AS $$
DECLARE
    same_approved INTEGER;
BEGIN
    SELECT COUNT(*) INTO same_approved
    FROM Approves a
    WHERE a.time = NEW.time
    AND a.date = NEW.date
    AND a.room = NEW.room
    AND a.floor = NEW.floor;

    IF same_approved > 0 THEN
        RAISE NOTICE 'There is already an approved session of the same time, date, room, and floor';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approved_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_approved_book();

--When the booker is removed from a meeting, the meeting is cancelled
CREATE OR REPLACE FUNCTION cancel_meeting()
RETURNS TRIGGER AS $$
DECLARE
    is_booker INTEGER;
BEGIN
    SELECT COUNT (*) INTO is_booker 
    WHERE OLD.b_eid = OLD.e_eid;

    IF is_booker > 0 THEN
        RAISE NOTICE 'A booker has been removed, the session booked by him will be cancelled';

        DELETE FROM Sessions s
        WHERE s.time = OLD.time
        AND s.date = OLD.date
        AND s.room = OLD.room
        AND s.floor = OLD.floor
        AND s.b_eid = OLD.e_eid;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER meeting_cancelled
AFTER DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION cancel_meeting();

CREATE TRIGGER updates_check
BEFORE INSERT OR UPDATE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION check_manager_from_same_dep_as_mr();

--An employee can only join meetings if the number of people in the meeting is less than the most recent updated capacity
CREATE OR REPLACE FUNCTION check_cap()
RETURNS TRIGGER AS $$
DECLARE
    latest_capacity INTEGER;
    num_of_attendee INTEGER;
BEGIN
    SELECT u.new_cap INTO latest_capacity
    FROM Updates u
    WHERE u.room = NEW.room
    AND u.floor = NEW.floor
    AND u.date <= NEW.date
    ORDER BY u.date DESC
    LIMIT 1;

    SELECT COUNT(*) INTO num_of_attendee
    FROM Joins j
    WHERE j.time = NEW.time
    AND j.date = NEW.date
    AND j.room = NEW.room
    AND j.floor = NEW.floor
    AND j.b_eid = NEW.b_eid;

    IF num_of_attendee >= latest_capacity THEN
        RAISE NOTICE 'Unable to join as session is already full';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cap_check
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_cap();