DROP FUNCTION IF EXISTS
    check_approval_status(INTEGER, DATE, INTEGER, INTEGER, INTEGER),
    view_booking_report(DATE, INTEGER),
    view_future_meeting(DATE, INTEGER),
    view_manager_report(DATE, INTEGER);

--find all meeting-rooms + their approval-status booked by this employee from the given date onwards
CREATE OR REPLACE FUNCTION check_approval_status(IN meeting_time INT, IN meeting_date DATE, IN meeting_room INT, IN meeting_floor INT, IN meeting_bid INT)
RETURNS VARCHAR(12) AS $$
DECLARE
    num_of_approved INTEGER;
    approved VARCHAR(12) := 'approved';
    not_approved VARCHAR(12) := 'not approved';
BEGIN
    SELECT COUNT (*) INTO num_of_approved
    FROM Approves a
    WHERE a.time = meeting_time
    AND a.date = meeting_date
    AND a.room = meeting_room
    AND a.floor = meeting_floor
    AND a.b_eid = meeting_bid;

    IF num_of_approved > 0 THEN
        RETURN approved;
    ELSE
        RETURN not_approved;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION view_booking_report(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, approval_status VARCHAR(12)) AS $$
BEGIN
    RETURN QUERY
    SELECT s.floor AS floor_no, s.room AS room_no, s.date AS meeting_date, s.time AS meeting_time, 
        (SELECT * FROM check_approval_status(s.time, s.date, s.room, s.floor, s.b_eid)) AS approval_status
    FROM Sessions s
    WHERE s.date >= start_date
    AND s.b_eid = this_eid
    ORDER BY s.date, s.time;
END;
$$ LANGUAGE plpgsql;

--find all approved meetings that this employee has to attend from the given date onwards
CREATE OR REPLACE FUNCTION view_future_meeting(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT) AS $$
BEGIN
    RETURN QUERY
    SELECT j.floor AS floor_no, j.room AS room_no, j.date AS meeting_date, j.time AS meeting_time
    FROM Joins j, Approves a
    WHERE j.time = a.time
    AND j.date = a.date
    AND j.room = a.room
    AND j.floor = a.floor
    AND j.b_eid = a.b_eid
    AND j.e_eid = this_eid
    AND j.date >= start_date
    ORDER BY j.date, j.time;
END;
$$ LANGUAGE plpgsql;

--find all meeting-rooms that require approval from this manager from the given date onwards
CREATE OR REPLACE FUNCTION view_manager_report(IN start_date DATE, IN this_eid INT)
RETURNS TABLE(floor_no INT, room_no INT, meeting_date DATE, meeting_time INT, booker_id INT) AS $$
BEGIN
    RETURN QUERY
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
        AND e.eid = this_eid)
    ORDER BY s.date, s.time;
END;
$$ LANGUAGE plpgsql;
