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
        RAISE NOTICE 'This employee has resigned';
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
$$LANGUAGE plpgsql;

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
    WHERE u.room = NEW.room AND u.floor = NEW.floor AND u.date >= NEW.date;

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

    SELECT j2.e_eid as e_eid
    FROM Approves s, Joins j1, Joins j2
    -- get participants of approved meetings
    WHERE (s.room, s.floor, s.date, s.time, s.b_eid) = (j1.room, j1.floor, j1.date, j1.time, s.b_eid)
    -- get sessions that eid was in in the past 3 days
    AND j1.e_eid = sick_eid AND (j1.date = sick_date OR j1.date = sick_date - INTERVAL '1 day' OR j1.date = sick_date - INTERVAL '2 day' OR j1.date = sick_date - INTERVAL '3 day')
    -- get close contacts;
    AND (j1.room, j1.floor, j1.date, j1.time, j1.b_eid) = (j2.room, j2.floor, j2.date, j2.time, j2.b_eid)
    
$$ LANGUAGE sql ;

-- TRIGGER FUNC AND TRIGGER TO REMOVE CLOSE CONTACTS FROM 7 DAYS OF SESSIONS
CREATE OR REPLACE FUNCTION rem_close_contacts()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.temp > 37.5 THEN
        RAISE NOTICE 'Close contacts are removed from meetings for the next 7 days
        and bookings made from close contacts are deleted';

        DELETE FROM Joins j USING contact_tracing(NEW.eid, NEW.date) cc 
        WHERE
            j.e_eid = cc AND
            j.date = NEW.date OR j.date = NEW.date + INTERVAL '1 day'OR
            j.date = NEW.date + INTERVAL '2 day'OR j.date = NEW.date + INTERVAL '3 day'OR
            j.date = NEW.date + INTERVAL '4 day'OR j.date = NEW.date + INTERVAL '5 day'OR
            j.date = NEW.date + INTERVAL '6 day'OR j.date = NEW.date + INTERVAL '7 day';
        DELETE FROM Sessions s USING contact_tracing(NEW.eid, NEW.date) cc 
        WHERE
            s.b_eid = cc AND
            s.date = NEW.date OR j.date = NEW.date + INTERVAL '1 day'OR
            s.date = NEW.date + INTERVAL '2 day'OR s.date = NEW.date + INTERVAL '3 day'OR
            s.date = NEW.date + INTERVAL '4 day'OR s.date = NEW.date + INTERVAL '5 day'OR
            s.date = NEW.date + INTERVAL '6 day'OR s.date = NEW.date + INTERVAL '7 day';

    END IF;
RETURN new;
END;
$$LANGUAGE plpgsql;


CREATE TRIGGER close_contact_rem
BEFORE INSERT OR UPDATE ON Health_Declarations
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

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-------------------------------------------APPLICATION FUNCTIONS----------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

---DECLARE HEALTH ---
CREATE OR REPLACE FUNCTION declare_health(eid1 INT, date1 DATE, temp1 FLOAT)
RETURNS VOID AS $$
BEGIN
INSERT INTO Health_Declarations (eid,date,temp) VALUES (eid1,date1,temp1);
END;
$$ LANGUAGE plpgsql;

-- NON_COMPLIANCE ROUTINE --
CREATE OR REPLACE FUNCTION non_compliance(IN start_date DATE, IN end_date DATE)
RETURNS TABLE(id INT, c DOUBLE PRECISION) AS $$

    SELECT e.eid AS id, extract(day FROM end_date::timestamp - start_date::timestamp) - count(h.eid) + 1 AS c
    FROM Employees e 
    LEFT OUTER JOIN  
    (SELECT * FROM Health_Declarations h1 WHERE h1.date >= START_DATE AND h1.date <= end_date)
    AS h ON e.eid = h.eid
    GROUP BY e.eid;

$$ LANGUAGE sql ;




------
-- For 




