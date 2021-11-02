
-- checks that the manager is from the same department as the meeting room
CREATE OR REPLACE FUNCTION check_manager_from_same_dep_as_mr()
RETURNS TRIGGER AS $$
DECLARE
    m_department_id INTEGER; -- manager
    target_department_id INTEGER; -- session or update

BEGIN
    
    select COALESCE(e.did,-1) into m_department_id 
    from Employees e, Managers m
    where e.eid = m.eid AND NEW.m_eid = m.eid;

    select COALESCE(mr.did, -1) into target_department_id
    from Meeting_Rooms mr
    where mr.room = NEW.room AND mr.floor = NEW.floor;

    if  m_department_id <> target_department_id then
        RAISE NOTICE 'The manager doesnt come from the same dep as the meeting room';
        return NULL;
    else
        return NEW;
    end if;

END;
$$LANGUAGE plpgsql;

CREATE TRIGGER approves_check
BEFORE INSERT OR UPDATE ON Approves
FOR EACH ROW 
EXECUTE FUNCTION check_manager_from_same_dep_as_mr();

-- insert into Meeting_Rooms (room, floor, rname, did) values (8, 10, 'Osaka', 9);
-- insert into Meeting_Rooms (room, floor, rname, did) values (7, 9, 'Manokwari', 8);

-- insert into Updates (date, new_cap, room, floor) values ('2020-07-01', 10, 8, 10);
-- insert into Updates (date, new_cap, room, floor) values ('2020-07-01', 10, 7, 9);

-- insert into Sessions (time, date, room, floor, eid) values (1900, '2021-07-23', 8, 10, 7);
-- insert into Sessions (time, date, room, floor, eid) values (1200, '2020-12-30', 7, 9, 87);

DROP TRIGGER IF EXISTS approves_check ON Approves;
insert into Approves (time, date, room, floor,b_eid, m_eid) values (19, '2021-07-23', 8, 10, 7,63);
insert into Approves (time, date, room, floor,b_eid, m_eid) values (12, '2020-12-30', 7, 9, 87, 80);


-- Checks that the Manager adding to Updates is from the same department as the meeting room that it is updating

CREATE TRIGGER updates_check
BEFORE INSERT OR UPDATE ON Updates
FOR EACH ROW 
EXECUTE FUNCTION check_manager_from_same_dep_as_mr();


insert into Updates (date, new_cap, room, floor,m_eid) values ('2020-07-02', 10, 8, 10, 42);


-- Create a function that can find everyone that is a close contact
CREATE OR REPLACE FUNCTION close_contacts(IN sick_eid INT, IN sick_date DATE)
RETURNS SETOF INT AS $$

    SELECT j2.e_eid as e_eid
    from Approves a, Sessions s, Joins j1, Joins j2
    -- get approved sessions
    where a.room = s.room AND a.floor = s.floor AND a.date = s.date AND a.time = s.time AND a.b_eid = s.b_eid
    -- get participants of approved meetings
    AND a.room = j1.room AND a.floor = j1.floor AND a.date = j1.date AND a.time = j1.time
    -- get sessions that eid was in in the past 3 days
    AND j1.e_eid = sick_eid AND (j1.date = sick_date OR j1.date = sick_date + INTERVAL '-1 day' OR j1.date = sick_date + INTERVAL '-2 day' OR j1.date = sick_date + INTERVAL '-3 day')
    -- get close contacts;
    AND j1.room = j2.room AND j1.floor = j2.floor AND j1.date = j2.date AND j1.time = j2.time AND j1.b_eid = j2.b_eid;
    
$$ LANGUAGE sql ;


CREATE OR REPLACE FUNCTION rem_close_contacts()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.temp > 37.0 then
        Delete FROM Joins j USING close_contacts(NEW.eid, NEW.date) cc 
        WHERE
            j.e_eid = cc AND
            j.date = NEW.date OR j.date = NEW.date + INTERVAL '1 day'OR
            j.date = NEW.date + INTERVAL '2 day'OR j.date = NEW.date + INTERVAL '3 day'OR
            j.date = NEW.date + INTERVAL '4 day'OR j.date = NEW.date + INTERVAL '5 day'OR
            j.date = NEW.date + INTERVAL '6 day'OR j.date = NEW.date + INTERVAL '7 day';
    end if;
Return new;
END;
$$LANGUAGE plpgsql;



-- SELECT * FROM close_contacts(87,'2020-12-30');
CREATE TRIGGER close_contact_rem
BEFORE INSERT OR UPDATE ON Health_Declarations
FOR EACH ROW 
EXECUTE FUNCTION rem_close_contacts();

 insert into Health_Declarations(date, temp, eid) values ('2020/07/24',37.8,54);