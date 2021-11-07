DROP TRIGGER IF EXISTS setEmployeeEmail ON Employees;
DROP TRIGGER IF EXISTS validJunior ON Juniors;
DROP TRIGGER IF EXISTS validBooker ON Bookers;
DROP TRIGGER IF EXISTS validSenior ON Seniors;
DROP TRIGGER IF EXISTS validManager ON Managers;
DROP TRIGGER IF EXISTS bookerNotResigned ON Sessions;
DROP TRIGGER IF EXISTS approverNotResigned ON Approves;

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

-- Prevent resigned employees from booking
CREATE OR REPLACE FUNCTION checkBookerResignationStatus()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.b_eid IN (
        SELECT eid FROM Employees
        WHERE resigned_date IS NULL
        OR resigned_date > CURRENT_DATE
    ) THEN 
        RETURN NEW;
    ELSE 
        RAISE NOTICE 'Booker has resigned';
        RETURN NULL;
    END IF;   
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookerNotResigned
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION checkBookerResignationStatus();

-- Prevent resigned employees from approves
CREATE OR REPLACE FUNCTION checkApproverResignationStatus()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.m_eid IN (
        SELECT eid FROM Employees
        WHERE resigned_date IS NULL
        OR resigned_date > CURRENT_DATE
    ) THEN 
        RETURN NEW;
    ELSE 
        RAISE NOTICE 'Approver has resigned';
        RETURN NULL;
    END IF;   
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approverNotResigned
BEFORE INSERT OR UPDATE ON Approves
FOR EACH ROW EXECUTE FUNCTION checkApproverResignationStatus();


