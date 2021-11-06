DROP TRIGGER IF EXISTS room_in_updates ON Employees;
DROP TRIGGER IF EXISTS delete_approved_joins ON Joins;


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

CREATE OR REPLACE FUNCTION leave_approved_meetings()
RETURNS TRIGGER AS $$
DECLARE
    number_of_sick INTEGER;
    join_approved INTEGER;
    join_session INTEGER;
BEGIN
    SELECT COUNT(*) INTO join_approved
    FROM Approves a
    WHERE a.time = NEW.time
    AND a.date = NEW.date
    AND a.room = NEW.room
    AND a.floor = NEW.floor
    AND a.b_eid = NEW.b_eid;

    SELECT COUNT(*) INTO join_session
    FROM Sessions s
    WHERE s.time = NEW.time
    AND s.date = NEW.date
    AND s.room = NEW.room
    AND s.floor = NEW.floor
    AND s.b_eid = NEW.b_eid;

    SELECT COUNT (*) INTO number_of_sick
    FROM (Health_Declarations h 
        JOIN contact_tracing(NEW.e_eid, NEW.date) c0 
            ON h.eid = c0
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '1 day' AS DATE ))  c1 
            ON h.eid = c1
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '2 day' AS DATE ))  c2 
            ON h.eid = c2
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '3 day' AS DATE ))  c3 
            ON h.eid = c3
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '4 day' AS DATE ))  c4 
            ON h.eid = c4
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '5 day' AS DATE ))  c5 
            ON h.eid = c5
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '6 day' AS DATE ))  c6 
            ON h.eid = c6
        JOIN contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '7 day' AS DATE ))  c7 
            ON h.eid = c7
    ) hc
    WHERE hc.temp > 37.5;
    
    IF number_of_sick > 0 or NEW.date > (SELECT resigned_date FROM Employees E where E.eid = NEW.e_eid) 
    or join_session = 0 or ( join_session >0 AND join_approved = 0) THEN 
        RAISE NOTICE 'Employee will be removed from Joins';
        RETURN OLD;

    ELSE
        RAISE NOTICE 'Cannot leave approved session';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_approved_joins
BEFORE DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION leave_approved_meetings();