-- This file is intended to test all functions and triggers except resignation and contact tracing

-- add department
SELECT * FROM add_department(0, 'Resigned');
SELECT * FROM add_department(1, 'Board');
SELECT * FROM add_department(2, 'Human Resources');
SELECT * FROM add_department(3, 'Marketing');
SELECT * FROM add_department(4, 'Sales');
SELECT * FROM add_department(5, 'Information Technology');
SELECT * FROM add_department(6, 'Research and Development');
SELECT * FROM add_department(7, 'Security');
SELECT * FROM add_department(8, 'Liaison');
SELECT * FROM add_department(9, 'Reception');
-- All should return INSERT 0 1 and 'Department added'.

-- add employee
SELECT * FROM add_employee('Shelton Emmerson', 1, 91111111, 61111111, 81111111);
SELECT * FROM add_employee('Chrissie Mirsada', 2, 92222222, 62222222, 82222222);
SELECT * FROM add_employee('Ermias Nejc', 3, 93333333, 63333333, 83333333);
SELECT * FROM add_employee('Toma Loui', 4, 94444444, 64444444, 84444444);
SELECT * FROM add_employee('Gal Ilme', 5, 95555555, 65555555, 85555555);
SELECT * FROM add_employee('Alfeo Lula', 6, 96666666, 66666666, 86666666);
SELECT * FROM add_employee('Runar Greet', 7, 97777777, 67777777, 87777777);
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

-- Add meeting room and check for associated updates
SELECT * FROM add_room(1, 10, 'Main Boardroom', 1, 12, '2021-11-04', 1); -- INSERT 0 1
SELECT COUNT(*) FROM Updates WHERE room = 1 AND floor = 10; -- Returns 1
SELECT * FROM add_room(1, 1, 'Spare Boardroom', 7, 12, '2021-11-04', 1); -- INSERT 0 1
SELECT COUNT(*) FROM Updates WHERE room = 1 AND floor = 1; -- Returns 1

-- Remove employee
SELECT * FROM remove_employee(7, '2021-11-05'); -- Should return 'Employee removed'.

-- Remove meeting room (should cascade to updates)
DELETE FROM Meeting_Rooms WHERE room = 1 AND floor = 1; -- DELETE 1

-- Remove department
SELECT * FROM remove_department(7); -- Should return 'Department removed'.

-- Attempt to book meeting in the past
SELECT * FROM book_room(10, 1, '2021-11-01', 9, 11, 1); -- Should return 'Cannot book in the past'

-- Normal booking
SELECT * FROM book_room(10, 1, '2022-01-01', 9, 11, 1); -- Should return 'Room Booked'

-- Unbook normal booking
SELECT * FROM unbook_room(10, 1, '2022-01-01', 9, 11, 1); -- Should return 'Room Unooked'

-- Normal Booking #2
SELECT * FROM book_room(10, 1, '2022-01-02', 9, 11, 1); -- Should return 'Room Booked'

-- Others join a normal booking
SELECT * FROM join_meeting(10, 1, '2022-01-02', 9, 11, 1, 2); -- Should return 'Joined Meeting'
SELECT COUNT(*) FROM Joins; -- Should return 4

-- Others leave a normal booking
SELECT * FROM leave_meeting(10, 1, '2022-01-02', 9, 11, 1, 2);
SELECT COUNT(*) FROM Joins; -- Should return 2

-- Attempted approval by manager from different department
SELECT * FROM add_employee('James Lee', 2, 98888888, 68888888, 88888888);
INSERT INTO Bookers VALUES(8);
INSERT INTO Managers VALUES(8);
SELECT * FROM approve_meeting(10, 1, '2022-01-02', 9, 11, 1, 8);
-- Should return 'The manager doesnt come from the same dep as the meeting room'

-- Approve normal booking
SELECT * FROM approve_meeting(10, 1, '2022-01-02', 9, 11, 1, 1);
-- Should return 'Booking approved'

-- Double Booking
SELECT * FROM book_room(10, 1, '2022-01-02', 9, 11, 2);
-- Should return 'There is already an approved session of the same time, date, room, and floor';

-- Attempt to join approved booking
SELECT * FROM join_meeting(10, 1, '2022-01-02', 9, 11, 1, 2);
SELECT COUNT(*) FROM Joins; -- Should return 2

-- Attempt to leave approved booking
SELECT * FROM leave_meeting(10, 1, '2022-01-02', 9, 11, 1, 1);
SELECT COUNT(*) FROM Joins; -- Should return 2

-- Normal booking #3
SELECT * FROM book_room(10, 1, '2022-01-03', 9, 11, 1); -- Should return 'Room Booked'

-- Booker leaves
SELECT * FROM join_meeting(10, 1, '2022-01-03', 9, 11, 1, 2);
SELECT COUNT(*) FROM Joins; -- Should return 6
SELECT * FROM leave_meeting(10, 1, '2022-01-03', 9, 11, 1, 1);
SELECT COUNT(*) FROM Joins; -- Should return 2

-- Update capacity by wrong manager
SELECT * FROM change_capacity(1, 10, 2, '2022-01-03', 8);

-- Update Capacity to 2 by correct manager
SELECT * FROM change_capacity(1, 10, 1, '2022-01-03', 1);

-- Attempt to join a max capacity meeting
SELECT * FROM book_room(10, 1, '2022-01-04', 9, 11, 1);
SELECT * FROM join_meeting(10, 1, '2022-01-04', 9, 11, 1, 2);
SELECT * FROM Joins; -- Should return 4
