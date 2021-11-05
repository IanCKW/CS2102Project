-- This file is intended to test all functions and triggers

-- add department
SELECT * FROM add_department('Board');
SELECT * FROM add_department('Human Resources');
SELECT * FROM add_department('Marketing');
SELECT * FROM add_department('Sales');
SELECT * FROM add_department('Information Technology');
SELECT * FROM add_department('Research and Development');
SELECT * FROM add_department('Security');
SELECT * FROM add_department('Liaison');
SELECT * FROM add_department('Reception');
-- All should return INSERT 0 1 and 'Department added'.

-- add employee
SELECT * FROM add_employee('Shelton Emmerson', NULL, 1, 91111111, 61111111, 81111111);
SELECT * FROM add_employee('Chrissie Mirsada', NULL, 2, 92222222, 62222222, 82222222);
SELECT * FROM add_employee('Ermias Nejc', NULL, 3, 93333333, 63333333, 83333333);
SELECT * FROM add_employee('Toma Loui', NULL, 4, 94444444, 64444444, 84444444);
SELECT * FROM add_employee('Gal Ilme', NULL, 5, 95555555, 65555555, 85555555);
SELECT * FROM add_employee('Alfeo Lula', NULL, 6, 96666666, 66666666, 86666666);
SELECT * FROM add_employee('Runar Greet', NULL, 7, 97777777, 67777777, 87777777);
SELECT * FROM add_employee('James Lee', NULL, 7, 98888888, 68888888, 88888888);
SELECT * FROM add_employee('Bilal Shehzad', NULL, 1, 99999999, 69999999, 89999999);
SELECT * FROM add_employee('Visnu Ravindran', NULL, 1, 90000000, 60000000, 80000000);
SELECT * FROM add_employee('Haywood Jablome', NULL, 1, 90222222, 60222222, 80222222);
SELECT * FROM add_employee('Seymour Butts', NULL, 1, 90333333, 60333333, 80333333);
-- All should return INSERT 0 1 and 'Employee added'.

-- Check for NULL employee emails
SELECT COUNT(*) FROM Employees WHERE email IS NULL; -- Returns 0;

-- Test ISA hierarchy
INSERT INTO Bookers VALUES(1); -- INSERT 0 1
INSERT INTO Juniors VALUES(1); -- INSERT 0 0

INSERT INTO Managers VALUES(1); -- INSERT 0 1
INSERT INTO Seniors VALUES (1); -- INSERT 0 0

INSERT INTO Bookers VALUES(2); -- INSERT 0 1
INSERT INTO Juniors VALUES(2); -- INSERT 0 0

INSERT INTO Seniors VALUES (2); -- INSERT 0 1
INSERT INTO Managers VALUES(2); -- INSERT 0 0

INSERT INTO Juniors VALUES(7); -- INSERT 0 1
INSERT INTO Bookers VALUES(7); -- INSERT 0 0

INSERT INTO Bookers VALUES(8); -- INSERT 0 1
INSERT INTO Managers VALUES(8); -- INSERT 0 1

INSERT INTO Bookers VALUES (9) -- INSERT 0 1
INSERT INTO Seniors VALUES (9) -- INSERT 0 1

INSERT INTO Bookers VALUES (10) -- INSERT 0 1
INSERT INTO Seniors VALUES (10) -- INSERT 0 1

INSERT INTO Bookers VALUES(11); -- INSERT 0 1
INSERT INTO Managers VALUES(11); -- INSERT 0 1

INSERT INTO Bookers VALUES(12); -- INSERT 0 1
INSERT INTO Managers VALUES(12); -- INSERT 0 1

-- add meeting room
SELECT * FROM add_room(1, 10, 'Main Boardroom', 1, 12, '2021-11-04', 1);
SELECT * FROM add_room(1, 1, 'Spare Boardroom', 7, 12, '2021-11-04', 8);

-- change capacity
SELECT * FROM change_capacity(1, 10, 10, '2021-11-05', 1);
-- Should return INSERT 0 1, 'Room Capacity Changed'
SELECT * FROM change_capacity(1, 1, 10, '2021-11-05', 1);
-- Should return UPDATE 0, 'The manager doesnt come from the same dep as the meeting room'

-- remove department
SELECT * FROM remove_department(8);
SELECT * FROM remove_department(9);
-- Should return DELETE 1 and 'Department removed'.
SELECT * FROM remove_department(1);
SELECT * FROM remove_department(2);
SELECT * FROM remove_department(3);
SELECT * FROM remove_department(4);
SELECT * FROM remove_department(5);
SELECT * FROM remove_department(6);
SELECT * FROM remove_department(7);
-- Should return DELETE 0 and 'Unable to delete department'.

-- remove employee
SELECT * FROM remove_employee(7, '2021-11-05');
-- Should return UPDATE 1 and 'Employee removed'.

