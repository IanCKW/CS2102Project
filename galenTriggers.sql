DROP TRIGGER IF EXISTS booker_joins ON Sessions;
DROP TRIGGER IF EXISTS temp_check_join ON Joins;
DROP TRIGGER IF EXISTS date_time_check_join ON Joins;
DROP TRIGGER IF EXISTS cap_check ON Joins;
DROP TRIGGER IF EXISTS temp_check_book ON Sessions;
DROP TRIGGER IF EXISTS date_time_check_book ON Sessions;
DROP TRIGGER IF EXISTS meeting_cancelled ON Joins;
DROP TRIGGER IF EXISTS approved_check_join ON Joins;
DROP TRIGGER IF EXISTS resignation_check ON Joins;
DROP TRIGGER IF EXISTS approved_check_book ON Sessions;
DROP TRIGGER IF EXISTS session_participation_check ON Sessions;
DROP TRIGGER IF EXISTS contact_check ON Sessions;

--The employee booking the room immediately joins the booked meeting
CREATE OR REPLACE FUNCTION automatically_join()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Joins (time, date, room, floor, b_eid, e_eid) VALUES (NEW.time, NEW.date, NEW.room, NEW.floor, NEW.b_eid, NEW.b_eid);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER join_automatically
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION automatically_join();

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
        RAISE NOTICE 'Employee has fever';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER temp_check_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_temp_join();

--An employee can only join future meetings
CREATE OR REPLACE FUNCTION check_date_time_join()
RETURNS TRIGGER AS $$
DECLARE
    date_current DATE;
    time_current INTEGER;
BEGIN
    SELECT CURRENT_DATE INTO date_current;
    SELECT CONVERT(TIME, GETDATE()) INTO time_current;

    IF date_current < NEW.date THEN
        RAISE NOTICE 'Session is already over';
        RETURN NULL;
    ELSE IF date_current = NEW.date THEN
        IF time_current < NEW.time THEN
            RAISE NOTICE 'Session is already over';
            RETURN NULL;
        ELSE
            RETURN NEW;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER date_time_check_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_date_time_join();

--An employee can only join meetings if the number of people in the meeting is less than the most recent updated capacity
CREATE OR REPLACE FUNCTION check_cap()
RETURNS TRIGGER AS $$
DECLARE
    cap INTEGER;
    current INTEGER;
BEGIN
    SELECT u.new_cap INTO cap
    FROM Updates u
    WHERE u.room = NEW.room
    AND u.floor = NEW.floor
    AND u.date <= NEW.date;

    SELECT COUNT(*) INTO current
    FROM Joins j
    WHERE j.time = NEW.time
    AND j.date = NEW.date
    AND j.room = NEW.room
    AND j.floor = NEW.floor
    AND j.b_eid = NEW.b_eid;

    IF current >= cap THEN
        RAISE NOTICE 'Session is full';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cap_check
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_cap();

--If an employee is having a fever, they cannot book a room (we check your most recent temperature)
CREATE OR REPLACE FUNCTION check_temp_book()
RETURNS TRIGGER AS $$
DECLARE
    tem FLOAT;
BEGIN
    SELECT temp INTO tem
    FROM Health_Declarations hd
    WHERE hd.eid = NEW.b_eid;

    IF tem > 37.5 THEN
        RAISE NOTICE 'Booker has fever';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER temp_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_temp_book();

--A booking can only be made for future meetings
CREATE OR REPLACE FUNCTION check_date_time_book()
RETURNS TRIGGER AS $$
DECLARE
    date_current DATE;
    time_current INTEGER;
BEGIN
    SELECT CURRENT_DATE INTO date_current;
    SELECT CONVERT(TIME, GETDATE()) INTO time_current;

    IF date_current < NEW.date THEN
        RAISE NOTICE 'Cannot book in the past';
        RETURN NULL;
    ELSE IF date_current = NEW.date THEN
        IF time_current < NEW.time THEN
            RAISE NOTICE 'Cannot book in the past';
            RETURN NULL;
        ELSE
            RETURN NEW;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER date_time_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_date_time_book();

--When the booker is removed from a meeting, the meeting is cancelled
CREATE OR REPLACE FUNCTION cancel_meeting()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM Sessions
    WHERE b_eid = NEW.b_eid;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER meeting_cancelled
BEFORE DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION cancel_meeting();

--No employees can join or leave from an already approved session
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
BEFORE INSERT OR UPDATE OR DELETE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_approved_join();

--Join cannot be made by someone who has resigned
CREATE OR REPLACE FUNCTION check_resignation()
RETURNS TRIGGER AS $$
DECLARE
    resign_date DATE;
BEGIN
    SELECT e.resigned_date INTO resign_date
    FROM Employees e
    WHERE e.eid = NEW.e_eid;

    IF resign_date IS NULL THEN
        RETURN NEW;
    ELSE IF resign_date > NEW.date THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Employee has already resigned';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER resignation_check
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_resignation();

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

--Each session must exist at least once in Join
CREATE OR REPLACE FUNCTION check_session_participation()
RETURNS TRIGGER AS $$
DECLARE
    date_current DATE;
    number_of_sessions INTEGER;
BEGIN
    SELECT CURRENT_DATE INTO date_current;

    SELECT COUNT(*) INTO number_of_sessions
    FROM Joins j
    WHERE j.time = NEW.time
    AND j.date = NEW.date
    AND j.room = NEW.room
    AND j.floor = NEW.floor
    AND j.b_eid = NEW.b_eid
    AND j.date < date_current;

    IF number_of_sessions > 0 THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Each session must exist at least once in Join';
        INSERT INTO Sessions (time, date, room, floor, b_eid) VALUES (NEW.time, NEW.date, NEW.room, NEW.floor, NEW.b_eid);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER session_participation_check
AFTER INSERT OR UPDATE OR DELETE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_session_participation();

--checks if an employee has been in contact with a sick employee in the past 3 days
CREATE OR REPLACE FUNCTION check_contact()
RETURNS TRIGGER AS $$
DECLARE
    number_of_sick INTEGER;
BEGIN
    SELECT COUNT (*) INTO number_of_sick
    FROM (Health_Declarations h JOIN contact_tracing(NEW.e_eid, NEW.date) c ON h.eid = c.e_eid) hc
    WHERE hc.temp > 37.5;

    IF number_of_sick > 0 THEN
        RAISE NOTICE 'Employee has been in contact with a sick employee in the past 3 days'
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER contact_check
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_contact();
