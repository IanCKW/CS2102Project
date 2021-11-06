
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
    WHERE Employees.did = OLD.did;

    SELECT COUNT (*) INTO count2
    FROM Meeting_Rooms m
    WHERE m.did = OLD.did;

    count = count1 + count2;

    IF count = 0 THEN
	RAISE NOTICE 'Department will be deleted';
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
BEGIN

    SELECT COUNT (*) INTO number_of_sick
    FROM (Health_Declarations h 
        JOIN contact_tracing(NEW.e_eid, NEW.date) c0 
            ON h.eid = c0.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '1 day') c1 
            ON h.eid = c1.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '2 day') c2 
            ON h.eid = c2.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '3 day') c3 
            ON h.eid = c3.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '4 day') c4 
            ON h.eid = c4.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '5 day') c5 
            ON h.eid = c5.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '6 day') c6 
            ON h.eid = c6.e_eid
        JOIN contact_tracing(NEW.e_eid, NEW.date - INTERVAL '7 day') c7 
            ON h.eid = c7.e_eid
    ) hc
    WHERE hc.temp > 37.5;
    
    IF number_of_sick > 0 or NEW.date > (SELECT resigned_date FROM Employees E where E.eid = NEW.e_eid) THEN
        RAISE NOTICE 'Employee will be removed from Joins';
        RETURN NEW;

    ELSE
        RAISE NOTICE 'Cannot leave approved session';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_approved_joins
BEFORE DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION leave_approved_meetings();