-- remove department
SELECT * FROM remove_department(7);
-- Should return DELETE 0 and 'Unable to delete department'.

-- remove meeting room (should cascade to updates)
DELETE FROM Meeting_Rooms WHERE room = 1 AND floor = 1; -- DELETE 1

-- remove department
SELECT * FROM remove_department(7);
-- Should return DELETE 1 and 'Department removed'.

-- book session
SELECT * FROM book_room(1, 1, '2021-11-08', 10, 13, 1);
-- Returns a few INSERT 0 1s and 'Room Booked'
SELECT * FROM approve_meeting(1, 1, '2021-11-08', 10, 13, 1, 1);
-- Returns a few INSERT 0 1s and 'Meeting Approved'

-- double booking
SELECT * FROM book_room(1, 1, '2021-11-08', 10, 13, 2);
-- Returns a few INSERT 0 0s and 'There is already an approved session of the same time, date, room, and floor'

SELECT * FROM book_room(1, 1, '2021-11-10', 10, 13, 2);
-- Returns a few INSERT 0 1s and 'Room Booked'

-- booker removed
SELECT * FROM leave_meeting(1, 1, '2021-11-10', 10, 13, 2, 2);
SELECT COUNT(*) FROM Sessions WHERE b_eid = 2; -- Returns 0

SELECT * FROM remove_employee(9); -- UPDATE 1 and 'Employee removed'
SELECT * FROM remove_employee(8); -- UPDATE 1 and 'Employee removed'

SELECT * FROM book_room(1, 1, '2021-11-09', 10, 13, 9);
-- Returns a few INSERT 0 0s and 'Booker has resigned'
SELECT * FROM approve_meeting(1, 1, '2021-11-09', 10, 13, 1, 8);
-- Returns a few INSERT 0 0s and 'Approver has resigned'
SELECT * FROM change_capacity(1, 1, 6, '2021-11-09', 8);
-- Returns a few INSERT 0 0s and 'Updater has resigned'

-- Check joins, approves and sessions asscoiated with eid 1
SELECT COUNT(*) FROM Joins WHERE e_eid = 1; -- Returns 1
SELECT COUNT(*) FROM Sessions WHERE b_eid = 1; -- Returns 1
SELECT COUNT(*) FROM Approves WHERE m_eid = 1; -- Returns 1

-- attempt to leave approved session
SELECT * FROM leave_meeting(1, 1, '2021-11-08', 10, 13, 1, 1);
-- Returns a few DELETE 0s 'Cannot join or leave approved session'

SELECT * FROM remove_employee(1); -- UPDATE 1 and 'Employee removed'

SELECT COUNT(*) FROM Joins WHERE e_eid = 1; -- Returns 0
SELECT COUNT(*) FROM Sessions WHERE b_eid = 1; -- Returns 0
SELECT COUNT(*) FROM Approves WHERE m_eid = 1; -- Returns 0

SELECT * FROM book_room(1, 1, '2021-11-09', 15, 16, 2); -- Room Booked
SELECT * FROM join_meeting(1, 1, '2021-11-09', 15, 16, 10); -- 
SELECT * FROM book_room(1, 1, '2021-11-11', 10, 13, 2);
SELECT * FROM book_room(1, 1, '2021-11-13', 22, 23, 11);
SELECT * FROM join_room(1, 1, '2021-11-13', 22, 23, 11, 10);
-- attempted approval by manager by different department
SELECT * FROM approve_meeting(1, 1, '2021-11-09', 15, 2)
-- regular approvals
SELECT * FROM approve_meeting(1, 1, '2021-11-09', 15, 16, 2, 11);
SELECT * FROM approve_meeting(1, 1, '2021-11-11', 10, 13, 2, 11);
-- Returns a few INSERT 0 1s and 'Room Booked'

-- remove future meetings booked by someone with a fever
-- reject their attempts to book as well
SELECT * FROM declare_health(2, '2021-11-10', 39.0); -- INSERT 0 1
SELECT * FROM book_room(1, 1, '2021-11-11', 15, 16, 2); -- INSERT 0 0
SELECT COUNT(*) FROM Sessions WHERE b_eid = 2 AND date > '2021-11-10'; -- Returns 0

-- try to join despite being a close contact
SELECT * FROM book_room(1, 1, '2021-11-11', 22, 23, 11);
SELECT * FROM join_meeting(1, 1, '2021-11-11', 22, 23, 11, 10); -- INSERT 0 0

-- try to book despite being a close contact
SELECT * FROM book_room(1, 1, '2021-11-11', 22, 23, 10); -- INSERT 0 0

-- removal of close contact from joins in the next 7 days
SELECT COUNT(*) FROM Joins WHERE b_eid = 11 AND e_eid = 10 AND date = '2021-11-13';
-- Returns 0
