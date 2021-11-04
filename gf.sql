DROP FUNCTION IF EXISTS
    view_booking_report(INTEGER, INTEGER),
    view_future_meeting(DATE, INTEGER),
    view_manager_report(DATE, INTEGER);

CREATE OR REPLACE FUNCTION view_booking_report(IN start_date DATE, IN input_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, is_approved INT) AS $$
    SELECT s.floor AS floor_no, s.room AS room_no, s.date AS meeting_date, s.time AS meeting_time, 
        (SELECT COUNT(*)
        FROM Approves a
        WHERE a.time = s.time
        AND a.date = s.date
        AND a.room = s.room
        AND a.floor = s.floor
        AND a.b_eid = input_eid) AS is_approved
    FROM Sessions s
    WHERE s.date >= start_date
    AND s.b_eid = input_eid
    ORDER BY s.date, s.time;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION view_future_meeting(IN start_date DATE, IN input_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT) AS $$
    SELECT j.floor AS floor_no, j.room AS room_no, j.date AS meeting_date, j.time AS meeting_time
    FROM Joins j, Approves a
    WHERE j.time = a.time
    AND j.date = a.date
    AND j.room = a.room
    AND j.floor = a.floor
    AND j.b_eid = a.b_eid
    AND j.e_eid = input_eid
    AND j.date >= start_date
    ORDER BY j.date, j.time;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION view_manager_report(IN start_date DATE, IN input_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, booker_id INT) AS $$
    SELECT s.floor AS floor_no, s.room AS room_no, s.date AS meeting_date, s.time AS meeting_time, s.b_eid AS booker_id
    FROM Sessions s
    WHERE NOT EXISTS (SELECT * 
        FROM Approves a 
        WHERE s.time = a.time
        AND s.date = a.date
        AND s.room = a.room
        AND s.floor = a.floor
        AND s.b_eid = a.b_eid)
    AND s.date >= start_date
    AND EXISTS (SELECT r.room, r.floor
        FROM Employees e, Managers m, Meeting_Rooms r
        WHERE e.eid = m.eid
        AND e.did = r.did
        AND r.room = s.room
        AND r.floor = s.floor
        AND e.eid = input_eid)
    ORDER BY s.date, s.time;
$$ LANGUAGE sql;