DROP TRIGGER IF EXISTS room_in_updates ON Employees;
DROP TRIGGER IF EXISTS delete_approved_joins ON Joins;
DROP TRIGGER IF EXISTS want_to_delete_dept ON Departments;



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
    WHERE a.time = OLD.time
    AND a.date = OLD.date
    AND a.room = OLD.room
    AND a.floor = OLD.floor
    AND a.b_eid = OLD.b_eid;

    SELECT COUNT(*) INTO join_session
    FROM Sessions s
    WHERE s.time = OLD.time
    AND s.date = OLD.date
    AND s.room = OLD.room
    AND s.floor = OLD.floor
    AND s.b_eid = OLD.b_eid;

    SELECT COUNT (*) INTO number_of_sick
    FROM Health_Declarations h,
        contact_tracing(OLD.e_eid, OLD.date) c0,
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '1 day' AS DATE ))  c1,
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '2 day' AS DATE ))  c2,
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '3 day' AS DATE ))  c3, 
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '4 day' AS DATE ))  c4,
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '5 day' AS DATE ))  c5, 
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '6 day' AS DATE ))  c6, 
        contact_tracing(OLD.e_eid, CAST ( OLD.date - INTERVAL '7 day' AS DATE ))  c7
    WHERE h.temp > 37.5 AND
    (
        (h.eid = c0 AND h.date >= CAST ( OLD.date - INTERVAL '3 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date AS DATE ) ) OR

        (h.eid = c1 AND h.date >= CAST ( OLD.date - INTERVAL '4 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '1 day' AS DATE ) ) OR

        (h.eid = c2 AND h.date >= CAST ( OLD.date - INTERVAL '5 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '2 day' AS DATE ) ) OR

        (h.eid = c3 AND h.date >= CAST ( OLD.date - INTERVAL '6 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '3 day' AS DATE ) ) OR

        (h.eid = c4 AND h.date >= CAST ( OLD.date - INTERVAL '7 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '4 day' AS DATE ) ) OR

        (h.eid = c5 AND h.date >= CAST ( OLD.date - INTERVAL '8 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '5 day' AS DATE ) ) OR

        (h.eid = c6 AND h.date >= CAST ( OLD.date - INTERVAL '9 day' AS DATE ) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '6 day' AS DATE ) ) OR

        (h.eid = c7 AND h.date >= CAST ( OLD.date - INTERVAL '10 day' AS DATE) AND 
                        h.date <= CAST ( OLD.date - INTERVAL '7 day' AS DATE ) ) 
    );
    IF number_of_sick = 0 THEN
    RAISE NOTICE 'This employee is a close contact or is sick. Employee can be removed';
    END IF;

    IF join_session = 0 THEN
    RAISE NOTICE 'Session has been deleted. Employee can be removed';
    END IF;

    IF number_of_sick > 0 OR OLD.date >= check_resign(OLD.e_eid) OR
    join_session = 0 OR ( join_session >0 AND join_approved = 0) THEN 
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



DROP TRIGGER IF EXISTS rem_future ON Employees;
DROP TRIGGER IF EXISTS check_resigned_updates ON Updates;
DROP TRIGGER IF EXISTS check_resigned_approves ON Approves;
DROP TRIGGER IF EXISTS check_resigned_book ON Sessions;
DROP TRIGGER IF EXISTS check_resigned_join ON Joins;
DROP TRIGGER IF EXISTS future_approves ON Approves; 
DROP TRIGGER IF EXISTS approves_check ON Approves;
DROP TRIGGER IF EXISTS updates_check ON Updates;
DROP TRIGGER IF EXISTS handle_updates ON Updates;
DROP TRIGGER IF EXISTS handle_update_delete ON Updates;
DROP TRIGGER IF EXISTS close_contact_rem ON Health_Declarations;
DROP TRIGGER IF EXISTS session_rem ON Health_Declarations;

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
------------------------TRIGGERS, FUNC, TRIGGER FUNCS FOR RESIGNATION----------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION check_resign(IN in_eid INT)
RETURNS DATE AS $$
    SELECT COALESCE(e.resigned_date,'3000-01-01')
    FROM Employees e
    WHERE e.eid = in_eid;
$$ LANGUAGE sql;


----- REMOVAL OF FUTURE APPROVALS, BOOKED SESSIONS AND PARTICIPATION IN SESSIONS ------
CREATE OR REPLACE FUNCTION future_rem()
RETURNS TRIGGER AS $$
BEGIN
    IF check_resign(NEW.eid) < '3000-01-01' THEN    
        RAISE NOTICE 'Future sessions, approvals and joins will be removed';
        
        DELETE FROM Sessions s
        WHERE NEW.eid = s.b_eid and s.date > NEW.resigned_date;

        DELETE FROM Approves a
        WHERE NEW.eid = a.m_eid and a.date > NEW.resigned_date;

        DELETE FROM Joins j
        WHERE NEW.eid = j.e_eid and j.date > NEW.resigned_date;

    END IF;
RETURN NEW;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER rem_future
AFTER INSERT OR UPDATE ON Employees
FOR EACH ROW
EXECUTE FUNCTION future_rem();

--- APPROVE/ UPDATE --- 

CREATE OR REPLACE FUNCTION updates_resigned_check()
RETURNS TRIGGER AS $$
BEGIN
    IF check_resign(NEW.m_eid) < NEW.date THEN    
        RAISE NOTICE 'Updater has resigned';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER check_resigned_updates
BEFORE INSERT OR UPDATE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION updates_resigned_check();

CREATE TRIGGER check_resigned_approves
BEFORE INSERT OR UPDATE ON Approves
FOR EACH ROW 
EXECUTE FUNCTION updates_resigned_check();


--- BOOK --- 
CREATE OR REPLACE FUNCTION book_resigned_check()
RETURNS TRIGGER AS $$
BEGIN
    IF check_resign(NEW.b_eid) < NEW.date THEN    
        RAISE NOTICE 'This employee has resigned';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER check_resigned_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW 
EXECUTE FUNCTION book_resigned_check();


--- JOIN ---
CREATE OR REPLACE FUNCTION join_resigned_check()
RETURNS TRIGGER AS $$
BEGIN
    IF check_resign(NEW.e_eid) < NEW.date THEN    
        RAISE NOTICE 'This employee has resigned';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER check_resigned_join
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW 
EXECUTE FUNCTION join_resigned_check();

-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------
----------------------CONSTRAINT TRIGGERS, FUNC, TRIGGER FUNCS FOR APPROVES, UPDATES, HD---------------------------
-------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------

-- TRIGGER FUNCTION THAT CHECKS THAT APPROVES IS FOR FUTURE MEETINGS
CREATE OR REPLACE FUNCTION approve_future()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.date < CURRENT_DATE then
        RAISE NOTICE 'Approvals must be for future dates';
        Return NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER future_approve
BEFORE INSERT OR UPDATE ON Approves
FOR EACH ROW 
EXECUTE FUNCTION approve_future();

--------------------------------------------------------------------------------------------------------------------

-- TRIGGER FUNCTION AND TRIGGER THAT CHECKS THAT THE MANAGER IS FROM THE SAME DEPARTMENT AS THE MEETING ROOM
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

--------------------------------------------------------------------------------------------------------------------

-- Checks that the Manager adding to Updates is from the same department as the meeting room that it is updating

CREATE TRIGGER updates_check
BEFORE INSERT OR UPDATE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION check_manager_from_same_dep_as_mr();


--------------------------------------------------------------------------------------------------------------------

-- TRIGGER FUNCTION AND TRIGGER REMOVES FUTURE SESSIONS WHERE THE NUM OF PARTICIPANTS > MOST RECENT CAPACITY
-- AND DELETES FUTURE UPDATES

CREATE OR REPLACE FUNCTION check_update()
RETURNS TRIGGER AS $$
BEGIN

    -- Find meeting room of NEW
    -- Find all sessions booked with the meeting room after NEW.date
    -- Find num of participants of each session. If > capacity, delete session
    WITH SessionsToBeDeleted AS
        (SELECT rel_sess.b_eid, rel_sess.time, rel_sess.date, rel_sess.room, rel_sess.floor
        FROM
            (SELECT s.b_eid AS b_eid, s.time AS time, s.date AS date, s.room AS room, s.floor AS floor
            FROM Sessions s
            WHERE s.room = NEW.room AND s.floor = NEW.floor AND s.date >= NEW.date) AS rel_sess,

            Joins j
        WHERE j.b_eid = rel_sess.b_eid AND j.time = rel_sess.time AND 
        j.date = rel_sess.date AND j.room = rel_sess.room AND j.floor = rel_sess.floor
        GROUP BY rel_sess.b_eid, rel_sess.time, rel_sess.date, rel_sess.room, rel_sess.floor
        HAVING COUNT(*) > NEW.new_cap)
    DELETE FROM Sessions s1 USING SessionsToBeDeleted
    WHERE s1.b_eid = SessionsToBeDeleted.b_eid AND 
        s1.time = SessionsToBeDeleted.time AND 
        s1.date = SessionsToBeDeleted.date AND 
        s1.room = SessionsToBeDeleted.room AND 
        s1.floor = SessionsToBeDeleted.floor;

    -- Future updates of the same meeting room are deleted
    DELETE FROM UPDATES u
    WHERE u.room = NEW.room AND u.floor = NEW.floor AND u.date > NEW.date;

RETURN NEW;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER handle_update
AFTER INSERT OR UPDATE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION check_update();

--------------------------------------------------------------------------------------------------------------------

-- CHECKS IF YOU DELETE FROM UPDATES THAT THERE EXISTS AN UPDATE FOR THE MEETING ROOM THAT IS BEFORE OR DURING
-- CURRENT DATE

CREATE OR REPLACE FUNCTION check_delete_update()
RETURNS TRIGGER AS $$
DECLARE
    count INTEGER;
BEGIN
    SELECT COUNT(*) INTO count
    FROM Updates u
    WHERE u.room = OLD.room AND u.floor = OLD.floor AND u.date < CURRENT_DATE AND u.date <> OLD.date;

    IF count > 0 THEN
        RETURN OLD;
    ELSE
        RAISE NOTICE 'You are deleting an Update from a meeting room that has no Update entry earlier than
        todays date.';
        RETURN NULL;
    END IF;

RETURN NEW;
END;
$$LANGUAGE plpgsql;

CREATE TRIGGER handle_update_delete
BEFORE DELETE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION check_delete_update();

--------------------------------------------------------------------------------------------------------------------


-- FUNCTION THAT CAN FIND EVERYONE THAT IS A CLOSE CONTACT
CREATE OR REPLACE FUNCTION contact_tracing(IN sick_eid INT, IN sick_date DATE)
RETURNS SETOF INT AS $$

    (SELECT j2.e_eid as e_eid
    FROM Approves s, Joins j1, Joins j2
    -- get participants of approved meetings
    WHERE (s.room, s.floor, s.date, s.time, s.b_eid) = (j1.room, j1.floor, j1.date, j1.time, s.b_eid)
    -- get sessions that eid was in in the past 3 days
    AND j1.e_eid = sick_eid AND (j1.date = sick_date OR j1.date = sick_date - INTERVAL '1 day' OR j1.date = sick_date - INTERVAL '2 day' OR j1.date = sick_date - INTERVAL '3 day')
    -- get close contacts;
    AND (j1.room, j1.floor, j1.date, j1.time, j1.b_eid) = (j2.room, j2.floor, j2.date, j2.time, j2.b_eid))
    UNION
    (SELECT e.eid FROM Employees e WHERE e.eid = sick_eid );
    
$$ LANGUAGE sql ;

-- TRIGGER FUNC AND TRIGGER TO REMOVE CLOSE CONTACTS FROM 7 DAYS OF SESSIONS and DELET SESSIONS BOOKED BY CLOSE CONTACTS
CREATE OR REPLACE FUNCTION rem_close_contacts()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.temp > 37.5 THEN
        RAISE NOTICE 'Close contacts are removed from meetings for the next 7 days
        and bookings made from close contacts are deleted';

        DELETE FROM Joins j USING contact_tracing(NEW.eid, NEW.date) cc 
        WHERE
            j.e_eid = cc AND
            (j.date = NEW.date OR j.date = NEW.date + INTERVAL '1 day'OR
            j.date = NEW.date + INTERVAL '2 day'OR j.date = NEW.date + INTERVAL '3 day'OR
            j.date = NEW.date + INTERVAL '4 day'OR j.date = NEW.date + INTERVAL '5 day'OR
            j.date = NEW.date + INTERVAL '6 day'OR j.date = NEW.date + INTERVAL '7 day');
        DELETE FROM Sessions s USING contact_tracing(NEW.eid, NEW.date) cc 
        WHERE
            s.b_eid = cc AND
            (s.date = NEW.date OR s.date = NEW.date + INTERVAL '1 day'OR
            s.date = NEW.date + INTERVAL '2 day'OR s.date = NEW.date + INTERVAL '3 day'OR
            s.date = NEW.date + INTERVAL '4 day'OR s.date = NEW.date + INTERVAL '5 day'OR
            s.date = NEW.date + INTERVAL '6 day'OR s.date = NEW.date + INTERVAL '7 day');

    END IF;
RETURN new;
END;
$$LANGUAGE plpgsql;


CREATE TRIGGER close_contact_rem
AFTER INSERT OR UPDATE ON Health_Declarations
FOR EACH ROW 
EXECUTE FUNCTION rem_close_contacts();


--------------------------------------------------------------------------------------------------------------------

 -- TRIGGER FUNC AND TRIGGER TO REMOVE SESSIONS AND APPROVES WHICH HAVE b_eid == booker_eid
CREATE OR REPLACE FUNCTION rem_sessions() -- cascades to delete approves and Joins
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.temp > 37.0 THEN 
        RAISE NOTICE 'This employee has a fever, all future sessions booked by them are deleted';
        DELETE FROM SESSIONS s
        WHERE NEW.eid = s.b_eid AND s.date >= NEW.date;
    END IF;
RETURN new;
END;
$$LANGUAGE plpgsql;


CREATE TRIGGER session_rem
BEFORE INSERT OR UPDATE ON Health_Declarations
FOR EACH ROW 
EXECUTE FUNCTION rem_sessions();



DROP TRIGGER IF EXISTS join_automatically ON Sessions;
DROP FUNCTION IF EXISTS automatically_join();
DROP TRIGGER IF EXISTS temp_check_join ON Joins;
DROP FUNCTION IF EXISTS check_temp_join();
DROP TRIGGER IF EXISTS date_time_check_join ON Joins;
DROP FUNCTION IF EXISTS check_date_time_join();
DROP TRIGGER IF EXISTS cap_check ON Joins;
DROP FUNCTION IF EXISTS check_cap();
DROP TRIGGER IF EXISTS temp_check_book ON Sessions;
DROP FUNCTION IF EXISTS check_temp_book();
DROP TRIGGER IF EXISTS date_time_check_book ON Sessions;
DROP FUNCTION IF EXISTS check_date_time_book();
DROP TRIGGER IF EXISTS meeting_cancelled ON Joins;
DROP FUNCTION IF EXISTS cancel_meeting();
DROP TRIGGER IF EXISTS approved_check_join ON Joins;
DROP FUNCTION IF EXISTS check_approved_join();
DROP TRIGGER IF EXISTS resignation_check ON Joins;
DROP FUNCTION IF EXISTS check_resignation();
DROP TRIGGER IF EXISTS approved_check_book ON Sessions;
DROP FUNCTION IF EXISTS check_approved_book();
DROP TRIGGER IF EXISTS contact_check ON Joins;
DROP FUNCTION IF EXISTS check_contact();
DROP TRIGGER IF EXISTS contact_check_book ON Sessions;
DROP FUNCTION IF EXISTS check_contact_book();

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

--An employee who has resigned cannot join any sessions
CREATE OR REPLACE FUNCTION check_resignation()
RETURNS TRIGGER AS $$
DECLARE
    resign_date DATE;
BEGIN
    SELECT e.resigned_date INTO resign_date
    FROM Employees e
    WHERE e.eid = NEW.e_eid;

    IF resign_date IS NULL OR resign_date > NEW.date THEN
        RETURN NEW;
    ELSE
        RAISE NOTICE 'Not allowed to join session as employee has already resigned';
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

CREATE OR REPLACE FUNCTION check_contact()
RETURNS TRIGGER AS $$
DECLARE
    num_of_sick_contacts INTEGER;
BEGIN
    SELECT COUNT (*) INTO num_of_sick_contacts
    FROM Health_Declarations h,
        contact_tracing(NEW.e_eid, NEW.date) c0,
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '1 day' AS DATE ))  c1,
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '2 day' AS DATE ))  c2,
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '3 day' AS DATE ))  c3, 
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '4 day' AS DATE ))  c4,
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '5 day' AS DATE ))  c5, 
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '6 day' AS DATE ))  c6, 
        contact_tracing(NEW.e_eid, CAST ( NEW.date - INTERVAL '7 day' AS DATE ))  c7
    WHERE h.temp > 37.5 AND
    (
        (h.eid = c0 AND h.date >= CAST ( NEW.date - INTERVAL '3 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date AS DATE ) ) OR

        (h.eid = c1 AND h.date >= CAST ( NEW.date - INTERVAL '4 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '1 day' AS DATE ) ) OR

        (h.eid = c2 AND h.date >= CAST ( NEW.date - INTERVAL '5 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '2 day' AS DATE ) ) OR

        (h.eid = c3 AND h.date >= CAST ( NEW.date - INTERVAL '6 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '3 day' AS DATE ) ) OR

        (h.eid = c4 AND h.date >= CAST ( NEW.date - INTERVAL '7 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '4 day' AS DATE ) ) OR

        (h.eid = c5 AND h.date >= CAST ( NEW.date - INTERVAL '8 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '5 day' AS DATE ) ) OR

        (h.eid = c6 AND h.date >= CAST ( NEW.date - INTERVAL '9 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '6 day' AS DATE ) ) OR

        (h.eid = c7 AND h.date >= CAST ( NEW.date - INTERVAL '10 day' AS DATE) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '7 day' AS DATE ) ) 
    );

    IF num_of_sick_contacts > 0 THEN
        RAISE NOTICE 'Not allowed to join session as employee has been in contact with a sick personel in the past 7 days';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER contact_check
BEFORE INSERT OR UPDATE ON Joins
FOR EACH ROW EXECUTE FUNCTION check_contact();

CREATE OR REPLACE FUNCTION check_contact_book()
RETURNS TRIGGER AS $$
DECLARE
    num_of_sick_contacts INTEGER;
BEGIN
    SELECT COUNT (*) INTO num_of_sick_contacts
    FROM Health_Declarations h,
        contact_tracing(NEW.b_eid, NEW.date) c0,
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '1 day' AS DATE ))  c1,
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '2 day' AS DATE ))  c2,
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '3 day' AS DATE ))  c3, 
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '4 day' AS DATE ))  c4,
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '5 day' AS DATE ))  c5, 
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '6 day' AS DATE ))  c6, 
        contact_tracing(NEW.b_eid, CAST ( NEW.date - INTERVAL '7 day' AS DATE ))  c7
    WHERE h.temp > 37.5 AND
    (
        (h.eid = c0 AND h.date >= CAST ( NEW.date - INTERVAL '3 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date AS DATE ) ) OR

        (h.eid = c1 AND h.date >= CAST ( NEW.date - INTERVAL '4 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '1 day' AS DATE ) ) OR

        (h.eid = c2 AND h.date >= CAST ( NEW.date - INTERVAL '5 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '2 day' AS DATE ) ) OR

        (h.eid = c3 AND h.date >= CAST ( NEW.date - INTERVAL '6 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '3 day' AS DATE ) ) OR

        (h.eid = c4 AND h.date >= CAST ( NEW.date - INTERVAL '7 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '4 day' AS DATE ) ) OR

        (h.eid = c5 AND h.date >= CAST ( NEW.date - INTERVAL '8 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '5 day' AS DATE ) ) OR

        (h.eid = c6 AND h.date >= CAST ( NEW.date - INTERVAL '9 day' AS DATE ) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '6 day' AS DATE ) ) OR

        (h.eid = c7 AND h.date >= CAST ( NEW.date - INTERVAL '10 day' AS DATE) AND 
                        h.date <= CAST ( NEW.date - INTERVAL '7 day' AS DATE ) ) 
    );

    IF num_of_sick_contacts > 0 THEN
        RAISE NOTICE 'Not allowed to book session as employee has been in contact with a sick personel in the past 7 days';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER contact_check_book
BEFORE INSERT OR UPDATE ON Sessions
FOR EACH ROW EXECUTE FUNCTION check_contact_book();
