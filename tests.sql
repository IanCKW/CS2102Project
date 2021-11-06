-- APPROVES

-- insert into Meeting_Rooms (room, floor, rname, did) values (8, 10, 'Osaka', 9);
-- insert into Meeting_Rooms (room, floor, rname, did) values (7, 9, 'Manokwari', 8);

-- insert into Updates (date, new_cap, room, floor) values ('2020-07-01', 10, 8, 10);
-- insert into Updates (date, new_cap, room, floor) values ('2020-07-01', 10, 7, 9);

-- insert into Sessions (time, date, room, floor, eid) values (1900, '2021-07-23', 8, 10, 7);
-- insert into Sessions (time, date, room, floor, eid) values (1200, '2020-12-30', 7, 9, 87);

DROP TRIGGER IF EXISTS approves_check ON Approves;
insert into Approves (time, date, room, floor,b_eid, m_eid) values (19, '2022-07-23', 8, 10, 7,42);
insert into Approves (time, date, room, floor,b_eid, m_eid) values (12, '2022-12-30', 7, 9, 87, 80);
insert into Approves (time, date, room, floor,b_eid, m_eid) values (19, '2022-07-25', 8, 10, 7,42);


-- UPDATES
insert into Updates (date, new_cap, room, floor,m_eid) values ('2020-07-02', 10, 8, 10, 42);


-- CLOSE CONTACTS
SELECT * FROM contact_tracing(87,'2022-12-30');
select * from contact_tracing(54, '2021-07-24');



-- JOIN REMOVAL
insert into Health_Declarations(date, temp, eid) values ('2021/07/25',37.8,54);


-- BOOKING + APPROVAL REMOVAL
insert into Health_Declarations(date, temp, eid) values ('2021/07/23',37.8,7);


-- NON COMPLIANCE
select * from non_compliance('2021/07/23', '2021/07/25');


-- RESIGNATION
update Employees set resigned_date =  '2023-01-01' where eid = 3;
insert into Joins (time, date, room, floor, b_eid, e_eid) values (12, '2022-12-30', 7, 9,87, 3);

-------------
--DROPPING --
DROP FUNCTION <function>  


---- ADI
insert into Bookers(eid) values ( 91 );
insert into Managers(eid) values ( 91 );